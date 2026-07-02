/**
 * Génère un document PDF de suivi lors du rejet d'un incident (format A4 portrait).
 * Utilise PDFKit pour la génération serveur-side.
 *
 * params = {
 *   equipmentName, locationId, department, description,
 *   reasonCode, comment, rejectedBy, rejectedAt
 * }
 */

const REJECT_REASON_LABELS = {
  duplicate:         'Doublon',
  not_reproducible:  'Non reproductible',
  out_of_scope:      'Hors périmètre',
  false_alarm:       'Fausse alerte',
  other:             'Autre',
};

async function generateRejectionDocumentPdf(params) {
  // Import dynamique pour compatibilité ESM/CJS
  let PDFDocument;
  try {
    PDFDocument = require('pdfkit');
  } catch (_) {
    // pdfkit non installé — retourner un PDF minimal d'erreur
    return Buffer.from('%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n');
  }

  const {
    equipmentName = '',
    locationId    = '',
    department    = '',
    description   = '',
    reasonCode    = '',
    comment       = '',
    rejectedBy    = '',
    rejectedAt    = '',
  } = params;

  const cible = equipmentName || locationId || department || '—';

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margin: 40,
      info: { Title: `Rejet incident — ${cible}` },
    });

    const buffers = [];
    doc.on('data', chunk => buffers.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);

    // ── Titre ────────────────────────────────────────────────────────────────
    doc.fillColor('#c62828').fontSize(16).font('Helvetica-Bold');
    doc.text('Incident non validé — Rejet', { align: 'left' });
    doc.moveDown(1);

    doc.moveTo(40, doc.y).lineTo(555, doc.y).strokeColor('#9e9e9e').lineWidth(0.5).stroke();
    doc.moveDown(1);

    // ── Détails de l'incident ───────────────────────────────────────────────
    _row(doc, 'Équipement / Lieu', cible);
    _row(doc, 'Département', department || '—');
    doc.moveDown(0.5);
    doc.fillColor('#757575').fontSize(10).font('Helvetica').text('Description', { continued: false });
    doc.fillColor('#212121').fontSize(10).font('Helvetica').text(description || '—', { width: 515 });
    doc.moveDown(1);

    doc.moveTo(40, doc.y).lineTo(555, doc.y).strokeColor('#9e9e9e').lineWidth(0.5).stroke();
    doc.moveDown(1);

    // ── Motif de rejet ───────────────────────────────────────────────────────
    _row(doc, 'Motif de rejet', REJECT_REASON_LABELS[reasonCode] || reasonCode);
    if (comment) {
      doc.moveDown(0.5);
      doc.fillColor('#757575').fontSize(10).font('Helvetica').text('Commentaire', { continued: false });
      doc.fillColor('#212121').fontSize(10).font('Helvetica').text(comment, { width: 515 });
      doc.moveDown(0.5);
    }
    _row(doc, 'Rejeté par', rejectedBy || '—');
    _row(doc, 'Date', rejectedAt || '—');

    doc.end();
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function _row(doc, label, value) {
  doc.fillColor('#757575').fontSize(10).font('Helvetica').text(label, { continued: true });
  doc.fillColor('#212121').fontSize(10).font('Helvetica-Bold').text(`  ${value || '—'}`);
}

module.exports = { generateRejectionDocumentPdf };
