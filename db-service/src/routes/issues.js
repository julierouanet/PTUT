const express = require('express');
const path    = require('path');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { TECH_ROLES, rolesCsv } = require('../utils/roles');
const { AUTH_SERVICE_URL, INTERNAL_SECRET, UPLOAD_DIR } = require('../config');
const { sendPushToRoles } = require('../utils/push_sender');
const { photoUpload } = require('../middleware/upload');

// ── Helpers d'envoi d'email vers auth-service (fire-and-forget) ───────────────

/**
 * Notifie un utilisateur spécifique via l'endpoint interne d'auth-service.
 * @param {object} opts - { type, to_email, to_name, user_id, payload }
 */
async function _notifyUser({ type, to_email, to_name, user_id, payload }) {
  if (!to_email) return;
  await fetch(`${AUTH_SERVICE_URL}/internal/notifications/send-email`, {
    method:  'POST',
    headers: {
      'Content-Type':       'application/json',
      'x-internal-secret':  INTERNAL_SECRET,
    },
    body: JSON.stringify({ type, to_email, to_name, user_id, payload }),
  });
}

/**
 * Notifie tous les utilisateurs des rôles spécifiés via l'endpoint interne.
 * @param {string[]} roles
 * @param {string}   type
 * @param {object}   payload
 */
async function _notifyRoles(roles, type, payload) {
  await fetch(`${AUTH_SERVICE_URL}/internal/notifications/send-to-roles`, {
    method:  'POST',
    headers: {
      'Content-Type':       'application/json',
      'x-internal-secret':  INTERNAL_SECRET,
    },
    body: JSON.stringify({ roles, type, payload }),
  });
}

const router = express.Router();

const VALID_STATUSES    = ['Reported', 'Acknowledged', 'Assigned', 'In Progress', 'Waiting Materials', 'Completed', 'Verified', 'Closed', 'Redirected'];
const VALID_URGENCIES   = ['Faible', 'Moyen', 'Urgent', 'Critique'];
const VALID_ISSUE_TYPES = ['Panne', 'Maintenance', 'Inspection', 'Autre'];
const VALID_GROUPS      = ['Biomédical', 'Infrastructure', 'IT'];

// Mapping groupe d'incident -> rôle spécialisé requis pour l'assignation.
const GROUP_TO_ROLE = {
  'Biomédical':     'technician_biomedical',
  'IT':             'technician_it',
  'Infrastructure': 'technician_infra',
};


// GET /api/issues
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { status, department, equipment_id } = req.query;

  let query = 'SELECT * FROM issues WHERE 1=1';
  const params = [];

  if (status)       { query += ' AND status = ?';       params.push(status); }
  if (department)   { query += ' AND department = ?';   params.push(department); }
  if (equipment_id) { query += ' AND equipment_id = ?'; params.push(equipment_id); }

  query += ' ORDER BY created_at DESC';

  res.json(db.prepare(query).all(...params));
});

// GET /api/issues/:id — retourne l'incident enrichi avec équipement, logs d'audit et maintenance
router.get('/:id', verifyToken, (req, res) => {
  const db = getDb();
  const issue = db.prepare('SELECT * FROM issues WHERE id = ?').get(req.params.id);

  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  // Données d'équipement lié (si applicable)
  const equipment = issue.equipment_id
    ? db.prepare('SELECT * FROM equipment WHERE id = ?').get(issue.equipment_id)
    : null;

  // Timeline d'audit : tous les logs liés à cet incident, ordre chronologique
  const auditLog = db.prepare(
    "SELECT id, timestamp, user_name, user_role, action, details FROM logs WHERE target_type = 'issue' AND target_id = ? ORDER BY timestamp ASC"
  ).all(req.params.id);

  // Enregistrements de maintenance liés à l'équipement (10 plus récents)
  const maintenanceRecords = issue.equipment_id
    ? db.prepare(
        'SELECT * FROM maintenance_records WHERE equipment_id = ? ORDER BY date DESC LIMIT 10'
      ).all(issue.equipment_id)
    : [];

  res.json({
    ...issue,
    equipment:           equipment   || null,
    audit_log:           auditLog,
    maintenance_records: maintenanceRecords,
  });
});

// GET /api/issues/:id/assignable-technicians
// Retourne la liste des techniciens spécialisés actifs compatibles avec le
// `assigned_group` de l'incident. Appelle auth-service en proxifiant le JWT
// du caller (la route ?role= y est accessible à tout utilisateur authentifié).
router.get('/:id/assignable-technicians', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), async (req, res) => {
  const db = getDb();
  const issue = db.prepare('SELECT id, assigned_group FROM issues WHERE id = ?').get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  const requiredRole = GROUP_TO_ROLE[issue.assigned_group];
  if (!requiredRole) {
    return res.status(400).json({ error: `Groupe invalide ou absent sur cet incident (${issue.assigned_group || 'null'})` });
  }

  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ error: 'Authorization header manquant' });
  }

  try {
    const url = `${AUTH_SERVICE_URL}/api/users?role=${encodeURIComponent(requiredRole)}`;
    const resp = await fetch(url, { headers: { authorization: authHeader } });
    if (!resp.ok) {
      const txt = await resp.text().catch(() => '');
      console.error(`[DB] Échec appel auth-service (${resp.status}): ${txt.substring(0, 200)}`);
      return res.status(502).json({ error: 'auth-service indisponible' });
    }
    const users = await resp.json();
    res.json(users);
  } catch (err) {
    console.error('[DB] Erreur fetch auth-service:', err.message);
    res.status(502).json({ error: 'Impossible de contacter auth-service' });
  }
});

// POST /api/issues - signaler un incident (équipement, lieu/infrastructure, ou catégorie libre)
router.post('/', verifyToken, (req, res) => {
  const db = getDb();
  const {
    id, equipment_id, equipment_name, location_id, location_text, location_tag, department,
    type, description, reporter, reporter_id, reporter_email, reporter_phone, urgency,
    issue_category: reqCategory, assigned_group: reqGroup,
  } = req.body;

  const hasEquipment     = equipment_id && equipment_name;
  const hasEquipmentName = !equipment_id && !!equipment_name; // nom seul (équipement non répertorié)
  const hasLocation      = !!location_id;
  const hasLocText    = !!(location_text && location_text.trim());
  const isAutre       = reqCategory === 'Autre';
  const isInfra       = reqCategory === 'Infrastructure';

  if (!id || (!hasEquipment && !hasEquipmentName && !hasLocation && !hasLocText && !isAutre && !isInfra) || !department || !type || !description || !reporter) {
    return res.status(400).json({ error: 'Champs requis manquants' });
  }

  // Validation format
  if (!/^[a-zA-Z0-9_-]+$/.test(id) || id.length > 100) {
    return res.status(400).json({ error: 'ID invalide' });
  }
  if (description.length > 2000) {
    return res.status(400).json({ error: 'Description trop longue (max 2000 caractères)' });
  }
  if (urgency && !VALID_URGENCIES.includes(urgency)) {
    return res.status(400).json({ error: `Urgence invalide. Valeurs acceptées : ${VALID_URGENCIES.join(', ')}` });
  }

  // Validation catégorie/groupe explicites
  const VALID_CATEGORIES = [...VALID_GROUPS, 'Autre'];
  if (reqCategory && !VALID_CATEGORIES.includes(reqCategory)) {
    return res.status(400).json({ error: `Catégorie invalide. Valeurs acceptées : ${VALID_CATEGORIES.join(', ')}` });
  }
  if (reqGroup && !VALID_GROUPS.includes(reqGroup)) {
    return res.status(400).json({ error: `Groupe invalide. Valeurs acceptées : ${VALID_GROUPS.join(', ')}` });
  }

  const urgencyValue    = urgency || 'Moyen';
  const derivedCategory = reqCategory || (hasEquipment ? 'Biomédical' : 'Infrastructure');
  const derivedGroup    = (reqGroup && VALID_GROUPS.includes(reqGroup))
    ? reqGroup
    : isAutre ? null : (hasEquipment ? 'Biomédical' : 'Infrastructure');

  try {
    db.prepare(`
      INSERT INTO issues (id, equipment_id, equipment_name, location_id, location_text, location_tag, issue_category, assigned_group, department, type, description, reporter, reporter_id, reporter_email, reporter_phone, urgency, created_at, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'), 'Reported')
    `).run(
      id,
      equipment_id   || null,
      equipment_name || null,
      location_id    || null,
      location_text  || null,
      location_tag   || null,
      derivedCategory,
      derivedGroup,
      department, type, description, reporter,
      reporter_id    || null,
      reporter_email || null,
      reporter_phone || null,
      urgencyValue
    );

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
      action: 'create_issue', target_type: 'issue', target_id: id,
      target_name: equipment_name || location_id || department,
      details: { type, department, category: derivedCategory, group: derivedGroup },
      ...extractReqMeta(req) });

    // ── Notification push aux techniciens du groupe concerné ─────────────────
    // Async non-bloquant : la réponse HTTP est envoyée avant l'envoi push.
    const targetRoles = derivedGroup ? [GROUP_TO_ROLE[derivedGroup]].filter(Boolean) : [];
    if (targetRoles.length) {
      setImmediate(() => {
        sendPushToRoles(targetRoles, {
          title: `Nouvel incident — ${urgencyValue}`,
          body:  `${department} : ${description.substring(0, 100)}`,
          icon:  '/icons/Icon-192.png',
          data:  { issueId: id },
        }).catch(() => {});
      });
    }

    // ── Email aux techniciens du groupe si incident CRITIQUE (fire-and-forget) ─
    if (urgencyValue === 'Critique' && targetRoles.length) {
      setImmediate(() => {
        _notifyRoles(targetRoles, 'critical_new_issue', {
          issue_id:       id,
          equipment_name: equipment_name || null,
          department,
          urgency:        urgencyValue,
          reporter_name:  reporter,
          description:    description,
        }).catch(() => {});
      });
    }

    res.status(201).json({ message: 'Incident signalé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) return res.status(409).json({ error: 'ID déjà utilisé' });
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/issues/:id - mettre à jour un incident
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { status, assigned_technician, diagnosis, actions, parts_replaced, urgency, assigned_group, taken_at, parts_consumed } = req.body;

  const existing = db.prepare(
    'SELECT id, equipment_name, location_id, status, department, assigned_group, urgency, diagnosis, assigned_technician, created_at FROM issues WHERE id = ?'
  ).get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  // Validation enum statut, urgence et groupe
  if (status && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `Statut invalide. Valeurs acceptées : ${VALID_STATUSES.join(', ')}` });
  }
  if (urgency && !VALID_URGENCIES.includes(urgency)) {
    return res.status(400).json({ error: `Urgence invalide. Valeurs acceptées : ${VALID_URGENCIES.join(', ')}` });
  }
  if (assigned_group && !VALID_GROUPS.includes(assigned_group)) {
    return res.status(400).json({ error: `Groupe invalide. Valeurs acceptées : ${VALID_GROUPS.join(', ')}` });
  }

  // Déstockage transactionnel si des pièces ont été consommées
  if (Array.isArray(parts_consumed) && parts_consumed.length > 0) {
    try {
      const destock = db.transaction((consumed) => {
        for (const { item_id, quantity } of consumed) {
          if (!item_id || typeof quantity !== 'number' || quantity <= 0) continue;
          const item = db.prepare('SELECT id, name, current_stock FROM inventory WHERE id = ?').get(item_id);
          if (!item) throw new Error(`Pièce introuvable : ${item_id}`);
          const newStock = item.current_stock - quantity;
          if (newStock < 0) throw new Error(`Stock insuffisant pour "${item.name}" (stock : ${item.current_stock}, demandé : ${quantity})`);
          db.prepare(`UPDATE inventory SET current_stock = ?, updated_at = datetime('now','localtime') WHERE id = ?`).run(newStock, item_id);
        }
      });
      destock(parts_consumed);
    } catch (err) {
      return res.status(409).json({ error: err.message });
    }
  }

  db.prepare(`
    UPDATE issues
    SET status = COALESCE(?, status),
        assigned_technician = COALESCE(?, assigned_technician),
        diagnosis = COALESCE(?, diagnosis),
        actions = COALESCE(?, actions),
        parts_replaced = COALESCE(?, parts_replaced),
        urgency = COALESCE(?, urgency),
        assigned_group = COALESCE(?, assigned_group),
        taken_at = COALESCE(?, taken_at),
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(status, assigned_technician, diagnosis, actions, parts_replaced, urgency, assigned_group || null, taken_at || null, req.params.id);

  const groupChanged = assigned_group && assigned_group !== existing.assigned_group;
  const actionLabel = status && status !== existing.status ? `issue_status_${status.toLowerCase().replace(/\s+/g, '_')}` : 'update_issue';

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: actionLabel, target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: {
      ...(status ? { old_status: existing.status, new_status: status } : {}),
      ...(groupChanged ? { old_group: existing.assigned_group, new_group: assigned_group } : {}),
      ...(parts_consumed?.length ? { parts_consumed } : {}),
    },
    ...extractReqMeta(req) });

  // ── Notifications email sur incidents CRITIQUES uniquement (fire-and-forget) ─
  // L'urgence effective est celle stockée en DB (avant la mise à jour)
  // OU celle envoyée dans le body (mise à jour concomitante).
  const effectiveUrgency = urgency || existing.urgency;
  const isCritique       = effectiveUrgency === 'Critique';

  if (isCritique) {
    const issueId     = req.params.id;
    const equip       = existing.equipment_name;
    const dept        = existing.department;
    const techName    = assigned_technician || req.user.name;
    const supervisors = ['supervisor', 'admin'];

    // 1. Technicien prend en charge (status → In Progress ET technicien assigné)
    const technicianJustAssigned = status === 'In Progress'
      && !existing.assigned_technician
      && (assigned_technician || req.user.name);

    if (technicianJustAssigned) {
      setImmediate(() => {
        _notifyRoles(supervisors, 'critical_acknowledged', {
          issue_id:        issueId,
          equipment_name:  equip,
          department:      dept,
          technician_name: techName,
        }).catch(() => {});
      });
    }

    // 2. Diagnostic posé pour la première fois
    const diagnosisJustSet = diagnosis
      && diagnosis.trim().length > 0
      && !existing.diagnosis;

    if (diagnosisJustSet) {
      setImmediate(() => {
        _notifyRoles(supervisors, 'critical_diagnosed', {
          issue_id:        issueId,
          equipment_name:  equip,
          department:      dept,
          technician_name: techName,
          diagnosis:       diagnosis.trim(),
        }).catch(() => {});
      });
    }

    // 3. Incident marqué Completed → KPIs de résolution
    if (status === 'Completed' && existing.status !== 'Completed') {
      const resolvedAt = new Date().toISOString();
      // Récupérer les données à jour (diagnosis/actions/parts peuvent être dans ce même PUT)
      const finalDiag    = diagnosis       || existing.diagnosis;
      const finalActions = actions         || null;
      const finalParts   = parts_replaced  || null;

      setImmediate(() => {
        _notifyRoles(supervisors, 'critical_resolved', {
          issue_id:        issueId,
          equipment_name:  equip,
          department:      dept,
          technician_name: techName,
          created_at:      existing.created_at,
          resolved_at:     resolvedAt,
          diagnosis:       finalDiag,
          actions:         finalActions,
          parts_replaced:  finalParts,
        }).catch(() => {});
      });
    }
  }

  res.json({ message: 'Incident mis à jour' });
});

// ── PATCH /api/issues/:id/escalate ───────────────────────────────────────────
// Suspend l'incident sur place (Waiting Materials ou Redirected) avec commentaire obligatoire.
router.patch('/:id/escalate', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { escalation_status, escalation_comment } = req.body;

  const VALID_ESCALATION_STATUSES = ['Waiting Materials', 'Redirected'];
  if (!escalation_status || !VALID_ESCALATION_STATUSES.includes(escalation_status)) {
    return res.status(400).json({ error: `escalation_status invalide. Valeurs acceptées : ${VALID_ESCALATION_STATUSES.join(', ')}` });
  }
  if (!escalation_comment || escalation_comment.trim().length < 10) {
    return res.status(400).json({ error: 'escalation_comment est requis (min 10 caractères)' });
  }

  const existing = db.prepare('SELECT * FROM issues WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
  const labelMap = { 'Waiting Materials': 'Matériaux manquants', 'Redirected': 'Redirigé' };
  const appendedActions = existing.actions
    ? `${existing.actions}\n[${ts}] Escalade (${labelMap[escalation_status]}) — ${escalation_comment.trim()}`
    : `[${ts}] Escalade (${labelMap[escalation_status]}) — ${escalation_comment.trim()}`;

  db.prepare(`
    UPDATE issues
    SET status = ?,
        actions = ?,
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(escalation_status, appendedActions, req.params.id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: `issue_status_${escalation_status.toLowerCase().replace(/\s+/g, '_')}`,
    target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: { old_status: existing.status, new_status: escalation_status, comment: escalation_comment.trim() },
    ...extractReqMeta(req) });

  res.json({ message: 'Incident escaladé', id: req.params.id, new_status: escalation_status });
});

// ── PATCH /api/issues/:id/reassign ────────────────────────────────────────
router.patch('/:id/reassign', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { new_group, reason } = req.body;

  if (!new_group || !reason) {
    return res.status(400).json({ error: 'new_group et reason sont requis' });
  }
  if (!VALID_GROUPS.includes(new_group)) {
    return res.status(400).json({ error: `Groupe invalide. Valeurs acceptées : ${VALID_GROUPS.join(', ')}` });
  }
  if (reason.trim().length < 10) {
    return res.status(400).json({ error: 'La raison doit contenir au moins 10 caractères' });
  }

  const existing = db.prepare('SELECT * FROM issues WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
  const appendedActions = existing.actions
    ? `${existing.actions}\n[${ts}] Transféré vers ${new_group} — ${reason.trim()}`
    : `[${ts}] Transféré vers ${new_group} — ${reason.trim()}`;

  db.prepare(`
    UPDATE issues
    SET assigned_group      = ?,
        assigned_technician = NULL,
        status              = 'Reported',
        actions             = ?,
        updated_at          = datetime('now','localtime')
    WHERE id = ?
  `).run(new_group, appendedActions, req.params.id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'reassign_issue', target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: { old_group: existing.assigned_group, new_group, old_technician: existing.assigned_technician, reason: reason.trim() },
    ...extractReqMeta(req) });

  res.json({ message: 'Incident réassigné', id: req.params.id });
});

// ── POST /api/issues/:id/photos ──────────────────────────────────────────────
router.post('/:id/photos', verifyToken, photoUpload.array('photos', 5), (req, res) => {
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ error: 'Aucun fichier reçu (champ "photos")' });
  }

  const db = getDb();
  const issue = db.prepare('SELECT id FROM issues WHERE id = ?').get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  // Vérifier la limite de 5 photos au total
  const existingCount = db.prepare('SELECT COUNT(*) AS c FROM issue_photos WHERE issue_id = ?').get(req.params.id).c;
  if (existingCount + req.files.length > 5) {
    return res.status(400).json({
      error: `Limite de 5 photos atteinte (déjà ${existingCount} photo(s) sur cet incident)`,
    });
  }

  const insertPhoto = db.prepare(`
    INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at)
    VALUES (?, ?, ?, ?, ?, datetime('now','localtime'))
  `);

  const inserted = [];
  for (const file of req.files) {
    const fileSizeKb = Math.ceil(file.size / 1024);
    const result = insertPhoto.run(req.params.id, file.filename, file.originalname, file.mimetype, fileSizeKb);
    inserted.push({ id: result.lastInsertRowid, original_name: file.originalname, file_size_kb: fileSizeKb });
  }

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'upload_issue_photos',
    target_type: 'issue', target_id: req.params.id, target_name: req.params.id,
    details: JSON.stringify({ count: req.files.length }),
    ...extractReqMeta(req),
  });

  res.status(201).json({ message: 'Photos ajoutées', photos: inserted });
});

// ── GET /api/issues/:id/photos ────────────────────────────────────────────────
router.get('/:id/photos', verifyToken, (req, res) => {
  const db = getDb();
  const issue = db.prepare('SELECT id FROM issues WHERE id = ?').get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  const photos = db.prepare(`
    SELECT id, original_name, mime_type, file_size_kb, uploaded_at
    FROM issue_photos
    WHERE issue_id = ?
    ORDER BY uploaded_at ASC
  `).all(req.params.id);

  res.json(photos);
});

// ── GET /api/issues/:id/photos/:photo_id/download ─────────────────────────────
router.get('/:id/photos/:photo_id/download', verifyToken, (req, res) => {
  const db = getDb();
  const photo = db.prepare(`
    SELECT * FROM issue_photos WHERE id = ? AND issue_id = ?
  `).get(req.params.photo_id, req.params.id);

  if (!photo) return res.status(404).json({ error: 'Photo introuvable' });

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'download_issue_photo',
    target_type: 'issue', target_id: req.params.id, target_name: photo.original_name,
    details: JSON.stringify({ photo_id: photo.id }),
    ...extractReqMeta(req),
  });

  const filePath = path.join(UPLOAD_DIR, photo.stored_name);
  res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(photo.original_name)}"`);
  res.setHeader('Content-Type', photo.mime_type);
  res.sendFile(filePath, { root: '/' }, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ error: 'Fichier introuvable sur le serveur' });
    }
  });
});

// DELETE /api/issues/:id (admin seulement)
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const existing = db.prepare('SELECT id, equipment_name FROM issues WHERE id = ?').get(req.params.id);
  const result = db.prepare('DELETE FROM issues WHERE id = ?').run(req.params.id);

  if (result.changes === 0) return res.status(404).json({ error: 'Incident introuvable' });

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'delete_issue', target_type: 'issue', target_id: req.params.id,
    target_name: existing?.equipment_name, ...extractReqMeta(req) });

  res.json({ message: 'Incident supprimé' });
});

module.exports = router;
