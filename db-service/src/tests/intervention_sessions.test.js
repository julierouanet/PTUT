'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

let mockCurrentRoles = ['admin'];
function setTestRole(...roles) { mockCurrentRoles = roles; }

jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-tech-0001',
      email:      'tech@kabutare.rw',
      name:       'Tech Test',
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

function seedIssue(id, { status = 'In Progress', equipmentId = 'eq-sess' } = {}) {
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES (?, ?, 'OPD', 'Monitoring', 'Operational')
  `).run(equipmentId, `Équipement ${equipmentId}`);
  db.prepare(`
    INSERT INTO issues (id, equipment_id, equipment_name, department, type, description, reporter, status, created_at)
    VALUES (?, ?, ?, 'OPD', 'Panne', 'desc', 'Testeur', ?, datetime('now','localtime'))
  `).run(id, equipmentId, `Équipement ${equipmentId}`, status);
}

beforeAll(() => { db = getDb(); setTestRole('admin'); });
afterAll(() => { if (server) server.close(); closeDb(); });
beforeEach(() => {
  db.prepare('DELETE FROM issue_intervention_sessions').run();
  db.prepare('DELETE FROM issues').run();
});

const AUTH = { Authorization: 'Bearer fake-token' };

// =============================================================================
// 1. GET /:id/sessions
// =============================================================================
describe('GET /api/issues/:id/sessions', () => {
  test('🚫 incident inexistant → 404', async () => {
    const res = await request(app).get('/api/issues/iss-fantome/sessions').set(AUTH);
    expect(res.status).toBe(404);
  });

  test('✅ liste vide si aucune session', async () => {
    seedIssue('iss-list-01');
    const res = await request(app).get('/api/issues/iss-list-01/sessions').set(AUTH);
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('✅ liste triée par loop_number', async () => {
    seedIssue('iss-list-02');
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis, closed_at)
      VALUES ('iss-list-02', 2, 'diag2', datetime('now','localtime'))`).run();
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis, closed_at)
      VALUES ('iss-list-02', 1, 'diag1', datetime('now','localtime'))`).run();
    const res = await request(app).get('/api/issues/iss-list-02/sessions').set(AUTH);
    expect(res.status).toBe(200);
    expect(res.body[0].loop_number).toBe(1);
    expect(res.body[1].loop_number).toBe(2);
  });
});

// =============================================================================
// 2. PUT /:id/sessions/active
// =============================================================================
describe('PUT /api/issues/:id/sessions/active', () => {
  test('🚫 incident inexistant → 404', async () => {
    const res = await request(app)
      .put('/api/issues/iss-fantome/sessions/active')
      .set(AUTH)
      .send({ diagnosis: 'diag' });
    expect(res.status).toBe(404);
  });

  test('🚫 incident non « In Progress » → 400', async () => {
    seedIssue('iss-not-inprog', { status: 'Reported' });
    const res = await request(app)
      .put('/api/issues/iss-not-inprog/sessions/active')
      .set(AUTH)
      .send({ diagnosis: 'diag' });
    expect(res.status).toBe(400);
  });

  test('✅ crée une session (loop_number = 1)', async () => {
    seedIssue('iss-create-01');
    const res = await request(app)
      .put('/api/issues/iss-create-01/sessions/active')
      .set(AUTH)
      .send({ diagnosis: 'Premier diagnostic', action_taken: 'Nettoyage', outcome: 'Partiel' });
    expect(res.status).toBe(200);
    expect(res.body.loop_number).toBe(1);
    expect(res.body.diagnosis).toBe('Premier diagnostic');
    expect(res.body.closed_at).toBeNull();
  });

  test('✅ ne duplique pas la session active sur double appel', async () => {
    seedIssue('iss-nodup-01');
    await request(app)
      .put('/api/issues/iss-nodup-01/sessions/active')
      .set(AUTH)
      .send({ diagnosis: 'diag1' });
    const res2 = await request(app)
      .put('/api/issues/iss-nodup-01/sessions/active')
      .set(AUTH)
      .send({ diagnosis: 'diag2', action_taken: 'action2' });
    expect(res2.status).toBe(200);
    const sessions = db.prepare(
      'SELECT * FROM issue_intervention_sessions WHERE issue_id = ?'
    ).all('iss-nodup-01');
    // Une seule session créée, mise à jour
    expect(sessions.length).toBe(1);
    expect(sessions[0].diagnosis).toBe('diag2');
    expect(sessions[0].action_taken).toBe('action2');
  });

  test('✅ loop_number incrémenté si session précédente fermée', async () => {
    seedIssue('iss-loop-01');
    // Insérer une session fermée (loop 1)
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis, closed_at)
      VALUES ('iss-loop-01', 1, 'diag1', datetime('now','localtime'))`).run();
    const res = await request(app)
      .put('/api/issues/iss-loop-01/sessions/active')
      .set(AUTH)
      .send({ diagnosis: 'diag2' });
    expect(res.status).toBe(200);
    expect(res.body.loop_number).toBe(2);
  });
});

// =============================================================================
// 3. POST /:id/sessions/active/close
// =============================================================================
describe('POST /api/issues/:id/sessions/active/close', () => {
  test('🚫 pas de session active → 400', async () => {
    seedIssue('iss-close-none');
    const res = await request(app)
      .post('/api/issues/iss-close-none/sessions/active/close')
      .set(AUTH)
      .send({ resolved: false, next_actions: 'Recommander technicien spécialisé' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Aucune session active/);
  });

  test('🚫 resolved=false sans next_actions → 400', async () => {
    seedIssue('iss-close-val');
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis)
      VALUES ('iss-close-val', 1, 'diag')`).run();
    const res = await request(app)
      .post('/api/issues/iss-close-val/sessions/active/close')
      .set(AUTH)
      .send({ resolved: false });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/next_actions/);
  });

  test('✅ clôture résolue', async () => {
    seedIssue('iss-close-res');
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis, action_taken)
      VALUES ('iss-close-res', 1, 'diag', 'action')`).run();
    const res = await request(app)
      .post('/api/issues/iss-close-res/sessions/active/close')
      .set(AUTH)
      .send({ resolved: true, outcome: 'Résolu définitivement' });
    expect(res.status).toBe(200);
    expect(res.body.resolved).toBe(1);
    expect(res.body.closed_at).not.toBeNull();
    expect(res.body.duration_hours).not.toBeNull();
  });

  test('✅ clôture non résolue avec next_actions', async () => {
    seedIssue('iss-close-nores');
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis)
      VALUES ('iss-close-nores', 1, 'diag')`).run();
    const res = await request(app)
      .post('/api/issues/iss-close-nores/sessions/active/close')
      .set(AUTH)
      .send({ resolved: false, next_actions: 'Commander pièce de rechange urgente' });
    expect(res.status).toBe(200);
    expect(res.body.resolved).toBe(0);
    expect(res.body.next_actions).toBe('Commander pièce de rechange urgente');
    expect(res.body.closed_at).not.toBeNull();
  });

  test('✅ plus de session active après clôture', async () => {
    seedIssue('iss-close-clean');
    db.prepare(`INSERT INTO issue_intervention_sessions
      (issue_id, loop_number, diagnosis)
      VALUES ('iss-close-clean', 1, 'diag')`).run();
    await request(app)
      .post('/api/issues/iss-close-clean/sessions/active/close')
      .set(AUTH)
      .send({ resolved: true, outcome: 'OK' });
    const active = db.prepare(
      'SELECT * FROM issue_intervention_sessions WHERE issue_id = ? AND closed_at IS NULL'
    ).get('iss-close-clean');
    expect(active).toBeUndefined();
  });
});
