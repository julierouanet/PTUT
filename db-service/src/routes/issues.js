const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole, SYSTEM_ROLES } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { AUTH_SERVICE_URL } = require('../config');
const { sendPushToRoles } = require('../utils/push_sender');

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

// Tous les rôles techniciens spécialisés (utilisés pour requireRole).
const TECH_ROLES = ['technician_biomedical', 'technician_it', 'technician_infra'];

// Sérialise les rôles d'un user (issus du JWT) pour la colonne `user_role` des logs.
const rolesCsv = (req) =>
  (Array.isArray(req.user?.roles) ? req.user.roles : [])
    .filter((r) => !SYSTEM_ROLES.has(r))
    .join(',');

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

// GET /api/issues/:id
router.get('/:id', verifyToken, (req, res) => {
  const db = getDb();
  const issue = db.prepare('SELECT * FROM issues WHERE id = ?').get(req.params.id);

  if (!issue) return res.status(404).json({ error: 'Incident introuvable' });

  res.json(issue);
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
    type, description, reporter, reporter_id, reporter_email, urgency,
    issue_category: reqCategory, assigned_group: reqGroup,
  } = req.body;

  const hasEquipment  = equipment_id && equipment_name;
  const hasLocation   = !!location_id;
  const hasLocText    = !!(location_text && location_text.trim());
  const isAutre       = reqCategory === 'Autre';
  const isInfra       = reqCategory === 'Infrastructure';

  if (!id || (!hasEquipment && !hasLocation && !hasLocText && !isAutre && !isInfra) || !department || !type || !description || !reporter) {
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
      INSERT INTO issues (id, equipment_id, equipment_name, location_id, location_text, location_tag, issue_category, assigned_group, department, type, description, reporter, reporter_id, reporter_email, urgency, created_at, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'), 'Reported')
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

    res.status(201).json({ message: 'Incident signalé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) return res.status(409).json({ error: 'ID déjà utilisé' });
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/issues/:id - mettre à jour un incident
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { status, assigned_technician, diagnosis, actions, parts_replaced, urgency, assigned_group } = req.body;

  const existing = db.prepare('SELECT id, equipment_name, location_id, status, department, assigned_group FROM issues WHERE id = ?').get(req.params.id);
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

  db.prepare(`
    UPDATE issues
    SET status = COALESCE(?, status),
        assigned_technician = COALESCE(?, assigned_technician),
        diagnosis = COALESCE(?, diagnosis),
        actions = COALESCE(?, actions),
        parts_replaced = COALESCE(?, parts_replaced),
        urgency = COALESCE(?, urgency),
        assigned_group = COALESCE(?, assigned_group),
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(status, assigned_technician, diagnosis, actions, parts_replaced, urgency, assigned_group || null, req.params.id);

  const groupChanged = assigned_group && assigned_group !== existing.assigned_group;
  const actionLabel = status && status !== existing.status ? `issue_status_${status.toLowerCase().replace(/\s+/g, '_')}` : 'update_issue';

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: actionLabel, target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: {
      ...(status ? { old_status: existing.status, new_status: status } : {}),
      ...(groupChanged ? { old_group: existing.assigned_group, new_group: assigned_group } : {}),
    },
    ...extractReqMeta(req) });

  res.json({ message: 'Incident mis à jour' });
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
