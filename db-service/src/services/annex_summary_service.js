/**
 * Génère le PDF de sommaire d'un incident : liste des documents d'intervention
 * puis des annexes numérotées, avec leur page de départ dans le PDF fusionné.
 * Les documents hérités (non numérotés) n'y figurent jamais.
 * Fonction pure (entries → Buffer|null), sans accès disque ni DB.
 */

const { PDFDocument, StandardFonts, PageSizes, rgb } = require('pdf-lib');

const MARGIN = 50;
const TITLE_SIZE = 16;
const ROW_SIZE = 11;
const ROW_HEIGHT = 22;
const ENTRIES_PER_PAGE = 25;
const TEXT_COLOR = rgb(0.1, 0.1, 0.1);

// Nombre de pages qu'occupera le sommaire pour `entryCount` entrées — déductible
// avant tout rendu, indépendamment du contenu réel des pages (cf. appelant :
// nécessaire pour calculer les pages de départ des groupes suivants).
function summaryPageCount(entryCount) {
  return entryCount > 0 ? Math.ceil(entryCount / ENTRIES_PER_PAGE) : 0;
}

// entries: [{ label, startPage }]
async function buildSummaryPdf(entries) {
  if (!entries || entries.length === 0) return null;

  const outDoc = await PDFDocument.create();
  const font = await outDoc.embedFont(StandardFonts.Helvetica);
  const boldFont = await outDoc.embedFont(StandardFonts.HelveticaBold);
  const [pageWidth, pageHeight] = PageSizes.A4;

  for (let offset = 0; offset < entries.length; offset += ENTRIES_PER_PAGE) {
    const chunk = entries.slice(offset, offset + ENTRIES_PER_PAGE);
    const page = outDoc.addPage([pageWidth, pageHeight]);
    let y = pageHeight - MARGIN;

    if (offset === 0) {
      page.drawText('Sommaire', { x: MARGIN, y, size: TITLE_SIZE, font: boldFont, color: TEXT_COLOR });
      y -= ROW_HEIGHT * 1.5;
    }

    for (const entry of chunk) {
      const pageLabel = `p. ${entry.startPage}`;
      page.drawText(entry.label, { x: MARGIN, y, size: ROW_SIZE, font, color: TEXT_COLOR });
      const pageLabelWidth = font.widthOfTextAtSize(pageLabel, ROW_SIZE);
      page.drawText(pageLabel, {
        x: pageWidth - MARGIN - pageLabelWidth,
        y,
        size: ROW_SIZE,
        font,
        color: TEXT_COLOR,
      });
      y -= ROW_HEIGHT;
    }
  }

  return Buffer.from(await outDoc.save());
}

module.exports = { buildSummaryPdf, summaryPageCount };
