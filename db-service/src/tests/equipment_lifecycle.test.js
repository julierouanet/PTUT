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

// Crée un équipement « vierge » (sans historique)
function seedEquipment(id, status = 'Operational') {
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES (?, ?, 'OPD', 'Monitoring', ?)
  `).run(id, `Équipement ${id}`, status);
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
// 1. POST /:id/decommission — réforme (soft delete)
// =============================================================================
describe('Réforme — POST /api/equipment/:id/decommission', () => {
  test('✅ réforme valide → 200, status Disposed, ligne conservée', async () => {
    seedEquipment('eq-dec-ok');
    const res = await request(app)
      .post('/api/equipment/eq-dec-ok/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'obsolete', disposal_method: 'destroyed', decommission_notes: 'Fin de vie' });

    expect(res.status).toBe(200);
    const eq = db.prepare('SELECT * FROM equipment WHERE id = ?').get('eq-dec-ok');
    expect(eq).toBeDefined();                       // soft delete : jamais effacé
    expect(eq.status).toBe('Disposed');
    expect(eq.decommission_reason).toBe('obsolete');
    expect(eq.disposal_method).toBe('destroyed');
    expect(eq.decommissioned_at).toBeTruthy();
    expect(eq.decommissioned_by_name).toBe('Admin Test');
  });

  test('🚫 motif invalide → 400', async () => {
    seedEquipment('eq-dec-badreason');
    const res = await request(app)
      .post('/api/equipment/eq-dec-badreason/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'pasvalide', disposal_method: 'destroyed' });

    expect(res.status).toBe(400);
  });

  test('🚫 méthode d\'élimination invalide → 400', async () => {
    seedEquipment('eq-dec-badmethod');
    const res = await request(app)
      .post('/api/equipment/eq-dec-badmethod/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'obsolete', disposal_method: 'pasvalide' });

    expect(res.status).toBe(400);
  });

  test('🚫 motif "replaced" sans replaced_by_id → 400', async () => {
    seedEquipment('eq-dec-noreplace');
    const res = await request(app)
      .post('/api/equipment/eq-dec-noreplace/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'replaced', disposal_method: 'sold' });

    expect(res.status).toBe(400);
  });

  test('✅ motif "replaced" avec remplaçant valide → 200, lien posé', async () => {
    seedEquipment('eq-old');
    seedEquipment('eq-new');
    const res = await request(app)
      .post('/api/equipment/eq-old/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'replaced', disposal_method: 'sold', replaced_by_id: 'eq-new' });

    expect(res.status).toBe(200);
    const eq = db.prepare('SELECT replaced_by_id FROM equipment WHERE id = ?').get('eq-old');
    expect(eq.replaced_by_id).toBe('eq-new');
  });

  test('🚫 remplaçant inexistant → 404', async () => {
    seedEquipment('eq-dec-badreplace');
    const res = await request(app)
      .post('/api/equipment/eq-dec-badreplace/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'replaced', disposal_method: 'sold', replaced_by_id: 'eq-fantome' });

    expect(res.status).toBe(404);
  });

  test('🚫 remplaçant = soi-même → 400', async () => {
    seedEquipment('eq-self');
    const res = await request(app)
      .post('/api/equipment/eq-self/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'replaced', disposal_method: 'sold', replaced_by_id: 'eq-self' });

    expect(res.status).toBe(400);
  });

  test('🚫 rôle non-admin → 403', async () => {
    seedEquipment('eq-dec-rbac');
    setTestRole('supervisor');
    const res = await request(app)
      .post('/api/equipment/eq-dec-rbac/decommission')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'obsolete', disposal_method: 'destroyed' });

    expect(res.status).toBe(403);
    setTestRole('admin');
  });
});

// =============================================================================
// 2. POST /:id/propose-disposal — proposition (tech/superviseur/admin)
// =============================================================================
describe('Proposition — POST /api/equipment/:id/propose-disposal', () => {
  test('✅ superviseur peut proposer → 200, status To be disposal', async () => {
    seedEquipment('eq-prop-ok');
    setTestRole('supervisor');
    const res = await request(app)
      .post('/api/equipment/eq-prop-ok/propose-disposal')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'irreparable' });

    expect(res.status).toBe(200);
    const eq = db.prepare('SELECT status, decommission_reason FROM equipment WHERE id = ?').get('eq-prop-ok');
    expect(eq.status).toBe('To be disposal');
    expect(eq.decommission_reason).toBe('irreparable');
    setTestRole('admin');
  });

  test('🚫 proposer sur un équipement déjà Disposed → 400', async () => {
    seedEquipment('eq-prop-disposed', 'Disposed');
    const res = await request(app)
      .post('/api/equipment/eq-prop-disposed/propose-disposal')
      .set('Authorization', 'Bearer fake-token')
      .send({ decommission_reason: 'obsolete' });

    expect(res.status).toBe(400);
  });
});

// =============================================================================
// 3. DELETE /:id — garde-fou hard delete
// =============================================================================
describe('Hard delete — garde-fou historique', () => {
  test('🚫 équipement avec incident → 409 hasHistory', async () => {
    seedEquipment('eq-hist');
    db.prepare(`
      INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, status, created_at)
      VALUES ('iss-hist', 'eq-hist', 'Équipement eq-hist', 'OPD', 'Panne', 'desc', 'Testeur', 'Reported', datetime('now','localtime'))
    `).run();

    const res = await request(app)
      .delete('/api/equipment/eq-hist')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(409);
    expect(res.body.hasHistory).toBe(true);
    expect(db.prepare('SELECT id FROM equipment WHERE id = ?').get('eq-hist')).toBeDefined();
  });

  test('✅ force=true purge l\'équipement et son historique → 200', async () => {
    const res = await request(app)
      .delete('/api/equipment/eq-hist?force=true')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(db.prepare('SELECT id FROM equipment WHERE id = ?').get('eq-hist')).toBeUndefined();
    expect(db.prepare('SELECT id FROM issues WHERE equipment_id = ?').get('eq-hist')).toBeUndefined();
  });

  test('✅ équipement vierge supprimé sans force → 200', async () => {
    seedEquipment('eq-vierge');
    const res = await request(app)
      .delete('/api/equipment/eq-vierge')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(db.prepare('SELECT id FROM equipment WHERE id = ?').get('eq-vierge')).toBeUndefined();
  });
});

// =============================================================================
// 4. GET liste — exclusion des Disposed
// =============================================================================
describe('GET /api/equipment — exclusion des réformés', () => {
  test('✅ liste par défaut exclut les Disposed', async () => {
    seedEquipment('eq-actif-list');
    seedEquipment('eq-dispose-list', 'Disposed');

    const res = await request(app)
      .get('/api/equipment')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.map((e) => e.id);
    expect(ids).toContain('eq-actif-list');
    expect(ids).not.toContain('eq-dispose-list');
  });

  test('✅ include_disposed=true inclut les Disposed', async () => {
    const res = await request(app)
      .get('/api/equipment?include_disposed=true')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.map((e) => e.id);
    expect(ids).toContain('eq-dispose-list');
  });

  test('✅ le remplaçant expose replaced_by_name et le lien inverse', async () => {
    // eq-old a été réformé et remplacé par eq-new (test précédent)
    const res = await request(app)
      .get('/api/equipment?include_disposed=true')
      .set('Authorization', 'Bearer fake-token');

    const old = res.body.find((e) => e.id === 'eq-old');
    const neuf = res.body.find((e) => e.id === 'eq-new');
    expect(old.replaced_by_name).toBe('Équipement eq-new');
    expect(neuf.replaces_id).toBe('eq-old');
  });
});
