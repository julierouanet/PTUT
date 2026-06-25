'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Mock du middleware d'auth (utilisateur admin systématique, hors scope RBAC) ─
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-light-0001',
      email:      'test@kabutare.rw',
      name:       'Utilisateur Test Light',
      roles:      ['admin'],
      department: 'OPD',
    };
    next();
  },
  requireRole: () => (req, _res, next) => next(),
  SYSTEM_ROLES: new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));

// ── Mock du logger (évite appels HTTP vers auth-service) ─────────────────────
jest.mock('../utils/logger', () => ({
  logAction:      jest.fn(),
  extractReqMeta: jest.fn(() => ({})),
  sendLog:        jest.fn(),
}));

// ── Mock des notifications push (évite appels réseau) ────────────────────────
jest.mock('../utils/push_sender', () => ({
  sendPushToRoles: jest.fn().mockResolvedValue(undefined),
}));

// ── Mock fetch global (évite appels à auth-service pour les emails) ───────────
global.fetch = jest.fn().mockResolvedValue({
  ok:   true,
  json: () => Promise.resolve({}),
  text: () => Promise.resolve(''),
});

// ── Mock des backups (initBackupCron peut utiliser node-cron) ─────────────────
jest.mock('../routes/backups', () => ({
  router:         require('express').Router(),
  initBackupCron: jest.fn(),
}));

const request = require('supertest');
const { app, server } = require('../index');
const { getDb, closeDb } = require('../database');

let db;

beforeAll(() => {
  db = getDb();

  const insertEq = db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status, manufacturer)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  // Volume suffisant pour dépasser le seuil de compression (1 Ko) du middleware.
  for (let i = 1; i <= 30; i++) {
    insertEq.run(`eq-light-${i}`, `Équipement Compression Test ${i} — description longue pour le volume`,
      'OPD', 'Monitoring', 'Operational', 'Philips');
  }

  const insertTag = db.prepare(
    'INSERT OR IGNORE INTO equipment_tags (equipment_id, tag_number) VALUES (?, ?)'
  );
  insertTag.run('eq-light-1', 'TAG-LIGHT-001');

  const insertMaint = db.prepare(`
    INSERT INTO maintenance_records (equipment_id, date, intervention, technician, is_future)
    VALUES (?, datetime('now','localtime'), 'Maintenance test', 'Technicien Test', 0)
  `);
  insertMaint.run('eq-light-1');
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// =============================================================================
// GET /api/equipment?light=true — payload allégé (optimisation premier accès)
// =============================================================================
describe('Mode léger — GET /api/equipment?light=true', () => {
  test('✅ legacy (sans page) : mêmes lignes, mais maintenanceHistory/futureMaintenance/tags vides', async () => {
    const full  = await request(app).get('/api/equipment').set('Authorization', 'Bearer fake-token');
    const light = await request(app).get('/api/equipment?light=true').set('Authorization', 'Bearer fake-token');

    expect(full.status).toBe(200);
    expect(light.status).toBe(200);

    const fullEq  = full.body.find((e) => e.id === 'eq-light-1');
    const lightEq = light.body.find((e) => e.id === 'eq-light-1');

    // L'équipement de référence a bien un tag et une maintenance en mode complet.
    expect(fullEq.tags).toEqual(['TAG-LIGHT-001']);
    expect(fullEq.maintenanceHistory.length).toBeGreaterThanOrEqual(1);

    // En mode léger : tableaux vides...
    expect(lightEq.maintenanceHistory).toEqual([]);
    expect(lightEq.futureMaintenance).toEqual([]);
    expect(lightEq.tags).toEqual([]);

    // ...mais toutes les colonnes scalaires de BASE_SELECT restent présentes
    // (les dashboards/listes Flutter en dépendent).
    for (const col of ['id', 'name', 'department', 'category', 'status', 'manufacturer']) {
      expect(lightEq[col]).toBe(fullEq[col]);
    }
  });

  test('✅ paginé (avec page) : mêmes lignes, mêmes garanties', async () => {
    const full  = await request(app)
      .get('/api/equipment?page=1&limit=50')
      .set('Authorization', 'Bearer fake-token');
    const light = await request(app)
      .get('/api/equipment?page=1&limit=50&light=true')
      .set('Authorization', 'Bearer fake-token');

    expect(full.status).toBe(200);
    expect(light.status).toBe(200);
    expect(light.body.total).toBe(full.body.total);

    const fullEq  = full.body.items.find((e) => e.id === 'eq-light-1');
    const lightEq = light.body.items.find((e) => e.id === 'eq-light-1');

    expect(fullEq.tags).toEqual(['TAG-LIGHT-001']);
    expect(lightEq.maintenanceHistory).toEqual([]);
    expect(lightEq.futureMaintenance).toEqual([]);
    expect(lightEq.tags).toEqual([]);
    expect(lightEq.name).toBe(fullEq.name);
    expect(lightEq.status).toBe(fullEq.status);
  });
});

// =============================================================================
// Compression — middleware `compression` (Express)
// =============================================================================
describe('Compression — middleware Express', () => {
  test('✅ une grosse réponse JSON est servie avec Content-Encoding: gzip', async () => {
    const res = await request(app)
      .get('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .set('Accept-Encoding', 'gzip');

    expect(res.status).toBe(200);
    expect(res.headers['content-encoding']).toBe('gzip');
  });
});
