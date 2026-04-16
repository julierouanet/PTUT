const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

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

  // Validation format et longueur
  if (!/^[a-zA-Z0-9_-]+$/.test(id) || id.length > 100) {
    return res.status(400).json({ error: 'ID invalide (alphanumérique, max 100 caractères)' });
  }
  if (typeof name !== 'string' || name.length > 255) {
    return res.status(400).json({ error: 'Nom invalide (max 255 caractères)' });
  }
  const VALID_CATEGORIES_INV = ['Consommable médical', 'Hygiène', 'Bureautique'];
  if (!VALID_CATEGORIES_INV.includes(category)) {
    return res.status(400).json({ error: 'Catégorie invalide' });
  }
  if (typeof current_stock !== 'number' || typeof min_stock !== 'number' || current_stock < 0 || min_stock < 0) {
    return res.status(400).json({ error: 'Les stocks doivent être des nombres positifs' });
  }
  if (typeof unit !== 'string' || unit.length > 50) {
    return res.status(400).json({ error: 'Unité invalide (max 50 caractères)' });
  }

  const status = computeStatus(current_stock, min_stock);

  try {
    db.prepare(`
      INSERT INTO inventory (id, name, category, current_stock, min_stock, unit, status, last_restocked)
      VALUES (?, ?, ?, ?, ?, ?, ?, date('now'))
    `).run(id, name, category, current_stock, min_stock, unit, status);

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
      action: 'create_inventory', target_type: 'inventory', target_id: id, target_name: name,
      details: { category, current_stock, unit }, ...extractReqMeta(req) });

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

  const isRestock = current_stock !== undefined && current_stock > existing.current_stock;
  const newLastRestocked = isRestock ? null : existing.last_restocked; // null → date('now') via CASE

  db.prepare(`
    UPDATE inventory
    SET name = COALESCE(?, name),
        category = COALESCE(?, category),
        unit = COALESCE(?, unit),
        current_stock = ?,
        min_stock = ?,
        status = ?,
        last_restocked = CASE WHEN ? = 1 THEN date('now','localtime') ELSE ? END,
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(name, category, unit, newStock, newMinStock, status, isRestock ? 1 : 0, existing.last_restocked, req.params.id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: isRestock ? 'restock_inventory' : 'update_inventory',
    target_type: 'inventory', target_id: req.params.id, target_name: name || existing.name,
    details: current_stock !== undefined ? { old_stock: existing.current_stock, new_stock: newStock } : undefined,
    ...extractReqMeta(req) });

  res.json({ message: 'Stock mis à jour', status });
});

// DELETE /api/inventory/:id (admin)
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const existing = db.prepare('SELECT id, name FROM inventory WHERE id = ?').get(req.params.id);
  const result = db.prepare('DELETE FROM inventory WHERE id = ?').run(req.params.id);

  if (result.changes === 0) return res.status(404).json({ error: 'Article introuvable' });

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: 'delete_inventory', target_type: 'inventory', target_id: req.params.id,
    target_name: existing?.name, ...extractReqMeta(req) });

  res.json({ message: 'Article supprimé' });
});

function computeStatus(current, min) {
  if (current === 0) return 'Rupture';
  if (current < min) return 'Faible';
  return 'Normal';
}

module.exports = router;
