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

const VALID_STATUSES    = ['Reported', 'Acknowledged', 'Assigned', 'In Progress', 'Waiting Materials', 'Completed', 'Verified', 'Closed', 'Redirected', 'Rejected'];
const VALID_URGENCIES   = ['Faible', 'Moyen', 'Urgent', 'Critique'];

// Motifs de rejet catégorisés (alimentent un futur KPI « taux de demandes invalides »)
const REJECT_REASONS    = ['duplicate', 'not_reproducible', 'out_of_scope', 'false_alarm', 'other'];

// ── Rapport d'intervention ─────────────────────────────────────────────────
// Whitelist alignée sur equipment.status (cf. routes/equipment.js VALID_STATUSES_EQ)
const VALID_EQUIPMENT_STATUS = ['Operational', 'Maintenance', 'Out of service', 'To be disposal', 'Disposed'];
// Statuts d'incident autorisant la finalisation du rapport
const REPORT_FINALIZABLE_STATUSES = ['Completed', 'Verified', 'Closed'];
// Colonnes de l'incident nécessaires aux routes du rapport (pré-remplissage live)
const ISSUE_REPORT_SELECT =
  'SELECT id, status, diagnosis, actions, parts_replaced, equipment_id, equipment_name FROM issues WHERE id = ?';
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

  // LEFT JOIN du rapport d'intervention finalisé : alimente les KPIs (MTTR réel,
  // coût de maintenance) côté Flutter sans appel supplémentaire.
  let query = `
    SELECT i.*,
           r.duration_hours AS report_duration_hours,
           r.estimated_cost AS report_estimated_cost
    FROM issues i
    LEFT JOIN issue_intervention_reports r
      ON r.issue_id = i.id AND r.report_status = 'finalized'
    WHERE 1=1`;
  const params = [];

  if (status)       { query += ' AND i.status = ?';       params.push(status); }
  if (department)   { query += ' AND i.department = ?';   params.push(department); }
  if (equipment_id) { query += ' AND i.equipment_id = ?'; params.push(equipment_id); }

  query += ' ORDER BY i.created_at DESC';

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

  // Date de résolution : posée uniquement à la 1ʳᵉ transition vers Completed.
  // COALESCE garantit l'idempotence (ne réécrit pas une date déjà posée).
  const resolvedAt = (status === 'Completed' && existing.status !== 'Completed')
    ? new Date().toISOString()
    : null;

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
        resolved_at = COALESCE(?, resolved_at),
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(status, assigned_technician, diagnosis, actions, parts_replaced, urgency, assigned_group || null, taken_at || null, resolvedAt, req.params.id);

  const groupChanged = assigned_group && assigned_group !== existing.assigned_group;
  const actionLabel = status && status !== existing.status ? `issue_status_${status.toLowerCase().replace(/\s+/g, '_')}` : 'update_issue';

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: actionLabel, target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: {
      ...(status ? { old_status: existing.status, new_status: status } : {}),
      ...(groupChanged ? { old_group: existing.assigned_group, new_group: assigned_group } : {}),
      ...(resolvedAt ? { resolved_at: resolvedAt } : {}),
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
      // Réutilise la date de résolution déjà persistée ; fallback de sécurité si null.
      const resolvedAtForNotif = resolvedAt || new Date().toISOString();
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
          resolved_at:     resolvedAtForNotif,
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

// ── PATCH /api/issues/:id/reject ──────────────────────────────────────────────
// Rejet rapide d'un incident encore en file de validation (statut 'Reported').
// Le valideur (admin/superviseur) tranche la recevabilité avec un motif catégorisé.
// L'incident n'est PAS supprimé : il est conservé pour la traçabilité.
router.patch('/:id/reject', verifyToken, requireRole('admin', 'supervisor'), (req, res) => {
  const db = getDb();
  const { reason_code, comment } = req.body;

  // 1. Validation explicite du motif catégorisé
  if (!reason_code || !REJECT_REASONS.includes(reason_code)) {
    return res.status(400).json({ error: `reason_code invalide. Valeurs acceptées : ${REJECT_REASONS.join(', ')}` });
  }
  const trimmedComment = (comment || '').trim();
  if (trimmedComment.length > 500) {
    return res.status(400).json({ error: 'comment ne doit pas dépasser 500 caractères' });
  }
  // Le motif "other" exige un commentaire explicatif (≥ 5 caractères)
  if (reason_code === 'other' && trimmedComment.length < 5) {
    return res.status(400).json({ error: 'Un commentaire (min 5 caractères) est requis pour le motif "other"' });
  }

  // 2. Vérifier existence
  const existing = db.prepare(
    'SELECT id, status, equipment_name, location_id, department, actions FROM issues WHERE id = ?'
  ).get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  // 3. On ne rejette que depuis la file de validation
  if (existing.status !== 'Reported') {
    return res.status(409).json({ error: 'Seul un incident au statut "Reported" peut être rejeté' });
  }

  // 4. Opération DB (synchrone) — append dans le journal d'actions
  const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
  const rejectLine = `[${ts}] Rejet (${reason_code})${trimmedComment ? ` — ${trimmedComment}` : ''}`;
  const appendedActions = existing.actions ? `${existing.actions}\n${rejectLine}` : rejectLine;

  db.prepare(`
    UPDATE issues
    SET status     = 'Rejected',
        actions    = ?,
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(appendedActions, req.params.id);

  // TODO: notifier le signaleur du rejet (hors scope — à brancher ultérieurement).

  // 5. Audit trail
  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'reject_issue', target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: { reason_code, comment: trimmedComment || null, old_status: existing.status },
    ...extractReqMeta(req) });

  res.json({ message: 'Incident rejeté', id: req.params.id });
});

// ── PATCH /api/issues/:id/detach ──────────────────────────────────────────────
// Un technicien (ou un admin) se détache d'un incident pris en charge ('In Progress')
// qui lui est assigné → l'incident retourne au pool (statut 'Acknowledged').
router.patch('/:id/detach', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { reason } = req.body;

  // 1. Validation explicite du motif
  if (!reason || reason.trim().length < 10) {
    return res.status(400).json({ error: 'reason est requis (min 10 caractères)' });
  }

  // 2. Vérifier existence
  const existing = db.prepare(
    'SELECT id, status, assigned_technician, equipment_name, location_id, department, actions FROM issues WHERE id = ?'
  ).get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  // 3. On ne détache qu'un incident en cours de traitement
  if (existing.status !== 'In Progress') {
    return res.status(409).json({ error: 'Seul un incident au statut "In Progress" peut être détaché' });
  }

  // 4. Un technicien ne détache que ses propres incidents (l'admin n'a pas cette restriction)
  const isAdmin = Array.isArray(req.user.roles) && req.user.roles.includes('admin');
  if (!isAdmin && existing.assigned_technician !== req.user.name) {
    return res.status(403).json({ error: 'Vous ne pouvez détacher que les incidents qui vous sont assignés' });
  }

  // 5. Opération DB (synchrone) — retour au pool + append journal d'actions
  const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
  const detachLine = `[${ts}] Détachement par ${req.user.name} — ${reason.trim()}`;
  const appendedActions = existing.actions ? `${existing.actions}\n${detachLine}` : detachLine;

  db.prepare(`
    UPDATE issues
    SET status              = 'Acknowledged',
        assigned_technician = NULL,
        taken_at            = NULL,
        actions             = ?,
        updated_at          = datetime('now','localtime')
    WHERE id = ?
  `).run(appendedActions, req.params.id);

  // 6. Audit trail
  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'detach_issue', target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: { reason: reason.trim(), old_technician: existing.assigned_technician, old_status: existing.status },
    ...extractReqMeta(req) });

  res.json({ message: 'Incident détaché', id: req.params.id });
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

// ════════════════════════════════════════════════════════════════════════════
// RAPPORT D'INTERVENTION (1:1 avec issue)
// ════════════════════════════════════════════════════════════════════════════

/**
 * Construit la réponse rapport enrichie : champs du rapport (ou brouillon vide)
 * + champs de pré-remplissage lus EN DIRECT depuis l'incident (jamais dupliqués).
 */
function _buildReportResponse(issue, report) {
  const base = report || { issue_id: issue.id, report_status: 'draft' };
  return {
    ...base,
    // Pré-remplissage live depuis l'incident
    diagnosis:      issue.diagnosis,
    actions:        issue.actions,
    parts_replaced: issue.parts_replaced,
    equipment_id:   issue.equipment_id,
    equipment_name: issue.equipment_name,
    issue_status:   issue.status,
  };
}

// ── GET /api/issues/:id/report ─────────────────────────────────────────────
router.get('/:id/report', verifyToken, (req, res) => {
  const db = getDb();
  const issue = db.prepare(ISSUE_REPORT_SELECT).get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  const report = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);
  res.json(_buildReportResponse(issue, report));
});

// ── PUT /api/issues/:id/report (UPSERT) ────────────────────────────────────
router.put('/:id/report', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const issue = db.prepare(ISSUE_REPORT_SELECT).get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  const {
    summary, root_cause, recommendations, duration_hours,
    returned_to_service_at, estimated_cost, final_equipment_status,
  } = req.body;

  // Validation : statut final équipement
  if (final_equipment_status && !VALID_EQUIPMENT_STATUS.includes(final_equipment_status)) {
    return res.status(400).json({ error: `Statut équipement invalide. Valeurs acceptées : ${VALID_EQUIPMENT_STATUS.join(', ')}` });
  }
  // Validation : valeurs numériques positives si fournies
  if (duration_hours != null && (typeof duration_hours !== 'number' || duration_hours < 0)) {
    return res.status(400).json({ error: 'duration_hours doit être un nombre positif' });
  }
  if (estimated_cost != null && (typeof estimated_cost !== 'number' || estimated_cost < 0)) {
    return res.status(400).json({ error: 'estimated_cost doit être un nombre positif' });
  }

  const isAdmin = req.user.roles.includes('admin');
  const existing = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);

  // Garde-fou : rapport figé non modifiable sauf admin
  if (existing && existing.report_status === 'finalized' && !isAdmin) {
    return res.status(409).json({ error: 'Rapport finalisé : modification réservée aux administrateurs (rouvrir le rapport au préalable)' });
  }

  // L'auteur est renseigné au premier enregistrement uniquement
  const authorId   = existing?.author_id   || req.user.id;
  const authorName = existing?.author_name || req.user.name;

  db.prepare(`
    INSERT INTO issue_intervention_reports
      (issue_id, summary, root_cause, recommendations, duration_hours,
       returned_to_service_at, estimated_cost, final_equipment_status,
       author_id, author_name)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(issue_id) DO UPDATE SET
      summary                = excluded.summary,
      root_cause             = excluded.root_cause,
      recommendations        = excluded.recommendations,
      duration_hours         = excluded.duration_hours,
      returned_to_service_at = excluded.returned_to_service_at,
      estimated_cost         = excluded.estimated_cost,
      final_equipment_status = excluded.final_equipment_status,
      updated_at             = datetime('now','localtime')
  `).run(
    req.params.id, summary || null, root_cause || null, recommendations || null,
    duration_hours ?? null, returned_to_service_at || null, estimated_cost ?? null,
    final_equipment_status || null, authorId, authorName
  );

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'update_intervention_report', target_type: 'issue', target_id: req.params.id,
    target_name: issue.equipment_name || issue.id,
    details: { final_equipment_status, duration_hours, estimated_cost },
    ...extractReqMeta(req) });

  const report = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);
  res.json(_buildReportResponse(issue, report));
});

// ── POST /api/issues/:id/report/finalize ───────────────────────────────────
router.post('/:id/report/finalize', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const issue = db.prepare(ISSUE_REPORT_SELECT).get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  // L'incident doit être résolu pour figer le rapport
  if (!REPORT_FINALIZABLE_STATUSES.includes(issue.status)) {
    return res.status(409).json({ error: `Rapport finalisable uniquement si l'incident est résolu (${REPORT_FINALIZABLE_STATUSES.join(', ')})` });
  }

  const existing = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Aucun rapport à finaliser pour cet incident' });
  if (existing.report_status === 'finalized') {
    return res.status(409).json({ error: 'Rapport déjà finalisé' });
  }

  db.prepare(`
    UPDATE issue_intervention_reports
    SET report_status     = 'finalized',
        validated_by_id   = ?,
        validated_by_name = ?,
        validated_at      = datetime('now','localtime'),
        updated_at        = datetime('now','localtime')
    WHERE issue_id = ?
  `).run(req.user.id, req.user.name, req.params.id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'finalize_intervention_report', target_type: 'issue', target_id: req.params.id,
    target_name: issue.equipment_name || issue.id, ...extractReqMeta(req) });

  const report = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);
  res.json(_buildReportResponse(issue, report));
});

// ── PATCH /api/issues/:id/report/reopen (admin uniquement) ─────────────────
router.patch('/:id/report/reopen', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const issue = db.prepare(ISSUE_REPORT_SELECT).get(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  const existing = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Aucun rapport pour cet incident' });

  db.prepare(`
    UPDATE issue_intervention_reports
    SET report_status = 'draft', updated_at = datetime('now','localtime')
    WHERE issue_id = ?
  `).run(req.params.id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'reopen_intervention_report', target_type: 'issue', target_id: req.params.id,
    target_name: issue.equipment_name || issue.id, ...extractReqMeta(req) });

  const report = db.prepare('SELECT * FROM issue_intervention_reports WHERE issue_id = ?').get(req.params.id);
  res.json(_buildReportResponse(issue, report));
});

module.exports = router;
