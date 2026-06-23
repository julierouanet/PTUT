// ── Types de documents valides pour equipment_documents ──────────────────────
// Partagé entre routes/documents.js (documents équipement) et routes/issues.js
// (documents d'intervention liés à un incident).
const VALID_DOC_TYPES = ['technical', 'intervention', 'certification', 'completion'];

module.exports = { VALID_DOC_TYPES };
