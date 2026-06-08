const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

// ── GET /api/categories/macro ─────────────────────────────────────────────────
// Retourne la liste des 3 macro-catégories (Biomedical, Infrastructure, IT).
router.get('/macro', verifyToken, (req, res) => {
  const db = getDb();
  const rows = db.prepare(
    'SELECT id, name FROM equipment_macro_categories ORDER BY name ASC'
  ).all();
  res.json(rows);
});

// ── GET /api/categories/sub ───────────────────────────────────────────────────
// Retourne les sous-catégories, avec count d'équipements.
// Filtre optionnel : ?macro_category_id=<id>
router.get('/sub', verifyToken, (req, res) => {
  const db = getDb();
  const { macro_category_id } = req.query;

  let query = `
    SELECT
      s.id,
      s.name,
      s.macro_category_id,
      emc.name AS macro_category_name,
      COUNT(e.id) AS equipment_count
    FROM equipment_subcategories s
    LEFT JOIN equipment_macro_categories emc ON emc.id = s.macro_category_id
    LEFT JOIN equipment e ON e.subcategory_id = s.id
    WHERE 1=1
  `;
  const params = [];

  if (macro_category_id) {
    query += ' AND s.macro_category_id = ?';
    params.push(parseInt(macro_category_id, 10));
  }

  query += ' GROUP BY s.id ORDER BY emc.name ASC, s.name ASC';

  const rows = db.prepare(query).all(...params);
  res.json(rows);
});

// ── GET /api/categories/sub/:id ───────────────────────────────────────────────
// Détail d'une sous-catégorie avec ses protocoles PM.
router.get('/sub/:id', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const sub = db.prepare(`
    SELECT s.*, emc.name AS macro_category_name
    FROM equipment_subcategories s
    LEFT JOIN equipment_macro_categories emc ON emc.id = s.macro_category_id
    WHERE s.id = ?
  `).get(id);

  if (!sub) return res.status(404).json({ error: 'Sous-catégorie introuvable' });

  const protocols = db.prepare(
    'SELECT * FROM pm_protocols WHERE subcategory_id = ? ORDER BY frequency_months ASC'
  ).all(id);

  const equipmentCount = db.prepare(
    'SELECT COUNT(*) AS cnt FROM equipment WHERE subcategory_id = ?'
  ).get(id).cnt;

  res.json({ ...sub, protocols, equipment_count: equipmentCount });
});

// ── POST /api/categories/sub ──────────────────────────────────────────────────
router.post('/sub', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { name, macro_category_id } = req.body;

  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });
  if (!macro_category_id) return res.status(400).json({ error: 'macro_category_id est requis' });

  const macro = db.prepare('SELECT id FROM equipment_macro_categories WHERE id = ?').get(parseInt(macro_category_id, 10));
  if (!macro) return res.status(404).json({ error: 'Macro-catégorie introuvable' });

  const duplicate = db.prepare(
    'SELECT id FROM equipment_subcategories WHERE LOWER(name) = LOWER(?)'
  ).get(name.trim());
  if (duplicate) return res.status(409).json({ error: 'Une sous-catégorie avec ce nom existe déjà' });

  const result = db.prepare(
    'INSERT INTO equipment_subcategories (name, macro_category_id) VALUES (?, ?)'
  ).run(name.trim(), parseInt(macro_category_id, 10));

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] ?? 'admin',
    action: 'create_subcategory',
    target_type: 'subcategory', target_id: String(result.lastInsertRowid), target_name: name.trim(),
    details: { macro_category_id },
    ...extractReqMeta(req),
  });

  res.status(201).json({
    id: result.lastInsertRowid,
    name: name.trim(),
    macro_category_id: parseInt(macro_category_id, 10),
    equipment_count: 0,
  });
});

// ── PUT /api/categories/sub/:id ────────────────────────────────────────────────
router.put('/sub/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const { name, macro_category_id } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });

  const existing = db.prepare('SELECT * FROM equipment_subcategories WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Sous-catégorie introuvable' });

  if (macro_category_id) {
    const macro = db.prepare('SELECT id FROM equipment_macro_categories WHERE id = ?').get(parseInt(macro_category_id, 10));
    if (!macro) return res.status(404).json({ error: 'Macro-catégorie introuvable' });
  }

  const duplicate = db.prepare(
    'SELECT id FROM equipment_subcategories WHERE LOWER(name) = LOWER(?) AND id != ?'
  ).get(name.trim(), id);
  if (duplicate) return res.status(409).json({ error: 'Une sous-catégorie avec ce nom existe déjà' });

  const newMacroId = macro_category_id ? parseInt(macro_category_id, 10) : existing.macro_category_id;
  db.prepare(
    'UPDATE equipment_subcategories SET name = ?, macro_category_id = ? WHERE id = ?'
  ).run(name.trim(), newMacroId, id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] ?? 'admin',
    action: 'update_subcategory',
    target_type: 'subcategory', target_id: String(id), target_name: name.trim(),
    details: { old_name: existing.name, name, macro_category_id },
    ...extractReqMeta(req),
  });

  res.json({ id, name: name.trim(), macro_category_id: newMacroId });
});

// ── DELETE /api/categories/sub/:id ────────────────────────────────────────────
router.delete('/sub/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const sub = db.prepare('SELECT * FROM equipment_subcategories WHERE id = ?').get(id);
  if (!sub) return res.status(404).json({ error: 'Sous-catégorie introuvable' });

  const { count } = db.prepare(
    'SELECT COUNT(*) AS count FROM equipment WHERE subcategory_id = ?'
  ).get(id);

  if (count > 0) {
    return res.status(409).json({
      error: 'SUBCATEGORY_HAS_EQUIPMENT',
      message: `Cette sous-catégorie a ${count} équipement(s) associé(s). Réaffectez-les avant de supprimer.`,
      equipment_count: count,
    });
  }

  db.prepare('DELETE FROM equipment_subcategories WHERE id = ?').run(id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] ?? 'admin',
    action: 'delete_subcategory',
    target_type: 'subcategory', target_id: String(id), target_name: sub.name,
    details: {},
    ...extractReqMeta(req),
  });

  res.json({ success: true, message: 'Sous-catégorie supprimée' });
});

module.exports = router;
