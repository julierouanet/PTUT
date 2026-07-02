const fs = require('fs');
const path = require('path');
const { UPLOAD_DIR } = require('../config');

// ── Insertion d'un document dans equipment_documents ──────────────────────────
// Partagé entre routes/documents.js (upload équipement) et routes/issues.js
// (upload document d'intervention). `equipmentId`/`issueId` sont nullable :
// un document peut être rattaché à l'un, l'autre, ou les deux.
// `annexNumber`/`annexTypeIndex` (nullable) : rang d'annexe déjà réservé pour
// les pièces jointes 'completion' — cf. nextAnnexNumber / nextDocumentAnnexTypeIndex.
function insertEquipmentDocument(db, { equipmentId, issueId, docType, file, userId, userName, annexNumber = null, annexTypeIndex = null }) {
  const fileSizeKb = Math.ceil(file.size / 1024);
  const result = db.prepare(`
    INSERT INTO equipment_documents
      (equipment_id, issue_id, document_type, original_name, stored_name, mime_type,
       file_size_kb, uploaded_by, uploader_name, uploaded_at, annex_number, annex_type_index)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'), ?, ?)
  `).run(
    equipmentId || null,
    issueId || null,
    docType,
    file.originalname,
    file.filename,
    file.mimetype,
    fileSizeKb,
    userId,
    userName,
    annexNumber,
    annexTypeIndex,
  );
  return {
    id: result.lastInsertRowid,
    original_name: file.originalname,
    stored_name: file.filename,
    mime_type: file.mimetype,
    file_size_kb: fileSizeKb,
    annex_number: annexNumber,
    annex_type_index: annexTypeIndex,
  };
}

// ── Numérotation d'annexe (compteur partagé equipment_documents + issue_photos) ──
// Doit être appelée à l'intérieur d'une db.transaction() pour éviter toute
// collision entre deux uploads concurrents sur le même incident.
function nextAnnexNumber(db, issueId) {
  const row = db.prepare(`
    SELECT MAX(n) AS maxN FROM (
      SELECT MAX(annex_number) AS n FROM equipment_documents WHERE issue_id = ?
      UNION ALL
      SELECT MAX(annex_number) AS n FROM issue_photos WHERE issue_id = ?
    )
  `).get(issueId, issueId);
  return (row.maxN || 0) + 1;
}

// Sous-compteur indépendant par type ('Pièce jointe' pour equipment_documents)
function nextDocumentAnnexTypeIndex(db, issueId) {
  const row = db.prepare(`
    SELECT COUNT(*) AS c FROM equipment_documents
    WHERE issue_id = ? AND document_type = 'completion' AND annex_type_index IS NOT NULL
  `).get(issueId);
  return row.c + 1;
}

// Sous-compteur indépendant par type ('Photo' pour issue_photos)
function nextPhotoAnnexTypeIndex(db, issueId) {
  const row = db.prepare(`
    SELECT COUNT(*) AS c FROM issue_photos WHERE issue_id = ? AND annex_type_index IS NOT NULL
  `).get(issueId);
  return row.c + 1;
}

// ── Écriture atomique d'un fichier (tmp + rename) ──────────────────────────────
// Évite qu'une requête de téléchargement concurrente lise un fichier à moitié écrit.
function writeFileAtomic(filePath, buffer) {
  const tmpPath = `${filePath}.tmp`;
  fs.writeFileSync(tmpPath, buffer);
  fs.renameSync(tmpPath, filePath);
}

// ── Finalise le tamponnage d'une pièce jointe 'completion' après succès ───────
// storedName/mimeType ne sont fournis que si une conversion image → PDF a eu lieu.
function finalizeDocumentAnnexStamp(db, id, { storedName, mimeType } = {}) {
  if (storedName) {
    db.prepare('UPDATE equipment_documents SET stored_name = ?, mime_type = ? WHERE id = ?')
      .run(storedName, mimeType, id);
  }
}

// ── Annule la réservation d'annexe d'une pièce jointe si le tamponnage échoue ──
// Le document reste tel qu'uploadé, traité comme un document hérité (non numéroté).
function revertDocumentAnnexStamp(db, id) {
  db.prepare('UPDATE equipment_documents SET annex_number = NULL, annex_type_index = NULL WHERE id = ?').run(id);
}

// ── Finalise le tamponnage d'une photo après succès (copie PDF séparée) ───────
function finalizePhotoAnnexStamp(db, id, annexPdfStoredName) {
  db.prepare('UPDATE issue_photos SET annex_pdf_stored_name = ? WHERE id = ?').run(annexPdfStoredName, id);
}

// ── Annule la réservation d'annexe d'une photo si le tamponnage échoue ────────
function revertPhotoAnnexStamp(db, id) {
  db.prepare('UPDATE issue_photos SET annex_number = NULL, annex_type_index = NULL, annex_pdf_stored_name = NULL WHERE id = ?').run(id);
}

// ── Téléchargement d'un document stocké (headers + sendFile) ──────────────────
function sendStoredDocument(res, doc) {
  const filePath = path.join(UPLOAD_DIR, doc.stored_name);
  res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(doc.original_name)}"`);
  res.setHeader('Content-Type', doc.mime_type);
  res.sendFile(filePath, { root: '/' }, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ error: 'Fichier introuvable sur le serveur' });
    }
  });
}

module.exports = {
  insertEquipmentDocument,
  sendStoredDocument,
  nextAnnexNumber,
  nextDocumentAnnexTypeIndex,
  nextPhotoAnnexTypeIndex,
  writeFileAtomic,
  finalizeDocumentAnnexStamp,
  revertDocumentAnnexStamp,
  finalizePhotoAnnexStamp,
  revertPhotoAnnexStamp,
};
