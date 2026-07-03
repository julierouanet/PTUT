const express = require('express');
const path = require('path');
const fs = require('fs');
const archiver = require('archiver');
const { PDFDocument } = require('pdf-lib');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { UPLOAD_DIR } = require('../config');
const { buildSummaryPdf, summaryPageCount } = require('../services/annex_summary_service');
const { buildPhotoGridPdf } = require('../services/annex_photo_grid_service');

const router = express.Router();

const ALLOWED_ROLES = ['admin', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
// 'photo' est un pseudo-type : jamais une valeur de equipment_documents.document_type,
// il route vers la table issue_photos (voir buildPhotoWhere).
const FILTERABLE_DOC_TYPES = ['intervention', 'completion', 'photo'];
// Comportement par défaut (paramètre `types` absent) inchangé pour la rétrocompatibilité
// des appelants existants — 'photo' doit être demandé explicitement.
const DEFAULT_DOC_TYPES = ['intervention', 'completion'];

// Parse le paramètre `types` (CSV "intervention,completion,photo" OU tableau Express
// si le client envoie ?types=a&types=b). Comparaison EXACTE, sensible à la casse
// (les valeurs DB sont strictement en minuscules, aucune normalisation). `final_report`
// n'est jamais une valeur acceptée ici : le rapport final est toujours inclus côté
// serveur (voir buildWhere), le client ne doit jamais le demander explicitement.
function parseTypes(rawTypes) {
  if (rawTypes === undefined) return { docTypes: DEFAULT_DOC_TYPES };

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
// documents+photos de la route GET / (alias 'combined'). Le rapport final
// (document_type = 'final_report') est TOUJOURS inclus, que le client l'ait
// demandé ou non (il ne peut d'ailleurs jamais le demander, voir parseTypes) —
// y compris quand docTypes est vide (aucune case cochée côté client).
function buildWhere({ uploadedBy, from, to, search, issueId, docTypes }, extraCondition, alias = 'ed') {
  // 'final_report' n'est jamais dans docTypes (le client ne peut pas le demander,
  // voir parseTypes) : l'ajouter systématiquement à la clause IN couvre à la fois
  // le cas "toujours inclus" et le cas docTypes vide, sans branche séparée ni OR
  // (qui empêcherait SQLite d'exploiter un index simple sur document_type).
  const { placeholders, params } = docTypesInClause([...docTypes, 'final_report']);
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

// Clause WHERE pour issue_photos, utilisée par /zip et /print-pdf quand le pseudo-type
// 'photo' est demandé. issue_photos n'a pas de colonne uploaded_by : les photos ne sont
// donc jamais filtrables par technicien et sont exclues si `uploadedBy` est renseigné
// (voir appels sites) plutôt que de planter ou d'ignorer silencieusement ce filtre.
function buildPhotoWhere({ from, to, search, issueId }) {
  let where = 'WHERE 1=1';
  const params = [];
  if (from) {
    where += ' AND date(uploaded_at) >= ?';
    params.push(from);
  }
  if (to) {
    where += ' AND date(uploaded_at) <= ?';
    params.push(to);
  }
  if (search) {
    where += ' AND original_name LIKE ? COLLATE NOCASE';
    params.push(`%${search}%`);
  }
  if (issueId) {
    where += ' AND issue_id = ?';
    params.push(issueId);
  }
  return { where, params };
}

// Charge les photos d'incident matchant les filtres, partagé entre /zip et /print-pdf
// (seules la colonne de fichier et une condition supplémentaire optionnelle diffèrent).
// [] si le pseudo-type 'photo' n'est pas demandé ou si uploaded_by est renseigné (voir
// buildPhotoWhere : issue_photos n'a pas de colonne uploaded_by).
function fetchFilteredPhotos(filters, { storedNameColumn, extraCondition = '' }) {
  if (!filters.docTypes.includes('photo') || filters.uploadedBy) return [];
  const { where, params } = buildPhotoWhere(filters);
  return getDb().prepare(`
    SELECT id, original_name, ${storedNameColumn} AS stored_name
    FROM issue_photos
    ${where}${extraCondition}
    ORDER BY uploaded_at DESC
  `).all(...params);
}

// Réponse d'erreur commune aux deux chemins de fusion PDF (par incident et multi-incidents).
function sendMergeError(res, err) {
  console.error('[DB] Échec fusion PDF intervention:', err);
  res.status(500).json({ error: 'Erreur lors de la fusion des PDF : ' + err.message });
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

  const db = getDb();
  const { where, params } = buildWhere(filters, null, 'combined');

  // Fusion documents + photos d'incident : les photos sont sans uploader/équipement
  // (colonnes NULL) et exposées sous document_type='photo' (pseudo-type distinct,
  // filtrable indépendamment de 'completion'), avec kind='photo' pour l'UI.
  const combinedFrom = `
    (
      SELECT ed.id, ed.document_type, ed.original_name, ed.mime_type, ed.file_size_kb,
             ed.uploader_name, ed.uploaded_by, ed.uploaded_at, ed.issue_id, ed.equipment_id,
             ed.deleted_at, ed.annex_number, ed.annex_type_index, 'document' AS kind
      FROM equipment_documents ed
      UNION ALL
      SELECT p.id, 'photo' AS document_type, p.original_name, p.mime_type, p.file_size_kb,
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

  const db = getDb();
  const { where, params } = buildWhere(filters);
  const docs = db.prepare(`
    SELECT ed.id, ed.original_name, ed.stored_name
    FROM equipment_documents ed
    ${where}
    ORDER BY ed.uploaded_at DESC
  `).all(...params);

  const photos = fetchFilteredPhotos(filters, { storedNameColumn: 'stored_name' });

  if (docs.length === 0 && photos.length === 0) {
    return res.status(404).json({ error: 'Aucun document pour ces critères' });
  }

  logExport(req, 'export_intervention_documents_zip', filters, docs.length + photos.length);

  const filename = `interventions_${filters.from || 'debut'}_${filters.to || 'fin'}.zip`;
  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

  const archive = archiver('zip');
  archive.on('error', (err) => {
    if (!res.headersSent) res.status(500).json({ error: 'Erreur lors de la génération du ZIP' });
  });
  archive.pipe(res);

  const usedNames = new Map();
  const addToArchive = (item) => {
    let name = item.original_name;
    const count = usedNames.get(name) || 0;
    if (count > 0) {
      const ext = path.extname(name);
      const base = path.basename(name, ext);
      name = `${base}_${count + 1}${ext}`;
    }
    usedNames.set(item.original_name, count + 1);
    archive.file(path.join(UPLOAD_DIR, item.stored_name), { name });
  };
  for (const doc of docs) addToArchive(doc);
  for (const photo of photos) addToArchive(photo);

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
// `docTypes` (sous-ensemble de FILTERABLE_DOC_TYPES) gate chaque groupe sauf le
// rapport final, toujours chargé sans condition — voir buildWhere pour la même
// règle appliquée aux autres routes.
async function buildIssuePrintPdf(issueId, docTypes) {
  const db = getDb();

  const finalReportDoc = db.prepare(`
    SELECT id, original_name, stored_name FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'final_report' AND mime_type = 'application/pdf'
  `).get(issueId);

  const interventionDocs = docTypes.includes('intervention') ? db.prepare(`
    SELECT id, original_name, stored_name FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'intervention' AND mime_type = 'application/pdf'
    ORDER BY uploaded_at ASC
  `).all(issueId) : [];

  const numberedDocAnnexes = docTypes.includes('completion') ? db.prepare(`
    SELECT id, original_name, stored_name, annex_number, annex_type_index
    FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'completion' AND annex_number IS NOT NULL
  `).all(issueId).map((d) => ({ ...d, kind: 'document' })) : [];

  // Contrairement aux annexes documents (annex_pdf_stored_name pointe déjà vers un
  // PDF 1 page/photo tamponné), les photos passent maintenant par une grille 2x2 :
  // on charge donc l'image ORIGINALE (stored_name), pas le PDF individuel — voir
  // annex_photo_grid_service.js.
  const numberedPhotoAnnexes = docTypes.includes('photo') ? db.prepare(`
    SELECT id, original_name, stored_name, mime_type, annex_number, annex_type_index
    FROM issue_photos
    WHERE issue_id = ? AND annex_number IS NOT NULL
    ORDER BY annex_number ASC
  `).all(issueId) : [];

  const legacyAnnexes = docTypes.includes('completion') ? db.prepare(`
    SELECT id, original_name, stored_name FROM equipment_documents
    WHERE issue_id = ? AND deleted_at IS NULL AND document_type = 'completion'
      AND annex_number IS NULL AND mime_type = 'application/pdf'
    ORDER BY uploaded_at ASC
  `).all(issueId).map((d) => ({ ...d, kind: 'document' })) : [];

  const totalDocs = (finalReportDoc ? 1 : 0) + interventionDocs.length + numberedDocAnnexes.length
    + numberedPhotoAnnexes.length + legacyAnnexes.length;
  if (totalDocs === 0) return null;

  // Les groupes sont indépendants (lignes DB et fichiers disque distincts) : chargés
  // en parallèle plutôt qu'en batches séquentiels.
  const [finalReportLoaded, interventionLoaded, numberedDocLoaded, legacyLoaded, photoGrid] = await Promise.all([
    finalReportDoc ? loadPdfGroup([finalReportDoc]).then((g) => g[0]) : Promise.resolve(null),
    loadPdfGroup(interventionDocs),
    loadPdfGroup(numberedDocAnnexes),
    loadPdfGroup(legacyAnnexes),
    buildPhotoGridPdf(
      numberedPhotoAnnexes.map((p) => ({
        imageBuffer: fs.readFileSync(path.join(UPLOAD_DIR, p.stored_name)),
        mimeType: p.mime_type,
        label: p.original_name,
        annexNumber: p.annex_number,
        annexTypeIndex: p.annex_type_index,
      })),
      issueId
    ),
  ]);

  // ── Sommaire : documents d'intervention + annexes numérotées, jamais les hérités ──
  const entries = [];
  let cursor = finalReportLoaded ? finalReportLoaded.pageCount : 0;

  const entryCount = interventionLoaded.length + numberedDocLoaded.length + numberedPhotoAnnexes.length;
  cursor += summaryPageCount(entryCount);

  for (const doc of interventionLoaded) {
    entries.push({ label: `Intervention — ${doc.original_name}`, startPage: cursor + 1 });
    cursor += doc.pageCount;
  }
  for (const annex of numberedDocLoaded) {
    entries.push({
      label: `Annexe ${annex.annex_number} — Pièce jointe ${annex.annex_type_index} — ${annex.original_name}`,
      startPage: cursor + 1,
    });
    cursor += annex.pageCount;
  }
  // Plusieurs photos peuvent partager la même page de grille : startPage n'est donc
  // pas incrémenté entrée par entrée mais lu depuis pageStartByEntryIndex.
  numberedPhotoAnnexes.forEach((annex, i) => {
    entries.push({
      label: `Annexe ${annex.annex_number} — Photo ${annex.annex_type_index} — ${annex.original_name}`,
      startPage: cursor + photoGrid.pageStartByEntryIndex[i],
    });
  });
  cursor += photoGrid.pageCount;

  const summaryBuffer = await buildSummaryPdf(entries);

  const mergedPdf = await PDFDocument.create();
  if (finalReportLoaded) await appendPdfGroup(mergedPdf, [finalReportLoaded]);
  if (summaryBuffer) {
    const summaryPdf = await PDFDocument.load(summaryBuffer);
    await appendPdfGroup(mergedPdf, [{ srcPdf: summaryPdf }]);
  }
  await appendPdfGroup(mergedPdf, interventionLoaded);
  await appendPdfGroup(mergedPdf, numberedDocLoaded);
  if (photoGrid.buffer) {
    const photoGridPdf = await PDFDocument.load(photoGrid.buffer);
    await appendPdfGroup(mergedPdf, [{ srcPdf: photoGridPdf }]);
  }
  await appendPdfGroup(mergedPdf, legacyLoaded);

  return { mergedPdf, docCount: totalDocs };
}

// ── GET /api/documents/interventions/print-pdf ────────────────────────────────
router.get('/print-pdf', verifyToken, requireRole(...ALLOWED_ROLES), async (req, res) => {
  const filters = parseFilters(req.query);
  if (filters.error) return res.status(400).json({ error: filters.error });

  // Merge par incident : réordonné (rapport final → sommaire → intervention →
  // annexes), comportement dédié qui ignore les filtres uploaded_by/from/to mais
  // respecte docTypes (le rapport final reste, lui, toujours inclus).
  if (filters.issueId) {
    try {
      const result = await buildIssuePrintPdf(filters.issueId, filters.docTypes);
      if (!result) return res.status(404).json({ error: 'Aucun document pour cet incident' });

      logExport(req, 'export_intervention_documents_pdf', filters, result.docCount);

      const mergedBytes = await result.mergedPdf.save();
      res.setHeader('Content-Type', 'application/pdf');
      res.send(Buffer.from(mergedBytes));
    } catch (err) {
      sendMergeError(res, err);
    }
    return;
  }

  // Merge multi-incidents (filtré par uploaded_by/from/to/types, + final_report
  // toujours inclus) — comportement inchangé pour intervention/completion.
  const db = getDb();
  const { where, params } = buildWhere(filters, "ed.mime_type = 'application/pdf'");
  const docs = db.prepare(`
    SELECT ed.id, ed.original_name, ed.stored_name
    FROM equipment_documents ed
    ${where}
    ORDER BY ed.uploaded_at DESC
  `).all(...params);

  // Les photos n'ont pas toutes de PDF associé (annex_pdf_stored_name NULL tant que
  // non numérotées en annexe) : seules celles déjà converties sont fusionnables ici,
  // sans tentative de conversion à la volée.
  const photoDocs = fetchFilteredPhotos(filters, {
    storedNameColumn: 'annex_pdf_stored_name',
    extraCondition: ' AND annex_pdf_stored_name IS NOT NULL',
  });

  const allDocs = [...docs, ...photoDocs];
  if (allDocs.length === 0) {
    return res.status(404).json({ error: 'Aucun PDF pour ces critères' });
  }

  try {
    const docsLoaded = await loadPdfGroup(allDocs);
    const mergedPdf = await PDFDocument.create();
    await appendPdfGroup(mergedPdf, docsLoaded);

    logExport(req, 'export_intervention_documents_pdf', filters, allDocs.length);

    const mergedBytes = await mergedPdf.save();
    res.setHeader('Content-Type', 'application/pdf');
    res.send(Buffer.from(mergedBytes));
  } catch (err) {
    sendMergeError(res, err);
  }
});

module.exports = router;
