'use strict';

const request = require('supertest');

// ── Mocks (hoistés par Jest avant tout require) ───────────────────────────────

jest.mock('express-rate-limit', () => () => (req, res, next) => next());

jest.mock('../src/utils/keycloakAdmin', () => ({
  kcAdminFetch:        jest.fn(),
  assignRolesToUser:   jest.fn().mockResolvedValue(undefined),
  removeRolesFromUser: jest.fn().mockResolvedValue(undefined),
  getUserRoleNames:    jest.fn().mockResolvedValue([]),
  mapKcUser:           jest.fn(),
  SYSTEM_ROLES:        new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));

jest.mock('../src/utils/logger', () => ({
  sendLog: jest.fn(),
  reqMeta: jest.fn(() => ({ ip_address: '127.0.0.1', user_agent: 'jest' })),
}));

// verifyToken mocké pour contourner la validation JWKS Keycloak.
// requireAdmin conserve sa logique réelle.
jest.mock('../src/middleware/auth', () => ({
  verifyToken: jest.fn(),
  requireAdmin: (req, res, next) => {
    if (!req.user?.roles?.includes('admin'))
      return res.status(403).json({ error: 'Access restricted to administrators' });
    next();
  },
  SYSTEM_ROLES: new Set([
    'offline_access', 'uma_authorization', 'default-roles-kabutare-hospital',
  ]),
}));

// ── Bootstrap ─────────────────────────────────────────────────────────────────

process.env.DB_PATH = ':memory:';

const { app, server } = require('../src/index');
const { verifyToken } = require('../src/middleware/auth');

// Helpers pour simuler les utilisateurs authentifiés
const asAdmin = (req, res, next) => {
  req.user = { id: 'admin-uuid', name: 'Admin Test', roles: ['admin'] };
  next();
};
const asUser = (req, res, next) => {
  req.user = { id: 'user-uuid', name: 'Staff Test', roles: ['hospitalStaff'] };
  next();
};

afterAll(() => server.close());

// ── Tests GET /api/feature-flags ───────────────────────────────────────────────

describe('GET /api/feature-flags', () => {
  beforeEach(() => {
    verifyToken.mockImplementation(asAdmin);
  });

  it('retourne la liste des feature flags avec is_global_active et role_overrides', async () => {
    const res = await request(app).get('/api/feature-flags');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Les deux flags par défaut doivent être présents
    const ids = res.body.map((f) => f.id);
    expect(ids).toContain('equipment');
    expect(ids).toContain('inventory');
  });

  it('chaque flag possède les champs attendus par le modèle Flutter', async () => {
    const res = await request(app).get('/api/feature-flags');
    expect(res.status).toBe(200);
    for (const flag of res.body) {
      expect(flag).toHaveProperty('id');
      expect(flag).toHaveProperty('name');
      expect(flag).toHaveProperty('is_global_active');
      expect(flag).toHaveProperty('role_overrides');
      expect(typeof flag.is_global_active).toBe('boolean');
      expect(typeof flag.role_overrides).toBe('object');
    }
  });

  it('accepte tout utilisateur authentifie (pas seulement admin)', async () => {
    verifyToken.mockImplementation(asUser);
    const res = await request(app).get('/api/feature-flags');
    expect(res.status).toBe(200);
  });

  it('tous les flags sont activés globalement par défaut', async () => {
    const res = await request(app).get('/api/feature-flags');
    for (const flag of res.body) {
      expect(flag.is_global_active).toBe(true);
    }
  });
});

// ── Tests PUT /api/feature-flags/:id ──────────────────────────────────────────

describe('PUT /api/feature-flags/:id', () => {
  beforeEach(() => {
    verifyToken.mockImplementation(asAdmin);
  });

  it('désactive le module inventory globalement', async () => {
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({ is_global_active: false, role_overrides: {} });

    expect(res.status).toBe(200);
    expect(res.body.is_global_active).toBe(false);
  });

  it('réactive le module inventory après désactivation', async () => {
    await request(app)
      .put('/api/feature-flags/inventory')
      .send({ is_global_active: false, role_overrides: {} });

    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({ is_global_active: true, role_overrides: {} });

    expect(res.status).toBe(200);
    expect(res.body.is_global_active).toBe(true);
  });

  it('enregistre un override par rôle', async () => {
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({
        is_global_active: true,
        role_overrides: { hospitalStaff: false },
      });

    expect(res.status).toBe(200);
    expect(res.body.role_overrides).toMatchObject({ hospitalStaff: false });
  });

  it('remplace les overrides existants à chaque PUT', async () => {
    // Premier PUT : deux overrides
    await request(app)
      .put('/api/feature-flags/inventory')
      .send({
        is_global_active: true,
        role_overrides: { hospitalStaff: false, supervisor: true },
      });

    // Deuxième PUT : un seul override (l'autre doit disparaître)
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({
        is_global_active: true,
        role_overrides: { hospitalStaff: false },
      });

    expect(res.status).toBe(200);
    expect(Object.keys(res.body.role_overrides)).toHaveLength(1);
    expect(res.body.role_overrides).not.toHaveProperty('supervisor');
  });

  it('reflète la désactivation dans le GET suivant', async () => {
    await request(app)
      .put('/api/feature-flags/equipment')
      .send({ is_global_active: false, role_overrides: {} });

    const res = await request(app).get('/api/feature-flags');
    const eq  = res.body.find((f) => f.id === 'equipment');
    expect(eq.is_global_active).toBe(false);
  });

  it('retourne 404 pour un flag inexistant', async () => {
    const res = await request(app)
      .put('/api/feature-flags/module_inexistant')
      .send({ is_global_active: false, role_overrides: {} });

    expect(res.status).toBe(404);
  });

  it('retourne 400 si is_global_active est absent', async () => {
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({ role_overrides: {} });

    expect(res.status).toBe(400);
  });

  it('retourne 400 si is_global_active nest pas un booleen', async () => {
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({ is_global_active: 'yes', role_overrides: {} });

    expect(res.status).toBe(400);
  });

  it('retourne 400 si un rôle inconnu est passé en override', async () => {
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({
        is_global_active: true,
        role_overrides: { roleInconnu: false },
      });

    expect(res.status).toBe(400);
  });

  it('retourne 403 si l\'utilisateur n\'est pas admin', async () => {
    verifyToken.mockImplementation(asUser);
    const res = await request(app)
      .put('/api/feature-flags/inventory')
      .send({ is_global_active: false, role_overrides: {} });

    expect(res.status).toBe(403);
  });

  it('refuse de désactiver le module settings', async () => {
    const res = await request(app)
      .put('/api/feature-flags/settings')
      .send({ is_global_active: false, role_overrides: {} });

    // 400 (settings inexistant → 404) ou 404 (settings absent du seed)
    // Dans les deux cas, le module ne doit pas être désactivé
    expect([400, 404]).toContain(res.status);
  });
});
