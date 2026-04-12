const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

const VALID_STATUSES  = ['Ouvert', 'En cours', 'Résolu', 'Annulé'];
const VALID_URGENCIES = ['Faible', 'Moyen', 'Urgent'];
const VALID_ISSUE_TYPES = ['Panne', 'Maintenance', 'Inspection', 'Autre'];

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

// POST /api/issues - signaler un incident
router.post('/', verifyToken, (req, res) => {
  const db = getDb();
  const { id, equipment_id, equipment_name, department, type, description, reporter, reporter_id, reporter_email, urgency } = req.body;

  if (!id || !equipment_id || !equipment_name || !department || !type || !description || !reporter) {
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

  const urgencyValue = urgency || 'Moyen';

  try {
    db.prepare(`
      INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, reporter_id, reporter_email, urgency, created_at, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), 'Ouvert')
    `).run(id, equipment_id, equipment_name, department, type, description, reporter, reporter_id || null, reporter_email || null, urgencyValue);

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
      action: 'create_issue', target_type: 'issue', target_id: id,
      target_name: equipment_name, details: { type, department }, ...extractReqMeta(req) });

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

  // Un technicien ne peut modifier que les incidents de son propre département
  if (req.user.role === 'technician' && req.user.department && existing.department !== req.user.department) {
    return res.status(403).json({ error: 'Accès limité aux incidents de votre département' });
  }

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
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(status, assigned_technician, diagnosis, actions, parts_replaced, urgency, req.params.id);

  const actionLabel = status && status !== existing.status ? `issue_status_${status.toLowerCase().replace(/\s+/g, '_')}` : 'update_issue';

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: actionLabel, target_type: 'issue', target_id: req.params.id,
    target_name: existing.equipment_name,
    details: status ? { old_status: existing.status, new_status: status } : undefined,
    ...extractReqMeta(req) });

  res.json({ message: 'Incident mis à jour' });
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
