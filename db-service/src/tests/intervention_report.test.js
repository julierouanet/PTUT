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

// Crée un incident lié à un équipement, dans un statut donné.
function seedIssue(id, { status = 'In Progress', equipmentId = 'eq-rep' } = {}) {
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES (?, ?, 'OPD', 'Monitoring', 'Operational')
  `).run(equipmentId, `Équipement ${equipmentId}`);
  db.prepare(`
    INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, status, diagnosis, actions, parts_replaced, created_at)
    VALUES (?, ?, ?, 'OPD', 'Panne', 'desc', 'Testeur', ?, 'Sonde HS', 'Remplacement sonde', 'Sonde X', datetime('now','localtime'))
  `).run(id, equipmentId, `Équipement ${equipmentId}`, status);
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
// 1. GET /:id/report — brouillon vide + pré-remplissage live
// =============================================================================
describe('GET /api/issues/:id/report', () => {
  test('🚫 incident inexistant → 404', async () => {
    const res = await request(app)
      .get('/api/issues/iss-fantome/report')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('✅ rapport absent → brouillon vide + champs live de l\'incident', async () => {
    seedIssue('iss-rep-empty');
    const res = await request(app)
      .get('/api/issues/iss-rep-empty/report')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.report_status).toBe('draft');
    expect(res.body.diagnosis).toBe('Sonde HS');          // pré-remplissage live
    expect(res.body.actions).toBe('Remplacement sonde');
    expect(res.body.equipment_id).toBe('eq-rep');
  });
});

// =============================================================================
// 2. PUT /:id/report — UPSERT, validation, RBAC
// =============================================================================
describe('PUT /api/issues/:id/report', () => {
  test('✅ création puis mise à jour (UPSERT) → 200', async () => {
    seedIssue('iss-rep-upsert');
    const create = await request(app)
      .put('/api/issues/iss-rep-upsert/report')
      .set('Authorization', 'Bearer fake-token')
      .send({ summary: 'Résumé v1', duration_hours: 2.5, estimated_cost: 45000, final_equipment_status: 'Operational' });

    expect(create.status).toBe(200);
    expect(create.body.summary).toBe('Résumé v1');
    expect(create.body.author_name).toBe('Admin Test');

    const update = await request(app)
      .put('/api/issues/iss-rep-upsert/report')
      .set('Authorization', 'Bearer fake-token')
      .send({ summary: 'Résumé v2' });

    expect(update.status).toBe(200);
    expect(update.body.summary).toBe('Résumé v2');
    // une seule ligne (UPSERT, pas d'insertion en double)
    const count = db.prepare('SELECT COUNT(*) n FROM issue_intervention_reports WHERE issue_id = ?').get('iss-rep-upsert');
    expect(count.n).toBe(1);
  });

  test('🚫 final_equipment_status invalide → 400', async () => {
    seedIssue('iss-rep-badstatus');
    const res = await request(app)
      .put('/api/issues/iss-rep-badstatus/report')
      .set('Authorization', 'Bearer fake-token')
      .send({ final_equipment_status: 'PasUnStatut' });
    expect(res.status).toBe(400);
  });

  test('🚫 rôle hospital_staff → 403', async () => {
    seedIssue('iss-rep-rbac');
    setTestRole('hospital_staff');
    const res = await request(app)
      .put('/api/issues/iss-rep-rbac/report')
      .set('Authorization', 'Bearer fake-token')
      .send({ summary: 'x' });
    expect(res.status).toBe(403);
    setTestRole('admin');
  });
});

// =============================================================================
// 3. POST /:id/report/finalize — gel + garde-fous
// =============================================================================
describe('POST /api/issues/:id/report/finalize', () => {
  test('🚫 incident non résolu → 409', async () => {
    seedIssue('iss-rep-notdone', { status: 'In Progress' });
    await request(app).put('/api/issues/iss-rep-notdone/report')
      .set('Authorization', 'Bearer fake-token').send({ summary: 'x' });

    const res = await request(app)
      .post('/api/issues/iss-rep-notdone/report/finalize')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(409);
  });

  test('✅ incident résolu → 200, report_status finalized + validateur', async () => {
    seedIssue('iss-rep-done', { status: 'Completed' });
    await request(app).put('/api/issues/iss-rep-done/report')
      .set('Authorization', 'Bearer fake-token').send({ summary: 'x' });

    const res = await request(app)
      .post('/api/issues/iss-rep-done/report/finalize')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(200);
    expect(res.body.report_status).toBe('finalized');
    expect(res.body.validated_by_name).toBe('Admin Test');
    expect(res.body.validated_at).toBeTruthy();
  });

  test('🚫 PUT sur rapport finalisé par non-admin → 409', async () => {
    setTestRole('technician_biomedical');
    const res = await request(app)
      .put('/api/issues/iss-rep-done/report')
      .set('Authorization', 'Bearer fake-token')
      .send({ summary: 'tentative' });
    expect(res.status).toBe(409);
    setTestRole('admin');
  });

  test('✅ PUT sur rapport finalisé par admin → 200', async () => {
    const res = await request(app)
      .put('/api/issues/iss-rep-done/report')
      .set('Authorization', 'Bearer fake-token')
      .send({ summary: 'correction admin' });
    expect(res.status).toBe(200);
    expect(res.body.summary).toBe('correction admin');
  });
});

// =============================================================================
// 4. PATCH /:id/report/reopen — admin uniquement
// =============================================================================
describe('PATCH /api/issues/:id/report/reopen', () => {
  test('🚫 non-admin → 403', async () => {
    setTestRole('supervisor');
    const res = await request(app)
      .patch('/api/issues/iss-rep-done/report/reopen')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(403);
    setTestRole('admin');
  });

  test('✅ admin rouvre → 200, report_status draft', async () => {
    const res = await request(app)
      .patch('/api/issues/iss-rep-done/report/reopen')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(200);
    expect(res.body.report_status).toBe('draft');
  });
});
