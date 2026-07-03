'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Rôle courant injecté par les tests ────────────────────────────────────────
let mockCurrentRoles = ['admin'];
function setTestRole(...roles) {
  mockCurrentRoles = roles;
}

// ── Mock du middleware d'auth ─────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-admin-0001',
      email:      'admin@kabutare.rw',
      name:       'Admin Test',
      roles:      mockCurrentRoles,
      department: 'OPD',
    };
    next();
  },
  requireRole: (...allowed) => (req, res, next) => {
    const userRoles = Array.isArray(req.user?.roles) ? req.user.roles : [];
    if (!userRoles.some((r) => allowed.includes(r))) {
      return res.status(403).json({ error: `Rôle requis: ${allowed.join(' ou ')}` });
    }
    next();
  },
  SYSTEM_ROLES: new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));

// ── Mock du logger (évite appels HTTP vers auth-service) ─────────────────────
jest.mock('../utils/logger', () => ({
  logAction:      jest.fn(),
  extractReqMeta: jest.fn(() => ({})),
  sendLog:        jest.fn(),
}));

jest.mock('../utils/push_sender', () => ({
  sendPushToRoles: jest.fn().mockResolvedValue(undefined),
}));

global.fetch = jest.fn().mockResolvedValue({
  ok:   true,
  json: () => Promise.resolve({}),
  text: () => Promise.resolve(''),
});

jest.mock('../routes/backups', () => ({
  router:         require('express').Router(),
  initBackupCron: jest.fn(),
}));

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const request = require('supertest');
const { PDFDocument } = require('pdf-lib');
const { app, server } = require('../index');
const { getDb, closeDb } = require('../database');
const { UPLOAD_DIR } = require('../config');

let db;

// ── Extraction du texte dessiné (Tj) depuis les content streams d'un PDF ──────
// Les chaînes sont en WinAnsiEncoding (≈ Latin-1, sauf 0x80-0x9F). On ne code
// en dur que le caractère qui diverge de Latin-1 et qu'on utilise (tiret cadratin).
function decodeWinAnsiHex(hex) {
  const bytes = Buffer.from(hex, 'hex');
  let out = '';
  for (const b of bytes) out += b === 0x97 ? '—' : String.fromCharCode(b);
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
    while ((tm = tjRe.exec(inflated))) texts.push(decodeWinAnsiHex(tm[1]));
  }
  return texts;
}

function seedIssue(id, { status = 'In Progress', equipmentId = null } = {}) {
  if (equipmentId) {
    db.prepare(`
      INSERT OR IGNORE INTO equipment (id, name, department, category, status)
      VALUES (?, ?, 'OPD', 'Monitoring', 'Operational')
    `).run(equipmentId, `Équipement ${equipmentId}`);
  }
  db.prepare(`
    INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, status, created_at)
    VALUES (?, ?, ?, 'OPD', 'Panne', 'desc', 'Testeur', ?, datetime('now','localtime'))
  `).run(id, equipmentId, equipmentId ? `Équipement ${equipmentId}` : null, status);
}

beforeAll(() => {
  db = getDb();
  setTestRole('admin');
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// =============================================================================
// GET /api/issues/:id/documents
// =============================================================================
describe('GET /api/issues/:id/documents', () => {
  test('🚫 incident inexistant → 404', async () => {
    const res = await request(app)
      .get('/api/issues/iss-fantome/documents')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('✅ incident sans document → liste vide', async () => {
    seedIssue('iss-doc-empty');
    const res = await request(app)
      .get('/api/issues/iss-doc-empty/documents')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

// =============================================================================
// POST /api/issues/:id/documents
// =============================================================================
describe('POST /api/issues/:id/documents', () => {
  test('🚫 aucun fichier reçu → 400', async () => {
    seedIssue('iss-doc-nofile');
    const res = await request(app)
      .post('/api/issues/iss-doc-nofile/documents')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });

  test('🚫 type de document invalide → 400', async () => {
    seedIssue('iss-doc-badtype');
    const res = await request(app)
      .post('/api/issues/iss-doc-badtype/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'pasUnType')
      .attach('files', Buffer.from('%PDF-1.4 fake'), { filename: 'rapport.pdf', contentType: 'application/pdf' });
    expect(res.status).toBe(400);
  });

  test('✅ upload réussi (incident sans équipement) → 201, issue_id renseigné, equipment_id NULL', async () => {
    seedIssue('iss-doc-noeq', { equipmentId: null });
    const res = await request(app)
      .post('/api/issues/iss-doc-noeq/documents')
      .set('Authorization', 'Bearer fake-token')
      .attach('files', Buffer.from('%PDF-1.4 fake'), { filename: 'compte-rendu.pdf', contentType: 'application/pdf' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].original_name).toBe('compte-rendu.pdf');

    const row = db.prepare('SELECT * FROM equipment_documents WHERE issue_id = ?').get('iss-doc-noeq');
    expect(row.equipment_id).toBeNull();
    expect(row.document_type).toBe('completion');

    const list = await request(app)
      .get('/api/issues/iss-doc-noeq/documents')
      .set('Authorization', 'Bearer fake-token');
    expect(list.body).toHaveLength(1);
  });
});

// =============================================================================
// GET /api/issues/:id/documents/:doc_id/download
// =============================================================================
describe('GET /api/issues/:id/documents/:doc_id/download', () => {
  test('🚫 document inexistant → 404', async () => {
    seedIssue('iss-doc-dl');
    const res = await request(app)
      .get('/api/issues/iss-doc-dl/documents/99999/download')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });
});

// =============================================================================
// GET /api/equipment/:id/documents — champs issue_id / issue_status / issue_created_at
// =============================================================================
describe('GET /api/equipment/:id/documents — jointure issues', () => {
  const EQ_ID = 'eq-join-test';
  const ISSUE_ID = 'iss-join-test';
  let docWithIssueId;
  let docNoIssueId;

  beforeAll(() => {
    // Seed équipement + incident liés
    db.prepare(`
      INSERT OR IGNORE INTO equipment (id, name, department, category, status)
      VALUES (?, 'Testeur JOIN', 'OPD', 'Monitoring', 'Operational')
    `).run(EQ_ID);
    seedIssue(ISSUE_ID, { status: 'Resolved', equipmentId: EQ_ID });

    // Document d'intervention avec issue_id renseigné
    const r1 = db.prepare(`
      INSERT INTO equipment_documents
        (equipment_id, issue_id, document_type, stored_name, original_name, mime_type, file_size_kb, uploaded_by, uploader_name, uploaded_at)
      VALUES (?, ?, 'intervention', 'stored-j1.pdf', 'rapport.pdf', 'application/pdf', 12, 'u1', 'Tech Test', datetime('now','localtime'))
    `).run(EQ_ID, ISSUE_ID);
    docWithIssueId = r1.lastInsertRowid;

    // Document historique sans issue_id
    const r2 = db.prepare(`
      INSERT INTO equipment_documents
        (equipment_id, issue_id, document_type, stored_name, original_name, mime_type, file_size_kb, uploaded_by, uploader_name, uploaded_at)
      VALUES (?, NULL, 'intervention', 'stored-j2.pdf', 'ancien.pdf', 'application/pdf', 8, 'u1', 'Tech Test', datetime('now','localtime'))
    `).run(EQ_ID);
    docNoIssueId = r2.lastInsertRowid;
  });

  test('✅ document lié à un incident → issue_id, issue_status, issue_created_at non nuls', async () => {
    const res = await request(app)
      .get(`/api/equipment/${EQ_ID}/documents`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const doc = res.body.find((d) => d.id === docWithIssueId);
    expect(doc).toBeDefined();
    expect(doc.issue_id).toBe(ISSUE_ID);
    expect(doc.issue_status).toBe('Resolved');
    expect(doc.issue_created_at).toBeTruthy();
  });

  test('✅ document sans issue_id → issue_id, issue_status, issue_created_at à null (pas de 500)', async () => {
    const res = await request(app)
      .get(`/api/equipment/${EQ_ID}/documents`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const doc = res.body.find((d) => d.id === docNoIssueId);
    expect(doc).toBeDefined();
    expect(doc.issue_id).toBeNull();
    expect(doc.issue_status).toBeNull();
    expect(doc.issue_created_at).toBeNull();
  });
});

// =============================================================================
// Nouveau routeur cross-équipement : /api/documents/interventions
// =============================================================================
function seedEquipmentForDocs(id) {
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES (?, ?, 'OPD', 'Monitoring', 'Operational')
  `).run(id, `Équipement ${id}`);
}

function insertInterventionDoc({
  equipmentId = 'idoc-eq-1', docType = 'intervention', storedName, originalName,
  mimeType = 'application/pdf', uploadedBy = 'tech-a', uploaderName = 'Tech A',
  uploadedAt, deletedAt = null, issueId = null,
}) {
  seedEquipmentForDocs(equipmentId);
  const at = uploadedAt || '2026-01-01 08:00:00';
  const result = db.prepare(`
    INSERT INTO equipment_documents
      (equipment_id, issue_id, document_type, original_name, stored_name, mime_type,
       file_size_kb, uploaded_by, uploader_name, uploaded_at, deleted_at)
    VALUES (?, ?, ?, ?, ?, ?, 5, ?, ?, ?, ?)
  `).run(equipmentId, issueId, docType, originalName, storedName, mimeType, uploadedBy, uploaderName, at, deletedAt);
  return result.lastInsertRowid;
}

function writeRealFile(storedName, content = 'contenu factice') {
  fs.writeFileSync(path.join(UPLOAD_DIR, storedName), content);
}

async function writeRealPdf(storedName) {
  const pdf = await PDFDocument.create();
  pdf.addPage([200, 200]);
  fs.writeFileSync(path.join(UPLOAD_DIR, storedName), await pdf.save());
}

// PDF avec un flux de contenu réel (nécessaire pour stampPdfAnnex, qui embarque
// la page via embedPage — une page sans contenu dessiné lève une exception pdf-lib).
async function makeRealPdfBuffer() {
  const pdf = await PDFDocument.create();
  const page = pdf.addPage([200, 200]);
  page.drawText('contenu réel');
  return Buffer.from(await pdf.save());
}

// PNG 1x1 minimal, suffisant pour imageToStampedPdf (embedPng)
const TINY_PNG = Buffer.from(
  '89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000c4944415478da6360606060000000050001a5f6454000' +
  '00000049454e44ae426082',
  'hex'
);

// Lit un flux de réponse binaire (ZIP/PDF) sans le parser en JSON/texte
function bufferParser(response, cb) {
  const chunks = [];
  response.on('data', (chunk) => chunks.push(chunk));
  response.on('end', () => cb(null, Buffer.concat(chunks)));
}

describe('GET /api/documents/interventions — liste', () => {
  test('✅ ne retourne que les documents intervention non supprimés', async () => {
    const idOk = insertInterventionDoc({ storedName: 'list-ok.pdf', originalName: 'list-ok.pdf' });
    const idTech = insertInterventionDoc({ storedName: 'list-tech.pdf', originalName: 'list-tech.pdf', docType: 'technical' });
    const idDeleted = insertInterventionDoc({ storedName: 'list-del.pdf', originalName: 'list-del.pdf', deletedAt: '2026-01-02 00:00:00' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idOk);
    expect(ids).not.toContain(idTech);
    expect(ids).not.toContain(idDeleted);
  });

  test('✅ filtre uploaded_by isole un seul technicien', async () => {
    const idA = insertInterventionDoc({ storedName: 'filt-a.pdf', originalName: 'filt-a.pdf', uploadedBy: 'tech-filter-a', uploaderName: 'Tech Filter A' });
    const idB = insertInterventionDoc({ storedName: 'filt-b.pdf', originalName: 'filt-b.pdf', uploadedBy: 'tech-filter-b', uploaderName: 'Tech Filter B' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ uploaded_by: 'tech-filter-a' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idA);
    expect(ids).not.toContain(idB);
  });

  test('✅ filtre from/to exclut les documents hors période', async () => {
    const idBefore = insertInterventionDoc({ storedName: 'date-before.pdf', originalName: 'date-before.pdf', uploadedAt: '2026-05-01 08:00:00' });
    const idInRange = insertInterventionDoc({ storedName: 'date-in.pdf', originalName: 'date-in.pdf', uploadedAt: '2026-05-15 08:00:00' });
    const idAfter = insertInterventionDoc({ storedName: 'date-after.pdf', originalName: 'date-after.pdf', uploadedAt: '2026-06-01 08:00:00' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ from: '2026-05-10', to: '2026-05-20' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idInRange);
    expect(ids).not.toContain(idBefore);
    expect(ids).not.toContain(idAfter);
  });

  test('🚫 400 si from mal formaté', async () => {
    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ from: '01-07-2026' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });

  test('🚫 400 si from > to', async () => {
    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ from: '2026-06-10', to: '2026-06-01' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });
});

describe('GET /api/documents/interventions — filtre types', () => {
  test('✅ pas de types → retourne intervention ET completion, exclut technical', async () => {
    const idIntervention = insertInterventionDoc({ storedName: 'types-default-int.pdf', originalName: 'types-default-int.pdf', docType: 'intervention' });
    const idCompletion = insertInterventionDoc({ storedName: 'types-default-comp.pdf', originalName: 'types-default-comp.pdf', docType: 'completion' });
    const idTech = insertInterventionDoc({ storedName: 'types-default-tech.pdf', originalName: 'types-default-tech.pdf', docType: 'technical' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idIntervention);
    expect(ids).toContain(idCompletion);
    expect(ids).not.toContain(idTech);
  });

  test('✅ types=intervention → ne retourne que les documents intervention', async () => {
    const idIntervention = insertInterventionDoc({ storedName: 'types-int-only.pdf', originalName: 'types-int-only.pdf', docType: 'intervention' });
    const idCompletion = insertInterventionDoc({ storedName: 'types-int-only-comp.pdf', originalName: 'types-int-only-comp.pdf', docType: 'completion' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: 'intervention' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idIntervention);
    expect(ids).not.toContain(idCompletion);
  });

  test('✅ types=completion → ne retourne que les documents completion', async () => {
    const idIntervention = insertInterventionDoc({ storedName: 'types-comp-only-int.pdf', originalName: 'types-comp-only-int.pdf', docType: 'intervention' });
    const idCompletion = insertInterventionDoc({ storedName: 'types-comp-only.pdf', originalName: 'types-comp-only.pdf', docType: 'completion' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: 'completion' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idCompletion);
    expect(ids).not.toContain(idIntervention);
  });

  test('✅ types=intervention,completion explicite → identique au cas par défaut', async () => {
    const idIntervention = insertInterventionDoc({ storedName: 'types-explicit-int.pdf', originalName: 'types-explicit-int.pdf', docType: 'intervention' });
    const idCompletion = insertInterventionDoc({ storedName: 'types-explicit-comp.pdf', originalName: 'types-explicit-comp.pdf', docType: 'completion' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: 'intervention,completion' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idIntervention);
    expect(ids).toContain(idCompletion);
  });

  test('🚫 types=Intervention (casse différente) → 400', async () => {
    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: 'Intervention' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });

  test('🚫 types=bogus → 400', async () => {
    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: 'bogus' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });

  test('✅ types= (chaîne vide) → 200, items vide, total 0', async () => {
    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: '' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.items).toEqual([]);
    expect(res.body.total).toBe(0);
  });

  test('✅ types[]=intervention&types[]=completion (forme tableau) → pas de crash serveur', async () => {
    const idIntervention = insertInterventionDoc({ storedName: 'types-arr-int.pdf', originalName: 'types-arr-int.pdf', docType: 'intervention' });
    const idCompletion = insertInterventionDoc({ storedName: 'types-arr-comp.pdf', originalName: 'types-arr-comp.pdf', docType: 'completion' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query('types[]=intervention&types[]=completion')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idIntervention);
    expect(ids).toContain(idCompletion);
  });
});

describe('GET /api/documents/interventions/technicians', () => {
  test('✅ retourne les paires uploaded_by/uploader_name distinctes, hors documents non-intervention', async () => {
    insertInterventionDoc({ storedName: 'tech-list-1.pdf', originalName: 'tech-list-1.pdf', uploadedBy: 'tech-list-x', uploaderName: 'Tech List X' });
    insertInterventionDoc({ storedName: 'tech-list-2.pdf', originalName: 'tech-list-2.pdf', uploadedBy: 'tech-list-x', uploaderName: 'Tech List X' });
    // Technicien qui n'a qu'un document 'technical' (jamais d'intervention) : ne doit pas apparaître
    insertInterventionDoc({ storedName: 'tech-list-onlytech.pdf', originalName: 'tech-list-onlytech.pdf', docType: 'technical', uploadedBy: 'tech-list-onlytech', uploaderName: 'Tech Only Technical' });

    const res = await request(app)
      .get('/api/documents/interventions/technicians')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const uploadedByList = res.body.map((t) => t.uploaded_by);
    expect(uploadedByList).toContain('tech-list-x');
    expect(uploadedByList).not.toContain('tech-list-onlytech');
    // DISTINCT : un seul enregistrement malgré 2 documents du même technicien
    expect(uploadedByList.filter((u) => u === 'tech-list-x')).toHaveLength(1);
  });

  test('✅ types=completion → exclut un technicien qui n\'a que des documents intervention', async () => {
    insertInterventionDoc({ storedName: 'tech-comp-only.pdf', originalName: 'tech-comp-only.pdf', docType: 'completion', uploadedBy: 'tech-comp-only', uploaderName: 'Tech Comp Only' });
    insertInterventionDoc({ storedName: 'tech-int-only.pdf', originalName: 'tech-int-only.pdf', docType: 'intervention', uploadedBy: 'tech-int-only', uploaderName: 'Tech Int Only' });

    const res = await request(app)
      .get('/api/documents/interventions/technicians')
      .query({ types: 'completion' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const uploadedByList = res.body.map((t) => t.uploaded_by);
    expect(uploadedByList).toContain('tech-comp-only');
    expect(uploadedByList).not.toContain('tech-int-only');
  });

  test('🚫 types=bogus → 400', async () => {
    const res = await request(app)
      .get('/api/documents/interventions/technicians')
      .query({ types: 'bogus' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });

  test('✅ sans from/to valides → ne plante jamais (route découplée de parseFilters)', async () => {
    const res = await request(app)
      .get('/api/documents/interventions/technicians')
      .query({ from: 'pas-une-date' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(200);
  });
});

describe('GET /api/documents/interventions/zip', () => {
  test('✅ retourne un ZIP (Content-Type application/zip)', async () => {
    const storedName = 'zip-ok.pdf';
    insertInterventionDoc({ storedName, originalName: 'zip-ok.pdf', uploadedBy: 'tech-zip-ok', uploaderName: 'Tech Zip Ok' });
    writeRealFile(storedName);

    const res = await request(app)
      .get('/api/documents/interventions/zip')
      .query({ uploaded_by: 'tech-zip-ok' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('application/zip');
  });

  test('🚫 404 si aucun document ne matche', async () => {
    const res = await request(app)
      .get('/api/documents/interventions/zip')
      .query({ uploaded_by: 'tech-zip-inexistant' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('🚫 types=intervention n\'inclut pas les documents completion', async () => {
    const storedComp = 'zip-comp-excl.pdf';
    writeRealFile(storedComp);
    insertInterventionDoc({ storedName: storedComp, originalName: 'zip-comp-excl.pdf', docType: 'completion', uploadedBy: 'tech-zip-comp-excl', uploaderName: 'Tech Zip Comp Excl' });

    const res = await request(app)
      .get('/api/documents/interventions/zip')
      .query({ uploaded_by: 'tech-zip-comp-excl', types: 'intervention' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('🚫 types= (chaîne vide) → 404', async () => {
    const res = await request(app)
      .get('/api/documents/interventions/zip')
      .query({ types: '' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('✅ types=photo → le ZIP contient les fichiers de issue_photos', async () => {
    seedIssue('iss-zip-photo');
    const photoStored = 'zip-photo.jpg';
    writeRealFile(photoStored);
    db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at)
      VALUES ('iss-zip-photo', ?, 'zip-photo.jpg', 'image/jpeg', 4, datetime('now','localtime'))
    `).run(photoStored);

    const res = await request(app)
      .get('/api/documents/interventions/zip')
      .query({ issue_id: 'iss-zip-photo', types: 'photo' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('application/zip');
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('🚫 types=photo + uploaded_by renseigné → exclut les photos (404 si rien d\'autre)', async () => {
    seedIssue('iss-zip-photo-excl');
    const photoStored = 'zip-photo-excl.jpg';
    writeRealFile(photoStored);
    db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at)
      VALUES ('iss-zip-photo-excl', ?, 'zip-photo-excl.jpg', 'image/jpeg', 4, datetime('now','localtime'))
    `).run(photoStored);

    const res = await request(app)
      .get('/api/documents/interventions/zip')
      .query({ issue_id: 'iss-zip-photo-excl', types: 'photo', uploaded_by: 'tech-zip-photo-excl' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });
});

describe('GET /api/documents/interventions/print-pdf', () => {
  test('✅ fusionne uniquement les PDF et exclut les images', async () => {
    const pdfStored = 'print-ok.pdf';
    const imgStored = 'print-img.jpg';
    await writeRealPdf(pdfStored);
    writeRealFile(imgStored);

    insertInterventionDoc({ storedName: pdfStored, originalName: 'print-ok.pdf', mimeType: 'application/pdf', uploadedBy: 'tech-print-ok', uploaderName: 'Tech Print Ok' });
    insertInterventionDoc({ storedName: imgStored, originalName: 'print-img.jpg', mimeType: 'image/jpeg', uploadedBy: 'tech-print-ok', uploaderName: 'Tech Print Ok' });

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ uploaded_by: 'tech-print-ok' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('application/pdf');
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('🚫 404 si aucun PDF ne matche (uniquement des photos)', async () => {
    const imgStored = 'print-onlyimg.jpg';
    writeRealFile(imgStored);
    insertInterventionDoc({ storedName: imgStored, originalName: 'print-onlyimg.jpg', mimeType: 'image/jpeg', uploadedBy: 'tech-print-nopdf', uploaderName: 'Tech Print No Pdf' });

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ uploaded_by: 'tech-print-nopdf' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(404);
  });

  test('🚫 types=intervention n\'inclut pas les PDF completion', async () => {
    const pdfStored = 'print-comp-excl.pdf';
    await writeRealPdf(pdfStored);
    insertInterventionDoc({ storedName: pdfStored, originalName: 'print-comp-excl.pdf', mimeType: 'application/pdf', docType: 'completion', uploadedBy: 'tech-print-comp-excl', uploaderName: 'Tech Print Comp Excl' });

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ uploaded_by: 'tech-print-comp-excl', types: 'intervention' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('🚫 types= (chaîne vide) → 404', async () => {
    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ types: '' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('✅ filtre par issue_id : ne fusionne que les PDF de l\'incident ciblé', async () => {
    seedIssue('iss-print-x', { equipmentId: 'idoc-eq-print-x' });
    seedIssue('iss-print-y', { equipmentId: 'idoc-eq-print-y' });

    const storedX1 = 'print-issue-x1.pdf';
    const storedX2 = 'print-issue-x2.pdf';
    const storedY = 'print-issue-y.pdf';
    await writeRealPdf(storedX1);
    await writeRealPdf(storedX2);
    await writeRealPdf(storedY);

    insertInterventionDoc({ equipmentId: 'idoc-eq-print-x', issueId: 'iss-print-x', storedName: storedX1, originalName: storedX1, uploadedBy: 'tech-print-issue', uploaderName: 'Tech Print Issue' });
    insertInterventionDoc({ equipmentId: 'idoc-eq-print-x', issueId: 'iss-print-x', storedName: storedX2, originalName: storedX2, uploadedBy: 'tech-print-issue', uploaderName: 'Tech Print Issue' });
    insertInterventionDoc({ equipmentId: 'idoc-eq-print-y', issueId: 'iss-print-y', storedName: storedY, originalName: storedY, uploadedBy: 'tech-print-issue', uploaderName: 'Tech Print Issue' });

    const resX = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ uploaded_by: 'tech-print-issue', issue_id: 'iss-print-x' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);
    const resY = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ uploaded_by: 'tech-print-issue', issue_id: 'iss-print-y' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(resX.status).toBe(200);
    expect(resY.status).toBe(200);
    // iss-print-x : 1 sommaire (2 entrées) + 2 pages intervention = 3.
    // iss-print-y : 1 sommaire (1 entrée) + 1 page intervention = 2.
    const pageCountX = (await PDFDocument.load(resX.body)).getPageCount();
    const pageCountY = (await PDFDocument.load(resY.body)).getPageCount();
    expect(pageCountX).toBe(3);
    expect(pageCountY).toBe(2);
  });

  test('🚫 404 si l\'issue n\'a aucun PDF (uniquement une image)', async () => {
    seedIssue('iss-print-noimg', { equipmentId: 'idoc-eq-print-noimg' });
    const imgStored = 'print-issue-noimg.jpg';
    writeRealFile(imgStored);
    insertInterventionDoc({ equipmentId: 'idoc-eq-print-noimg', issueId: 'iss-print-noimg', storedName: imgStored, originalName: imgStored, mimeType: 'image/jpeg', uploadedBy: 'tech-print-noimg', uploaderName: 'Tech Print Noimg' });

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ uploaded_by: 'tech-print-noimg', issue_id: 'iss-print-noimg' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(404);
  });

  test('✅ rapport final + intervention + annexes numérotées → réordonné avec sommaire', async () => {
    const issueId = 'iss-print-full';
    const eqId = 'idoc-eq-print-full';
    seedIssue(issueId, { equipmentId: eqId });

    const finalReportStored = 'print-full-final.pdf';
    const int1Stored = 'print-full-int1.pdf';
    const int2Stored = 'print-full-int2.pdf';
    const annexDocStored = 'print-full-annexdoc.pdf';
    const annexPhotoStored = 'print-full-annexphoto.png';
    await writeRealPdf(finalReportStored);
    await writeRealPdf(int1Stored);
    await writeRealPdf(int2Stored);
    await writeRealPdf(annexDocStored);
    // Image originale (pas un PDF pré-tamponné) : la grille photo la charge directement.
    writeRealFile(annexPhotoStored, TINY_PNG);

    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: finalReportStored, originalName: 'final.pdf', docType: 'final_report', uploadedBy: 'tech-full', uploaderName: 'Tech Full' });
    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: int1Stored, originalName: 'int1.pdf', docType: 'intervention', uploadedBy: 'tech-full', uploaderName: 'Tech Full', uploadedAt: '2026-01-01 08:00:00' });
    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: int2Stored, originalName: 'int2.pdf', docType: 'intervention', uploadedBy: 'tech-full', uploaderName: 'Tech Full', uploadedAt: '2026-01-01 09:00:00' });

    const annexDocId = insertInterventionDoc({ equipmentId: eqId, issueId, storedName: annexDocStored, originalName: 'annexdoc.pdf', docType: 'completion', uploadedBy: 'tech-full', uploaderName: 'Tech Full' });
    db.prepare('UPDATE equipment_documents SET annex_number = 1, annex_type_index = 1 WHERE id = ?').run(annexDocId);

    db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at, annex_number, annex_type_index, annex_pdf_stored_name)
      VALUES (?, ?, 'photo.png', 'image/png', 5, datetime('now','localtime'), 2, 1, 'legacy-unused.pdf')
    `).run(issueId, annexPhotoStored);

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: 'intervention,completion,photo' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    // 1 rapport final + 1 sommaire (4 entrées : 2 intervention + 2 annexes) +
    // 2 pages intervention + 1 page annexe document + 1 page grille photo (1 photo) = 6 pages.
    const merged = await PDFDocument.load(res.body);
    expect(merged.getPageCount()).toBe(6);
  });

  test('✅ types=intervention (sur le même incident) → uniquement rapport final + intervention, pas d\'annexes', async () => {
    const issueId = 'iss-print-filtered';
    const eqId = 'idoc-eq-print-filtered';
    seedIssue(issueId, { equipmentId: eqId });

    const finalReportStored = 'print-filtered-final.pdf';
    const intStored = 'print-filtered-int.pdf';
    const annexDocStored = 'print-filtered-annexdoc.pdf';
    await writeRealPdf(finalReportStored);
    await writeRealPdf(intStored);
    await writeRealPdf(annexDocStored);

    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: finalReportStored, originalName: 'final.pdf', docType: 'final_report', uploadedBy: 'tech-filtered', uploaderName: 'Tech Filtered' });
    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: intStored, originalName: 'int.pdf', docType: 'intervention', uploadedBy: 'tech-filtered', uploaderName: 'Tech Filtered' });
    const annexDocId = insertInterventionDoc({ equipmentId: eqId, issueId, storedName: annexDocStored, originalName: 'annexdoc.pdf', docType: 'completion', uploadedBy: 'tech-filtered', uploaderName: 'Tech Filtered' });
    db.prepare('UPDATE equipment_documents SET annex_number = 1, annex_type_index = 1 WHERE id = ?').run(annexDocId);

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: 'intervention' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    // 1 rapport final + 1 sommaire (1 entrée : intervention seule) + 1 page intervention = 3.
    // La pièce jointe (annexe 1) est exclue car 'completion' n'est pas dans types.
    const merged = await PDFDocument.load(res.body);
    expect(merged.getPageCount()).toBe(3);
  });

  test('✅ types= (tout décoché) sur incident n\'ayant qu\'un rapport final → 200, PDF d\'une seule page', async () => {
    const issueId = 'iss-print-onlyfinal';
    const eqId = 'idoc-eq-print-onlyfinal';
    seedIssue(issueId, { equipmentId: eqId });
    const finalStored = 'print-onlyfinal.pdf';
    await writeRealPdf(finalStored);
    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: finalStored, originalName: 'final.pdf', docType: 'final_report', uploadedBy: 'tech-onlyfinal', uploaderName: 'Tech Onlyfinal' });

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: '' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    const merged = await PDFDocument.load(res.body);
    expect(merged.getPageCount()).toBe(1);
  });

  test('🚫 types= (tout décoché) sur incident sans aucun document → 404', async () => {
    const issueId = 'iss-print-nodocs';
    seedIssue(issueId);

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: '' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(404);
  });
});

describe('GET /api/documents/interventions/print-pdf — grille photos annexées', () => {
  function seedNumberedPhoto(issueId, storedName, annexNumber, annexTypeIndex) {
    writeRealFile(storedName, TINY_PNG);
    db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at, annex_number, annex_type_index)
      VALUES (?, ?, ?, 'image/png', 1, datetime('now','localtime'), ?, ?)
    `).run(issueId, storedName, storedName, annexNumber, annexTypeIndex);
  }

  test('✅ 5 photos annexées → grille sur 2 pages (4 puis 1)', async () => {
    const issueId = 'iss-print-grid5';
    seedIssue(issueId);
    for (let i = 1; i <= 5; i++) {
      seedNumberedPhoto(issueId, `grid5-photo-${i}.png`, i, i);
    }

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: 'photo' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    const merged = await PDFDocument.load(res.body);
    // 1 sommaire (5 entrées → 1 page) + 2 pages de grille (4 puis 1 photo) = 3.
    expect(merged.getPageCount()).toBe(3);
  });

  test('✅ 1 seule photo → grille sur 1 page (pas de crash sur page incomplète)', async () => {
    const issueId = 'iss-print-grid1';
    seedIssue(issueId);
    seedNumberedPhoto(issueId, 'grid1-photo.png', 1, 1);

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: 'photo' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    const merged = await PDFDocument.load(res.body);
    expect(merged.getPageCount()).toBe(2); // sommaire (1) + grille (1)
  });

  test('✅ 0 photo, uniquement documents completion → comportement inchangé (pas de régression)', async () => {
    const issueId = 'iss-print-grid0';
    const eqId = 'idoc-eq-print-grid0';
    seedIssue(issueId, { equipmentId: eqId });
    const annexDocStored = 'grid0-annexdoc.pdf';
    await writeRealPdf(annexDocStored);
    const annexDocId = insertInterventionDoc({ equipmentId: eqId, issueId, storedName: annexDocStored, originalName: 'annexdoc.pdf', docType: 'completion', uploadedBy: 'tech-grid0', uploaderName: 'Tech Grid0' });
    db.prepare('UPDATE equipment_documents SET annex_number = 1, annex_type_index = 1 WHERE id = ?').run(annexDocId);

    const res = await request(app)
      .get('/api/documents/interventions/print-pdf')
      .query({ issue_id: issueId, types: 'completion' })
      .set('Authorization', 'Bearer fake-token')
      .buffer(true)
      .parse(bufferParser);

    expect(res.status).toBe(200);
    const merged = await PDFDocument.load(res.body);
    // 1 sommaire (1 entrée) + 1 page annexe document = 2 pages, aucune page de grille.
    expect(merged.getPageCount()).toBe(2);
  });

  test('🚫 erreur de fusion → 500 avec message détaillé + log console.error', async () => {
    const issueId = 'iss-print-grid-err';
    const eqId = 'idoc-eq-print-grid-err';
    seedIssue(issueId, { equipmentId: eqId });
    // Document PDF corrompu : PDFDocument.load échoue dans loadPdfGroup.
    const corruptStored = 'grid-err-final.pdf';
    writeRealFile(corruptStored, 'pas un pdf du tout');
    insertInterventionDoc({ equipmentId: eqId, issueId, storedName: corruptStored, originalName: 'final.pdf', docType: 'final_report', uploadedBy: 'tech-grid-err', uploaderName: 'Tech Grid Err' });

    const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const res = await request(app)
        .get('/api/documents/interventions/print-pdf')
        .query({ issue_id: issueId })
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(500);
      expect(res.body.error).toContain('Erreur lors de la fusion des PDF :');
      expect(res.body.error.length).toBeGreaterThan('Erreur lors de la fusion des PDF :'.length);
      expect(consoleErrorSpy).toHaveBeenCalledWith('[DB] Échec fusion PDF intervention:', expect.any(Error));
    } finally {
      consoleErrorSpy.mockRestore();
    }
  });
});

// =============================================================================
// GET /api/documents/interventions — inclusion des photos (UNION ALL)
// Placé en fin de fichier : ces tests insèrent avec uploaded_at "maintenant",
// ce qui fausserait la pagination par défaut (LIMIT 20, tri uploaded_at DESC)
// des tests de filtre par date exécutés plus haut.
// =============================================================================
describe('GET /api/documents/interventions — inclusion des photos', () => {
  test('✅ types=photo → inclut les photos d\'incident (kind=photo, document_type=photo)', async () => {
    seedIssue('iss-list-photo');
    const photoId = db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at, annex_number, annex_type_index)
      VALUES ('iss-list-photo', 'list-photo.jpg', 'list-photo.jpg', 'image/jpeg', 4, datetime('now','localtime'), 1, 1)
    `).run().lastInsertRowid;

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ issue_id: 'iss-list-photo', types: 'photo' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const item = res.body.items.find((d) => d.id === photoId && d.kind === 'photo');
    expect(item).toBeDefined();
    expect(item.document_type).toBe('photo');
    expect(item.annex_number).toBe(1);
  });

  test('🚫 sans types=photo (défaut intervention+completion) → les photos ne sont pas incluses', async () => {
    seedIssue('iss-list-photo-default');
    db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at)
      VALUES ('iss-list-photo-default', 'list-photo-default.jpg', 'list-photo-default.jpg', 'image/jpeg', 4, datetime('now','localtime'))
    `).run();

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ issue_id: 'iss-list-photo-default' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(0);
  });

  test('✅ filtre uploaded_by exclut les photos (non attribuées à un uploader)', async () => {
    seedIssue('iss-list-photo-excl');
    db.prepare(`
      INSERT INTO issue_photos (issue_id, stored_name, original_name, mime_type, file_size_kb, uploaded_at)
      VALUES ('iss-list-photo-excl', 'list-photo-excl.jpg', 'list-photo-excl.jpg', 'image/jpeg', 4, datetime('now','localtime'))
    `).run();

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ uploaded_by: 'tech-filter-a', issue_id: 'iss-list-photo-excl', types: 'photo' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(0);
  });
});

// =============================================================================
// Rapport final toujours inclus (FEAT — cases à cocher export documents)
// =============================================================================
describe('GET /api/documents/interventions — rapport final toujours inclus', () => {
  test('✅ types= (aucune case cochée) → retourne uniquement les documents final_report', async () => {
    const idFinal = insertInterventionDoc({ storedName: 'final-always.pdf', originalName: 'final-always.pdf', docType: 'final_report' });
    const idIntervention = insertInterventionDoc({ storedName: 'final-always-int.pdf', originalName: 'final-always-int.pdf', docType: 'intervention' });

    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: '' })
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((d) => d.id);
    expect(ids).toContain(idFinal);
    expect(ids).not.toContain(idIntervention);
  });

  test('🚫 types=final_report (envoyé explicitement par le client) → 400', async () => {
    const res = await request(app)
      .get('/api/documents/interventions')
      .query({ types: 'final_report' })
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(400);
  });
});

// =============================================================================
// Tamponnage + numérotation d'annexe — POST /:id/documents (completion) et /:id/photos
// Placé en fin de fichier : ces tests insèrent des documents avec uploaded_at
// "maintenant" (route réelle), ce qui fausserait la pagination par défaut
// (LIMIT 20, tri uploaded_at DESC) des tests de filtre exécutés plus haut.
// =============================================================================
describe('Tamponnage et numérotation d\'annexe', () => {
  test('✅ pièce jointe PDF "completion" → annex_number=1, annex_type_index=1, fichier tamponné', async () => {
    seedIssue('iss-annex-doc');
    const pdfBuffer = await makeRealPdfBuffer();

    const res = await request(app)
      .post('/api/issues/iss-annex-doc/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'completion')
      .attach('files', pdfBuffer, { filename: 'piece-jointe.pdf', contentType: 'application/pdf' });

    expect(res.status).toBe(201);
    expect(res.body[0].annex_number).toBe(1);
    expect(res.body[0].annex_type_index).toBe(1);

    const row = db.prepare('SELECT * FROM equipment_documents WHERE issue_id = ?').get('iss-annex-doc');
    expect(row.annex_number).toBe(1);
    expect(row.annex_type_index).toBe(1);

    const stampedBytes = fs.readFileSync(path.join(UPLOAD_DIR, row.stored_name));
    expect(extractDrawnTexts(stampedBytes)).toContain(
      'Annexe 1 — Incident n° iss-annex-doc — Pièce jointe 1 — Page 1/1'
    );
    const loaded = await PDFDocument.load(stampedBytes);
    expect(loaded.getPageCount()).toBe(1);
  });

  test('✅ deux pièces jointes successives sur le même incident → annex_number 1 puis 2', async () => {
    seedIssue('iss-annex-doc-seq');
    const pdf1 = await makeRealPdfBuffer();
    const pdf2 = await makeRealPdfBuffer();

    const res1 = await request(app)
      .post('/api/issues/iss-annex-doc-seq/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'completion')
      .attach('files', pdf1, { filename: 'pj1.pdf', contentType: 'application/pdf' });
    const res2 = await request(app)
      .post('/api/issues/iss-annex-doc-seq/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'completion')
      .attach('files', pdf2, { filename: 'pj2.pdf', contentType: 'application/pdf' });

    expect(res1.body[0].annex_number).toBe(1);
    expect(res2.body[0].annex_number).toBe(2);
  });

  test('✅ document "intervention" (pas completion) → jamais numéroté', async () => {
    seedIssue('iss-annex-nonumber');
    const pdfBuffer = await makeRealPdfBuffer();

    const res = await request(app)
      .post('/api/issues/iss-annex-nonumber/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'intervention')
      .attach('files', pdfBuffer, { filename: 'compte-rendu.pdf', contentType: 'application/pdf' });

    expect(res.status).toBe(201);
    expect(res.body[0].annex_number).toBeNull();
  });

  test('🚫 PDF corrompu → upload conserve le document mais sans annexe (garde-fou non bloquant)', async () => {
    seedIssue('iss-annex-corrupt');
    const res = await request(app)
      .post('/api/issues/iss-annex-corrupt/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'completion')
      .attach('files', Buffer.from('pas un pdf du tout'), { filename: 'corrompu.pdf', contentType: 'application/pdf' });

    expect(res.status).toBe(201);
    expect(res.body[0].annex_number).toBeNull();

    const row = db.prepare('SELECT * FROM equipment_documents WHERE issue_id = ?').get('iss-annex-corrupt');
    expect(row.annex_number).toBeNull();
    expect(row.document_type).toBe('completion');
  });

  test('✅ photo → annex_number réservé, copie PDF tamponnée générée sans modifier l\'original', async () => {
    seedIssue('iss-annex-photo');

    const res = await request(app)
      .post('/api/issues/iss-annex-photo/photos')
      .set('Authorization', 'Bearer fake-token')
      .attach('photos', TINY_PNG, { filename: 'photo1.png', contentType: 'image/png' });

    expect(res.status).toBe(201);
    expect(res.body.photos[0].annex_number).toBe(1);
    expect(res.body.photos[0].annex_type_index).toBe(1);

    const row = db.prepare('SELECT * FROM issue_photos WHERE issue_id = ?').get('iss-annex-photo');
    expect(row.annex_pdf_stored_name).toBeTruthy();

    // L'image originale n'est jamais modifiée
    const originalBytes = fs.readFileSync(path.join(UPLOAD_DIR, row.stored_name));
    expect(originalBytes.equals(TINY_PNG)).toBe(true);

    const stampedPdf = fs.readFileSync(path.join(UPLOAD_DIR, row.annex_pdf_stored_name));
    const loaded = await PDFDocument.load(stampedPdf);
    expect(loaded.getPageCount()).toBe(1);
    expect(extractDrawnTexts(stampedPdf)).toContain(
      'Annexe 1 — Incident n° iss-annex-photo — Photo 1 — Page 1/1'
    );
  });

  test('✅ compteur d\'annexe partagé entre pièce jointe et photo sur le même incident', async () => {
    seedIssue('iss-annex-shared');
    const pdfBuffer = await makeRealPdfBuffer();

    const docRes = await request(app)
      .post('/api/issues/iss-annex-shared/documents')
      .set('Authorization', 'Bearer fake-token')
      .field('type', 'completion')
      .attach('files', pdfBuffer, { filename: 'pj.pdf', contentType: 'application/pdf' });
    expect(docRes.body[0].annex_number).toBe(1);
    expect(docRes.body[0].annex_type_index).toBe(1);

    const photoRes = await request(app)
      .post('/api/issues/iss-annex-shared/photos')
      .set('Authorization', 'Bearer fake-token')
      .attach('photos', TINY_PNG, { filename: 'photo1.png', contentType: 'image/png' });
    expect(photoRes.body.photos[0].annex_number).toBe(2);
    expect(photoRes.body.photos[0].annex_type_index).toBe(1); // 1ère photo — sous-compteur indépendant
  });
});

describe('RBAC — rôle non autorisé sur les 4 endpoints', () => {
  test('🚫 hospitalStaff → 403 sur liste/technicians/zip/print-pdf', async () => {
    setTestRole('hospitalStaff');
    try {
      const list = await request(app).get('/api/documents/interventions').set('Authorization', 'Bearer fake-token');
      expect(list.status).toBe(403);

      const techs = await request(app).get('/api/documents/interventions/technicians').set('Authorization', 'Bearer fake-token');
      expect(techs.status).toBe(403);

      const zip = await request(app).get('/api/documents/interventions/zip').set('Authorization', 'Bearer fake-token');
      expect(zip.status).toBe(403);

      const pdf = await request(app).get('/api/documents/interventions/print-pdf').set('Authorization', 'Bearer fake-token');
      expect(pdf.status).toBe(403);
    } finally {
      setTestRole('admin');
    }
  });
});
