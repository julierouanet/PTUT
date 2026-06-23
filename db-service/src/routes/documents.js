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
    let query = `
      SELECT id, document_type, original_name, mime_type, file_size_kb,
             uploader_name, uploaded_at
      FROM equipment_documents
      WHERE equipment_id = ? AND deleted_at IS NULL
    `;
    const params = [req.params.id];
    if (type && VALID_DOC_TYPES.includes(type)) {
      query += ' AND document_type = ?';
      params.push(type);
    }
    query += ' ORDER BY uploaded_at DESC';

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
