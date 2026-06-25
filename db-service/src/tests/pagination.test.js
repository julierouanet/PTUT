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
      id:         'test-uuid-pagination-0001',
      email:      'test@kabutare.rw',
      name:       'Utilisateur Test Pagination',
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

  // ── Correction schéma issues en DB :memory: (cf. rbac_equipment_issues.test.js) ─
  const existingCols = new Set(db.pragma('table_info(issues)').map((c) => c.name));
  const missingCols = ['location_text', 'location_tag', 'reporter_phone', 'taken_at'];
  for (const col of missingCols) {
    if (!existingCols.has(col)) {
      try { db.exec(`ALTER TABLE issues ADD COLUMN ${col} TEXT`); } catch (_) {}
    }
  }

  // 5 équipements de référence pour tester la pagination/recherche
  const insertEq = db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status, manufacturer)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  insertEq.run('eq-pg-1', 'Moniteur Pagination Alpha', 'OPD', 'Monitoring', 'Operational', 'Philips');
  insertEq.run('eq-pg-2', 'Moniteur Pagination Beta',  'OPD', 'Monitoring', 'Operational', 'GE');
  insertEq.run('eq-pg-3', 'Scanner Pagination Gamma',  'Radiologie', 'Imagerie', 'Operational', 'Siemens');
  insertEq.run('eq-pg-4', 'Pompe Pagination Delta',    'Chirurgie', 'Therapeutique', 'Operational', 'Braun');
  insertEq.run('eq-pg-5', 'Lit Pagination Epsilon',     'OPD', 'Mobilier', 'Operational', 'Hillrom');

  // 5 incidents de référence : 4 actifs (statuts variés) + 1 Completed
  const insertIssue = db.prepare(`
    INSERT OR IGNORE INTO issues (
      id, equipment_id, equipment_name, issue_category, assigned_group,
      department, type, description, reporter, reporter_id, urgency, status,
      assigned_technician, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now','localtime'))
  `);
  insertIssue.run('iss-pg-1', 'eq-pg-1', 'Moniteur Pagination Alpha', 'Biomédical', 'Biomédical', 'OPD', 'Panne', 'Incident pagination 1', 'Dr A', 'user-pg-rep', 'Moyen', 'Reported', null);
  insertIssue.run('iss-pg-2', 'eq-pg-2', 'Moniteur Pagination Beta', 'Biomédical', 'IT', 'OPD', 'Panne', 'Incident pagination 2', 'Dr B', 'user-pg-other', 'Urgent', 'Assigned', null);
  insertIssue.run('iss-pg-3', 'eq-pg-3', 'Scanner Pagination Gamma', 'Biomédical', null, 'Radiologie', 'Panne', 'Incident pagination 3 (groupe NULL)', 'Dr C', 'user-pg-other', 'Faible', 'In Progress', 'Tech Pagination');
  insertIssue.run('iss-pg-4', 'eq-pg-4', 'Pompe Pagination Delta', 'Biomédical', 'Biomédical', 'Chirurgie', 'Panne', 'Incident pagination 4', 'Dr D', 'user-pg-other', 'Critique', 'In Progress', null);
  insertIssue.run('iss-pg-5', 'eq-pg-5', 'Lit Pagination Epsilon', 'Infrastructure', 'Infrastructure', 'OPD', 'Inspection', 'Incident pagination 5 (clôturé)', 'Dr E', 'user-pg-other', 'Moyen', 'Completed', null);
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// =============================================================================
// GET /api/equipment — pagination serveur
// =============================================================================
describe('Pagination — GET /api/equipment', () => {
  test('✅ sans `page` → réponse legacy (tableau brut), inchangée', async () => {
    const res = await request(app)
      .get('/api/equipment')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.some((e) => e.id === 'eq-pg-1')).toBe(true);
  });

  test('✅ avec `page`/`limit` → enveloppe paginée cohérente', async () => {
    const res = await request(app)
      .get('/api/equipment?page=1&limit=2')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('items');
    expect(res.body).toHaveProperty('total');
    expect(res.body).toHaveProperty('page', 1);
    expect(res.body).toHaveProperty('limit', 2);
    expect(res.body).toHaveProperty('total_pages');
    expect(res.body.items.length).toBe(2);
    expect(res.body.total).toBeGreaterThanOrEqual(5);
  });

  test('✅ `search` filtre les résultats et le total est cohérent', async () => {
    const res = await request(app)
      .get('/api/equipment?page=1&limit=20&search=Pagination Alpha')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.items.every((e) => e.name.includes('Pagination Alpha'))).toBe(true);
    expect(res.body.total).toBe(res.body.items.length);
    expect(res.body.items.length).toBeGreaterThanOrEqual(1);
  });

  test('🚫 `page=0` → 400', async () => {
    const res = await request(app)
      .get('/api/equipment?page=0')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(400);
  });

  test('🚫 `sort_by` invalide → 400', async () => {
    const res = await request(app)
      .get('/api/equipment?page=1&sort_by=invalide')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(400);
  });

  test('✅ `limit` > 100 est clampé à 100 sans erreur', async () => {
    const res = await request(app)
      .get('/api/equipment?page=1&limit=500')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.limit).toBe(100);
  });
});

// =============================================================================
// GET /api/issues — pagination serveur
// =============================================================================
describe('Pagination — GET /api/issues', () => {
  test('✅ sans `page` → réponse legacy (tableau brut), inchangée', async () => {
    const res = await request(app)
      .get('/api/issues')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('✅ `page`/`limit`/`status_ne` exclut bien les incidents Completed', async () => {
    const res = await request(app)
      .get('/api/issues?page=1&limit=20&status_ne=Completed')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.items.some((i) => i.id === 'iss-pg-5')).toBe(false);
    expect(res.body.items.every((i) => i.status !== 'Completed')).toBe(true);
  });

  test('✅ `assigned_group_in=IT` inclut aussi les incidents à assigned_group NULL', async () => {
    const res = await request(app)
      .get('/api/issues?page=1&limit=20&assigned_group_in=IT')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const ids = res.body.items.map((i) => i.id);
    expect(ids).toContain('iss-pg-2'); // assigned_group = 'IT'
    expect(ids).toContain('iss-pg-3'); // assigned_group = NULL
    expect(ids).not.toContain('iss-pg-1'); // assigned_group = 'Biomédical'
  });

  test('🚫 `urgency` invalide → 400', async () => {
    const res = await request(app)
      .get('/api/issues?urgency=Inconnu')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(400);
  });

  test('🚫 `assigned_group_in` avec une valeur invalide → 400', async () => {
    const res = await request(app)
      .get('/api/issues?page=1&assigned_group_in=IT,Bidon')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(400);
  });

  test('✅ `reporter_id` filtre par signaleur', async () => {
    const res = await request(app)
      .get('/api/issues?page=1&limit=20&reporter_id=user-pg-rep')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.items.every((i) => i.reporter_id === 'user-pg-rep')).toBe(true);
    expect(res.body.items.length).toBeGreaterThanOrEqual(1);
  });

  test('🚫 `page` absent mais `status` invalide → 400 (validation indépendante de la pagination)', async () => {
    const res = await request(app)
      .get('/api/issues?status=StatutBidon')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(400);
  });
});
