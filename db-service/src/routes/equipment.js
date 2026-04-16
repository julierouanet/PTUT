const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

const VALID_STATUSES_EQ   = ['Disponible', 'En service', 'En maintenance', 'Hors service'];
const VALID_DEPARTMENTS   = ['IT', 'Radiologie', 'Réanimation', 'Stérilisation', 'Laboratoire', 'Urgences', 'Maintenance', 'Infrastructure'];
const VALID_CATEGORIES_EQ = ['Imagerie', 'Laboratoire', 'Chirurgie', 'Monitoring', 'Thérapeutique', 'Informatique', 'Mobilier', 'Autre'];

// GET /api/equipment - liste tous les équipements
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { department, status, category } = req.query;

  let query = 'SELECT * FROM equipment WHERE 1=1';
  const params = [];

  if (department) { query += ' AND department = ?'; params.push(department); }
  if (status)     { query += ' AND status = ?';     params.push(status); }
  if (category)   { query += ' AND category = ?';   params.push(category); }

  query += ' ORDER BY name ASC';

  const equipment = db.prepare(query).all(...params);

  // Attach maintenance records
  const result = equipment.map(eq => {
    const history = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 0 ORDER BY date DESC').all(eq.id);
    const future  = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 1 ORDER BY date ASC').all(eq.id);
    return { ...eq, maintenanceHistory: history, futureMaintenance: future };
  });

  res.json(result);
});

// POST /api/equipment/restore — restaurer un équipement supprimé (admin)
router.post('/restore', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { id, name, department, category, serial_number, status, supplier, location, next_revision_date } = req.body;

  if (!id || !name || !department || !category) {
    return res.status(400).json({ error: 'Données de restauration incomplètes' });
  }

  try {
    db.prepare(`
      INSERT INTO equipment (id, name, department, category, serial_number, status, supplier, location, next_revision_date)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(id, name, department, category, serial_number || null, status || 'Disponible', supplier || null, location || null, next_revision_date || null);

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
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

// GET /api/equipment/:id
router.get('/:id', verifyToken, (req, res) => {
  const db = getDb();
  const eq = db.prepare('SELECT * FROM equipment WHERE id = ?').get(req.params.id);

  if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

  const history = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 0 ORDER BY date DESC').all(eq.id);
  const future  = db.prepare('SELECT * FROM maintenance_records WHERE equipment_id = ? AND is_future = 1 ORDER BY date ASC').all(eq.id);

  res.json({ ...eq, maintenanceHistory: history, futureMaintenance: future });
});

// POST /api/equipment - créer un équipement (admin/supervisor)
router.post('/', verifyToken, requireRole('admin', 'supervisor'), (req, res) => {
  const db = getDb();
  const { id, name, department, category, serial_number, status, supplier, location, next_revision_date } = req.body;

  if (!id || !name || !department || !category) {
    return res.status(400).json({ error: 'Champs requis: id, name, department, category' });
  }

  // Validation format
  if (!/^[a-zA-Z0-9_-]+$/.test(id) || id.length > 100) {
    return res.status(400).json({ error: 'ID invalide (alphanumérique, max 100 caractères)' });
  }
  if (typeof name !== 'string' || name.length > 255) {
    return res.status(400).json({ error: 'Nom invalide (max 255 caractères)' });
  }
  if (!VALID_DEPARTMENTS.includes(department)) {
    return res.status(400).json({ error: 'Département invalide' });
  }
  if (status && !VALID_STATUSES_EQ.includes(status)) {
    return res.status(400).json({ error: `Statut invalide. Valeurs acceptées : ${VALID_STATUSES_EQ.join(', ')}` });
  }

  try {
    db.prepare(`
      INSERT INTO equipment (id, name, department, category, serial_number, status, supplier, location, next_revision_date)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(id, name, department, category, serial_number || null, status || 'Disponible', supplier || null, location || null, next_revision_date || null);

    logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
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

// PUT /api/equipment/:id - modifier un équipement
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
  const db = getDb();
  const { name, department, category, serial_number, status, supplier, location, next_revision_date } = req.body;

  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  db.prepare(`
    UPDATE equipment
    SET name = COALESCE(?, name),
        department = COALESCE(?, department),
        category = COALESCE(?, category),
        serial_number = COALESCE(?, serial_number),
        status = COALESCE(?, status),
        supplier = COALESCE(?, supplier),
        location = COALESCE(?, location),
        next_revision_date = COALESCE(?, next_revision_date),
        updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(name, department, category, serial_number, status, supplier, location, next_revision_date, req.params.id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: 'update_equipment', target_type: 'equipment', target_id: req.params.id,
    target_name: name || existing.name,
    details: { snapshot_before: { id: existing.id, name: existing.name, status: existing.status, department: existing.department } },
    ...extractReqMeta(req) });

  res.json({ message: 'Équipement mis à jour' });
});

// DELETE /api/equipment/:id (admin seulement)
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  db.prepare('DELETE FROM equipment WHERE id = ?').run(req.params.id);
  const rawReason = req.query.reason;
  // Sanitisation : longueur max 200 chars, caractères simples uniquement
  const reason = rawReason && typeof rawReason === 'string'
    ? rawReason.replace(/[<>'"]/g, '').substring(0, 200)
    : undefined;

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: 'delete_equipment', target_type: 'equipment', target_id: req.params.id,
    target_name: existing.name,
    details: {
      snapshot: { id: existing.id, name: existing.name, department: existing.department, category: existing.category, status: existing.status },
      ...(reason ? { reason } : {}),
    },
    ...extractReqMeta(req) });

  res.json({ message: 'Équipement supprimé' });
});

// POST /api/equipment/:id/maintenance - ajouter un enregistrement de maintenance
router.post('/:id/maintenance', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
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

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: is_future ? 'schedule_maintenance' : 'add_maintenance',
    target_type: 'equipment', target_id: req.params.id, target_name: eq.name,
    details: { date, intervention, technician }, ...extractReqMeta(req) });

  res.status(201).json({ message: 'Maintenance enregistrée', id: result.lastInsertRowid });
});

module.exports = router;
