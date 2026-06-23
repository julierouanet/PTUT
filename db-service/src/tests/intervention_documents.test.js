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
