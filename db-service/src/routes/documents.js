const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { documentUpload } = require('../middleware/upload');
const { VALID_DOC_TYPES } = require('../utils/document_types');
const { insertEquipmentDocument, sendStoredDocument } = require('../utils/documents_repo');

const router = express.Router();

// ── GET /api/equipment/:id/documents ─────────────────────────────────────────
router.get('/:id/documents', verifyToken,
  requireRole('admin', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'),
  (req, res) => {
    const db = getDb();
    const eq = db.prepare('SELECT id FROM equipment WHERE id = ?').get(req.params.id);
    if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

    const { type } = req.query;
    // Fusion documents + photos d'incident rattachées à cet équipement — même
    // pattern que GET /api/issues/:id/documents, restreint aux photos déjà
    // tamponnées (annex_pdf_stored_name renseigné).
    let query = `
      SELECT ed.id, ed.document_type, ed.original_name, ed.mime_type, ed.file_size_kb,
             ed.uploader_name, ed.uploaded_at, ed.issue_id, ed.annex_number, ed.annex_type_index,
             'document' AS kind, i.status AS issue_status, i.created_at AS issue_created_at
      FROM equipment_documents ed
      LEFT JOIN issues i ON i.id = ed.issue_id
      WHERE ed.equipment_id = ? AND ed.deleted_at IS NULL
      UNION ALL
      SELECT p.id, 'photo' AS document_type, p.original_name, p.mime_type, p.file_size_kb,
             NULL AS uploader_name, p.uploaded_at, p.issue_id, p.annex_number, p.annex_type_index,
             'photo' AS kind, i2.status AS issue_status, i2.created_at AS issue_created_at
      FROM issue_photos p
      JOIN issues i2 ON i2.id = p.issue_id
      WHERE i2.equipment_id = ? AND p.annex_pdf_stored_name IS NOT NULL
    `;
    const params = [req.params.id, req.params.id];
    query = `SELECT * FROM (${query}) combined`;
    if (type === 'photo' || (type && VALID_DOC_TYPES.includes(type))) {
      query += ' WHERE document_type = ?';
      params.push(type);
    }
    query += ' ORDER BY issue_created_at DESC NULLS LAST, uploaded_at DESC';

    res.json(db.prepare(query).all(...params));
  }
);

// ── POST /api/equipment/:id/documents ────────────────────────────────────────
router.post('/:id/documents', verifyToken,
  requireRole('admin', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'),
  documentUpload.single('file'),
  (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'Fichier manquant (champ "file")' });

    const db = getDb();
    const eq = db.prepare('SELECT id, name FROM equipment WHERE id = ?').get(req.params.id);
    if (!eq) return res.status(404).json({ error: 'Équipement introuvable' });

    const docType = req.body.type || 'technical';
    if (!VALID_DOC_TYPES.includes(docType)) {
      return res.status(400).json({
        error: `Type invalide. Valeurs acceptées : ${VALID_DOC_TYPES.join(', ')}`,
      });
    }

    const inserted = insertEquipmentDocument(db, {
      equipmentId: req.params.id,
      docType,
      file: req.file,
      userId: req.user.id,
      userName: req.user.name,
    });

    logAction({
      user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
      action: 'upload_document',
      target_type: 'equipment', target_id: req.params.id, target_name: eq.name,
      details: JSON.stringify({ doc_type: docType, file: req.file.originalname, size_kb: inserted.file_size_kb }),
      ...extractReqMeta(req),
    });

    res.status(201).json({
      id:            inserted.id,
      stored_name:   req.file.filename,
      original_name: req.file.originalname,
      document_type: docType,
      mime_type:     req.file.mimetype,
      file_size_kb:  inserted.file_size_kb,
    });
  }
);

// ── GET /api/equipment/:id/documents/:doc_id/download ────────────────────────
router.get('/:id/documents/:doc_id/download', verifyToken,
  requireRole('admin', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'),
  (req, res) => {
    const db = getDb();
    const doc = db.prepare(`
      SELECT * FROM equipment_documents
      WHERE id = ? AND equipment_id = ? AND deleted_at IS NULL
    `).get(req.params.doc_id, req.params.id);

    if (!doc) return res.status(404).json({ error: 'Document introuvable' });

    logAction({
      user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
      action: 'download_document',
      target_type: 'equipment', target_id: req.params.id, target_name: doc.original_name,
      details: JSON.stringify({ doc_id: doc.id }),
      ...extractReqMeta(req),
    });

    sendStoredDocument(res, doc);
  }
);

// ── DELETE /api/equipment/:id/documents/:doc_id ───────────────────────────────
router.delete('/:id/documents/:doc_id', verifyToken,
  requireRole('admin', 'supervisor'),
  (req, res) => {
    const db = getDb();
    const doc = db.prepare(`
      SELECT * FROM equipment_documents
      WHERE id = ? AND equipment_id = ? AND deleted_at IS NULL
    `).get(req.params.doc_id, req.params.id);

    if (!doc) return res.status(404).json({ error: 'Document introuvable' });

    db.prepare(`
      UPDATE equipment_documents
      SET deleted_at = datetime('now','localtime')
      WHERE id = ?
    `).run(doc.id);

    logAction({
      user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
      action: 'delete_document',
      target_type: 'equipment', target_id: req.params.id, target_name: doc.original_name,
      details: JSON.stringify({ doc_id: doc.id, doc_type: doc.document_type }),
      ...extractReqMeta(req),
    });

    res.json({ message: 'Document supprimé' });
  }
);

module.exports = router;
