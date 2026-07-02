'use strict';

const zlib = require('zlib');
const { PDFDocument } = require('pdf-lib');
const { stampPdfAnnex, imageToStampedPdf } = require('../services/annex_stamp_service');

// PNG 1x1 minimal (pixel transparent), suffisant pour embedPng
const TINY_PNG = Buffer.from(
  '89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000c4944415478da6360606060000000050001a5f6454000' +
  '00000049454e44ae426082',
  'hex'
);

// ── Extraction du texte dessiné (Tj) depuis les content streams d'un PDF ──────
// Les chaînes sont en WinAnsiEncoding (≈ Latin-1, sauf 0x80-0x9F). On ne code
// en dur que le caractère qui diverge de Latin-1 et qu'on utilise (tiret cadratin).
function decodeWinAnsiHex(hex) {
  const bytes = Buffer.from(hex, 'hex');
  let out = '';
  for (const b of bytes) {
    out += b === 0x97 ? '—' : String.fromCharCode(b);
  }
  return out;
}

function extractDrawnTexts(pdfBytes) {
  const raw = Buffer.from(pdfBytes).toString('latin1');
  const streamRe = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
  const texts = [];
  let m;
  while ((m = streamRe.exec(raw))) {
    let inflated;
    try {
      inflated = zlib.inflateSync(Buffer.from(m[1], 'latin1')).toString('latin1');
    } catch (_) {
      continue; // pas un flux FlateDecode (ex. image binaire)
    }
    const tjRe = /<([0-9A-Fa-f]+)>\s*Tj/g;
    let tm;
    while ((tm = tjRe.exec(inflated))) {
      texts.push(decodeWinAnsiHex(tm[1]));
    }
  }
  return texts;
}

async function makeSourcePdf(pageCount) {
  const doc = await PDFDocument.create();
  for (let i = 0; i < pageCount; i++) {
    const page = doc.addPage([200, 300]);
    page.drawText(`contenu page ${i + 1}`);
  }
  return Buffer.from(await doc.save());
}

// Un PDF minimal avec /Count 0 — impossible à obtenir via PDFDocument.create()
// + save(), qui insère toujours une page par défaut à la sauvegarde.
function makeZeroPagePdf() {
  const text = [
    '%PDF-1.4',
    '1 0 obj',
    '<< /Type /Catalog /Pages 2 0 R >>',
    'endobj',
    '2 0 obj',
    '<< /Type /Pages /Kids [] /Count 0 >>',
    'endobj',
    'trailer',
    '<< /Size 3 /Root 1 0 R >>',
    '%%EOF',
  ].join('\n');
  return Buffer.from(text, 'latin1');
}

describe('stampPdfAnnex', () => {
  test('✅ PDF source de 2 pages → sortie de 2 pages, texte exact sur chaque page', async () => {
    const src = await makeSourcePdf(2);
    const out = await stampPdfAnnex(src, {
      annexNumber: 3, issueId: 'ISS-042', typeLabel: 'Pièce jointe', typeIndex: 2,
    });

    const loaded = await PDFDocument.load(out);
    expect(loaded.getPageCount()).toBe(2);

    const texts = extractDrawnTexts(out);
    expect(texts).toContain('Annexe 3 — Incident n° ISS-042 — Pièce jointe 2 — Page 1/2');
    expect(texts).toContain('Annexe 3 — Incident n° ISS-042 — Pièce jointe 2 — Page 2/2');
  });

  test('🚫 PDF 0 page → lève une exception', async () => {
    await expect(stampPdfAnnex(makeZeroPagePdf(), {
      annexNumber: 1, issueId: 'ISS-1', typeLabel: 'Pièce jointe', typeIndex: 1,
    })).rejects.toThrow('PDF source vide (0 page)');
  });

  test('🚫 buffer corrompu → lève une exception (pas de crash process)', async () => {
    await expect(stampPdfAnnex(Buffer.from('pas un pdf'), {
      annexNumber: 1, issueId: 'ISS-1', typeLabel: 'Pièce jointe', typeIndex: 1,
    })).rejects.toThrow();
  });
});

describe('imageToStampedPdf', () => {
  test('✅ image PNG → PDF 1 page avec "Page 1/1"', async () => {
    const out = await imageToStampedPdf(TINY_PNG, 'image/png', {
      annexNumber: 5, issueId: 'ISS-7', typeLabel: 'Photo', typeIndex: 1,
    });

    const loaded = await PDFDocument.load(out);
    expect(loaded.getPageCount()).toBe(1);

    const texts = extractDrawnTexts(out);
    expect(texts).toContain('Annexe 5 — Incident n° ISS-7 — Photo 1 — Page 1/1');
  });
});
