const express = require('express');
const path    = require('path');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { documentUpload } = require('../middleware/upload');
const { UPLOAD_DIR } = require('../config');

const router = express.Router();

// Mêmes 3 types que equipment_documents.
const VALID_DOC_TYPES = ['technical', 'intervention', 'certification'];

// ════════════════════════════════════════════════════════════════════════════
// FABRICANTS (equipment_brands)
// ════════════════════════════════════════════════════════════════════════════

// ── GET /api/brands ───────────────────────────────────────────────────────────
// Liste des fabricants avec model_count et equipment_count.
// Filtre optionnel ?subcategory_id= : fabricants présents dans cette sous-cat.
router.get('/brands', verifyToken, (req, res) => {
  const db = getDb();
  const { subcategory_id } = req.query;
  const subId = subcategory_id ? parseInt(subcategory_id, 10) : null;

  let rows;
  if (Number.isFinite(subId)) {
    rows = db.prepare(`
      SELECT
        b.id,
        b.name,
        COUNT(DISTINCT m.id) AS model_count,
        COUNT(DISTINCT e.id) AS equipment_count
      FROM equipment_brands b
      JOIN equipment_models m ON m.brand_id = b.id AND m.subcategory_id = ?
      LEFT JOIN equipment e ON e.model_id = m.id
      GROUP BY b.id
      ORDER BY b.name ASC
    `).all(subId);
  } else {
    rows = db.prepare(`
      SELECT
        b.id,
        b.name,
        COUNT(DISTINCT m.id) AS model_count,
        COUNT(DISTINCT e.id) AS equipment_count
      FROM equipment_brands b
      LEFT JOIN equipment_models m ON m.brand_id = b.id
      LEFT JOIN equipment e ON e.model_id = m.id
      GROUP BY b.id
      ORDER BY b.name ASC
    `).all();
  }

  res.json(rows);
});

// ── GET /api/brands/:id ───────────────────────────────────────────────────────
// Détail d'un fabricant + ses modèles (filtrables ?subcategory_id=).
router.get('/brands/:id', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const brand = db.prepare('SELECT * FROM equipment_brands WHERE id = ?').get(id);
  if (!brand) return res.status(404).json({ error: 'Fabricant introuvable' });

  const { subcategory_id } = req.query;
  const subId = subcategory_id ? parseInt(subcategory_id, 10) : null;

  let models;
  if (Number.isFinite(subId)) {
    models = db.prepare(`
      SELECT
        m.id, m.name, m.subcategory_id,
        s.name AS subcategory_name,
        COUNT(e.id) AS equipment_count
      FROM equipment_models m
      LEFT JOIN equipment_subcategories s ON s.id = m.subcategory_id
      LEFT JOIN equipment e ON e.model_id = m.id
      WHERE m.brand_id = ? AND m.subcategory_id = ?
      GROUP BY m.id
      ORDER BY m.name ASC
    `).all(id, subId);
  } else {
    models = db.prepare(`
      SELECT
        m.id, m.name, m.subcategory_id,
        s.name AS subcategory_name,
        COUNT(e.id) AS equipment_count
      FROM equipment_models m
      LEFT JOIN equipment_subcategories s ON s.id = m.subcategory_id
      LEFT JOIN equipment e ON e.model_id = m.id
      WHERE m.brand_id = ?
      GROUP BY m.id
      ORDER BY m.name ASC
    `).all(id);
  }

  res.json({ ...brand, models });
});

// ── POST /api/brands ──────────────────────────────────────────────────────────
router.post('/brands', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { name } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });

  const duplicate = db.prepare(
    'SELECT id FROM equipment_brands WHERE name = ? COLLATE NOCASE'
  ).get(name.trim());
  if (duplicate) return res.status(409).json({ error: 'Un fabricant avec ce nom existe déjà' });

  const result = db.prepare('INSERT INTO equipment_brands(name) VALUES (?)').run(name.trim());

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'create_brand',
    target_type: 'brand', target_id: String(result.lastInsertRowid), target_name: name.trim(),
    details: JSON.stringify({ name: name.trim() }),
    ...extractReqMeta(req),
  });

  res.status(201).json({ id: result.lastInsertRowid, name: name.trim(), model_count: 0, equipment_count: 0 });
});

// ── PUT /api/brands/:id ───────────────────────────────────────────────────────
router.put('/brands/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const { name } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });

  const existing = db.prepare('SELECT * FROM equipment_brands WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Fabricant introuvable' });

  const duplicate = db.prepare(
    'SELECT id FROM equipment_brands WHERE name = ? COLLATE NOCASE AND id != ?'
  ).get(name.trim(), id);
  if (duplicate) return res.status(409).json({ error: 'Un fabricant avec ce nom existe déjà' });

  db.prepare(
    "UPDATE equipment_brands SET name = ?, updated_at = datetime('now','localtime') WHERE id = ?"
  ).run(name.trim(), id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'update_brand',
    target_type: 'brand', target_id: String(id), target_name: name.trim(),
    details: JSON.stringify({ old_name: existing.name, name: name.trim() }),
    ...extractReqMeta(req),
  });

  res.json({ id, name: name.trim() });
});

// ── DELETE /api/brands/:id ────────────────────────────────────────────────────
// Bloqué (409 BRAND_HAS_MODELS) s'il reste un modèle OU un équipement rattaché.
router.delete('/brands/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const brand = db.prepare('SELECT * FROM equipment_brands WHERE id = ?').get(id);
  if (!brand) return res.status(404).json({ error: 'Fabricant introuvable' });

  const modelCount = db.prepare(
    'SELECT COUNT(*) AS c FROM equipment_models WHERE brand_id = ?'
  ).get(id).c;
  const equipmentCount = db.prepare(`
    SELECT COUNT(*) AS c
    FROM equipment e
    JOIN equipment_models m ON m.id = e.model_id
    WHERE m.brand_id = ?
  `).get(id).c;

  if (modelCount > 0 || equipmentCount > 0) {
    return res.status(409).json({
      error: 'BRAND_HAS_MODELS',
      message: `Ce fabricant a ${modelCount} modèle(s) et ${equipmentCount} équipement(s) rattaché(s). Réaffectez-les avant de supprimer.`,
      model_count: modelCount,
      equipment_count: equipmentCount,
    });
  }

  db.prepare('DELETE FROM equipment_brands WHERE id = ?').run(id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'delete_brand',
    target_type: 'brand', target_id: String(id), target_name: brand.name,
    details: JSON.stringify({}),
    ...extractReqMeta(req),
  });

  res.json({ success: true, message: 'Fabricant supprimé' });
});

// ════════════════════════════════════════════════════════════════════════════
// MODÈLES (equipment_models)
// ════════════════════════════════════════════════════════════════════════════

// ── GET /api/models ───────────────────────────────────────────────────────────
// Filtres optionnels ?subcategory_id= ?brand_id=. equipment_count par modèle.
router.get('/models', verifyToken, (req, res) => {
  const db = getDb();
  const { subcategory_id, brand_id } = req.query;

  let query = `
    SELECT
      m.id, m.name, m.brand_id, m.subcategory_id,
      b.name AS brand_name,
      s.name AS subcategory_name,
      COUNT(e.id) AS equipment_count
    FROM equipment_models m
    JOIN equipment_brands b ON b.id = m.brand_id
    LEFT JOIN equipment_subcategories s ON s.id = m.subcategory_id
    LEFT JOIN equipment e ON e.model_id = m.id
    WHERE 1=1
  `;
  const params = [];
  if (subcategory_id) { query += ' AND m.subcategory_id = ?'; params.push(parseInt(subcategory_id, 10)); }
  if (brand_id)       { query += ' AND m.brand_id = ?';       params.push(parseInt(brand_id, 10)); }
  query += ' GROUP BY m.id ORDER BY b.name ASC, m.name ASC';

  res.json(db.prepare(query).all(...params));
});

// ── GET /api/models/:id ───────────────────────────────────────────────────────
// Fiche complète : modèle + fabricant + sous-cat + équipements + documents + PM.
router.get('/models/:id', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const model = db.prepare(`
    SELECT
      m.*,
      b.name AS brand_name,
      s.name AS subcategory_name
    FROM equipment_models m
    JOIN equipment_brands b ON b.id = m.brand_id
    LEFT JOIN equipment_subcategories s ON s.id = m.subcategory_id
    WHERE m.id = ?
  `).get(id);
  if (!model) return res.status(404).json({ error: 'Modèle introuvable' });

  const equipment = db.prepare(`
    SELECT id, name, status, manufacturer, model, model_id
    FROM equipment
    WHERE model_id = ?
    ORDER BY name ASC
  `).all(id);

  const documents = db.prepare(`
    SELECT id, document_type, original_name, mime_type, file_size_kb, uploader_name, uploaded_at
    FROM model_documents
    WHERE model_id = ? AND deleted_at IS NULL
    ORDER BY uploaded_at DESC
  `).all(id);

  const protocols = db.prepare(`
    SELECT p.*
    FROM pm_protocols p
    JOIN model_pm_protocols mp ON mp.protocol_id = p.id
    WHERE mp.model_id = ?
    ORDER BY p.frequency_months ASC
  `).all(id);

  res.json({ ...model, equipment, documents, protocols });
});

// ── POST /api/models ──────────────────────────────────────────────────────────
router.post('/models', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { brand_id, subcategory_id, name } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name est requis' });
  if (!brand_id) return res.status(400).json({ error: 'brand_id est requis' });

  const brand = db.prepare('SELECT id, name FROM equipment_brands WHERE id = ?').get(parseInt(brand_id, 10));
  if (!brand) return res.status(404).json({ error: 'Fabricant introuvable' });

  let subId = null;
  if (subcategory_id !== null && subcategory_id !== undefined && subcategory_id !== '') {
    subId = parseInt(subcategory_id, 10);
    const sub = db.prepare('SELECT id FROM equipment_subcategories WHERE id = ?').get(subId);
    if (!sub) return res.status(404).json({ error: 'Sous-catégorie introuvable' });
  }

  // Doublon sur la contrainte UNIQUE(brand_id, subcategory_id, name COLLATE NOCASE).
  const duplicate = db.prepare(`
    SELECT id FROM equipment_models
    WHERE brand_id = ? AND name = ? COLLATE NOCASE
      AND (subcategory_id IS ?)
  `).get(parseInt(brand_id, 10), name.trim(), subId);
  if (duplicate) return res.status(409).json({ error: 'Un modèle identique existe déjà pour ce fabricant' });

  const result = db.prepare(
    'INSERT INTO equipment_models(brand_id, subcategory_id, name) VALUES (?, ?, ?)'
  ).run(parseInt(brand_id, 10), subId, name.trim());

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'create_model',
    target_type: 'model', target_id: String(result.lastInsertRowid), target_name: name.trim(),
    details: JSON.stringify({ brand_id, subcategory_id: subId, name: name.trim() }),
    ...extractReqMeta(req),
  });

  res.status(201).json({
    id: result.lastInsertRowid,
    brand_id: parseInt(brand_id, 10),
    subcategory_id: subId,
    name: name.trim(),
    brand_name: brand.name,
    equipment_count: 0,
  });
});

// ── PUT /api/models/:id ───────────────────────────────────────────────────────
router.put('/models/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const existing = db.prepare('SELECT * FROM equipment_models WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Modèle introuvable' });

  const { brand_id, subcategory_id, name } = req.body;
  const newName = (name !== undefined && name !== null) ? String(name).trim() : existing.name;
  if (!newName) return res.status(400).json({ error: 'name ne peut pas être vide' });

  let newBrandId = existing.brand_id;
  if (brand_id !== undefined && brand_id !== null && brand_id !== '') {
    newBrandId = parseInt(brand_id, 10);
    const brand = db.prepare('SELECT id FROM equipment_brands WHERE id = ?').get(newBrandId);
    if (!brand) return res.status(404).json({ error: 'Fabricant introuvable' });
  }

  let newSubId = existing.subcategory_id;
  if (subcategory_id !== undefined) {
    if (subcategory_id === null || subcategory_id === '') {
      newSubId = null;
    } else {
      newSubId = parseInt(subcategory_id, 10);
      const sub = db.prepare('SELECT id FROM equipment_subcategories WHERE id = ?').get(newSubId);
      if (!sub) return res.status(404).json({ error: 'Sous-catégorie introuvable' });
    }
  }

  const duplicate = db.prepare(`
    SELECT id FROM equipment_models
    WHERE brand_id = ? AND name = ? COLLATE NOCASE
      AND (subcategory_id IS ?) AND id != ?
  `).get(newBrandId, newName, newSubId, id);
  if (duplicate) return res.status(409).json({ error: 'Un modèle identique existe déjà pour ce fabricant' });

  db.prepare(`
    UPDATE equipment_models
    SET brand_id = ?, subcategory_id = ?, name = ?, updated_at = datetime('now','localtime')
    WHERE id = ?
  `).run(newBrandId, newSubId, newName, id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'update_model',
    target_type: 'model', target_id: String(id), target_name: newName,
    details: JSON.stringify({ old_name: existing.name, name: newName, brand_id: newBrandId, subcategory_id: newSubId }),
    ...extractReqMeta(req),
  });

  res.json({ id, brand_id: newBrandId, subcategory_id: newSubId, name: newName });
});

// ── DELETE /api/models/:id ────────────────────────────────────────────────────
// Bloqué (409 MODEL_HAS_EQUIPMENT) si des équipements y sont rattachés.
router.delete('/models/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const model = db.prepare('SELECT * FROM equipment_models WHERE id = ?').get(id);
  if (!model) return res.status(404).json({ error: 'Modèle introuvable' });

  const equipmentCount = db.prepare(
    'SELECT COUNT(*) AS c FROM equipment WHERE model_id = ?'
  ).get(id).c;

  if (equipmentCount > 0) {
    return res.status(409).json({
      error: 'MODEL_HAS_EQUIPMENT',
      message: `Ce modèle a ${equipmentCount} équipement(s) associé(s). Réaffectez-les avant de supprimer.`,
      equipment_count: equipmentCount,
    });
  }

  db.prepare('DELETE FROM equipment_models WHERE id = ?').run(id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'delete_model',
    target_type: 'model', target_id: String(id), target_name: model.name,
    details: JSON.stringify({}),
    ...extractReqMeta(req),
  });

  res.json({ success: true, message: 'Modèle supprimé' });
});

// ════════════════════════════════════════════════════════════════════════════
// DOCUMENTS DE MODÈLE (model_documents) — calqué sur documents.js
// ════════════════════════════════════════════════════════════════════════════

// ── GET /api/models/:id/documents ─────────────────────────────────────────────
router.get('/models/:id/documents', verifyToken, (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

  const model = db.prepare('SELECT id FROM equipment_models WHERE id = ?').get(id);
  if (!model) return res.status(404).json({ error: 'Modèle introuvable' });

  const { type } = req.query;
  let query = `
    SELECT id, document_type, original_name, mime_type, file_size_kb, uploader_name, uploaded_at
    FROM model_documents
    WHERE model_id = ? AND deleted_at IS NULL
  `;
  const params = [id];
  if (type && VALID_DOC_TYPES.includes(type)) {
    query += ' AND document_type = ?';
    params.push(type);
  }
  query += ' ORDER BY uploaded_at DESC';

  res.json(db.prepare(query).all(...params));
});

// ── POST /api/models/:id/documents ────────────────────────────────────────────
router.post('/models/:id/documents', verifyToken, requireRole('admin'),
  documentUpload.single('file'),
  (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'Fichier manquant (champ "file")' });

    const db = getDb();
    const id = parseInt(req.params.id, 10);
    if (!Number.isFinite(id)) return res.status(400).json({ error: 'ID invalide' });

    const model = db.prepare('SELECT id, name FROM equipment_models WHERE id = ?').get(id);
    if (!model) return res.status(404).json({ error: 'Modèle introuvable' });

    const docType = req.body.type || 'technical';
    if (!VALID_DOC_TYPES.includes(docType)) {
      return res.status(400).json({
        error: `Type invalide. Valeurs acceptées : ${VALID_DOC_TYPES.join(', ')}`,
      });
    }

    const fileSizeKb = Math.ceil(req.file.size / 1024);

    const result = db.prepare(`
      INSERT INTO model_documents
        (model_id, document_type, original_name, stored_name, mime_type,
         file_size_kb, uploaded_by, uploader_name, uploaded_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'))
    `).run(
      id,
      docType,
      req.file.originalname,
      req.file.filename,
      req.file.mimetype,
      fileSizeKb,
      req.user.id,
      req.user.name,
    );

    logAction({
      user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
      action: 'upload_model_document',
      target_type: 'model', target_id: String(id), target_name: model.name,
      details: JSON.stringify({ doc_type: docType, file: req.file.originalname, size_kb: fileSizeKb }),
      ...extractReqMeta(req),
    });

    res.status(201).json({
      id:            result.lastInsertRowid,
      stored_name:   req.file.filename,
      original_name: req.file.originalname,
      document_type: docType,
      mime_type:     req.file.mimetype,
      file_size_kb:  fileSizeKb,
    });
  }
);

// ── GET /api/models/:id/documents/:docId/download ─────────────────────────────
router.get('/models/:id/documents/:docId/download', verifyToken, (req, res) => {
  const db = getDb();
  const doc = db.prepare(`
    SELECT * FROM model_documents
    WHERE id = ? AND model_id = ? AND deleted_at IS NULL
  `).get(req.params.docId, req.params.id);

  if (!doc) return res.status(404).json({ error: 'Document introuvable' });

  const filePath = path.join(UPLOAD_DIR, doc.stored_name);
  res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(doc.original_name)}"`);
  res.setHeader('Content-Type', doc.mime_type || 'application/octet-stream');
  res.sendFile(filePath, { root: '/' }, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ error: 'Fichier introuvable sur le serveur' });
    }
  });
});

// ── DELETE /api/models/:id/documents/:docId ───────────────────────────────────
router.delete('/models/:id/documents/:docId', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const doc = db.prepare(`
    SELECT * FROM model_documents
    WHERE id = ? AND model_id = ? AND deleted_at IS NULL
  `).get(req.params.docId, req.params.id);

  if (!doc) return res.status(404).json({ error: 'Document introuvable' });

  db.prepare(
    "UPDATE model_documents SET deleted_at = datetime('now','localtime') WHERE id = ?"
  ).run(doc.id);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
    action: 'delete_model_document',
    target_type: 'model', target_id: String(req.params.id), target_name: doc.original_name,
    details: JSON.stringify({ doc_id: doc.id, doc_type: doc.document_type }),
    ...extractReqMeta(req),
  });

  res.json({ message: 'Document supprimé' });
});

// ════════════════════════════════════════════════════════════════════════════
// LIENS MODÈLE ↔ PROTOCOLES PM (model_pm_protocols)
// ════════════════════════════════════════════════════════════════════════════

// ── POST /api/models/:id/protocols/:protocolId ───────────────────────────────
router.post('/models/:id/protocols/:protocolId', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  const protocolId = parseInt(req.params.protocolId, 10);
  if (!Number.isFinite(id) || !Number.isFinite(protocolId)) {
    return res.status(400).json({ error: 'ID invalide' });
  }

  const model = db.prepare('SELECT id, name FROM equipment_models WHERE id = ?').get(id);
  if (!model) return res.status(404).json({ error: 'Modèle introuvable' });
  const protocol = db.prepare('SELECT id, name FROM pm_protocols WHERE id = ?').get(protocolId);
  if (!protocol) return res.status(404).json({ error: 'Protocole introuvable' });

  db.prepare(
    'INSERT OR IGNORE INTO model_pm_protocols(model_id, protocol_id) VALUES (?, ?)'
  ).run(id, protocolId);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'link_model_protocol',
    target_type: 'model', target_id: String(id), target_name: model.name,
    details: JSON.stringify({ protocol_id: protocolId, protocol_name: protocol.name }),
    ...extractReqMeta(req),
  });

  res.status(201).json({ model_id: id, protocol_id: protocolId });
});

// ── DELETE /api/models/:id/protocols/:protocolId ──────────────────────────────
router.delete('/models/:id/protocols/:protocolId', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const id = parseInt(req.params.id, 10);
  const protocolId = parseInt(req.params.protocolId, 10);
  if (!Number.isFinite(id) || !Number.isFinite(protocolId)) {
    return res.status(400).json({ error: 'ID invalide' });
  }

  const model = db.prepare('SELECT id, name FROM equipment_models WHERE id = ?').get(id);
  if (!model) return res.status(404).json({ error: 'Modèle introuvable' });

  db.prepare(
    'DELETE FROM model_pm_protocols WHERE model_id = ? AND protocol_id = ?'
  ).run(id, protocolId);

  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] ?? 'admin',
    action: 'unlink_model_protocol',
    target_type: 'model', target_id: String(id), target_name: model.name,
    details: JSON.stringify({ protocol_id: protocolId }),
    ...extractReqMeta(req),
  });

  res.json({ message: 'Protocole délié' });
});

module.exports = router;
