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
      id:    'test-uuid-catalog-0001',
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
let subId;          // sous-catégorie de référence
let protocolId;     // protocole PM de référence

beforeAll(() => {
  db = getDb();

  // Sous-catégorie de référence (rattachée à la macro biomédicale id=1).
  const macro = db.prepare("SELECT id FROM equipment_macro_categories WHERE name = 'Biomedical'").get();
  const subRes = db.prepare(
    'INSERT INTO equipment_subcategories(name, macro_category_id) VALUES (?, ?)'
  ).run('Catalogue Test Subcat', macro.id);
  subId = subRes.lastInsertRowid;

  // Protocole PM de référence rattaché à cette sous-catégorie.
  const protoRes = db.prepare(`
    INSERT INTO pm_protocols(subcategory_id, name, frequency_months, estimated_duration_hours, checklist)
    VALUES (?, 'Protocole Test', 6, 2.0, '[]')
  `).run(subId);
  protocolId = protoRes.lastInsertRowid;
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// =============================================================================
// 1. FABRICANTS — CRUD + RBAC
// =============================================================================
describe('Catalogue — /api/brands', () => {
  test('✅ admin crée un fabricant → 201', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Philips' });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body.name).toBe('Philips');
  });

  test('✅ technicien (TECH_ROLES) peut créer un fabricant → 201', async () => {
    setTestRole('technician_biomedical');
    const res = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'GE Healthcare' });
    expect(res.status).toBe(201);
  });

  test('🚫 hospitalStaff ne peut pas créer un fabricant → 403', async () => {
    setTestRole('hospitalStaff');
    const res = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Autre fabricant' });
    expect(res.status).toBe(403);
  });

  test('🚫 name manquant → 400', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({});
    expect(res.status).toBe(400);
  });

  test('🚫 doublon (COLLATE NOCASE) → 409', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'philips' });
    expect(res.status).toBe(409);
  });

  test('✅ liste des fabricants avec compteurs → 200', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get('/api/brands')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    const philips = res.body.find((b) => b.name === 'Philips');
    expect(philips).toBeDefined();
    expect(philips).toHaveProperty('model_count');
    expect(philips).toHaveProperty('equipment_count');
  });
});

// =============================================================================
// 2. MODÈLES — CRUD + filtres + 409 rattachement
// =============================================================================
describe('Catalogue — /api/models', () => {
  let brandId;
  let modelId;

  beforeAll(async () => {
    setTestRole('admin');
    const b = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Dräger' });
    brandId = b.body.id;
  });

  test('✅ admin crée un modèle → 201', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/models')
      .set('Authorization', 'Bearer fake')
      .send({ brand_id: brandId, subcategory_id: subId, name: 'Fabius Plus' });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    modelId = res.body.id;
  });

  test('🚫 doublon modèle (même fabricant/sous-cat) → 409', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/models')
      .set('Authorization', 'Bearer fake')
      .send({ brand_id: brandId, subcategory_id: subId, name: 'fabius plus' });
    expect(res.status).toBe(409);
  });

  test('🚫 brand_id manquant → 400', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post('/api/models')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Sans fabricant' });
    expect(res.status).toBe(400);
  });

  test('✅ filtre ?brand_id= → 200 et equipment_count présent', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get(`/api/models?brand_id=${brandId}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body[0]).toHaveProperty('equipment_count');
  });

  test('✅ filtre ?subcategory_id= → 200', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get(`/api/models?subcategory_id=${subId}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.every((m) => m.subcategory_id === subId)).toBe(true);
  });

  test('✅ détail modèle → équipements/documents/protocoles', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get(`/api/models/${modelId}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('brand_name', 'Dräger');
    expect(Array.isArray(res.body.equipment)).toBe(true);
    expect(Array.isArray(res.body.documents)).toBe(true);
    expect(Array.isArray(res.body.protocols)).toBe(true);
  });

  test('🚫 DELETE modèle avec équipement rattaché → 409 MODEL_HAS_EQUIPMENT', async () => {
    // Rattache un équipement directement en base.
    db.prepare(`
      INSERT INTO equipment (id, name, department, category, status, model_id)
      VALUES ('eq-catalog-model', 'Ventilateur test', 'OPD', 'Catalogue Test Subcat', 'Operational', ?)
    `).run(modelId);

    setTestRole('admin');
    const res = await request(app)
      .delete(`/api/models/${modelId}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(409);
    expect(res.body.error).toBe('MODEL_HAS_EQUIPMENT');

    // Nettoyage du rattachement pour les tests suivants.
    db.prepare("DELETE FROM equipment WHERE id = 'eq-catalog-model'").run();
  });

  test('🚫 DELETE fabricant avec modèle rattaché → 409 BRAND_HAS_MODELS', async () => {
    setTestRole('admin');
    const res = await request(app)
      .delete(`/api/brands/${brandId}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(409);
    expect(res.body.error).toBe('BRAND_HAS_MODELS');
  });

  test('✅ DELETE modèle puis fabricant (sans rattachement) → 200', async () => {
    setTestRole('admin');
    const delModel = await request(app)
      .delete(`/api/models/${modelId}`)
      .set('Authorization', 'Bearer fake');
    expect(delModel.status).toBe(200);

    const delBrand = await request(app)
      .delete(`/api/brands/${brandId}`)
      .set('Authorization', 'Bearer fake');
    expect(delBrand.status).toBe(200);
  });
});

// =============================================================================
// 3. DOCUMENTS DE MODÈLE — upload / liste / suppression
// =============================================================================
describe('Catalogue — documents de modèle', () => {
  let brandId;
  let modelId;

  beforeAll(async () => {
    setTestRole('admin');
    const b = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Mindray' });
    brandId = b.body.id;
    const m = await request(app)
      .post('/api/models')
      .set('Authorization', 'Bearer fake')
      .send({ brand_id: brandId, subcategory_id: subId, name: 'BeneView T8' });
    modelId = m.body.id;
  });

  test('✅ admin upload un document → 201', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post(`/api/models/${modelId}/documents`)
      .set('Authorization', 'Bearer fake')
      .field('type', 'technical')
      .attach('file', Buffer.from('%PDF-1.4 test'), 'manuel.pdf');
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
  });

  test('🚫 non-admin ne peut pas uploader → 403', async () => {
    setTestRole('technician_biomedical');
    const res = await request(app)
      .post(`/api/models/${modelId}/documents`)
      .set('Authorization', 'Bearer fake')
      .field('type', 'technical')
      .attach('file', Buffer.from('%PDF-1.4 test'), 'manuel2.pdf');
    expect(res.status).toBe(403);
  });

  test('✅ liste des documents → 200', async () => {
    setTestRole('admin');
    const res = await request(app)
      .get(`/api/models/${modelId}/documents`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
  });

  test('✅ suppression (soft-delete) → 200 puis absent de la liste', async () => {
    setTestRole('admin');
    const list = await request(app)
      .get(`/api/models/${modelId}/documents`)
      .set('Authorization', 'Bearer fake');
    const docId = list.body[0].id;

    const del = await request(app)
      .delete(`/api/models/${modelId}/documents/${docId}`)
      .set('Authorization', 'Bearer fake');
    expect(del.status).toBe(200);

    const after = await request(app)
      .get(`/api/models/${modelId}/documents`)
      .set('Authorization', 'Bearer fake');
    expect(after.body.find((d) => d.id === docId)).toBeUndefined();
  });
});

// =============================================================================
// 4. LIENS MODÈLE ↔ PROTOCOLES PM
// =============================================================================
describe('Catalogue — liens protocoles PM', () => {
  let modelId;

  beforeAll(async () => {
    setTestRole('admin');
    const b = await request(app)
      .post('/api/brands')
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Siemens' });
    const m = await request(app)
      .post('/api/models')
      .set('Authorization', 'Bearer fake')
      .send({ brand_id: b.body.id, subcategory_id: subId, name: 'Acuson' });
    modelId = m.body.id;
  });

  test('✅ lier un protocole → 201 puis présent dans la fiche', async () => {
    setTestRole('admin');
    const link = await request(app)
      .post(`/api/models/${modelId}/protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake');
    expect(link.status).toBe(201);

    const detail = await request(app)
      .get(`/api/models/${modelId}`)
      .set('Authorization', 'Bearer fake');
    expect(detail.body.protocols.find((p) => p.id === protocolId)).toBeDefined();
  });

  test('✅ lier deux fois est idempotent → 201', async () => {
    setTestRole('admin');
    const link = await request(app)
      .post(`/api/models/${modelId}/protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake');
    expect(link.status).toBe(201);
  });

  test('✅ délier un protocole → 200 puis absent', async () => {
    setTestRole('admin');
    const unlink = await request(app)
      .delete(`/api/models/${modelId}/protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake');
    expect(unlink.status).toBe(200);

    const detail = await request(app)
      .get(`/api/models/${modelId}`)
      .set('Authorization', 'Bearer fake');
    expect(detail.body.protocols.find((p) => p.id === protocolId)).toBeUndefined();
  });

  test('🚫 lier sur un modèle introuvable → 404', async () => {
    setTestRole('admin');
    const res = await request(app)
      .post(`/api/models/999999/protocols/${protocolId}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(404);
  });
});

// =============================================================================
// 5. SOUS-CATÉGORIE — description métier (PUT /sub/:id + propagation fiche équipement)
// =============================================================================
describe('Sous-catégorie — description', () => {
  test('✅ admin met à jour la description → 200 et persistance via GET /sub/:id', async () => {
    setTestRole('admin');
    const put = await request(app)
      .put(`/api/categories/sub/${subId}`)
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Catalogue Test Subcat', description: 'Équipements de test biomédicaux' });
    expect(put.status).toBe(200);
    expect(put.body.description).toBe('Équipements de test biomédicaux');

    const get = await request(app)
      .get(`/api/categories/sub/${subId}`)
      .set('Authorization', 'Bearer fake');
    expect(get.status).toBe(200);
    expect(get.body.description).toBe('Équipements de test biomédicaux');
  });

  test('✅ description exposée sur GET /api/equipment/:id (subcategory_description)', async () => {
    db.prepare(`
      INSERT INTO equipment (id, name, department, category, status, subcategory_id)
      VALUES ('eq-desc-test', 'Moniteur test', 'OPD', 'Catalogue Test Subcat', 'Operational', ?)
    `).run(subId);

    setTestRole('admin');
    const res = await request(app)
      .get('/api/equipment/eq-desc-test')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(res.body.subcategory_description).toBe('Équipements de test biomédicaux');

    db.prepare("DELETE FROM equipment WHERE id = 'eq-desc-test'").run();
  });

  test('✅ description vide → effacée (null)', async () => {
    setTestRole('admin');
    const put = await request(app)
      .put(`/api/categories/sub/${subId}`)
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Catalogue Test Subcat', description: '' });
    expect(put.status).toBe(200);
    expect(put.body.description).toBeNull();
  });

  test('🚫 non-admin ne peut pas modifier la description → 403', async () => {
    setTestRole('technician_biomedical');
    const res = await request(app)
      .put(`/api/categories/sub/${subId}`)
      .set('Authorization', 'Bearer fake')
      .send({ name: 'Catalogue Test Subcat', description: 'tentative' });
    expect(res.status).toBe(403);
  });
});
