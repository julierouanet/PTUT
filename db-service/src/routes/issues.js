const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');

const router = express.Router();

// GET /api/issues
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { status, department } = req.query;

  let query = 'SELECT * FROM issues WHERE 1=1';
  const params = [];

  if (status)     { query += ' AND status = ?';     params.push(status); }
  if (department) { query += ' AND department = ?'; params.push(department); }

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
  const { id, equipment_id, equipment_name, department, type, description, reporter } = req.body;

  if (!id || !equipment_id || !equipment_name || !department || !type || !description || !reporter) {
    return res.status(400).json({ error: 'Champs requis manquants' });
  }

  try {
    db.prepare(`
      INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, created_at, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), 'Ouvert')
    `).run(id, equipment_id, equipment_name, department, type, description, reporter);

    res.status(201).json({ message: 'Incident signalé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) return res.status(409).json({ error: 'ID déjà utilisé' });
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/issues/:id - mettre à jour un incident
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
  const db = getDb();
  const { status, assigned_technician, diagnosis, actions, parts_replaced } = req.body;

  const existing = db.prepare('SELECT id FROM issues WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Incident introuvable' });

  db.prepare(`
    UPDATE issues
    SET status = COALESCE(?, status),
        assigned_technician = COALESCE(?, assigned_technician),
        diagnosis = COALESCE(?, diagnosis),
        actions = COALESCE(?, actions),
        parts_replaced = COALESCE(?, parts_replaced),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(status, assigned_technician, diagnosis, actions, parts_replaced, req.params.id);

  res.json({ message: 'Incident mis à jour' });
});

// DELETE /api/issues/:id (admin seulement)
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const result = db.prepare('DELETE FROM issues WHERE id = ?').run(req.params.id);

  if (result.changes === 0) return res.status(404).json({ error: 'Incident introuvable' });

  res.json({ message: 'Incident supprimé' });
});

module.exports = router;
