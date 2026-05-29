const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole, SYSTEM_ROLES } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

// Rôles techniciens spécialisés (autorisés sur les mêmes routes que l'ancien `technician`).
const TECH_ROLES = ['technician_biomedical', 'technician_it', 'technician_infra'];
const rolesCsv = (req) =>
  (Array.isArray(req.user?.roles) ? req.user.roles : [])
    .filter((r) => !SYSTEM_ROLES.has(r))
    .join(',');

const VALID_STATUSES_EQ = [
  'Operational',
  'Maintenance',
  'Out of service',
  'To be disposal',
  'Disposed',
];
const VALID_CRITICALITIES = ['A', 'B', 'C'];

// Requête de base pour récupérer un équipement avec ses relations
const BASE_SELECT = `
  SELECT
    e.*,
    es.name   AS subcategory_name,
    emc.name  AS macro_category,
    emc.id    AS macro_category_id_resolved
  FROM equipment e
  LEFT JOIN equipment_subcategories        es  ON es.id  = e.subcategory_id
  LEFT JOIN equipment_macro_categories     emc ON emc.id = e.macro_category_id
`;

// Helper : enrichit un équipement brut avec maintenance + tags
function enrichEquipment(db, eq) {
  const histStmt   = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 0 ORDER BY date DESC');
  const futureStmt = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 1 ORDER BY date ASC');
  const tagsStmt   = db.prepare('SELECT tag_number FROM equipment_tags WHERE equipment_id = ? ORDER BY tag_number ASC');
  return {
    ...eq,
    maintenanceHistory: histStmt.all(eq.id),
    futureMaintenance:  futureStmt.all(eq.id),
    tags:               tagsStmt.all(eq.id).map(r => r.tag_number),
  };
}

// Résout macro_category_id à partir de subcategory_id si non fourni explicitement
function resolveMacroCategoryId(db, subcategoryId, explicitMacroCategoryId) {
  if (explicitMacroCategoryId) return parseInt(explicitMacroCategoryId, 10) || null;
  if (!subcategoryId) return null;
  const sub = db.prepare('SELECT macro_category_id FROM equipment_subcategories WHERE id = ?').get(subcategoryId);
  return sub ? sub.macro_category_id : null;
}

// ── GET /api/equipment ────────────────────────────────────────────────────────
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { department, status, category, macro_category, macro_category_id } = req.query;

  let query = `${BASE_SELECT} WHERE 1=1`;
  const params = [];

  if (department)        { query += ' AND e.department = ?';         params.push(department); }
  if (status)            { query += ' AND e.status = ?';             params.push(status); }
  if (category)          { query += ' AND e.category = ?';           params.push(category); }
  if (macro_category)    { query += ' AND emc.name = ?';             params.push(macro_category); }
  if (macro_category_id) { query += ' AND e.macro_category_id = ?';  params.push(parseInt(macro_category_id, 10)); }

  query += ' ORDER BY e.name ASC';

  const equipment = db.prepare(query).all(...params);

  const histStmt   = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 0 ORDER BY date DESC');
  const futureStmt = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 1 ORDER BY date ASC');
  const tagsStmt   = db.prepare('SELECT tag_number FROM equipment_tags WHERE equipment_id = ? ORDER BY tag_number ASC');

  const result = equipment.map(eq => ({
    ...eq,
    maintenanceHistory: histStmt.all(eq.id),
    futureMaintenance:  futureStmt.all(eq.id),
    tags:               tagsStmt.all(eq.id).map(r => r.tag_number),
  }));

  res.json(result);
});

// ── GET /api/equipment/by-tag/:tagNumber ─────────────────────────────────────
router.get('/by-tag/:tagNumber', verifyToken, (req, res) => {
  const db = getDb();
  const tagNumber = req.params.tagNumber?.trim();
  if (!tagNumber) return res.status(400).json({ error: 'Tag number requis' });

  const eq = db.prepare(`
    ${BASE_SELECT}
    JOIN equipment_tags t ON t.equipment_id = e.id
    WHERE t.tag_number = ?
    LIMIT 1
  `).get(tagNumber);

  if (!eq) return res.status(404).json({ error: 'Équipement introuvable pour ce tag' });

  const tags = db.prepare('SELECT tag_number FROM equipment_tags WHERE equipment_id = ? ORDER BY tag_number').all(eq.id).map(r => r.tag_number);
  res.json({ ...eq, tags, maintenanceHistory: [], futureMaintenance: [] });
});

// ── POST /api/equipment/restore ───────────────────────────────────────────────
router.post('/restore', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const {
    id, name, department, category, serial_number, status, location,
    manufacturer, model, manuf_year, install_date, next_revision_date,
    last_preventive_maintenance, next_preventive_maintenance,
    subcategory_id, macro_category_id, warranty_end_date, criticality,
  } = req.body;

  if (!id || !name || !department || !category) {
    return res.status(400).json({ error: 'Données de restauration incomplètes' });
  }

  const resolvedMacroCategoryId = resolveMacroCategoryId(db, subcategory_id, macro_category_id);
  const critVal = criticality && VALID_CRITICALITIES.includes(criticality) ? criticality : null;

  try {
    db.prepare(`
      INSERT INTO equipment (
        id, name, department, category, serial_number, status, location,
        manufacturer, model, manuf_year, install_date, next_revision_date,
        last_preventive_maintenance, next_preventive_maintenance,
        subcategory_id, macro_category_id, warranty_end_date, criticality
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id, name, department, category,
      serial_number || null,
      status || 'Operational',
      location || null,
      manufacturer || null, model || null,
      manuf_year != null ? parseInt(manuf_year, 10) || null : null,
      install_date || null,
      next_revision_date || null,
      last_preventive_maintenance || null,
      next_preventive_maintenance || null,
      subcategory_id ? parseInt(subcategory_id, 10) : null,
      resolvedMacroCategoryId,
      warranty_end_date || null,
      critVal,
    );

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
      action: 'restore_equipment', target_type: 'equipment', target_id: id, target_name: name,
      ...extractReqMeta(req) });

    res.status(201).json({ message: 'Équipement restauré', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Un équipement avec cet ID existe déjà' });
    }
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/equipment/:id ────────────────────────────────────────────────────
router.get('/:id', verifyToken, (req, res) => {
  const db = getDb();
  const eq = db.prepare(`${BASE_SELECT} WHERE e.id = ?`).get(req.params.id);
  if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

  const history = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 0 ORDER BY date DESC').all(eq.id);
  const future  = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 1 ORDER BY date ASC').all(eq.id);
  const tags    = db.prepare('SELECT tag_number FROM equipment_tags WHERE equipment_id = ? ORDER BY tag_number ASC').all(eq.id).map(r => r.tag_number);

  // Protocoles PM de la sous-catégorie de cet équipement
  const pmProtocols = eq.subcategory_id
    ? db.prepare(`
        SELECT p.*, s.name AS subcategory_name
        FROM pm_protocols p
        LEFT JOIN equipment_subcategories s ON s.id = p.subcategory_id
        WHERE p.subcategory_id = ?
        ORDER BY p.frequency_months ASC
      `).all(eq.subcategory_id).map(p => ({
          ...p,
          checklist: p.checklist ? (() => { try { return JSON.parse(p.checklist); } catch (_) { return []; } })() : [],
        }))
    : [];

  res.json({ ...eq, maintenanceHistory: history, futureMaintenance: future, tags, pmProtocols });
});

// ── POST /api/equipment ───────────────────────────────────────────────────────
router.post('/', verifyToken, requireRole('admin', 'supervisor'), (req, res) => {
  const db = getDb();
  const {
    id, name, department, category, serial_number, status, location,
    manufacturer, model, manuf_year, install_date, next_revision_date,
    last_preventive_maintenance, next_preventive_maintenance,
    subcategory_id, macro_category_id, warranty_end_date, criticality,
  } = req.body;

  if (!id || !name || !department || !category) {
    return res.status(400).json({ error: 'Champs requis: id, name, department, category' });
  }
  if (!/^[a-zA-Z0-9_-]+$/.test(id) || id.length > 100) {
    return res.status(400).json({ error: 'ID invalide (alphanumérique, max 100 caractères)' });
  }
  if (typeof name !== 'string' || name.length > 255) {
    return res.status(400).json({ error: 'Nom invalide (max 255 caractères)' });
  }
  if (status && !VALID_STATUSES_EQ.includes(status)) {
    return res.status(400).json({ error: `Statut invalide. Valeurs acceptées : ${VALID_STATUSES_EQ.join(', ')}` });
  }
  if (criticality && !VALID_CRITICALITIES.includes(criticality)) {
    return res.status(400).json({ error: 'criticality invalide (A, B ou C)' });
  }

  let manufYearInt = null;
  if (manuf_year != null && manuf_year !== '') {
    manufYearInt = parseInt(manuf_year, 10);
    if (!Number.isFinite(manufYearInt) || manufYearInt < 1900 || manufYearInt > 2100) {
      return res.status(400).json({ error: 'Année de fabrication invalide (1900 - 2100)' });
    }
  }

  const subIdInt = subcategory_id ? parseInt(subcategory_id, 10) : null;
  const resolvedMacroCategoryId = resolveMacroCategoryId(db, subIdInt, macro_category_id);

  try {
    db.prepare(`
      INSERT INTO equipment (
        id, name, department, category, serial_number, status, location,
        manufacturer, model, manuf_year, install_date, next_revision_date,
        last_preventive_maintenance, next_preventive_maintenance,
        subcategory_id, macro_category_id, warranty_end_date, criticality
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id, name, department, category,
      serial_number || null,
      status || 'Operational',
      location || null,
      manufacturer || null, model || null, manufYearInt,
      install_date || null, next_revision_date || null,
      last_preventive_maintenance || null,
      next_preventive_maintenance || null,
      subIdInt,
      resolvedMacroCategoryId,
      warranty_end_date || null,
      criticality || null,
    );

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
      action: 'create_equipment', target_type: 'equipment', target_id: id, target_name: name,
      ...extractReqMeta(req) });

    res.status(201).json({ message: 'Équipement créé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'ID déjà utilisé' });
    }
    res.status(500).json({ error: err.message });
  }
});

// ── PUT /api/equipment/:id ────────────────────────────────────────────────────
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const {
    name, department, category, serial_number, status, location,
    manufacturer, model, manuf_year, install_date, next_revision_date,
    last_preventive_maintenance, next_preventive_maintenance,
    subcategory_id, macro_category_id, warranty_end_date, criticality,
  } = req.body;

  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  if (status && !VALID_STATUSES_EQ.includes(status)) {
    return res.status(400).json({ error: `Statut invalide. Valeurs acceptées : ${VALID_STATUSES_EQ.join(', ')}` });
  }
  if (criticality && !VALID_CRITICALITIES.includes(criticality)) {
    return res.status(400).json({ error: 'criticality invalide (A, B ou C)' });
  }

  let manufYearInt = null;
  if (manuf_year !== undefined && manuf_year !== null && manuf_year !== '') {
    manufYearInt = parseInt(manuf_year, 10);
    if (!Number.isFinite(manufYearInt) || manufYearInt < 1900 || manufYearInt > 2100) {
      return res.status(400).json({ error: 'Année de fabrication invalide (1900 - 2100)' });
    }
  }

  const subIdInt = subcategory_id !== undefined
    ? (subcategory_id ? parseInt(subcategory_id, 10) : null)
    : undefined;

  // Résolution de macro_category_id : si subcategory_id est fourni, le dériver
  let resolvedMacro = undefined;
  if (subIdInt !== undefined) {
    resolvedMacro = resolveMacroCategoryId(db, subIdInt, macro_category_id);
  } else if (macro_category_id !== undefined) {
    resolvedMacro = parseInt(macro_category_id, 10) || null;
  }

  db.prepare(`
    UPDATE equipment
    SET name                        = COALESCE(?, name),
        department                  = COALESCE(?, department),
        category                    = COALESCE(?, category),
        serial_number               = COALESCE(?, serial_number),
        status                      = COALESCE(?, status),
        location                    = COALESCE(?, location),
        manufacturer                = COALESCE(?, manufacturer),
        model                       = COALESCE(?, model),
        manuf_year                  = COALESCE(?, manuf_year),
        install_date                = COALESCE(?, install_date),
        next_revision_date          = COALESCE(?, next_revision_date),
        last_preventive_maintenance = COALESCE(?, last_preventive_maintenance),
        next_preventive_maintenance = COALESCE(?, next_preventive_maintenance),
        subcategory_id              = COALESCE(?, subcategory_id),
        macro_category_id           = COALESCE(?, macro_category_id),
        warranty_end_date           = COALESCE(?, warranty_end_date),
        criticality                 = COALESCE(?, criticality),
        updated_at                  = datetime('now','localtime')
    WHERE id = ?
  `).run(
    name, department, category, serial_number, status, location,
    manufacturer, model, manufYearInt, install_date, next_revision_date,
    last_preventive_maintenance, next_preventive_maintenance,
    subIdInt !== undefined ? subIdInt : null,
    resolvedMacro !== undefined ? resolvedMacro : null,
    warranty_end_date !== undefined ? warranty_end_date : null,
    criticality || null,
    req.params.id,
  );

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'update_equipment', target_type: 'equipment', target_id: req.params.id,
    target_name: name || existing.name,
    details: {
      snapshot_before: {
        id: existing.id, name: existing.name, status: existing.status,
        department: existing.department, criticality: existing.criticality,
        last_preventive_maintenance: existing.last_preventive_maintenance,
        next_preventive_maintenance: existing.next_preventive_maintenance,
      },
    },
    ...extractReqMeta(req) });

  res.json({ message: 'Équipement mis à jour' });
});

// ── DELETE /api/equipment/:id ─────────────────────────────────────────────────
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  db.prepare('DELETE FROM equipment WHERE id = ?').run(req.params.id);
  const rawReason = req.query.reason;
  const reason = rawReason && typeof rawReason === 'string'
    ? rawReason.replace(/[<>'"]/g, '').substring(0, 200)
    : undefined;

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'delete_equipment', target_type: 'equipment', target_id: req.params.id,
    target_name: existing.name,
    details: {
      snapshot: {
        id: existing.id, name: existing.name, department: existing.department,
        category: existing.category, status: existing.status,
        criticality: existing.criticality, warranty_end_date: existing.warranty_end_date,
      },
      ...(reason ? { reason } : {}),
    },
    ...extractReqMeta(req) });

  res.json({ message: 'Équipement supprimé' });
});

// ── POST /api/equipment/:id/maintenance ───────────────────────────────────────
router.post('/:id/maintenance', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { date, intervention, technician, is_future } = req.body;

  if (!date || !intervention || !technician) {
    return res.status(400).json({ error: 'Champs requis: date, intervention, technician' });
  }

  const eq = db.prepare('SELECT id, name FROM equipment WHERE id = ?').get(req.params.id);
  if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

  const result = db.prepare(`
    INSERT INTO maintenance_records (equipment_id, date, intervention, technician, is_future)
    VALUES (?, ?, ?, ?, ?)
  `).run(req.params.id, date, intervention, technician, is_future ? 1 : 0);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: is_future ? 'schedule_maintenance' : 'add_maintenance',
    target_type: 'equipment', target_id: req.params.id, target_name: eq.name,
    details: { date, intervention, technician }, ...extractReqMeta(req) });

  res.status(201).json({ message: 'Maintenance enregistrée', id: result.lastInsertRowid });
});

module.exports = router;
