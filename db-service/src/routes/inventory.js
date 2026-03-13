const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');

const router = express.Router();

// GET /api/inventory
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { status, category } = req.query;

  let query = 'SELECT * FROM inventory WHERE 1=1';
  const params = [];

  if (status)   { query += ' AND status = ?';   params.push(status); }
  if (category) { query += ' AND category = ?'; params.push(category); }

  query += ' ORDER BY name ASC';

  res.json(db.prepare(query).all(...params));
});

// GET /api/inventory/:id
router.get('/:id', verifyToken, (req, res) => {
  const db = getDb();
  const item = db.prepare('SELECT * FROM inventory WHERE id = ?').get(req.params.id);

  if (!item) return res.status(404).json({ error: 'Article introuvable' });

  res.json(item);
});

// POST /api/inventory - créer un article
router.post('/', verifyToken, requireRole('admin', 'supervisor'), (req, res) => {
  const db = getDb();
  const { id, name, category, current_stock, min_stock, unit } = req.body;

  if (!id || !name || !category || current_stock === undefined || min_stock === undefined || !unit) {
    return res.status(400).json({ error: 'Champs requis: id, name, category, current_stock, min_stock, unit' });
  }

  const status = computeStatus(current_stock, min_stock);

  try {
    db.prepare(`
      INSERT INTO inventory (id, name, category, current_stock, min_stock, unit, status, last_restocked)
      VALUES (?, ?, ?, ?, ?, ?, ?, date('now'))
    `).run(id, name, category, current_stock, min_stock, unit, status);

    res.status(201).json({ message: 'Article créé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) return res.status(409).json({ error: 'ID déjà utilisé' });
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/inventory/:id - mettre à jour le stock
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
  const db = getDb();
  const { current_stock, min_stock, name, category, unit } = req.body;

  const existing = db.prepare('SELECT * FROM inventory WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Article introuvable' });

  const newStock    = current_stock !== undefined ? current_stock : existing.current_stock;
  const newMinStock = min_stock     !== undefined ? min_stock     : existing.min_stock;
  const status      = computeStatus(newStock, newMinStock);

  const restocked = (current_stock !== undefined && current_stock > existing.current_stock)
    ? `date('now')`
    : `'${existing.last_restocked}'`;

  db.prepare(`
    UPDATE inventory
    SET name = COALESCE(?, name),
        category = COALESCE(?, category),
        unit = COALESCE(?, unit),
        current_stock = ?,
        min_stock = ?,
        status = ?,
        last_restocked = ${restocked},
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(name, category, unit, newStock, newMinStock, status, req.params.id);

  res.json({ message: 'Stock mis à jour', status });
});

// DELETE /api/inventory/:id (admin)
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const result = db.prepare('DELETE FROM inventory WHERE id = ?').run(req.params.id);

  if (result.changes === 0) return res.status(404).json({ error: 'Article introuvable' });

  res.json({ message: 'Article supprimé' });
});

function computeStatus(current, min) {
  if (current === 0)         return 'Rupture';
  if (current < min)         return 'Faible';
  return 'Normal';
}

module.exports = router;
