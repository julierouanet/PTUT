const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { rolesCsv } = require('../utils/roles');

const router = express.Router();

const VALID_CRITICALITIES = ['A', 'B', 'C'];

// ── GET /api/pm-protocols ────────────────────────────────────────────────────
// Liste des protocoles PM. Filtres : ?subcategory_id=, ?macro_category_id=
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { subcategory_id, macro_category_id } = req.query;

  let query = `
    SELECT
      p.*,
      s.name   AS subcategory_name,
      emc.name AS macro_category_name
    FROM pm_protocols p
    LEFT JOIN equipment_subcategories s        ON s.id  = p.subcategory_id
    LEFT JOIN equipment_macro_categories emc   ON emc.id = s.macro_category_id
    WHERE 1=1
  `;
  const params = [];

  if (subcategory_id) {
    query += ' AND p.subcategory_id = ?';
    params.push(parseInt(subcategory_id, 10));
  }
  if (macro_category_id) {
    query += ' AND s.macro_category_id = ?';
    params.push(parseInt(macro_category_id, 10));
  }

  query += ' ORDER BY emc.name ASC, s.name ASC, p.frequency_months ASC';

  const rows = db.prepare(query).all(...params);
  // Désérialiser la checklist JSON pour chaque protocole
  const result = rows.map(r => ({
    ...r,
    checklist: r.checklist ? (() => { try { return JSON.parse(r.checklist); } catch (_) { return []; } })() : [],
  }));

  res.json(result);
});

// ── GET /api/pm-protocols/:id ────────────────────────────────────────────────
router.get('/:id', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const row = db.prepare(`
    SELECT
      p.*,
      s.name   AS subcategory_name,
      emc.name AS macro_category_name
    FROM pm_protocols p
    LEFT JOIN equipment_subcategories s      ON s.id   = p.subcategory_id
    LEFT JOIN equipment_macro_categories emc ON emc.id = s.macro_category_id
    WHERE p.id = ?
  `).get(id);

  if (!row) return res.status(404).json({ error: 'Protocole introuvable' });

  res.json({
    ...row,
    checklist: row.checklist
      ? (() => { try { return JSON.parse(row.checklist); } catch (_) { return []; } })()
      : [],
  });
});

// ── POST /api/pm-protocols ───────────────────────────────────────────────────
router.post('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { subcategory_id, name, frequency_months, estimated_duration_hours, checklist } = req.body;

  if (!subcategory_id || !name || !frequency_months) {
    return res.status(400).json({ error: 'Champs requis : subcategory_id, name, frequency_months' });
  }

  const freqInt = parseInt(frequency_months, 10);
  if (!Number.isFinite(freqInt) || freqInt < 1 || freqInt > 120) {
    return res.status(400).json({ error: 'frequency_months invalide (1–120)' });
  }

  let durationFloat = null;
  if (estimated_duration_hours != null && estimated_duration_hours !== '') {
    durationFloat = parseFloat(estimated_duration_hours);
    if (!Number.isFinite(durationFloat) || durationFloat <= 0) {
      return res.status(400).json({ error: 'estimated_duration_hours invalide' });
    }
  }

  // Valider et sérialiser la checklist
  let checklistJson = null;
  if (checklist != null) {
    if (!Array.isArray(checklist)) {
      return res.status(400).json({ error: 'checklist doit être un tableau JSON' });
    }
    if (checklist.some(item => typeof item !== 'string')) {
      return res.status(400).json({ error: 'Chaque élément de la checklist doit être une chaîne' });
    }
    checklistJson = JSON.stringify(checklist);
  }

  // Vérifier que la sous-catégorie existe
  const sub = db.prepare('SELECT id FROM equipment_subcategories WHERE id = ?').get(subcategory_id);
  if (!sub) return res.status(404).json({ error: 'Sous-catégorie introuvable' });

  const result = db.prepare(`
    INSERT INTO pm_protocols (subcategory_id, name, frequency_months, estimated_duration_hours, checklist)
    VALUES (?, ?, ?, ?, ?)
  `).run(subcategory_id, name.trim(), freqInt, durationFloat, checklistJson);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'create_pm_protocol',
    target_type: 'pm_protocol', target_id: String(result.lastInsertRowid), target_name: name,
    details: JSON.stringify({ subcategory_id, frequency_months: freqInt }),
    ...extractReqMeta(req),
  });

  res.status(201).json({ message: 'Protocole créé', id: result.lastInsertRowid });
});

// ── PUT /api/pm-protocols/:id ────────────────────────────────────────────────
router.put('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const existing = db.prepare('SELECT * FROM pm_protocols WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Protocole introuvable' });

  const { name, frequency_months, estimated_duration_hours, checklist } = req.body;

  let freqInt = null;
  if (frequency_months != null) {
    freqInt = parseInt(frequency_months, 10);
    if (!Number.isFinite(freqInt) || freqInt < 1 || freqInt > 120) {
      return res.status(400).json({ error: 'frequency_months invalide (1–120)' });
    }
  }

  let durationFloat = undefined;
  if (estimated_duration_hours !== undefined) {
    if (estimated_duration_hours === null || estimated_duration_hours === '') {
      durationFloat = null;
    } else {
      durationFloat = parseFloat(estimated_duration_hours);
      if (!Number.isFinite(durationFloat) || durationFloat <= 0) {
        return res.status(400).json({ error: 'estimated_duration_hours invalide' });
      }
    }
  }

  let checklistJson = undefined;
  if (checklist !== undefined) {
    if (checklist === null) {
      checklistJson = null;
    } else {
      if (!Array.isArray(checklist)) {
        return res.status(400).json({ error: 'checklist doit être un tableau JSON' });
      }
      checklistJson = JSON.stringify(checklist);
    }
  }

  db.prepare(`
    UPDATE pm_protocols
    SET name                     = COALESCE(?, name),
        frequency_months         = COALESCE(?, frequency_months),
        estimated_duration_hours = CASE WHEN ? IS NOT NULL THEN ? ELSE estimated_duration_hours END,
        checklist                = CASE WHEN ? IS NOT NULL THEN ? ELSE checklist END,
        updated_at               = datetime('now','localtime')
    WHERE id = ?
  `).run(
    name ? name.trim() : null,
    freqInt,
    durationFloat !== undefined ? 1 : null, durationFloat !== undefined ? durationFloat : null,
    checklistJson !== undefined ? 1 : null, checklistJson !== undefined ? checklistJson : null,
    id,
  );

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'update_pm_protocol',
    target_type: 'pm_protocol', target_id: String(id), target_name: name || existing.name,
    details: JSON.stringify({ frequency_months: freqInt }),
    ...extractReqMeta(req),
  });

  res.json({ message: 'Protocole mis à jour' });
});

// ── DELETE /api/pm-protocols/:id ─────────────────────────────────────────────
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const existing = db.prepare('SELECT * FROM pm_protocols WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Protocole introuvable' });

  db.prepare('DELETE FROM pm_protocols WHERE id = ?').run(id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'delete_pm_protocol',
    target_type: 'pm_protocol', target_id: String(id), target_name: existing.name,
    details: JSON.stringify({ subcategory_id: existing.subcategory_id }),
    ...extractReqMeta(req),
  });

  res.json({ message: 'Protocole supprimé' });
});

module.exports = router;
