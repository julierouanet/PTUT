const path = require('path');
const { UPLOAD_DIR } = require('../config');

// ── Insertion d'un document dans equipment_documents ──────────────────────────
// Partagé entre routes/documents.js (upload équipement) et routes/issues.js
// (upload document d'intervention). `equipmentId`/`issueId` sont nullable :
// un document peut être rattaché à l'un, l'autre, ou les deux.
function insertEquipmentDocument(db, { equipmentId, issueId, docType, file, userId, userName }) {
  const fileSizeKb = Math.ceil(file.size / 1024);
  const result = db.prepare(`
    INSERT INTO equipment_documents
      (equipment_id, issue_id, document_type, original_name, stored_name, mime_type,
       file_size_kb, uploaded_by, uploader_name, uploaded_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'))
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
  );
  return { id: result.lastInsertRowid, original_name: file.originalname, file_size_kb: fileSizeKb };
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

module.exports = { insertEquipmentDocument, sendStoredDocument };
