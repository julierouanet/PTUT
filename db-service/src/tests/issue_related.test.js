'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

let mockCurrentRoles = ['admin'];

jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:    'test-uuid-related-0001',
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

beforeAll(() => {
  db = getDb();

  // Équipement de référence
  db.prepare(
    "INSERT INTO equipment (id, name, department, category, status) VALUES ('eq-related-test', 'Moniteur Test', 'Urgences', 'Monitoring', 'Operational')"
  ).run();

  // 5 incidents passés sur cet équipement (du plus ancien au plus récent)
  for (let i = 1; i <= 5; i++) {
    db.prepare(
      `INSERT INTO issues (id, equipment_id, type, status, urgency, reporter, department, description, created_at)
       VALUES ('ISS-REL-OLD-00${i}', 'eq-related-test', 'Panne', 'Closed', 'High', 'Technicien ${i}', 'Urgences', 'Desc ${i}',
               datetime('now', '-${6 - i} days'))`
    ).run();
  }

  // Incident courant (celui qu'on va interroger)
  db.prepare(
    "INSERT INTO issues (id, equipment_id, type, status, urgency, reporter, department, description, created_at) VALUES ('ISS-REL-CURR', 'eq-related-test', 'Panne', 'Open', 'Medium', 'Infirmier Test', 'Urgences', 'Panne actuelle', datetime('now'))"
  ).run();

  // Incident sans equipment_id (infrastructure)
  db.prepare(
    "INSERT INTO issues (id, type, status, urgency, reporter, department, description, location_text, created_at) VALUES ('ISS-REL-NOEQ', 'Panne', 'Open', 'Low', 'Reporter', 'Urgences', 'Desc infra', 'Bloc A — Salle 3', datetime('now'))"
  ).run();
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

describe('GET /api/issues/:id — related_issues', () => {
  test('✅ incident sans equipment_id → related_issues vide', async () => {
    const res = await request(app)
      .get('/api/issues/ISS-REL-NOEQ')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.related_issues)).toBe(true);
    expect(res.body.related_issues).toHaveLength(0);
  });

  test('✅ incident avec équipement ayant 5 antécédents → max 3 items triés DESC', async () => {
    const res = await request(app)
      .get('/api/issues/ISS-REL-CURR')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    const items = res.body.related_issues;
    expect(Array.isArray(items)).toBe(true);
    expect(items.length).toBe(3);
    // L'incident courant n'est pas dans la liste
    expect(items.every((i) => i.id !== 'ISS-REL-CURR')).toBe(true);
    // Triés DESC par created_at : le plus récent en premier
    expect(items[0].id).toBe('ISS-REL-OLD-005');
    expect(items[1].id).toBe('ISS-REL-OLD-004');
    expect(items[2].id).toBe('ISS-REL-OLD-003');
    // Champs attendus
    expect(items[0]).toMatchObject({
      id: expect.any(String),
      type: expect.any(String),
      status: expect.any(String),
      urgency: expect.any(String),
      created_at: expect.any(String),
      reporter: expect.any(String),
    });
  });
});
