/**
 * Génère une étiquette de maintenance préventive au format A6 paysage.
 * Utilise PDFKit pour la génération serveur-side.
 *
 * params = {
 *   equipmentName, serialNumber, department,
 *   technicianName, performedAt, nextPm, hospitalName
 * }
 */
async function generateMaintenanceLabelPdf(params) {
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
    serialNumber  = null,
    department    = '',
    technicianName = '',
    performedAt   = '',
    nextPm        = '',
    hospitalName  = 'Hôpital de District de Kabutare',
  } = params;

  // A6 paysage : 419.53pt × 297.64pt (148mm × 105mm à 72dpi)
  const A6_W = 419.53;
  const A6_H = 297.64;

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: [A6_W, A6_H],
      margin: 28,
      info: { Title: `Étiquette PM — ${equipmentName}` },
    });

    const buffers = [];
    doc.on('data', chunk => buffers.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);

    const marginX = 28;
    const contentW = A6_W - 2 * marginX;
    let y = 28;

    // ── En-tête hôpital ──────────────────────────────────────────────────────
    doc.rect(marginX, y, contentW, 24).fill('#1565c0');
    doc.fillColor('white').fontSize(10).font('Helvetica-Bold');
    doc.text(hospitalName, marginX + 4, y + 7, { width: contentW - 8, align: 'center' });

    y += 30;

    // ── Séparateur ───────────────────────────────────────────────────────────
    doc.moveTo(marginX, y).lineTo(marginX + contentW, y)
       .strokeColor('#9e9e9e').lineWidth(0.5).stroke();
    y += 8;

    // ── Lignes équipement ────────────────────────────────────────────────────
    doc.fillColor('#212121').fontSize(9).font('Helvetica');
    _row(doc, marginX, y, contentW, 'Équipement', equipmentName);
    y += 18;

    if (serialNumber) {
      _row(doc, marginX, y, contentW, 'N° série', serialNumber);
      y += 18;
    }

    _row(doc, marginX, y, contentW, 'Département', department);
    y += 18;

    // ── Séparateur ───────────────────────────────────────────────────────────
    doc.moveTo(marginX, y).lineTo(marginX + contentW, y)
       .strokeColor('#9e9e9e').lineWidth(0.5).stroke();
    y += 8;

    // ── Lignes maintenance ───────────────────────────────────────────────────
    _row(doc, marginX, y, contentW, 'Technicien', technicianName);
    y += 18;

    _row(doc, marginX, y, contentW, 'Date maint.', _formatDate(performedAt));
    y += 18;

    // Prochaine maintenance en bleu gras
    doc.font('Helvetica-Bold').fontSize(9).fillColor('#1565c0');
    _row(doc, marginX, y, contentW, 'Prochaine', _formatDate(nextPm), true);

    doc.end();
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function _row(doc, x, y, width, label, value, highlight = false) {
  const labelW = 80;
  doc.font('Helvetica').fontSize(9).fillColor('#757575');
  doc.text(label, x, y, { width: labelW });
  doc.font(highlight ? 'Helvetica-Bold' : 'Helvetica')
     .fontSize(9)
     .fillColor(highlight ? '#1565c0' : '#212121');
  doc.text(value || '—', x + labelW, y, { width: width - labelW });
}

function _formatDate(iso) {
  if (!iso || iso.length < 10) return iso || '—';
  const parts = iso.substring(0, 10).split('-');
  if (parts.length !== 3) return iso;
  return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

module.exports = { generateMaintenanceLabelPdf };
