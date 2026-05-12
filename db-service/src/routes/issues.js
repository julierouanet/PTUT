const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

const VALID_STATUSES    = ['Reported', 'Acknowledged', 'Assigned', 'In Progress', 'Waiting Materials', 'Completed', 'Verified', 'Closed', 'Redirected'];
const VALID_URGENCIES   = ['Faible', 'Moyen', 'Urgent'];
const VALID_ISSUE_TYPES = ['Panne', 'Maintenance', 'Inspection', 'Autre'];
const VALID_GROUPS      = ['Biomédical', 'Infrastructure', 'IT'];

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

// POST /api/issues - signaler un incident (équipement ou lieu/infrastructure)
router.post('/', verifyToken, (req, res) => {
  const db = getDb();
  const { id, equipment_id, equipment_name, location_id, department, type, description, reporter, reporter_id, reporter_email, urgency } = req.body;

  const hasEquipment = equipment_id && equipment_name;
  const hasLocation  = !!location_id;

  if (!id || (!hasEquipment && !hasLocation) || !department || !type || !description || !reporter) {
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

  const urgencyValue    = urgency || 'Moyen';
  const derivedCategory = hasEquipment ? 'Biomédical' : 'Infrastructure';
  const derivedGroup    = hasEquipment ? 'Biomédical' : 'Infrastructure';

  try {
    db.prepare(`
      INSERT INTO issues (id, equipment_id, equipment_name, location_id, issue_category, assigned_group, department, type, description, reporter, reporter_id, reporter_email, urgency, created_at, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'), 'Reported')
    `).run(
      id,
      equipment_id  || null,
      equipment_name || null,
      location_id   || null,
      derivedCategory,
      derivedGroup,
      department, type, description, reporter,
      reporter_id    || null,
      reporter_email || null,
      urgencyValue
    );

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
      action: 'create_issue', target_type: 'issue', target_id: id,
      target_name: equipment_name || location_id || department,
      details: { type, department, category: derivedCategory, group: derivedGroup },
      ...extractReqMeta(req) });

    res.status(201).json({ message: 'Incident signalé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) return res.status(409).json({ error: 'ID déjà utilisé' });
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/issues/:id - mettre à jour un incident
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
  const db = getDb();
  const { status, assigned_technician, diagnosis, actions, parts_replaced, urgency } = req.body;

  const existing = db.prepare('SELECT id, equipment_name, status, department FROM issues WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  // Validation enum statut et urgence
  if (status && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `Statut invalide. Valeurs acceptées : ${VALID_STATUSES.join(', ')}` });
  }
  if (urgency && !VALID_URGENCIES.includes(urgency)) {
    return res.status(400).json({ error: `Urgence invalide. Valeurs acceptées : ${VALID_URGENCIES.join(', ')}` });
  }

  db.prepare(`
    UPDATE issues
    SET status = COALESCE(?, status),
        assigned_technician = COALESCE(?, assigned_technician),
        diagnosis = COALESCE(?, diagnosis),
        actions = COALESCE(?, actions),
        parts_replaced = COALESCE(?, parts_replaced),
        urgency = COALESCE(?, urgency),
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(status, assigned_technician, diagnosis, actions, parts_replaced, urgency, req.params.id);

  const actionLabel = status && status !== existing.status ? `issue_status_${status.toLowerCase().replace(/\s+/g, '_')}` : 'update_issue';

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: actionLabel, target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name || existing.location_id || existing.department,
    details: status ? { old_status: existing.status, new_status: status } : undefined,
    ...extractReqMeta(req) });

  res.json({ message: 'Incident mis à jour' });
});

// ── PATCH /api/issues/:id/reassign ────────────────────────────────────────
router.patch('/:id/reassign', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
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

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
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

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: 'delete_issue', target_type: 'issue', target_id: req.params.id,
    target_name: existing?.equipment_name, ...extractReqMeta(req) });

  res.json({ message: 'Incident supprimé' });
});

module.exports = router;
