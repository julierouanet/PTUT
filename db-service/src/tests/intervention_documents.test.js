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

const request = require('supertest');
const { app, server } = require('../index');
const { getDb, closeDb } = require('../database');

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
