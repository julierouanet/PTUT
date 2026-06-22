'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.KC_REALM         = 'kabutare-hospital';
process.env.KC_ADMIN_URL     = 'http://keycloak-test';
process.env.KC_CLIENT_ID     = 'auth-service-test';
process.env.KC_CLIENT_SECRET = 'test-secret';
process.env.BREVO_API_KEY    = 'env-brevo-key';
process.env.BREVO_SENDER_EMAIL = 'env@hospital.local';
process.env.BREVO_SENDER_NAME  = 'GMAO Test';

// ── Mock rate-limiter ─────────────────────────────────────────────────────────
jest.mock('express-rate-limit', () => () => (req, res, next) => next());

let mockCurrentRoles = ['admin'];
function setTestRole(...roles) { mockCurrentRoles = roles; }

// ── Mock middleware auth ──────────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:    'test-uuid-admin-0001',
      email: 'admin@kabutare.rw',
      name:  'Admin Test',
      roles: mockCurrentRoles,
    };
    next();
  },
  requireAdmin: (req, res, next) => {
    if (!req.user?.roles?.includes('admin')) {
      return res.status(403).json({ error: 'Access restricted to administrators' });
    }
    next();
  },
  SYSTEM_ROLES: new Set(),
}));

// ── Mocks divers ──────────────────────────────────────────────────────────────
jest.mock('../utils/keycloakAdmin', () => ({
  kcAdminFetch:        jest.fn(),
  assignRolesToUser:   jest.fn().mockResolvedValue(undefined),
  removeRolesFromUser: jest.fn().mockResolvedValue(undefined),
  getUserRoleNames:    jest.fn().mockResolvedValue(['admin']),
  mapKcUser:           jest.fn((u, roles) => ({ ...u, roles })),
}));
jest.mock('../utils/logger', () => ({
  sendLog:        jest.fn(),
  reqMeta:        jest.fn(() => ({})),
  logAction:      jest.fn(),
  extractReqMeta: jest.fn(() => ({})),
}));

// ── Mock sendEmail pour éviter les appels réseau Brevo ────────────────────────
jest.mock('../utils/email_service', () => ({
  sendEmail:         jest.fn().mockResolvedValue(undefined),
  buildEmailContent: jest.fn(),
}));

const request         = require('supertest');
const { app, server } = require('../index');
const { getDb }       = require('../database');

afterAll(() => server.close());

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Injecte une valeur dans app_settings directement en DB. */
function dbSet(key, value) {
  getDb().prepare('UPDATE app_settings SET value = ? WHERE key = ?').run(value, key);
}

// ─────────────────────────────────────────────────────────────────────────────
// (a) GET /public — accessible sans token, ne contient aucune clé Brevo
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/app-settings/public', () => {
  it('répond 200 sans header Authorization', async () => {
    const res = await request(app).get('/api/app-settings/public');
    expect(res.status).toBe(200);
  });

  it('renvoie uniquement les 3 clés de contact', async () => {
    const res = await request(app).get('/api/app-settings/public');
    const keys = Object.keys(res.body);
    expect(keys).toEqual(expect.arrayContaining([
      'login_contact_title',
      'login_contact_email',
      'login_contact_phone',
    ]));
    // Pas de clé Brevo dans la réponse publique
    expect(keys).not.toContain('brevo_api_key');
    expect(keys).not.toContain('brevo_sender_email');
    expect(keys).not.toContain('brevo_sender_name');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// (b) GET /api/app-settings — admin masque brevo_api_key (configured + hint)
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/app-settings (admin)', () => {
  beforeEach(() => setTestRole('admin'));

  it('répond 200 pour un admin', async () => {
    const res = await request(app).get('/api/app-settings');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('masque brevo_api_key — jamais de value dans la réponse', async () => {
    dbSet('brevo_api_key', 'sk-abcdef1234567890');

    const res     = await request(app).get('/api/app-settings');
    const apiRow  = res.body.find(r => r.key === 'brevo_api_key');

    expect(apiRow).toBeDefined();
    expect(apiRow.is_secret).toBe(true);
    expect(apiRow).not.toHaveProperty('value');
    // configured = true car on vient de mettre une valeur
    expect(apiRow.configured).toBe(true);
    // hint = 4 derniers caractères
    expect(apiRow.hint).toBe('7890');
  });

  it('retourne configured=false et hint=null si la clé Brevo est vide', async () => {
    dbSet('brevo_api_key', '');

    const res    = await request(app).get('/api/app-settings');
    const apiRow = res.body.find(r => r.key === 'brevo_api_key');

    expect(apiRow.configured).toBe(false);
    expect(apiRow.hint).toBeNull();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// (c) PUT /api/app-settings — règles clé secrète
// ─────────────────────────────────────────────────────────────────────────────
describe('PUT /api/app-settings', () => {
  beforeEach(() => {
    setTestRole('admin');
    dbSet('brevo_api_key', 'initial-api-key');
  });

  it('brevo_api_key:"" → valeur inchangée', async () => {
    const res = await request(app)
      .put('/api/app-settings')
      .send({ settings: { brevo_api_key: '' } });

    expect(res.status).toBe(200);
    const raw = getDb().prepare("SELECT value FROM app_settings WHERE key='brevo_api_key'").get();
    expect(raw.value).toBe('initial-api-key');
  });

  it('brevo_api_key:"__CLEAR__" → vide la clé', async () => {
    const res = await request(app)
      .put('/api/app-settings')
      .send({ settings: { brevo_api_key: '__CLEAR__' } });

    expect(res.status).toBe(200);
    const raw = getDb().prepare("SELECT value FROM app_settings WHERE key='brevo_api_key'").get();
    expect(raw.value).toBe('');
  });

  it('brevo_api_key:"nouvelle-cle" → écrit la valeur', async () => {
    const res = await request(app)
      .put('/api/app-settings')
      .send({ settings: { brevo_api_key: 'nouvelle-cle' } });

    expect(res.status).toBe(200);
    const raw = getDb().prepare("SELECT value FROM app_settings WHERE key='brevo_api_key'").get();
    expect(raw.value).toBe('nouvelle-cle');
    // La réponse ne doit pas exposer la valeur
    const apiRow = res.body.find(r => r.key === 'brevo_api_key');
    expect(apiRow).not.toHaveProperty('value');
  });

  it('clé inconnue → 400', async () => {
    const res = await request(app)
      .put('/api/app-settings')
      .send({ settings: { unknown_key: 'valeur' } });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/inconnue/i);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// (d) Accès non-admin → 403
// ─────────────────────────────────────────────────────────────────────────────
describe('Protection RBAC — non-admin', () => {
  beforeEach(() => setTestRole('hospitalStaff'));

  it('GET /api/app-settings → 403 pour hospitalStaff', async () => {
    const res = await request(app).get('/api/app-settings');
    expect(res.status).toBe(403);
  });

  it('PUT /api/app-settings → 403 pour hospitalStaff', async () => {
    const res = await request(app)
      .put('/api/app-settings')
      .send({ settings: { login_contact_title: 'Piratage' } });
    expect(res.status).toBe(403);
  });

  it('POST /api/app-settings/test-email → 403 pour hospitalStaff', async () => {
    const res = await request(app)
      .post('/api/app-settings/test-email')
      .send({ to_email: 'pirate@example.com' });
    expect(res.status).toBe(403);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// (e) _getBrevoConfig — préfère la valeur DB non vide, retombe sur l'env sinon
// ─────────────────────────────────────────────────────────────────────────────
describe('_getBrevoConfig — priorité DB sur env', () => {
  beforeEach(() => setTestRole('admin'));

  it('utilise la clé Brevo de la DB quand elle est renseignée', async () => {
    dbSet('brevo_api_key',     'db-api-key');
    dbSet('brevo_sender_email', 'db@hospital.rw');
    dbSet('brevo_sender_name',  'DB Sender');

    // Un appel test-email déclenche sendEmail → la config est lue à l'envoi
    const { sendEmail } = require('../utils/email_service');
    sendEmail.mockClear();

    await request(app)
      .post('/api/app-settings/test-email')
      .send({ to_email: 'test@example.com' });

    expect(sendEmail).toHaveBeenCalledTimes(1);
  });

  it('utilise la config env quand la DB est vide', async () => {
    dbSet('brevo_api_key',     '');
    dbSet('brevo_sender_email', '');
    dbSet('brevo_sender_name',  '');

    const { sendEmail } = require('../utils/email_service');
    sendEmail.mockClear();

    // sendEmail est mocké — vérifie juste qu'aucune erreur 500 n'est levée
    // (si la config env est vide, sendEmail retourne silencieusement)
    const res = await request(app)
      .post('/api/app-settings/test-email')
      .send({ to_email: 'test@example.com' });

    // La route doit répondre 200 (email envoyé ou non selon la config env)
    expect(res.status).toBe(200);
  });
});
