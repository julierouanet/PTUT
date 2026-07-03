/**
 * Tamponnage permanent des annexes (pièces jointes 'completion' et photos
 * d'incident) : ajoute un bandeau d'en-tête sur CHAQUE page, toujours en
 * français, avec le numéro d'annexe, l'incident et la pagination.
 * Fonctions pures (Buffer → Buffer), sans accès disque ni DB.
 */

const { PDFDocument, StandardFonts, rgb, PageSizes } = require('pdf-lib');

const BAND_HEIGHT = 50;
const BAND_COLOR = rgb(0.9, 0.9, 0.9);
const TEXT_COLOR = rgb(0.1, 0.1, 0.1);
const FONT_SIZE = 10;
const MARGIN = 24;

function buildStampText({ annexNumber, issueId, typeLabel, typeIndex, page, totalPages }) {
  return `Annexe ${annexNumber} — Incident n° ${issueId} — ${typeLabel} ${typeIndex} — Page ${page}/${totalPages}`;
}

function drawBand(page, font, { width, bandY, text }) {
  page.drawRectangle({ x: 0, y: bandY, width, height: BAND_HEIGHT, color: BAND_COLOR });
  page.drawText(text, {
    x: MARGIN,
    y: bandY + (BAND_HEIGHT - FONT_SIZE) / 2,
    size: FONT_SIZE,
    font,
    color: TEXT_COLOR,
  });
}

// ── Tamponne un PDF source (déjà PDF), page par page ─────────────────────────
async function stampPdfAnnex(inputBuffer, { annexNumber, issueId, typeLabel, typeIndex }) {
  const srcPdf = await PDFDocument.load(inputBuffer);
  const totalPages = srcPdf.getPageCount();
  if (totalPages === 0) throw new Error('PDF source vide (0 page)');

  const outDoc = await PDFDocument.create();
  const font = await outDoc.embedFont(StandardFonts.Helvetica);

  for (let i = 0; i < totalPages; i++) {
    const srcPage = srcPdf.getPage(i);
    const { width, height } = srcPage.getSize();
    const embedded = await outDoc.embedPage(srcPage);

    const newPage = outDoc.addPage([width, height + BAND_HEIGHT]);
    newPage.drawPage(embedded, { x: 0, y: 0, xScale: 1, yScale: 1 });
    drawBand(newPage, font, {
      width,
      bandY: height,
      text: buildStampText({ annexNumber, issueId, typeLabel, typeIndex, page: i + 1, totalPages }),
    });
  }

  return Buffer.from(await outDoc.save());
}

// ── Convertit une image (JPEG/PNG) en PDF tamponné d'une seule page ──────────
async function imageToStampedPdf(imageBuffer, mimeType, { annexNumber, issueId, typeLabel, typeIndex }) {
  const outDoc = await PDFDocument.create();
  const font = await outDoc.embedFont(StandardFonts.Helvetica);

  let image;
  if (mimeType === 'image/png') {
    image = await outDoc.embedPng(imageBuffer);
  } else {
    // Recopie dans un buffer non poolé : le JpegEmbedder de pdf-lib (contrairement
    // au PngEmbedder) lit `imageData.buffer` sans tenir compte de byteOffset/
    // byteLength, ce qui le fait échouer ("SOI not found in JPEG") sur tout
    // buffer issu du pool interne de Node (fs.readFileSync sur un fichier < 4 Ko,
    // ex. petite photo compressée) alors que l'image source est parfaitement valide.
    const normalizedBuffer = Buffer.from(
      imageBuffer.buffer.slice(imageBuffer.byteOffset, imageBuffer.byteOffset + imageBuffer.byteLength)
    );
    image = await outDoc.embedJpg(normalizedBuffer);
  }

  const [pageWidth, pageHeight] = PageSizes.A4;
  const page = outDoc.addPage([pageWidth, pageHeight]);

  const availableWidth = pageWidth - MARGIN * 2;
  const availableHeight = pageHeight - BAND_HEIGHT - MARGIN * 2;
  const scale = Math.min(availableWidth / image.width, availableHeight / image.height, 1);
  const drawWidth = image.width * scale;
  const drawHeight = image.height * scale;
  const x = (pageWidth - drawWidth) / 2;
  const y = MARGIN;

  page.drawImage(image, { x, y, width: drawWidth, height: drawHeight });
  drawBand(page, font, {
    width: pageWidth,
    bandY: pageHeight - BAND_HEIGHT,
    text: buildStampText({ annexNumber, issueId, typeLabel, typeIndex, page: 1, totalPages: 1 }),
  });

  return Buffer.from(await outDoc.save());
}

module.exports = { stampPdfAnnex, imageToStampedPdf };
