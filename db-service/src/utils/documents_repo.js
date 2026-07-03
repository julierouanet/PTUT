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
  // Lié en paramètre (plutôt que datetime('now','localtime') inline) pour que
  // la valeur insérée et celle renvoyée au client restent identiques — sinon
  // le modèle Flutter EquipmentDocument (uploadedAt non-nullable) ne peut pas
  // être reconstruit depuis la seule réponse d'insertion. Locale 'sv-SE' sans
  // timeZone forcé = format 'YYYY-MM-DD HH:MM:SS' dans le fuseau système du
  // conteneur, identique à ce que produit `localtime` côté SQLite.
  const uploadedAt = new Date().toLocaleString('sv-SE');
  const result = db.prepare(`
    INSERT INTO equipment_documents
      (equipment_id, issue_id, document_type, original_name, stored_name, mime_type,
       file_size_kb, uploaded_by, uploader_name, uploaded_at, annex_number, annex_type_index)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    uploadedAt,
    annexNumber,
    annexTypeIndex,
  );
  return {
    id: result.lastInsertRowid,
    document_type: docType,
    original_name: file.originalname,
    stored_name: file.filename,
    mime_type: file.mimetype,
    file_size_kb: fileSizeKb,
    uploaded_by: userId,
    uploader_name: userName,
    uploaded_at: uploadedAt,
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

// ── Nom de téléchargement convivial (Content-Disposition uniquement) ─────────
// Format : "<Équipement> - <Tag> - Issue <IssueID> - Annexe <N><ext>". Le
// fichier PHYSIQUE (stored_name, UUID) n'est jamais renommé — seul le nom
// présenté à l'utilisateur au téléchargement change. Chaque segment
// indisponible (équipement non lié, tag absent, annexe non numérotée — ex.
// document hérité) est omis proprement plutôt que d'insérer une valeur
// vide/"null"/"undefined".
function buildFriendlyDownloadName({ equipmentName, tagNumber, issueId, annexNumber, originalName }) {
  const ext = path.extname(originalName);
  const parts = [];
  if (equipmentName) parts.push(equipmentName);
  if (tagNumber) parts.push(tagNumber);
  if (issueId) parts.push(`Issue ${issueId}`);
  if (annexNumber != null) parts.push(`Annexe ${annexNumber}`);
  if (parts.length === 0) return originalName;
  // Caractères interdits dans un nom de fichier Windows/Unix
  const safe = parts.join(' - ').replace(/[\\/:*?"<>|]/g, '_');
  return `${safe}${ext}`;
}

// ── Téléchargement d'un document stocké (headers + sendFile) ──────────────────
// `friendlyName` (optionnel) : nom convivial calculé via buildFriendlyDownloadName,
// utilisé à la place de doc.original_name quand fourni par l'appelant.
function sendStoredDocument(res, doc, friendlyName) {
  const filePath = path.join(UPLOAD_DIR, doc.stored_name);
  const downloadName = friendlyName || doc.original_name;
  res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(downloadName)}"`);
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
  buildFriendlyDownloadName,
  nextAnnexNumber,
  nextDocumentAnnexTypeIndex,
  nextPhotoAnnexTypeIndex,
  writeFileAtomic,
  finalizeDocumentAnnexStamp,
  revertDocumentAnnexStamp,
  finalizePhotoAnnexStamp,
  revertPhotoAnnexStamp,
};
