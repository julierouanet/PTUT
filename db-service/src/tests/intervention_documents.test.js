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
const request = require('supertest');
const { PDFDocument } = require('pdf-lib');
const { app, server } = require('../index');
const { getDb, closeDb } = require('../database');
const { UPLOAD_DIR } = require('../config');

let db;

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
  uploadedAt, deletedAt = null,
}) {
  seedEquipmentForDocs(equipmentId);
  const at = uploadedAt || '2026-01-01 08:00:00';
  const result = db.prepare(`
    INSERT INTO equipment_documents
      (equipment_id, document_type, original_name, stored_name, mime_type,
       file_size_kb, uploaded_by, uploader_name, uploaded_at, deleted_at)
    VALUES (?, ?, ?, ?, ?, 5, ?, ?, ?, ?)
  `).run(equipmentId, docType, originalName, storedName, mimeType, uploadedBy, uploaderName, at, deletedAt);
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
