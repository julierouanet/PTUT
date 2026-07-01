const express = require('express');
const path = require('path');
const fs = require('fs');
const archiver = require('archiver');
const { PDFDocument } = require('pdf-lib');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { UPLOAD_DIR } = require('../config');

const router = express.Router();

const ALLOWED_ROLES = ['admin', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// ── Validation commune des filtres from/to/uploaded_by ────────────────────────
function parseFilters(query) {
  const { uploaded_by, from, to, search } = query;

  if (from !== undefined && !DATE_RE.test(from)) {
    return { error: 'Format de date invalide (attendu YYYY-MM-DD)' };
  }
  if (to !== undefined && !DATE_RE.test(to)) {
    return { error: 'Format de date invalide (attendu YYYY-MM-DD)' };
  }
  if (from !== undefined && to !== undefined && from > to) {
    return { error: 'from doit être antérieur ou égal à to' };
  }

  return { uploadedBy: uploaded_by || null, from: from || null, to: to || null, search: search || null };
}

// Construit la clause WHERE + params communs à list/zip/print-pdf
function buildWhere({ uploadedBy, from, to, search }, extraCondition) {
  let where = "WHERE ed.document_type = 'intervention' AND ed.deleted_at IS NULL";
  const params = [];

  if (extraCondition) where += ` AND ${extraCondition}`;
  if (uploadedBy) {
    where += ' AND ed.uploaded_by = ?';
    params.push(uploadedBy);
  }
  if (from) {
    where += ' AND date(ed.uploaded_at) >= ?';
    params.push(from);
  }
  if (to) {
    where += ' AND date(ed.uploaded_at) <= ?';
    params.push(to);
  }
  if (search) {
    where += ' AND ed.original_name LIKE ? COLLATE NOCASE';
    params.push(`%${search}%`);
  }

  return { where, params };
}

// Audit trail commun aux deux exports (ZIP/PDF) — même forme, seule l'action diffère
function logExport(req, action, filters, docCount) {
  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
    action,
    target_type: 'equipment_documents', target_id: null, target_name: null,
    details: JSON.stringify({ uploaded_by: filters.uploadedBy, from: filters.from, to: filters.to, doc_count: docCount }),
    ...extractReqMeta(req),
  });
}

// ── GET /api/documents/interventions ──────────────────────────────────────────
router.get('/', verifyToken, requireRole(...ALLOWED_ROLES), (req, res) => {
  const filters = parseFilters(req.query);
  if (filters.error) return res.status(400).json({ error: filters.error });

  const { page, limit } = req.query;
  const pageInt = page !== undefined ? parseInt(page, 10) : 1;
  if (!Number.isFinite(pageInt) || pageInt < 1) {
    return res.status(400).json({ error: 'page invalide' });
  }
  let limitInt = limit !== undefined ? parseInt(limit, 10) : 20;
  if (!Number.isFinite(limitInt) || limitInt < 1 || limitInt > 100) {
    return res.status(400).json({ error: 'limit invalide' });
  }

  const db = getDb();
  const { where, params } = buildWhere(filters);

  const total = db.prepare(`SELECT COUNT(*) AS total FROM equipment_documents ed ${where}`).get(...params).total;
  const totalPages = Math.max(1, Math.ceil(total / limitInt));
  const offset = (pageInt - 1) * limitInt;

  const items = db.prepare(`
    SELECT ed.id, ed.document_type, ed.original_name, ed.mime_type, ed.file_size_kb,
           ed.uploader_name, ed.uploaded_by, ed.uploaded_at, ed.issue_id, ed.equipment_id,
           e.name AS equipment_name, i.status AS issue_status, i.created_at AS issue_created_at
    FROM equipment_documents ed
    LEFT JOIN equipment e ON e.id = ed.equipment_id
    LEFT JOIN issues i ON i.id = ed.issue_id
    ${where}
    ORDER BY ed.uploaded_at DESC
    LIMIT ? OFFSET ?
  `).all(...params, limitInt, offset);

  res.json({ items, total, page: pageInt, limit: limitInt, total_pages: totalPages });
});

// ── GET /api/documents/interventions/technicians ──────────────────────────────
router.get('/technicians', verifyToken, requireRole(...ALLOWED_ROLES), (req, res) => {
  const db = getDb();
  const items = db.prepare(`
    SELECT DISTINCT uploaded_by, uploader_name
    FROM equipment_documents
    WHERE document_type = 'intervention' AND deleted_at IS NULL AND uploaded_by IS NOT NULL
    ORDER BY uploader_name
  `).all();
  res.json(items);
});

// ── GET /api/documents/interventions/zip ──────────────────────────────────────
router.get('/zip', verifyToken, requireRole(...ALLOWED_ROLES), (req, res) => {
  const filters = parseFilters(req.query);
  if (filters.error) return res.status(400).json({ error: filters.error });

  const db = getDb();
  const { where, params } = buildWhere(filters);
  const docs = db.prepare(`
    SELECT ed.id, ed.original_name, ed.stored_name
    FROM equipment_documents ed
    ${where}
    ORDER BY ed.uploaded_at DESC
  `).all(...params);

  if (docs.length === 0) {
    return res.status(404).json({ error: 'Aucun document pour ces critères' });
  }

  logExport(req, 'export_intervention_documents_zip', filters, docs.length);

  const filename = `interventions_${filters.from || 'debut'}_${filters.to || 'fin'}.zip`;
  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

  const archive = archiver('zip');
  archive.on('error', (err) => {
    if (!res.headersSent) res.status(500).json({ error: 'Erreur lors de la génération du ZIP' });
  });
  archive.pipe(res);

  const usedNames = new Map();
  for (const doc of docs) {
    let name = doc.original_name;
    const count = usedNames.get(name) || 0;
    if (count > 0) {
      const ext = path.extname(name);
      const base = path.basename(name, ext);
      name = `${base}_${count + 1}${ext}`;
    }
    usedNames.set(doc.original_name, count + 1);
    archive.file(path.join(UPLOAD_DIR, doc.stored_name), { name });
  }

  archive.finalize();
});

// ── GET /api/documents/interventions/print-pdf ────────────────────────────────
router.get('/print-pdf', verifyToken, requireRole(...ALLOWED_ROLES), async (req, res) => {
  const filters = parseFilters(req.query);
  if (filters.error) return res.status(400).json({ error: filters.error });

  const db = getDb();
  const { where, params } = buildWhere(filters, "ed.mime_type = 'application/pdf'");
  const docs = db.prepare(`
    SELECT ed.id, ed.original_name, ed.stored_name
    FROM equipment_documents ed
    ${where}
    ORDER BY ed.uploaded_at DESC
  `).all(...params);

  if (docs.length === 0) {
    return res.status(404).json({ error: 'Aucun PDF pour ces critères' });
  }

  try {
    const mergedPdf = await PDFDocument.create();
    for (const doc of docs) {
      const filePath = path.join(UPLOAD_DIR, doc.stored_name);
      const bytes = fs.readFileSync(filePath);
      const srcPdf = await PDFDocument.load(bytes);
      const pages = await mergedPdf.copyPages(srcPdf, srcPdf.getPageIndices());
      pages.forEach((page) => mergedPdf.addPage(page));
    }

    logExport(req, 'export_intervention_documents_pdf', filters, docs.length);

    const mergedBytes = await mergedPdf.save();
    res.setHeader('Content-Type', 'application/pdf');
    res.send(Buffer.from(mergedBytes));
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la fusion des PDF' });
  }
});

module.exports = router;
