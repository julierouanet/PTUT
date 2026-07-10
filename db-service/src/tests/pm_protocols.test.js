'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Rôle courant injecté par les tests ────────────────────────────────────────
let mockCurrentRoles = ['hospitalStaff'];

function setTestRole(...roles) {
  mockCurrentRoles = roles;
}

// ── Mock du middleware d'auth ─────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-db-0002',
      email:      'test-pm@kabutare.rw',
      name:       'Utilisateur Test PM',
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

// ── Mock des backups (initBackupCron peut utiliser node-cron) ────────────────
jest.mock('../routes/backups', () => ({
  router:         require('express').Router(),
  initBackupCron: jest.fn(),
}));

const request = require('supertest');
const { app, server } = require('../index');
const { getDb, closeDb } = require('../database');

let db;
let subcategoryId;

beforeAll(() => {
  db = getDb();

  // Sous-catégorie de référence pour les protocoles PM de test
  db.prepare(`
    INSERT OR IGNORE INTO equipment_macro_categories (name) VALUES ('Biomedical')
  `).run();
  const macro = db.prepare(`SELECT id FROM equipment_macro_categories WHERE name = 'Biomedical'`).get();

  db.prepare(`
    INSERT OR IGNORE INTO equipment_subcategories (name, macro_category_id)
    VALUES ('Sous-catégorie test PM', ?)
  `).run(macro.id);
  subcategoryId = db.prepare(
    `SELECT id FROM equipment_subcategories WHERE name = 'Sous-catégorie test PM'`
  ).get().id;
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// =============================================================================
// POST /api/pm-protocols — élargi admin, supervisor, TECH_ROLES
// =============================================================================
describe('RBAC — POST /api/pm-protocols', () => {
  const ROLES_AUTORISÉS = ['admin', 'supervisor', 'technician_biomedical', 'technician_it', 'technician_infra'];
  const ROLES_REFUSÉS   = ['hospitalStaff', 'technician'];

  test.each(ROLES_AUTORISÉS)(
    '✅ rôle %s peut créer un protocole PM → 201',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/pm-protocols')
        .set('Authorization', 'Bearer fake-token')
        .send({
          subcategory_id: subcategoryId,
          name: `Protocole créé par ${role}`,
          frequency_months: 6,
          checklist: ['Vérifier calibration', 'Nettoyer capteurs'],
        });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('id');
    }
  );

  test.each(ROLES_REFUSÉS)(
    '🚫 rôle %s ne peut PAS créer un protocole PM → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/pm-protocols')
        .set('Authorization', 'Bearer fake-token')
        .send({
          subcategory_id: subcategoryId,
          name: 'Protocole refusé',
          frequency_months: 6,
          checklist: ['Tâche'],
        });

      expect(res.status).toBe(403);
    }
  );

  test('🚫 admin — checklist avec élément non-string → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/pm-protocols')
      .set('Authorization', 'Bearer fake-token')
      .send({
        subcategory_id: subcategoryId,
        name: 'Protocole checklist invalide',
        frequency_months: 6,
        checklist: ['Tâche valide', { label: 'objet invalide' }],
      });

    expect(res.status).toBe(400);
  });
});

// =============================================================================
// PUT /api/pm-protocols/:id — élargi admin, supervisor, TECH_ROLES
// =============================================================================
describe('RBAC — PUT /api/pm-protocols/:id', () => {
  let protocolId;

  beforeEach(async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/pm-protocols')
      .set('Authorization', 'Bearer fake-token')
      .send({
        subcategory_id: subcategoryId,
        name: 'Protocole à modifier',
        frequency_months: 3,
        checklist: ['Tâche initiale'],
      });
    protocolId = res.body.id;
  });

  test('✅ supervisor peut modifier un protocole existant → 200', async () => {
    setTestRole('supervisor');

    const res = await request(app)
      .put(`/api/pm-protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ name: 'Protocole modifié par supervisor' });

    expect(res.status).toBe(200);
  });

  test('🚫 hospitalStaff ne peut PAS modifier un protocole → 403', async () => {
    setTestRole('hospitalStaff');

    const res = await request(app)
      .put(`/api/pm-protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ name: 'Tentative refusée' });

    expect(res.status).toBe(403);
  });

  test('🚫 admin — checklist avec élément non-string → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .put(`/api/pm-protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ checklist: ['Tâche valide', 42] });

    expect(res.status).toBe(400);
  });
});

// =============================================================================
// DELETE /api/pm-protocols/:id — reste admin only (non élargi)
// =============================================================================
describe('RBAC — DELETE /api/pm-protocols/:id', () => {
  let protocolId;

  beforeEach(async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/pm-protocols')
      .set('Authorization', 'Bearer fake-token')
      .send({
        subcategory_id: subcategoryId,
        name: 'Protocole à supprimer',
        frequency_months: 12,
        checklist: ['Tâche'],
      });
    protocolId = res.body.id;
  });

  test('🚫 technician_biomedical ne peut PAS supprimer un protocole → 403', async () => {
    setTestRole('technician_biomedical');

    const res = await request(app)
      .delete(`/api/pm-protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(403);
  });

  test('✅ admin peut supprimer un protocole → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .delete(`/api/pm-protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
  });
});

// =============================================================================
// GET /api/pm-protocols — filtre par subcategory_id
// =============================================================================
describe('GET /api/pm-protocols?subcategory_id=', () => {
  test('✅ retourne uniquement les protocoles de la sous-catégorie filtrée', async () => {
    setTestRole('admin');

    // Autre sous-catégorie, ne doit pas apparaître dans le résultat filtré
    const macro = db.prepare(`SELECT id FROM equipment_macro_categories WHERE name = 'Biomedical'`).get();
    db.prepare(`
      INSERT OR IGNORE INTO equipment_subcategories (name, macro_category_id)
      VALUES ('Autre sous-catégorie test PM', ?)
    `).run(macro.id);
    const otherSubcategoryId = db.prepare(
      `SELECT id FROM equipment_subcategories WHERE name = 'Autre sous-catégorie test PM'`
    ).get().id;

    await request(app)
      .post('/api/pm-protocols')
      .set('Authorization', 'Bearer fake-token')
      .send({
        subcategory_id: subcategoryId,
        name: 'Protocole sous-catégorie cible',
        frequency_months: 6,
        checklist: ['Tâche'],
      });
    await request(app)
      .post('/api/pm-protocols')
      .set('Authorization', 'Bearer fake-token')
      .send({
        subcategory_id: otherSubcategoryId,
        name: 'Protocole autre sous-catégorie',
        frequency_months: 6,
        checklist: ['Tâche'],
      });

    const res = await request(app)
      .get(`/api/pm-protocols?subcategory_id=${subcategoryId}`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.every((p) => p.subcategory_id === subcategoryId)).toBe(true);
    expect(res.body.some((p) => p.name === 'Protocole sous-catégorie cible')).toBe(true);
    expect(res.body.some((p) => p.name === 'Protocole autre sous-catégorie')).toBe(false);
  });
});
