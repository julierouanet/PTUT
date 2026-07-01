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

function seedEquipment(id, status = 'Operational') {
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES (?, ?, 'OPD', 'Monitoring', ?)
  `).run(id, `Équipement ${id}`, status);
}

// Crée un incident résolu directement (created_at/resolved_at explicites pour un MTTR maîtrisé).
function seedResolvedIssue(id, equipmentId, { createdAt, resolvedAt, technician = 'Jean Tech' } = {}) {
  db.prepare(`
    INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, status, assigned_technician, created_at, resolved_at)
    VALUES (?, ?, ?, 'OPD', 'Panne', 'desc', 'Testeur', 'Completed', ?, ?, ?)
  `).run(id, equipmentId, `Équipement ${equipmentId}`, technician, createdAt, resolvedAt);
}

function seedInterventionReport(issueId, { durationHours = null, rootCause = null, summary = null, reportStatus = 'draft' } = {}) {
  db.prepare(`
    INSERT INTO issue_intervention_reports (issue_id, summary, root_cause, duration_hours, report_status)
    VALUES (?, ?, ?, ?, ?)
  `).run(issueId, summary, rootCause, durationHours, reportStatus);
}

function seedSession(issueId, loopNumber) {
  db.prepare(`
    INSERT INTO issue_intervention_sessions (issue_id, loop_number, resolved, closed_at)
    VALUES (?, ?, 1, datetime('now','localtime'))
  `).run(issueId, loopNumber);
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
// GET /api/equipment/:id/final-report
// =============================================================================
describe('GET /api/equipment/:id/final-report', () => {
  test('✅ équipement sans intervention → valeurs neutres, jamais d\'erreur', async () => {
    seedEquipment('eq-fr-empty');
    const res = await request(app)
      .get('/api/equipment/eq-fr-empty/final-report')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.equipment_id).toBe('eq-fr-empty');
    expect(res.body.summary).toEqual({
      total_interventions: 0,
      mttr_hours_avg: null,
      reopened_rate_pct: null,
      downtime_hours_total: 0,
    });
    expect(res.body.interventions).toEqual([]);
  });

  test('✅ 2 incidents résolus dont 1 réouvert avec rapport finalisé → KPI corrects', async () => {
    seedEquipment('eq-fr-two');

    // Incident 1 : réouvert (loop 1 puis 2), rapport finalisé avec duration_hours connu
    seedResolvedIssue('iss-fr-1', 'eq-fr-two', {
      createdAt: '2026-06-01 08:00:00',
      resolvedAt: '2026-06-01 12:00:00', // 4h
    });
    seedSession('iss-fr-1', 1);
    seedSession('iss-fr-1', 2);
    seedInterventionReport('iss-fr-1', { durationHours: 4.0, rootCause: 'Fusible HS', summary: 'Remplacé', reportStatus: 'finalized' });

    // Incident 2 : résolu du premier coup, rapport en brouillon (exclu du downtime)
    seedResolvedIssue('iss-fr-2', 'eq-fr-two', {
      createdAt: '2026-06-05 09:00:00',
      resolvedAt: '2026-06-05 11:00:00', // 2h
    });
    seedSession('iss-fr-2', 1);
    seedInterventionReport('iss-fr-2', { durationHours: 2.0, rootCause: 'Calibration', summary: 'OK', reportStatus: 'draft' });

    const res = await request(app)
      .get('/api/equipment/eq-fr-two/final-report')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.summary.total_interventions).toBe(2);
    expect(res.body.summary.reopened_rate_pct).toBe(50.0);
    expect(res.body.summary.downtime_hours_total).toBe(4.0); // seul le rapport finalisé compte
    expect(res.body.summary.mttr_hours_avg).not.toBeNull();
    expect(typeof res.body.summary.mttr_hours_avg).toBe('number');

    const first = res.body.interventions.find((i) => i.issue_id === 'iss-fr-1');
    expect(first.reopened).toBe(true);
    const second = res.body.interventions.find((i) => i.issue_id === 'iss-fr-2');
    expect(second.reopened).toBe(false);
  });

  test('🚫 équipement inconnu → 404', async () => {
    const res = await request(app)
      .get('/api/equipment/eq-fr-fantome/final-report')
      .set('Authorization', 'Bearer fake-token');
    expect(res.status).toBe(404);
  });

  test('✅ équipement Disposed avec historique → 200 (pas de 404/403)', async () => {
    seedEquipment('eq-fr-disposed', 'Disposed');
    seedResolvedIssue('iss-fr-disposed', 'eq-fr-disposed', {
      createdAt: '2026-05-01 08:00:00',
      resolvedAt: '2026-05-01 10:00:00',
    });

    const res = await request(app)
      .get('/api/equipment/eq-fr-disposed/final-report')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body.summary.total_interventions).toBe(1);
  });
});
