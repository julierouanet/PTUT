/**
 * Grille de photos annexées à un incident : 4 photos par page (2 colonnes ×
 * 2 lignes), avec bandeau d'en-tête par page et légende sous chaque photo.
 * Fonction pure (Buffer[] → Buffer), sans accès disque ni DB.
 */

const { PDFDocument, StandardFonts, PageSizes } = require('pdf-lib');
const { drawBand, embedImage, BAND_HEIGHT, MARGIN, TEXT_COLOR } = require('./annex_stamp_service');

const CAPTION_FONT_SIZE = 9;
const CELL_GAP = 10;
const CAPTION_HEIGHT = 14;
const COLS = 2;
const ROWS = 2;
const PHOTOS_PER_PAGE = COLS * ROWS;

// Tronque `text` pour qu'il tienne dans `maxWidth` avec `font`/`size`, sans jamais déborder de la cellule.
function truncateToWidth(text, font, size, maxWidth) {
  if (font.widthOfTextAtSize(text, size) <= maxWidth) return text;
  let truncated = text;
  while (truncated.length > 1 && font.widthOfTextAtSize(`${truncated}…`, size) > maxWidth) {
    truncated = truncated.slice(0, -1);
  }
  return `${truncated}…`;
}

// entries: [{ imageBuffer, mimeType, label, annexNumber, annexTypeIndex }]
// Retourne { buffer: Buffer|null, pageStartByEntryIndex: number[], pageCount: number } —
// pages 1-based, relatives à ce PDF seul (plusieurs entrées peuvent partager la même page).
async function buildPhotoGridPdf(entries, issueId) {
  if (!entries || entries.length === 0) return { buffer: null, pageStartByEntryIndex: [], pageCount: 0 };

  const outDoc = await PDFDocument.create();
  const font = await outDoc.embedFont(StandardFonts.Helvetica);
  const [pageWidth, pageHeight] = PageSizes.A4;

  const gridTop = pageHeight - BAND_HEIGHT - MARGIN;
  const gridWidth = pageWidth - MARGIN * 2;
  const gridHeight = gridTop - MARGIN;
  const cellWidth = (gridWidth - CELL_GAP) / COLS;
  const cellHeight = (gridHeight - CELL_GAP) / ROWS;

  const totalPages = Math.ceil(entries.length / PHOTOS_PER_PAGE);
  const pageStartByEntryIndex = [];

  for (let pageIndex = 0; pageIndex < totalPages; pageIndex++) {
    const pageNumber = pageIndex + 1;
    const chunkStart = pageIndex * PHOTOS_PER_PAGE;
    const chunk = entries.slice(chunkStart, chunkStart + PHOTOS_PER_PAGE);
    const page = outDoc.addPage([pageWidth, pageHeight]);

    drawBand(page, font, {
      width: pageWidth,
      bandY: pageHeight - BAND_HEIGHT,
      text: `Annexes photos — Incident n° ${issueId} — Page ${pageNumber}/${totalPages}`,
    });

    for (let cellIndex = 0; cellIndex < chunk.length; cellIndex++) {
      const entry = chunk[cellIndex];
      pageStartByEntryIndex[chunkStart + cellIndex] = pageNumber;

      const col = cellIndex % COLS;
      const row = Math.floor(cellIndex / COLS);
      const cellX = MARGIN + col * (cellWidth + CELL_GAP);
      const cellTop = gridTop - row * (cellHeight + CELL_GAP);
      const cellBottom = cellTop - cellHeight;

      const image = await embedImage(outDoc, entry.imageBuffer, entry.mimeType);

      const imageAreaHeight = cellHeight - CAPTION_HEIGHT;
      const scale = Math.min(cellWidth / image.width, imageAreaHeight / image.height, 1);
      const drawWidth = image.width * scale;
      const drawHeight = image.height * scale;
      const imageX = cellX + (cellWidth - drawWidth) / 2;
      const imageY = cellBottom + CAPTION_HEIGHT + (imageAreaHeight - drawHeight) / 2;

      page.drawImage(image, { x: imageX, y: imageY, width: drawWidth, height: drawHeight });

      const caption = `Annexe ${entry.annexNumber} — Photo ${entry.annexTypeIndex} — ${entry.label}`;
      const truncated = truncateToWidth(caption, font, CAPTION_FONT_SIZE, cellWidth);
      page.drawText(truncated, {
        x: cellX,
        y: cellBottom + (CAPTION_HEIGHT - CAPTION_FONT_SIZE) / 2,
        size: CAPTION_FONT_SIZE,
        font,
        color: TEXT_COLOR,
      });
    }
  }

  return { buffer: Buffer.from(await outDoc.save()), pageStartByEntryIndex, pageCount: totalPages };
}

module.exports = { buildPhotoGridPdf };
