const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { TECH_ROLES, rolesCsv } = require('../utils/roles');
const { generateMaintenanceLabelPdf } = require('../services/pdf_label_service');
const { buildReplacementPlan } = require('../utils/replacement');

const router = express.Router();

const VALID_STATUSES_EQ = [
  'Operational',
  'Maintenance',
  'Out of service',
  'To be disposal',
  'Disposed',
];
const VALID_CRITICALITIES = ['A', 'B', 'C'];

// Cycle de vie : motifs de réforme et méthodes d'élimination (whitelists serveur).
// Toute valeur hors liste est rejetée en 400. disposal_method reste extensible
// (ex. 'recycled' futur) mais on ne l'ajoute pas tant que le module déchets
// biomédicaux n'est pas implémenté.
const DECOMMISSION_REASONS = ['irreparable', 'obsolete', 'replaced', 'lost', 'donated_out'];
const DISPOSAL_METHODS     = ['destroyed', 'sold', 'donated', 'returned', 'cannibalized'];

// Requête de base pour récupérer un équipement avec ses relations
const BASE_SELECT = `
  SELECT
    e.*,
    es.name   AS subcategory_name,
    emc.name  AS macro_category,
    emc.id    AS macro_category_id_resolved,
    -- Nom du remplaçant pointé par e.replaced_by_id (lien « remplacé par → »)
    (SELECT r.name FROM equipment r WHERE r.id = e.replaced_by_id)                 AS replaced_by_name,
    -- Lien inverse : l'équipement réformé que CET équipement remplace
    (SELECT o.id   FROM equipment o WHERE o.replaced_by_id = e.id LIMIT 1)         AS replaces_id,
    (SELECT o.name FROM equipment o WHERE o.replaced_by_id = e.id LIMIT 1)         AS replaces_name
  FROM equipment e
  LEFT JOIN equipment_subcategories        es  ON es.id  = e.subcategory_id
  LEFT JOIN equipment_macro_categories     emc ON emc.id = e.macro_category_id
`;

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
  const {
    department, status, category, macro_category, macro_category_id,
    subcategory_id, brand_id, model_id, include_disposed,
  } = req.query;

  let query = `${BASE_SELECT} WHERE 1=1`;
  const params = [];

  // Les équipements réformés (Disposed) sortent des listes actives par défaut.
  // ?include_disposed=true pour les inclure (vue « équipements réformés »).
  // Un filtre status explicite a priorité (permet de cibler les Disposed).
  if (include_disposed !== 'true' && status !== 'Disposed') {
    query += " AND e.status != 'Disposed'";
  }

  if (department)        { query += ' AND e.department = ?';         params.push(department); }
  if (status)            { query += ' AND e.status = ?';             params.push(status); }
  if (category)          { query += ' AND e.category = ?';           params.push(category); }
  if (macro_category)    { query += ' AND emc.name = ?';             params.push(macro_category); }
  if (macro_category_id) { query += ' AND e.macro_category_id = ?';  params.push(parseInt(macro_category_id, 10)); }
  if (subcategory_id)    { query += ' AND e.subcategory_id = ?';     params.push(parseInt(subcategory_id, 10)); }
  if (model_id)          { query += ' AND e.model_id = ?';           params.push(parseInt(model_id, 10)); }
  // Filtre par fabricant : via le modèle rattaché à l'équipement.
  if (brand_id) {
    query += ' AND e.model_id IN (SELECT id FROM equipment_models WHERE brand_id = ?)';
    params.push(parseInt(brand_id, 10));
  }

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

// ── GET /api/equipment/replacement-plan ──────────────────────────────────────
// Plan de remplacement priorisé des équipements BIOMÉDICAUX (RA3 S5).
// Calcul serveur (source de vérité unique) du statut de remplacement et de
// l'horizon budgétaire à partir de l'âge et de la durée de vie de la sous-cat.
// Lecture réservée admin/supervisor (≈ permission generateReports).
// NB : route statique placée AVANT /:id pour ne pas être capturée.
router.get('/replacement-plan', verifyToken, requireRole('admin', 'supervisor'), (req, res) => {
  const db = getDb();

  const rows = db.prepare(`
    SELECT
      e.id,
      e.name,
      e.criticality,
      e.manuf_year,
      e.install_date,
      e.status,
      es.name                     AS subcategory,
      es.expected_lifespan_years  AS expected_lifespan_years
    FROM equipment e
    LEFT JOIN equipment_subcategories    es  ON es.id  = e.subcategory_id
    LEFT JOIN equipment_macro_categories emc ON emc.id = e.macro_category_id
    WHERE emc.name = 'Biomedical'
  `).all();

  const currentYear = new Date().getFullYear();
  const plan = buildReplacementPlan(rows, currentYear);

  res.json(plan);
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

  // Plan PM actif de cet équipement (fréquence + dernière date)
  const pmPlan = db.prepare(
    'SELECT id, frequency_months, last_completed_date FROM preventive_maintenance_plans WHERE equipment_id = ? LIMIT 1'
  ).get(eq.id) || null;

  res.json({ ...eq, maintenanceHistory: history, futureMaintenance: future, tags, pmProtocols, pmPlan });
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

// ── POST /api/equipment/:id/propose-disposal ──────────────────────────────────
// Étape 1 du workflow de réforme : un technicien/superviseur PROPOSE la mise au
// rebut. L'équipement passe 'To be disposal' (reste visible dans les listes
// actives), motif pré-rempli mais modifiable à la validation par l'admin.
router.post('/:id/propose-disposal', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { id } = req.params;
  const { decommission_reason } = req.body;

  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  if (existing.status === 'Disposed') {
    return res.status(400).json({ error: 'Équipement déjà réformé' });
  }
  if (!DECOMMISSION_REASONS.includes(decommission_reason)) {
    return res.status(400).json({ error: `Motif invalide. Valeurs acceptées : ${DECOMMISSION_REASONS.join(', ')}` });
  }

  db.prepare(`
    UPDATE equipment
    SET status = 'To be disposal', decommission_reason = ?, updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(decommission_reason, id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'propose_disposal_equipment', target_type: 'equipment', target_id: id,
    target_name: existing.name,
    details: { decommission_reason, status_before: existing.status },
    ...extractReqMeta(req) });

  res.json({ message: 'Mise au rebut proposée' });
});

// ── POST /api/equipment/:id/decommission ──────────────────────────────────────
// Étape 2 (validation finale, admin only) : réforme effective (soft delete).
// L'équipement passe 'Disposed' et conserve tout son historique pour l'audit.
router.post('/:id/decommission', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { id } = req.params;
  const { decommission_reason, disposal_method, decommission_notes, replaced_by_id } = req.body;

  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  // 1. Validation des whitelists
  if (!DECOMMISSION_REASONS.includes(decommission_reason)) {
    return res.status(400).json({ error: `Motif invalide. Valeurs acceptées : ${DECOMMISSION_REASONS.join(', ')}` });
  }
  if (!DISPOSAL_METHODS.includes(disposal_method)) {
    return res.status(400).json({ error: `Méthode d'élimination invalide. Valeurs acceptées : ${DISPOSAL_METHODS.join(', ')}` });
  }

  // 2. Validation du lien remplaçant
  const replacedById = replaced_by_id || null;
  if (replacedById) {
    if (replacedById === id) {
      return res.status(400).json({ error: 'Un équipement ne peut pas se remplacer lui-même' });
    }
    const replacement = db.prepare('SELECT id FROM equipment WHERE id = ?').get(replacedById);
    if (!replacement) return res.status(404).json({ error: 'Équipement remplaçant introuvable' });
  }
  // Motif 'replaced' → le remplaçant est obligatoire
  if (decommission_reason === 'replaced' && !replacedById) {
    return res.status(400).json({ error: "replaced_by_id requis lorsque le motif est 'replaced'" });
  }

  const notes = decommission_notes && typeof decommission_notes === 'string'
    ? decommission_notes.substring(0, 1000)
    : null;

  // 3. Soft delete : on ne supprime jamais la ligne
  db.prepare(`
    UPDATE equipment
    SET status                  = 'Disposed',
        decommissioned_at       = datetime('now','localtime'),
        decommission_reason     = ?,
        disposal_method         = ?,
        decommission_notes      = ?,
        decommissioned_by_id    = ?,
        decommissioned_by_name  = ?,
        replaced_by_id          = ?,
        updated_at              = datetime('now','localtime')
    WHERE id = ?
  `).run(decommission_reason, disposal_method, notes, req.user.id, req.user.name, replacedById, id);

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'decommission_equipment', target_type: 'equipment', target_id: id,
    target_name: existing.name,
    details: {
      decommission_reason, disposal_method, notes, replaced_by_id: replacedById,
      status_before: existing.status,
    },
    ...extractReqMeta(req) });

  res.json({ message: 'Équipement réformé' });
});

// ── DELETE /api/equipment/:id ─────────────────────────────────────────────────
// Suppression DÉFINITIVE (hard delete) réservée aux erreurs de saisie.
// Garde-fou type Fiix : un équipement avec historique ne peut pas être effacé
// sans ?force=true (admin only) — il faut le réformer (POST /decommission).
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = req.params.id;
  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  // Décompte de l'historique lié en une seule requête (issues n'a PAS de FK).
  const hist = db.prepare(`
    SELECT
      (SELECT COUNT(*) FROM issues               WHERE equipment_id = @id) +
      (SELECT COUNT(*) FROM maintenance_records  WHERE equipment_id = @id) +
      (SELECT COUNT(*) FROM equipment_tags       WHERE equipment_id = @id) +
      (SELECT COUNT(*) FROM equipment_documents  WHERE equipment_id = @id AND deleted_at IS NULL) AS total
  `).get({ id });
  const hasHistory = hist.total > 0;

  const forced = req.query.force === 'true';

  // Garde-fou : refuse la purge d'un équipement avec historique sans force
  if (hasHistory && !forced) {
    return res.status(409).json({
      error: 'Équipement avec historique : réformer au lieu de supprimer',
      hasHistory: true,
    });
  }

  // Purge : issues/equipment_tags/equipment_documents sans CASCADE → manuel ;
  // maintenance_records part en CASCADE (FK ON DELETE CASCADE).
  const purge = db.transaction(() => {
    if (forced) {
      db.prepare('DELETE FROM issues WHERE equipment_id = ?').run(id);
      db.prepare('DELETE FROM equipment_tags WHERE equipment_id = ?').run(id);
      db.prepare('DELETE FROM equipment_documents WHERE equipment_id = ?').run(id);
    }
    db.prepare('DELETE FROM equipment WHERE id = ?').run(id);
  });
  purge();

  const rawReason = req.query.reason;
  const reason = rawReason && typeof rawReason === 'string'
    ? rawReason.replace(/[<>'"]/g, '').substring(0, 200)
    : undefined;

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: 'delete_equipment', target_type: 'equipment', target_id: id,
    target_name: existing.name,
    details: {
      snapshot: {
        id: existing.id, name: existing.name, department: existing.department,
        category: existing.category, status: existing.status,
        criticality: existing.criticality, warranty_end_date: existing.warranty_end_date,
      },
      ...(forced ? { forced: true } : {}),
      ...(reason ? { reason } : {}),
    },
    ...extractReqMeta(req) });

  res.json({ message: 'Équipement supprimé' });
});

// ── POST /api/equipment/:id/maintenance ───────────────────────────────────────
// Enregistrement d'une maintenance préventive ou corrective (v3).
// Si maintenance_type = 'preventive' : met à jour last/next PM, gère le plan, dé-stocke les pièces.
// Rétro-compatible : si seuls date/intervention/technician/is_future sont fournis, comportement legacy.
router.post('/:id/maintenance', verifyToken, requireRole('admin', 'supervisor', ...TECH_ROLES), (req, res) => {
  const db = getDb();
  const { id } = req.params;
  const {
    date, intervention, technician, is_future,
    checklist_snapshot, notes, duration_minutes, parts_used, maintenance_type,
  } = req.body;

  // Validation minimale legacy
  if (is_future !== undefined && !maintenance_type) {
    // Chemin legacy : date + intervention + technician requis
    if (!date || !intervention || !technician) {
      return res.status(400).json({ error: 'Champs requis: date, intervention, technician' });
    }
  }

  const eq = db.prepare('SELECT * FROM equipment WHERE id = ?').get(id);
  if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

  const isPreventive = maintenance_type === 'preventive';

  // ── Chemin v3 (maintenance préventive) ──────────────────────────────────────
  if (isPreventive) {
    const now = db.prepare("SELECT datetime('now','localtime') as now").get().now;

    // 1. Insérer dans maintenance_records
    const insertResult = db.prepare(`
      INSERT INTO maintenance_records
        (equipment_id, date, intervention, technician, technician_id,
         checklist_snapshot, duration_minutes, parts_used, maintenance_type, is_future)
      VALUES (?, ?, 'Maintenance préventive', ?, ?, ?, ?, ?, 'preventive', 0)
    `).run(
      id, now,
      req.user.name, req.user.id,
      JSON.stringify(checklist_snapshot || []),
      duration_minutes || null,
      JSON.stringify(parts_used || []),
    );

    // 2. Récupérer frequency_months : plan existant > pm_protocols > défaut 12
    let freqMonths = null;
    const plan = db.prepare(
      'SELECT frequency_months FROM preventive_maintenance_plans WHERE equipment_id = ?'
    ).get(id);
    if (plan) {
      freqMonths = plan.frequency_months;
    } else {
      const proto = db.prepare(`
        SELECT p.frequency_months FROM pm_protocols p
        JOIN equipment_subcategories s ON s.id = p.subcategory_id
        WHERE s.id = (SELECT subcategory_id FROM equipment WHERE id = ? LIMIT 1)
        ORDER BY p.frequency_months ASC LIMIT 1
      `).get(id);
      freqMonths = proto ? proto.frequency_months : 12;
    }

    // 3. Calculer next_preventive_maintenance
    const nextPm = db.prepare(
      "SELECT datetime(?, '+' || ? || ' months') as next"
    ).get(now, freqMonths).next;

    // 4. UPSERT preventive_maintenance_plans
    db.prepare(`
      INSERT INTO preventive_maintenance_plans
        (equipment_id, frequency_months, last_completed_date, updated_at)
      VALUES (?, ?, ?, datetime('now','localtime'))
      ON CONFLICT(equipment_id) DO UPDATE SET
        last_completed_date = excluded.last_completed_date,
        updated_at = excluded.updated_at
    `).run(id, freqMonths, now);

    // 5. UPDATE equipment (dates PM + statut)
    db.prepare(`
      UPDATE equipment SET
        last_preventive_maintenance = ?,
        next_preventive_maintenance = ?,
        status = CASE WHEN status = 'Out of service' THEN status ELSE 'Operational' END,
        updated_at = datetime('now','localtime')
      WHERE id = ?
    `).run(now, nextPm, id);

    // 6. Déstockage des pièces utilisées
    if (parts_used && parts_used.length > 0) {
      const updateStock = db.prepare(`
        UPDATE inventory
        SET current_stock = MAX(0, current_stock - ?),
            updated_at = datetime('now','localtime')
        WHERE id = ?
      `);
      for (const part of parts_used) {
        if (part.inventory_id && part.qty > 0) {
          updateStock.run(part.qty, part.inventory_id);
        }
      }
    }

    // 7. Audit trail
    logAction({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
      action: 'validate_preventive_maintenance',
      target_type: 'equipment', target_id: id, target_name: eq.name,
      details: JSON.stringify({
        duration_minutes: duration_minutes || null,
        parts_count: (parts_used || []).length,
        next_pm: nextPm,
      }),
      ...extractReqMeta(req),
    });

    return res.json({
      maintenance_record_id: insertResult.lastInsertRowid,
      next_preventive_maintenance: nextPm,
      parts_updated: (parts_used || []).length > 0,
    });
  }

  // ── Chemin legacy (corrective / planifiée) ───────────────────────────────────
  if (!date || !intervention || !technician) {
    return res.status(400).json({ error: 'Champs requis: date, intervention, technician' });
  }

  const result = db.prepare(`
    INSERT INTO maintenance_records (equipment_id, date, intervention, technician, is_future, maintenance_type)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, date, intervention, technician, is_future ? 1 : 0, maintenance_type || 'corrective');

  logAction({ user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
    action: is_future ? 'schedule_maintenance' : 'add_maintenance',
    target_type: 'equipment', target_id: id, target_name: eq.name,
    details: JSON.stringify({ date, intervention, technician }), ...extractReqMeta(req) });

  res.status(201).json({ message: 'Maintenance enregistrée', id: result.lastInsertRowid });
});

// ── PUT /api/equipment/:id/pm-plan ────────────────────────────────────────────
router.put('/:id/pm-plan', verifyToken,
  requireRole('admin', 'supervisor', 'technician', ...TECH_ROLES),
  (req, res) => {
    const db = getDb();
    const { id } = req.params;
    const { frequency_months } = req.body;

    // Validation
    if (!frequency_months || typeof frequency_months !== 'number' ||
        !Number.isFinite(frequency_months) || frequency_months < 1) {
      return res.status(400).json({ error: 'frequency_months requis (entier >= 1)' });
    }

    const eq = db.prepare('SELECT id, name FROM equipment WHERE id = ?').get(id);
    if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

    // UPSERT plan PM
    db.prepare(`
      INSERT INTO preventive_maintenance_plans (equipment_id, frequency_months, updated_at)
      VALUES (?, ?, datetime('now','localtime'))
      ON CONFLICT(equipment_id) DO UPDATE SET
        frequency_months = excluded.frequency_months,
        updated_at = excluded.updated_at
    `).run(id, frequency_months);

    logAction({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
      action: 'update_pm_frequency',
      target_type: 'equipment', target_id: id, target_name: eq.name,
      details: JSON.stringify({ frequency_months }),
      ...extractReqMeta(req),
    });

    res.json({ message: 'Fréquence de maintenance mise à jour' });
  }
);

// ── GET /api/equipment/:id/maintenance-label/:record_id ───────────────────────
router.get('/:id/maintenance-label/:record_id', verifyToken,
  requireRole('admin', 'supervisor', 'technician', ...TECH_ROLES),
  async (req, res) => {
    const db = getDb();
    const { id, record_id } = req.params;

    const eq = db.prepare('SELECT * FROM equipment WHERE id = ?').get(id);
    if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

    const record = db.prepare(
      'SELECT * FROM maintenance_records WHERE id = ? AND equipment_id = ?'
    ).get(parseInt(record_id, 10), id);
    if (!record) return res.status(404).json({ error: 'Enregistrement introuvable' });

    const plan = db.prepare(
      'SELECT frequency_months FROM preventive_maintenance_plans WHERE equipment_id = ? LIMIT 1'
    ).get(id);
    const freqMonths = plan ? plan.frequency_months : 12;
    const nextPm = db.prepare(
      "SELECT datetime(?, '+' || ? || ' months') as next"
    ).get(record.date, freqMonths).next;

    try {
      const pdfBytes = await generateMaintenanceLabelPdf({
        equipmentName: eq.name,
        serialNumber:  eq.serial_number || null,
        department:    eq.department,
        technicianName: record.technician,
        performedAt:   record.date,
        nextPm,
        hospitalName:  'Hôpital de District de Kabutare',
      });

      const dateStr = record.date.substring(0, 10).replace(/-/g, '');
      logAction({
        user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req),
        action: 'generate_maintenance_label',
        target_type: 'equipment', target_id: id, target_name: eq.name,
        details: JSON.stringify({ record_id }),
        ...extractReqMeta(req),
      });

      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `inline; filename="label-${id}-${dateStr}.pdf"`);
      res.send(pdfBytes);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  }
);

module.exports = router;
