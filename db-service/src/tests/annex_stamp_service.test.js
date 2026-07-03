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

// JPEG 2x2 minimal valide (généré via System.Drawing, baseline), suffisant
// pour embedJpg. Volontairement < 4 Ko : reproduit la taille des buffers
// issus du pool interne de Node (fs.readFileSync sur un petit fichier), qui
// est le scénario couvert par le test 🚫 ci-dessous.
const TINY_JPG = Buffer.from(
  'ffd8ffe000104a46494600010101006000600000ffdb0043000402030303020403030304040404050906050505050b080806090d' +
  '0b0d0d0d0b0c0c0e1014110e0f130f0c0c1218121315161717170e11191b19161a14161716ffdb0043010404040505050a06060a' +
  '160f0c0f161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616' +
  '1616ffc00011080002000203012200021101031101ffc4001f000001050101010101010000000000000000010203040506070809' +
  '0a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c115' +
  '52d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a' +
  '737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9ca' +
  'd2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f01000301010101010101010100000000000001' +
  '02030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108' +
  '144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a53545556575859' +
  '5a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9' +
  'bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffda000c03010002110311003f00fa' +
  '83f676f873f0f752fd9fbc0ba8ea3e04f0cde5e5e785f4e9ee6e6e34782496791ad6366776642598924927924d14515f3b8bff00' +
  '78a9eaff0033e4f1dfef557fc4ff00367fffd9',
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

  test('✅ image JPEG → PDF 1 page avec "Page 1/1"', async () => {
    const out = await imageToStampedPdf(TINY_JPG, 'image/jpeg', {
      annexNumber: 6, issueId: 'ISS-8', typeLabel: 'Photo', typeIndex: 1,
    });

    const loaded = await PDFDocument.load(out);
    expect(loaded.getPageCount()).toBe(1);

    const texts = extractDrawnTexts(out);
    expect(texts).toContain('Annexe 6 — Incident n° ISS-8 — Photo 1 — Page 1/1');
  });

  test('✅ image JPEG dans un buffer avec byteOffset non nul → ne lève pas "SOI not found"', async () => {
    // Simule le buffer que renvoie fs.readFileSync sur un fichier < 4 Ko (vue
    // sur le pool interne de Node, byteOffset non nul) — c'est ce cas précis
    // qui faisait échouer embedJpg avant la copie défensive dans
    // imageToStampedPdf (voir annex_stamp_service.js).
    const padded = Buffer.concat([Buffer.alloc(16), TINY_JPG]);
    const sliced = padded.subarray(16);
    expect(sliced.byteOffset).not.toBe(0);

    const out = await imageToStampedPdf(sliced, 'image/jpeg', {
      annexNumber: 1, issueId: 'ISS-9', typeLabel: 'Photo', typeIndex: 1,
    });

    const loaded = await PDFDocument.load(out);
    expect(loaded.getPageCount()).toBe(1);
  });
});
