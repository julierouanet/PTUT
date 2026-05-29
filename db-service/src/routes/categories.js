const express = require('express');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');

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

module.exports = router;
