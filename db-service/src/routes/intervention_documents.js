const express = require('express');
const path = require('path');
const fs = require('fs');
const archiver = require('archiver');
const { PDFDocument } = require('pdf-lib');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { UPLOAD_DIR } = require('../config');
const { VALID_DOC_TYPES } = require('../utils/document_types');
const { buildSummaryPdf, summaryPageCount } = require('../services/annex_summary_service');

const router = express.Router();

const ALLOWED_ROLES = ['admin', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const FILTERABLE_DOC_TYPES = VALID_DOC_TYPES.filter((t) => t === 'intervention' || t === 'completion');

// Parse le paramètre `types` (CSV "intervention,completion" OU tableau Express
// si le client envoie ?types=a&types=b). Comparaison EXACTE, sensible à la casse
// (les valeurs DB sont strictement en minuscules, aucune normalisation).
function parseTypes(rawTypes) {
  if (rawTypes === undefined) return { docTypes: FILTERABLE_DOC_TYPES };

  const tokens = Array.isArray(rawTypes) ? rawTypes : String(rawTypes).split(',');
  const docTypes = tokens.map((t) => String(t).trim()).filter((t) => t.length > 0);

  const unknown = docTypes.find((t) => !FILTERABLE_DOC_TYPES.includes(t));
  if (unknown) {
    return { error: `Type de document invalide : "${unknown}". Valeurs acceptées : ${FILTERABLE_DOC_TYPES.join(', ')}` };
  }

  return { docTypes }; // peut être [] si types= ou types=, — valide, pas une erreur
}

// Clause IN (?,?,...) + params pour filtrer sur document_type — partagée entre
// buildWhere (routes /, /zip, /print-pdf) et /technicians.
function docTypesInClause(docTypes) {
  return { placeholders: docTypes.map(() => '?').join(','), params: [...docTypes] };
}

// ── Validation commune des filtres from/to/uploaded_by/types ─────────────────
function parseFilters(query) {
  const { uploaded_by, from, to, search, types, issue_id } = query;

  if (from !== undefined && !DATE_RE.test(from)) {
    return { error: 'Format de date invalide (attendu YYYY-MM-DD)' };
  }
  if (to !== undefined && !DATE_RE.test(to)) {
    return { error: 'Format de date invalide (attendu YYYY-MM-DD)' };
  }
  if (from !== undefined && to !== undefined && from > to) {
    return { error: 'from doit être antérieur ou égal à to' };
  }

  const { docTypes, error: typesError } = parseTypes(types);
  if (typesError) return { error: typesError };

  return {
    uploadedBy: uploaded_by || null, from: from || null, to: to || null,
    search: search || null, issueId: issue_id || null, docTypes,
  };
}

// Construit la clause WHERE + params communs à list/zip/print-pdf.
// `alias` permet de réutiliser cette fonction sur la sous-requête fusionnée
// documents+photos de la route GET / (alias 'combined').
// N'est appelée que si filters.docTypes.length > 0 (jamais de IN () vide)
function buildWhere({ uploadedBy, from, to, search, issueId, docTypes }, extraCondition, alias = 'ed') {
  const { placeholders, params } = docTypesInClause(docTypes);
  let where = `WHERE ${alias}.document_type IN (${placeholders}) AND ${alias}.deleted_at IS NULL`;

  if (extraCondition) where += ` AND ${extraCondition}`;
  if (uploadedBy) {
    where += ` AND ${alias}.uploaded_by = ?`;
    params.push(uploadedBy);
  }
  if (from) {
    where += ` AND date(${alias}.uploaded_at) >= ?`;
    params.push(from);
  }
  if (to) {
    where += ` AND date(${alias}.uploaded_at) <= ?`;
    params.push(to);
  }
  if (search) {
    where += ` AND ${alias}.original_name LIKE ? COLLATE NOCASE`;
    params.push(`%${search}%`);
  }
  if (issueId) {
    where += ` AND ${alias}.issue_id = ?`;
    params.push(issueId);
  }

  return { where, params };
}

// Audit trail commun aux deux exports (ZIP/PDF) — même forme, seule l'action diffère
function logExport(req, action, filters, docCount) {
  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
    action,
    target_type: 'equipment_documents', target_id: null, target_name: null,
    details: JSON.stringify({ uploaded_by: filters.uploadedBy, from: filters.from, to: filters.to, types: filters.docTypes, issue_id: filters.issueId, doc_count: docCount }),
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

  if (filters.docTypes.length === 0) {
    return res.json({ items: [], total: 0, page: pageInt, limit: limitInt, total_pages: 1 });
  }

  const db = getDb();
  const { where, params } = buildWhere(filters, null, 'combined');

  // Fusion documents + photos d'incident : les photos sont sans uploader/équipement
  // (colonnes NULL) et exposées sous document_type='completion' pour passer le
  // filtre FILTERABLE_DOC_TYPES existant, avec kind='photo' pour les distinguer.
  const combinedFrom = `
    (
      SELECT ed.id, ed.document_type, ed.original_name, ed.mime_type, ed.file_size_kb,
             ed.uploader_name, ed.uploaded_by, ed.uploaded_at, ed.issue_id, ed.equipment_id,
             ed.deleted_at, ed.annex_number, ed.annex_type_index, 'document' AS kind
      FROM equipment_documents ed
      UNION ALL
      SELECT p.id, 'completion' AS document_type, p.original_name, p.mime_type, p.file_size_kb,
             NULL AS uploader_name, NULL AS uploaded_by, p.uploaded_at, p.issue_id, NULL AS equipment_id,
             NULL AS deleted_at, p.annex_number, p.annex_type_index, 'photo' AS kind
      FROM issue_photos p
    ) combined
  `;

  const total = db.prepare(`SELECT COUNT(*) AS total FROM ${combinedFrom} ${where}`).get(...params).total;
  const totalPages = Math.max(1, Math.ceil(total / limitInt));
  const offset = (pageInt - 1) * limitInt;

  const items = db.prepare(`
    SELECT combined.id, combined.document_type, combined.original_name, combined.mime_type, combined.file_size_kb,
           combined.uploader_name, combined.uploaded_by, combined.uploaded_at, combined.issue_id, combined.equipment_id,
           combined.annex_number, combined.annex_type_index, combined.kind,
           e.name AS equipment_name, i.status AS issue_status, i.created_at AS issue_created_at
    FROM ${combinedFrom}
    LEFT JOIN equipment e ON e.id = combined.equipment_id
    LEFT JOIN issues i ON i.id = combined.issue_id
    ${where}
    ORDER BY combined.uploaded_at DESC
    LIMIT ? OFFSET ?
  `).all(...params, limitInt, offset);

  res.json({ items, total, page: pageInt, limit: limitInt, total_pages: totalPages });
});

// ── GET /api/documents/interventions/technicians ──────────────────────────────
router.get('/technicians', verifyToken, requireRole(...ALLOWED_ROLES), (req, res) => {
  const { docTypes, error } = parseTypes(req.query.types);
  if (error) return res.status(400).json({ error });
  if (docTypes.length === 0) return res.json([]);

  const db = getDb();
  const { placeholders, params } = docTypesInClause(docTypes);
  const items = db.prepare(`
    SELECT DISTINCT uploaded_by, uploader_name
    FROM equipment_documents
    WHERE document_type IN (${placeholders}) AND deleted_at IS NULL AND uploaded_by IS NOT NULL
    ORDER BY uploader_name
  `).all(...params);
  res.json(items);
});

// ── GET /api/documents/interventions/zip ──────────────────────────────────────
router.get('/zip', verifyToken, requireRole(...ALLOWED_ROLES), (req, res) => {
  const filters = parseFilters(req.query);
  if (filters.error) return res.status(400).json({ error: filters.error });
  if (filters.docTypes.length === 0) {
    return res.status(404).json({ error: 'Aucun document pour ces critères' });
  }

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

// Charge en mémoire chaque document d'une liste (bytes + PDFDocument + pageCount),
// nécessaire pour calculer les pages de départ du sommaire AVANT tout assemblage.
async function loadPdfGroup(list) {
  return Promise.all(list.map(async (d) => {
    const bytes = fs.readFileSync(path.join(UPLOAD_DIR, d.stored_name));
    const srcPdf = await PDFDocument.load(bytes);
    return { ...d, srcPdf, pageCount: srcPdf.getPageCount() };
  }));
}

// Copie les pages de chaque document chargé (loadPdfGroup) dans mergedPdf, dans l'ordre.
async function appendPdfGroup(mergedPdf, loadedDocs) {
  for (const doc of loadedDocs) {
    const pages = await mergedPdf.copyPages(doc.srcPdf, doc.srcPdf.getPageIndices());
    pages.forEach((page) => mergedPdf.addPage(page));
  }
}

// ── Merge PDF par incident : rapport final → sommaire → intervention → annexes ──
// Remplace le tri unique par date : reconstruction en 4 groupes distincts, avec
// un sommaire conditionnel (documents d'intervention + annexes numérotées).
async function buildIssuePrintPdf(issueId) {
  const db = getDb();

  const finalReportDoc = db.prepare(`
    SELECT id, original_name, stored_name FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'final_report' AND mime_type = 'application/pdf'
  `).get(issueId);

  const interventionDocs = db.prepare(`
    SELECT id, original_name, stored_name FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'intervention' AND mime_type = 'application/pdf'
    ORDER BY uploaded_at ASC
  `).all(issueId);

  const numberedDocAnnexes = db.prepare(`
    SELECT id, original_name, stored_name, annex_number, annex_type_index
    FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'completion' AND annex_number IS NOT NULL
  `).all(issueId).map((d) => ({ ...d, kind: 'document' }));

  const numberedPhotoAnnexes = db.prepare(`
    SELECT id, original_name, annex_pdf_stored_name AS stored_name, annex_number, annex_type_index
    FROM issue_photos
    WHERE issue_id = ? AND annex_pdf_stored_name IS NOT NULL
  `).all(issueId).map((p) => ({ ...p, kind: 'photo' }));

  const numberedAnnexes = [...numberedDocAnnexes, ...numberedPhotoAnnexes]
    .sort((a, b) => a.annex_number - b.annex_number);

  const legacyAnnexes = db.prepare(`
    SELECT id, original_name, stored_name FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'completion'
      AND annex_number IS NULL AND mime_type = 'application/pdf'
    ORDER BY uploaded_at ASC
  `).all(issueId).map((d) => ({ ...d, kind: 'document' }));

  const totalDocs = (finalReportDoc ? 1 : 0) + interventionDocs.length + numberedAnnexes.length + legacyAnnexes.length;
  if (totalDocs === 0) return null;

  // Les 4 groupes sont indépendants (lignes DB et fichiers disque distincts) : chargés
  // en parallèle plutôt qu'en 4 batches séquentiels.
  const [finalReportLoaded, interventionLoaded, numberedLoaded, legacyLoaded] = await Promise.all([
    finalReportDoc ? loadPdfGroup([finalReportDoc]).then((g) => g[0]) : Promise.resolve(null),
    loadPdfGroup(interventionDocs),
    loadPdfGroup(numberedAnnexes),
    loadPdfGroup(legacyAnnexes),
  ]);

  // ── Sommaire : documents d'intervention + annexes numérotées, jamais les hérités ──
  const entries = [];
  let cursor = finalReportLoaded ? finalReportLoaded.pageCount : 0;

  const entryCount = interventionLoaded.length + numberedLoaded.length;
  cursor += summaryPageCount(entryCount);

  for (const doc of interventionLoaded) {
    entries.push({ label: `Intervention — ${doc.original_name}`, startPage: cursor + 1 });
    cursor += doc.pageCount;
  }
  for (const annex of numberedLoaded) {
    const typeLabel = annex.kind === 'photo' ? 'Photo' : 'Pièce jointe';
    entries.push({
      label: `Annexe ${annex.annex_number} — ${typeLabel} ${annex.annex_type_index} — ${annex.original_name}`,
      startPage: cursor + 1,
    });
    cursor += annex.pageCount;
  }

  const summaryBuffer = await buildSummaryPdf(entries);

  const mergedPdf = await PDFDocument.create();
  if (finalReportLoaded) await appendPdfGroup(mergedPdf, [finalReportLoaded]);
  if (summaryBuffer) {
    const summaryPdf = await PDFDocument.load(summaryBuffer);
    await appendPdfGroup(mergedPdf, [{ srcPdf: summaryPdf }]);
  }
  await appendPdfGroup(mergedPdf, interventionLoaded);
  await appendPdfGroup(mergedPdf, numberedLoaded);
  await appendPdfGroup(mergedPdf, legacyLoaded);

  return { mergedPdf, docCount: totalDocs };
}

// ── GET /api/documents/interventions/print-pdf ────────────────────────────────
router.get('/print-pdf', verifyToken, requireRole(...ALLOWED_ROLES), async (req, res) => {
  const filters = parseFilters(req.query);
  if (filters.error) return res.status(400).json({ error: filters.error });

  // Merge par incident : réordonné (rapport final → sommaire → intervention →
  // annexes), comportement dédié qui ignore les filtres uploaded_by/from/to/types.
  if (filters.issueId) {
    try {
      const result = await buildIssuePrintPdf(filters.issueId);
      if (!result) return res.status(404).json({ error: 'Aucun document pour cet incident' });

      logExport(req, 'export_intervention_documents_pdf', filters, result.docCount);

      const mergedBytes = await result.mergedPdf.save();
      res.setHeader('Content-Type', 'application/pdf');
      res.send(Buffer.from(mergedBytes));
    } catch (err) {
      res.status(500).json({ error: 'Erreur lors de la fusion des PDF' });
    }
    return;
  }

  // Merge multi-incidents (filtré par uploaded_by/from/to/types) — comportement inchangé.
  if (filters.docTypes.length === 0) {
    return res.status(404).json({ error: 'Aucun PDF pour ces critères' });
  }

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
    const docsLoaded = await loadPdfGroup(docs);
    const mergedPdf = await PDFDocument.create();
    await appendPdfGroup(mergedPdf, docsLoaded);

    logExport(req, 'export_intervention_documents_pdf', filters, docs.length);

    const mergedBytes = await mergedPdf.save();
    res.setHeader('Content-Type', 'application/pdf');
    res.send(Buffer.from(mergedBytes));
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la fusion des PDF' });
  }
});

module.exports = router;
