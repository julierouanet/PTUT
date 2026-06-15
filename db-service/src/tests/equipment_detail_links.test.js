'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Rôle courant injecté par les tests ────────────────────────────────────────
let mockCurrentRoles = ['admin'];
function setTestRole(...roles) { mockCurrentRoles = roles; }

// ── Mock du middleware d'auth ─────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:    'test-uuid-eqdetail-0001',
      email: 'test@kabutare.rw',
      name:  'Utilisateur Test',
      roles: mockCurrentRoles,
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
let subId;     // sous-catégorie de référence
let brandId;   // fabricant de référence
let modelId;   // modèle de référence

beforeAll(() => {
  db = getDb();

  // Sous-catégorie rattachée à la macro biomédicale (id=1 par défaut).
  const macro = db.prepare("SELECT id FROM equipment_macro_categories WHERE name = 'Biomedical'").get();
  subId = db.prepare(
    'INSERT INTO equipment_subcategories(name, macro_category_id) VALUES (?, ?)'
  ).run('Détail Test Subcat', macro.id).lastInsertRowid;

  // Fabricant + modèle de catalogue.
  brandId = db.prepare('INSERT INTO equipment_brands(name) VALUES (?)').run('Philips Détail').lastInsertRowid;
  modelId = db.prepare(
    'INSERT INTO equipment_models(brand_id, subcategory_id, name) VALUES (?, ?, ?)'
  ).run(brandId, subId, 'IntelliVue MX450').lastInsertRowid;

  // Équipement RATTACHÉ au catalogue (model_id + subcategory_id).
  db.prepare(`
    INSERT INTO equipment (id, name, department, category, status, subcategory_id, model_id)
    VALUES ('eq-detail-linked', 'Moniteur lié', 'Radiologie', 'Détail Test Subcat', 'Operational', ?, ?)
  `).run(subId, modelId);

  // Équipement NON catalogué (ni model_id ni subcategory_id).
  db.prepare(`
    INSERT INTO equipment (id, name, department, category, status)
    VALUES ('eq-detail-orphan', 'Moniteur orphelin', 'Radiologie', 'Autre', 'Operational')
  `).run();
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

describe('GET /api/equipment/:id — métadonnées cliquables', () => {
  test('✅ équipement rattaché → expose model_id/brand_id/brand_name/subcategory_id/subcategory_name', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get('/api/equipment/eq-detail-linked')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.model_id).toBe(modelId);
    expect(res.body.brand_id).toBe(brandId);
    expect(res.body.brand_name).toBe('Philips Détail');
    expect(res.body.subcategory_id).toBe(subId);
    expect(res.body.subcategory_name).toBe('Détail Test Subcat');
  });

  test('✅ équipement non catalogué → brand_id/brand_name/model_id à null', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get('/api/equipment/eq-detail-orphan')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.model_id).toBeNull();
    expect(res.body.brand_id).toBeNull();
    expect(res.body.brand_name).toBeNull();
    expect(res.body.subcategory_id).toBeNull();
    expect(res.body.subcategory_name).toBeNull();
  });
});

describe('GET /api/categories/detail — détail catégorie par nom', () => {
  test('✅ renvoie équipements + fabricants présents', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get('/api/categories/detail')
      .query({ name: 'Détail Test Subcat' })
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('Détail Test Subcat');
    expect(Array.isArray(res.body.equipment)).toBe(true);
    expect(res.body.equipment.find((e) => e.id === 'eq-detail-linked')).toBeDefined();
    const philips = res.body.brands.find((b) => b.name === 'Philips Détail');
    expect(philips).toBeDefined();
    expect(philips.equipment_count).toBeGreaterThanOrEqual(1);
  });

  test('🚫 name manquant → 400', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get('/api/categories/detail')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(400);
  });
});

describe('GET /api/departments/:id/detail — dashboard département', () => {
  let deptId;

  beforeAll(() => {
    deptId = db.prepare('INSERT INTO departments(name) VALUES (?)').run('Détail Dept Test').lastInsertRowid;
    // Équipement actif rattaché au département (par department_id) + PM en retard.
    db.prepare(`
      INSERT INTO equipment (id, name, department, department_id, category, status, next_preventive_maintenance)
      VALUES ('eq-dept-1', 'Équipement dept', 'Détail Dept Test', ?, 'Autre', 'Operational', '2000-01-01')
    `).run(deptId);
    // Incident ouvert dans ce département.
    db.prepare(`
      INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, created_at, status, urgency)
      VALUES ('iss-dept-1', 'eq-dept-1', 'Équipement dept', 'Détail Dept Test', 'panne', 'Ne démarre plus', 'Test', datetime('now'), 'Reported', 'Haut')
    `).run();
  });

  test('✅ renvoie kpis + equipment + openIssues', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get(`/api/departments/${deptId}/detail`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('Détail Dept Test');
    expect(res.body.kpis.total).toBe(1);
    expect(res.body.kpis.operational).toBe(1);
    expect(res.body.kpis.pmOverdue).toBe(1);
    expect(res.body.equipment.find((e) => e.id === 'eq-dept-1')).toBeDefined();
    expect(res.body.openIssues.find((i) => i.id === 'iss-dept-1')).toBeDefined();
  });

  test('🚫 département introuvable → 404', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get('/api/departments/999999/detail')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(404);
  });
});
