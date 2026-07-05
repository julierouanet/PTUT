'use strict';

// ── RBAC supervisor « consultation + rapports » — défense en profondeur ───────
// Le rôle supervisor ne peut plus AGIR sur les incidents : chaque route de
// mutation (et le GET assignable-technicians, qui ne sert qu'au flux de
// réassignation) doit répondre 403 pour un token supervisor.
// Le comportement reste inchangé pour admin et technician_biomedical
// (≠ 403 — la suite de la validation peut répondre 200/400/404/409).
// Le supervisor conserve la consultation (GET) et le signalement (POST /api/issues).

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Rôle courant injecté par les tests ────────────────────────────────────────
let mockCurrentRoles = ['supervisor'];

function setTestRole(...roles) {
  mockCurrentRoles = roles;
}

// ── Mock du middleware d'auth ─────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-sup-0001',
      email:      'supervisor@kabutare.rw',
      name:       'Superviseur Test',
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
  sendPushToUser:  jest.fn().mockResolvedValue(undefined),
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

  // ── Correction schéma issues en DB :memory: ────────────────────────────────
  // Même correctif que rbac_equipment_issues.test.js : la migration "rebuild
  // issues" recrée la table sans les colonnes des ALTER TABLE précédents.
  const existingCols = new Set(db.pragma('table_info(issues)').map((c) => c.name));
  for (const col of ['location_text', 'location_tag', 'reporter_phone', 'taken_at']) {
    if (!existingCols.has(col)) {
      try { db.exec(`ALTER TABLE issues ADD COLUMN ${col} TEXT`); } catch (_) {}
    }
  }

  // Équipement et incident de référence
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES ('eq-sup-test', 'Moniteur cardiaque test', 'OPD', 'Monitoring', 'Operational')
  `).run();
  db.prepare(`
    INSERT OR IGNORE INTO issues (
      id, equipment_id, equipment_name, issue_category, assigned_group,
      department, type, description, reporter, urgency, status, created_at
    ) VALUES (
      'iss-sup-test', 'eq-sup-test', 'Moniteur cardiaque test', 'Biomédical', 'Biomédical',
      'OPD', 'Panne', 'Incident de référence RBAC supervisor', 'Dr. Test', 'Urgent', 'Assigned',
      datetime('now','localtime')
    )
  `).run();
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// ── Table des routes retirées au supervisor (§2 de la spec) ──────────────────
// [méthode, chemin, body] — le body minimal suffit : requireRole tranche AVANT
// toute validation, donc le supervisor reçoit 403 quel que soit le contenu.
const ROUTES_RETIREES = [
  ['get',    '/api/issues/iss-sup-test/assignable-technicians', undefined],
  ['put',    '/api/issues/iss-sup-test',                        { status: 'In Progress' }],
  ['patch',  '/api/issues/iss-sup-test/escalate',               { escalation_status: 'Waiting Materials', escalation_comment: 'Test' }],
  ['patch',  '/api/issues/iss-sup-test/close-as-disposed',      {}],
  ['patch',  '/api/issues/iss-sup-test/reassign',               {}],
  ['patch',  '/api/issues/iss-sup-test/reject',                 { reason_code: 'duplicate' }],
  ['patch',  '/api/issues/iss-sup-test/detach',                 { reason: 'Motif suffisamment long pour la validation' }],
  ['patch',  '/api/issues/iss-sup-test/link-equipment',         { equipment_id: 'eq-sup-test' }],
  ['post',   '/api/issues/iss-sup-test/documents',              {}],
  ['delete', '/api/issues/iss-sup-test/documents/1',            undefined],
  ['put',    '/api/issues/iss-sup-test/report',                 {}],
  ['post',   '/api/issues/iss-sup-test/report/finalize',        {}],
  ['put',    '/api/issues/iss-sup-test/sessions/active',        {}],
  ['post',   '/api/issues/iss-sup-test/sessions/active/close',  {}],
];

function call(role, method, url, body) {
  setTestRole(role);
  let req = request(app)[method](url).set('Authorization', 'Bearer fake-token');
  if (body !== undefined) req = req.send(body);
  return req;
}

describe('RBAC supervisor — routes de mutation des incidents retirées', () => {
  test.each(ROUTES_RETIREES)(
    '🚫 supervisor %s %s → 403',
    async (method, url, body) => {
      const res = await call('supervisor', method, url, body);
      expect(res.status).toBe(403);
    }
  );

  test.each(ROUTES_RETIREES)(
    '✅ admin %s %s → comportement inchangé (≠ 403)',
    async (method, url, body) => {
      const res = await call('admin', method, url, body);
      expect(res.status).not.toBe(403);
    }
  );

  test.each(ROUTES_RETIREES)(
    '✅ technician_biomedical %s %s → passe le contrôle de rôle',
    async (method, url, body) => {
      const res = await call('technician_biomedical', method, url, body);
      // Un technicien peut recevoir un 403 métier APRÈS requireRole (ex: detach
      // d'un incident non assigné à lui) — mais jamais le 403 « Rôle requis ».
      if (res.status === 403) {
        expect(res.body.error || '').not.toMatch(/Rôle requis/);
      }
    }
  );
});

describe('RBAC supervisor — consultation et signalement conservés', () => {
  test('✅ GET /api/issues → 200', async () => {
    const res = await call('supervisor', 'get', '/api/issues');
    expect(res.status).toBe(200);
  });

  test('✅ GET /api/issues/:id → 200', async () => {
    const res = await call('supervisor', 'get', '/api/issues/iss-sup-test');
    expect(res.status).toBe(200);
  });

  test('✅ POST /api/issues (signaler) → 201', async () => {
    const res = await call('supervisor', 'post', '/api/issues', {
      id:             `iss-sup-new-${Date.now()}`,
      equipment_id:   'eq-sup-test',
      equipment_name: 'Moniteur cardiaque test',
      department:     'OPD',
      type:           'Panne',
      description:    'Signalement par un superviseur — doit rester autorisé',
      reporter:       'Superviseur Test',
      urgency:        'Moyen',
    });
    expect(res.status).toBe(201);
  });
});
