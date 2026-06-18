const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

// ── GET /api/departments ───────────────────────────────────────────────────────
// Retourne la liste avec stats (equipment_count, open_issues_count) incluses.
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const rows = db.prepare(`
    SELECT
      d.id,
      d.name,
      d.description,
      (SELECT COUNT(*) FROM equipment e WHERE e.department_id = d.id) AS equipment_count,
      (SELECT COUNT(*) FROM issues i
       WHERE i.department = d.name
         AND i.status NOT IN ('Completed', 'Closed')) AS open_issues_count
    FROM departments d
    ORDER BY d.name ASC
  `).all();
  res.json(rows);
});

// ── GET /api/departments/:id/stats ────────────────────────────────────────────
router.get('/:id/stats', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const dept = db.prepare('SELECT id, name FROM departments WHERE id = ?').get(id);
  if (!dept) return res.status(404).json({ error: 'Département introuvable' });

  const { equipment_count } = db.prepare(
    'SELECT COUNT(*) AS equipment_count FROM equipment WHERE department_id = ?'
  ).get(id);

  const { open_issues_count } = db.prepare(
    `SELECT COUNT(*) AS open_issues_count FROM issues
     WHERE department = ? AND status NOT IN ('Completed', 'Closed')`
  ).get(dept.name);

  res.json({ equipment_count, open_issues_count });
});

// ── GET /api/departments/:id/detail ───────────────────────────────────────────
// Dashboard d'un département (lecture seule) : KPIs parc + équipements + incidents
// ouverts ET résolus. Les KPIs/équipements filtrent par department_id ; les
// incidents par nom (issues.department est un texte, comme dans /stats et la liste).
router.get('/:id/detail', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const dept = db.prepare('SELECT id, name FROM departments WHERE id = ?').get(id);
  if (!dept) return res.status(404).json({ error: 'Département introuvable' });

  // KPIs parc : compteurs par statut (hors réformés pour le total actif) + PM en retard.
  // pmOverdue = même logique que l'alerte PM « due » (échéance dépassée), hors réformés.
  const kpis = db.prepare(`
    SELECT
      COUNT(*)                                                              AS total,
      SUM(CASE WHEN status = 'Operational'    THEN 1 ELSE 0 END)            AS operational,
      SUM(CASE WHEN status = 'Maintenance'    THEN 1 ELSE 0 END)            AS maintenance,
      SUM(CASE WHEN status = 'Out of service' THEN 1 ELSE 0 END)            AS outOfService,
      SUM(CASE
            WHEN next_preventive_maintenance IS NOT NULL
             AND date(next_preventive_maintenance) < date('now','localtime')
            THEN 1 ELSE 0 END)                                              AS pmOverdue
    FROM equipment
    WHERE department_id = ? AND status != 'Disposed'
  `).get(id);

  // Équipements actifs du département.
  const equipment = db.prepare(`
    SELECT id, name, status, category
    FROM equipment
    WHERE department_id = ? AND status != 'Disposed'
    ORDER BY name ASC
  `).all(id);

  // Incidents ouverts (statuts non terminaux). Jointure du lieu pour afficher
  // un nom même quand l'incident vise une infrastructure (equipment_id NULL).
  const openIssues = db.prepare(`
    SELECT i.id, i.type, i.description, i.status, i.urgency, i.issue_category,
           i.equipment_name,
           COALESCE(l.name, i.location_text) AS location_name,
           i.created_at, i.updated_at
    FROM issues i
    LEFT JOIN locations l ON l.id = i.location_id
    WHERE i.department = ?
      AND i.status IN ('Reported','Acknowledged','Assigned','In Progress','Waiting Materials','Redirected')
    ORDER BY i.created_at DESC
  `).all(dept.name);

  // Incidents résolus (statuts terminaux). Triés par date de clôture (updated_at).
  const resolvedIssues = db.prepare(`
    SELECT i.id, i.type, i.description, i.status, i.urgency, i.issue_category,
           i.equipment_name,
           COALESCE(l.name, i.location_text) AS location_name,
           i.created_at, i.updated_at
    FROM issues i
    LEFT JOIN locations l ON l.id = i.location_id
    WHERE i.department = ?
      AND i.status IN ('Completed','Verified','Closed')
    ORDER BY i.updated_at DESC
  `).all(dept.name);

  res.json({
    id: dept.id,
    name: dept.name,
    kpis: {
      total:           kpis.total        || 0,
      operational:     kpis.operational  || 0,
      maintenance:     kpis.maintenance  || 0,
      outOfService:    kpis.outOfService || 0,
      pmOverdue:       kpis.pmOverdue    || 0,
      openIssuesCount: openIssues.length,
    },
    equipment,
    openIssues,
    resolvedIssues,
  });
});

// ── GET /api/departments/:id/check-dependencies ───────────────────────────────
router.get('/:id/check-dependencies', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const { count } = db.prepare(
    'SELECT COUNT(*) AS count FROM equipment WHERE department_id = ?'
  ).get(id);

  res.json({ has_dependencies: count > 0, equipment_count: count });
});

// ── POST /api/departments ──────────────────────────────────────────────────────
router.post('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { name, description } = req.body;

  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });

  const duplicate = db.prepare(
    'SELECT id FROM departments WHERE LOWER(name) = LOWER(?)'
  ).get(name.trim());
  if (duplicate) return res.status(409).json({ error: 'Un département avec ce nom existe déjà' });

  const result = db.prepare(
    'INSERT INTO departments (name, description) VALUES (?, ?)'
  ).run(name.trim(), description?.trim() || null);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] ?? 'admin',
    action: 'create_department',
    target_type: 'department', target_id: String(result.lastInsertRowid), target_name: name.trim(),
    details: { description: description?.trim() || null },
    ...extractReqMeta(req),
  });

  res.status(201).json({
    id: result.lastInsertRowid,
    name: name.trim(),
    description: description?.trim() || null,
    equipment_count: 0,
    open_issues_count: 0,
  });
});

// ── PUT /api/departments/:id ───────────────────────────────────────────────────
router.put('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const { name, description } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });

  const existing = db.prepare('SELECT * FROM departments WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Département introuvable' });

  const duplicate = db.prepare(
    'SELECT id FROM departments WHERE LOWER(name) = LOWER(?) AND id != ?'
  ).get(name.trim(), id);
  if (duplicate) return res.status(409).json({ error: 'Un département avec ce nom existe déjà' });

  db.prepare(
    'UPDATE departments SET name = ?, description = ? WHERE id = ?'
  ).run(name.trim(), description?.trim() || null, id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] ?? 'admin',
    action: 'update_department',
    target_type: 'department', target_id: String(id), target_name: name.trim(),
    details: { old_name: existing.name, name, description },
    ...extractReqMeta(req),
  });

  res.json({ id, name: name.trim(), description: description?.trim() || null });
});

// ── DELETE /api/departments/:id ────────────────────────────────────────────────
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const dept = db.prepare('SELECT * FROM departments WHERE id = ?').get(id);
  if (!dept) return res.status(404).json({ error: 'Département introuvable' });

  const { count } = db.prepare(
    'SELECT COUNT(*) AS count FROM equipment WHERE department_id = ?'
  ).get(id);

  if (count > 0) {
    return res.status(409).json({
      error: 'DEPARTMENT_HAS_EQUIPMENT',
      message: `Ce département a ${count} équipement(s) associé(s). Réaffectez-les avant de supprimer.`,
      equipment_count: count,
    });
  }

  db.prepare('DELETE FROM departments WHERE id = ?').run(id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0] ?? 'admin',
    action: 'delete_department',
    target_type: 'department', target_id: String(id), target_name: dept.name,
    details: {},
    ...extractReqMeta(req),
  });

  res.json({ success: true, message: 'Département supprimé' });
});

module.exports = router;
