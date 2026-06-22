'use strict';

const request = require('supertest');

// ── Mocks (hoistés par Jest avant tout require) ───────────────────────────────

jest.mock('express-rate-limit', () => () => (req, res, next) => next());

jest.mock('../src/utils/keycloakAdmin', () => ({
  kcAdminFetch:        jest.fn(),
  assignRolesToUser:   jest.fn().mockResolvedValue(undefined),
  removeRolesFromUser: jest.fn().mockResolvedValue(undefined),
  getUserRoleNames:    jest.fn().mockResolvedValue([]),
  mapKcUser: (u, roles) => ({
    id:         u.id,
    name:       `${u.firstName ?? ''} ${u.lastName ?? ''}`.trim() || u.username || '',
    first_name: u.firstName ?? '',
    last_name:  u.lastName  ?? '',
    email:      u.email     || u.username || '',
    department: u.attributes?.department?.[0] ?? '',
    phone:      u.attributes?.phone?.[0]       ?? null,
    is_active:  u.enabled ? 1 : 0,
    created_at: u.createdTimestamp ? new Date(u.createdTimestamp).toISOString() : '',
    roles,
  }),
  SYSTEM_ROLES: new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));

jest.mock('../src/utils/logger', () => ({
  sendLog: jest.fn(),
  reqMeta: jest.fn(() => ({ ip_address: '127.0.0.1', user_agent: 'jest' })),
}));

// verifyToken est mocké pour contourner la validation JWKS (RS256 Keycloak).
// requireAdmin conserve sa logique réelle (vérifie req.user.roles).
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

const { getDb, resetDb } = require('../src/database');
const { app, server }    = require('../src/index');
const { verifyToken }    = require('../src/middleware/auth');
const { kcAdminFetch, assignRolesToUser, getUserRoleNames } = require('../src/utils/keycloakAdmin');

// ── Fixtures ──────────────────────────────────────────────────────────────────

const STAFF = {
  id: 'kc-staff-1', email: 'staff@kabutare.rw', name: 'Jean Dupont',
  given_name: 'Jean', family_name: 'Dupont',
  roles: ['hospitalStaff'], department: 'Chirurgie', phone: null,
};

const ADMIN = {
  id: 'kc-admin-1', email: 'admin@kabutare.rw', name: 'Admin Test',
  given_name: 'Admin', family_name: 'Test',
  roles: ['admin'], department: 'Administration', phone: null,
};

// ── Helpers ───────────────────────────────────────────────────────────────────

// Injecte un utilisateur dans req.user pour simuler un token Keycloak valide.
function asUser(user) {
  verifyToken.mockImplementation((req, res, next) => { req.user = { ...user }; next(); });
}

// Construit une réponse Fetch simulée pour kcAdminFetch.
function kcResp(body, { status = 200, location } = {}) {
  const hdrs = location ? { location } : {};
  return {
    ok:     status >= 200 && status < 300,
    status,
    json:   () => Promise.resolve(body),
    text:   () => Promise.resolve(typeof body === 'string' ? body : JSON.stringify(body)),
    headers: { get: (n) => hdrs[n.toLowerCase()] ?? null },
  };
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────

beforeEach(() => {
  // resetAllMocks efface aussi les implémentations persistantes (mockResolvedValue sans Once)
  jest.resetAllMocks();

  // Comportement par défaut : pas de token → 401
  verifyToken.mockImplementation((req, res, next) =>
    res.status(401).json({ error: 'Token manquant' })
  );
  // Valeurs de retour par défaut pour les helpers Keycloak
  getUserRoleNames.mockResolvedValue([]);
  assignRolesToUser.mockResolvedValue(undefined);

  // Nettoyage des tables de workflow entre chaque test (évite les conflits 409)
  const db = getDb();
  db.prepare('DELETE FROM department_change_requests').run();
  db.prepare('DELETE FROM role_change_requests').run();
});

afterAll(() => {
  server.close();
  resetDb();
});

// =============================================================================
//  1. HEALTH CHECK
// =============================================================================

describe('GET /health', () => {
  test('retourne 200 avec status ok sans infos sensibles', async () => {
    // Isolation : le handler /health interroge Keycloak (OIDC discovery) via fetch.
    // On mocke global.fetch pour éviter tout appel réseau réel en test (correctif #9 audit).
    const realFetch = global.fetch;
    global.fetch = jest.fn().mockResolvedValue({
      ok:   true,
      json: () => Promise.resolve({ issuer: 'https://keycloak/realms/kabutare-hospital' }),
    });

    try {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.service).toBe('auth-service');
      const body = JSON.stringify(res.body);
      expect(body).not.toContain('secret');
      expect(body).not.toContain('password');
    } finally {
      global.fetch = realFetch;
    }
  });
});

// =============================================================================
//  2. GET /api/auth/me
// =============================================================================

describe('GET /api/auth/me', () => {
  test('sans token → 401', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  test('hospitalStaff reçoit son profil et ses permissions SQLite', async () => {
    asUser(STAFF);
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(STAFF.id);
    expect(res.body.email).toBe(STAFF.email);
    expect(res.body.roles).toEqual(['hospitalStaff']);
    // Seed database.js : hospitalStaff → ['viewEquipment', 'reportIssue', 'trackIssues']
    expect(res.body.permissions).toEqual(
      expect.arrayContaining(['viewEquipment', 'reportIssue', 'trackIssues'])
    );
    expect(res.body.permissions).not.toContain('manageUsers');
    expect(res.body.permissions).not.toContain('changeDepartment');
  });

  test('admin reçoit toutes les permissions', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(res.body.roles).toContain('admin');
    ['manageUsers', 'manageEquipment', 'changeDepartment', 'generateReports'].forEach((p) => {
      expect(res.body.permissions).toContain(p);
    });
  });

  test('rôle inconnu → permissions vides', async () => {
    asUser({ ...STAFF, roles: ['role_inexistant'] });
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(res.body.permissions).toEqual([]);
  });

  test('le mot de passe ne figure jamais dans la réponse', async () => {
    asUser(STAFF);
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake');

    expect(JSON.stringify(res.body)).not.toMatch(/password/i);
  });
});

// =============================================================================
//  3. POST /api/auth/register (public — pas de verifyToken)
// =============================================================================

describe('POST /api/auth/register', () => {
  const valid = {
    first_name: 'Alice', last_name: 'Martin',
    email: 'alice@kabutare.rw', password: 'Password1!', department: 'Chirurgie',
  };

  test('champs requis manquants → 400', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'x@k.rw', password: 'Pass1234!' });
    expect(res.status).toBe(400);
  });

  test('mot de passe trop court → 400', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...valid, password: 'abc' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/court/i);
  });

  test('email invalide → 400', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...valid, email: 'pas-un-email' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/email/i);
  });

  test('email déjà utilisé (Keycloak 409) → 409', async () => {
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 409 }));
    const res = await request(app).post('/api/auth/register').send(valid);
    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/déjà utilisé/);
  });

  test('inscription réussie → 201 avec id Keycloak', async () => {
    const fakeId = 'kc-new-user-uuid';
    kcAdminFetch
      .mockResolvedValueOnce(kcResp({}, { status: 201, location: `/users/${fakeId}` })) // POST /users
      .mockResolvedValueOnce(kcResp({}, { status: 204 }))                                // reset-password
      .mockResolvedValueOnce(kcResp({}, { status: 204 }));                               // send-verify-email
    assignRolesToUser.mockResolvedValueOnce(undefined);

    const res = await request(app).post('/api/auth/register').send(valid);
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(fakeId);
    expect(res.body.message).toMatch(/compte créé/i);
  });

  test('erreur Keycloak non-409 → 502', async () => {
    kcAdminFetch.mockResolvedValueOnce(kcResp('Internal error', { status: 500 }));
    const res = await request(app).post('/api/auth/register').send(valid);
    expect(res.status).toBe(502);
  });
});

// =============================================================================
//  3b. POST /api/auth/access-request (public — sécurisé audit 2026-06-10)
// =============================================================================

describe('POST /api/auth/access-request', () => {
  const valid = {
    first_name: 'Claire', last_name: 'Niyonsaba',
    email: 'claire@kabutare.rw', password: 'Password1!', department: 'Maternité',
  };

  // Récupère le mock sendLog (module mocké en tête de fichier)
  const { sendLog } = require('../src/utils/logger');

  test('champs requis manquants → 400', async () => {
    const res = await request(app)
      .post('/api/auth/access-request')
      .send({ email: 'x@k.rw' });
    expect(res.status).toBe(400);
  });

  test('email invalide → 400', async () => {
    const res = await request(app)
      .post('/api/auth/access-request')
      .send({ ...valid, email: 'pas-un-email' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/email/i);
  });

  test('mot de passe trop court → 400', async () => {
    const res = await request(app)
      .post('/api/auth/access-request')
      .send({ ...valid, password: 'abc' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/8 caractères/);
  });

  test('email déjà utilisé (Keycloak 409) → 409', async () => {
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 409 }));
    const res = await request(app).post('/api/auth/access-request').send(valid);
    expect(res.status).toBe(409);
  });

  test('création réussie → 201, compte créé email non vérifié SANS blocage de connexion', async () => {
    const fakeId = 'kc-access-req-uuid';
    kcAdminFetch
      .mockResolvedValueOnce(kcResp({}, { status: 201, location: `/users/${fakeId}` })) // POST /users
      .mockResolvedValueOnce(kcResp({}, { status: 204 }))                                // reset-password
      .mockResolvedValueOnce(kcResp({}, { status: 204 }));                               // send-verify-email
    assignRolesToUser.mockResolvedValueOnce(undefined);

    const res = await request(app).post('/api/auth/access-request').send(valid);
    expect(res.status).toBe(201);
    expect(res.body.message).toMatch(/vous pouvez vous connecter/i);

    // Le compte Keycloak doit être créé email non vérifié, sans requiredActions
    // (aucun blocage de connexion — VERIFY_EMAIL n'est plus posé)
    const createBody = JSON.parse(kcAdminFetch.mock.calls[0][1].body);
    expect(createBody.emailVerified).toBe(false);
    expect(createBody.requiredActions).toBeUndefined();

    // L'email de vérification doit être déclenché
    const verifyCall = kcAdminFetch.mock.calls.find(([url]) => url.includes('send-verify-email'));
    expect(verifyCall).toBeDefined();

    // Seul le rôle hospitalStaff est assigné
    expect(assignRolesToUser).toHaveBeenCalledWith(fakeId, ['hospitalStaff']);

    // Audit trail central
    expect(sendLog).toHaveBeenCalledWith(expect.objectContaining({
      action:      'access_request_account_created',
      target_type: 'user',
      target_id:   fakeId,
    }));
  });

  test('erreur Keycloak non-409 → 502', async () => {
    kcAdminFetch.mockResolvedValueOnce(kcResp('Internal error', { status: 500 }));
    const res = await request(app).post('/api/auth/access-request').send(valid);
    expect(res.status).toBe(502);
  });
});

// =============================================================================
//  4. POST /api/auth/forgot-password (anti-énumération — toujours 200)
// =============================================================================

describe('POST /api/auth/forgot-password', () => {
  test('email inconnu → 200 quand même (anti-énumération)', async () => {
    kcAdminFetch.mockResolvedValue(kcResp([], { status: 200 }));
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'inconnu@kabutare.rw' });
    expect(res.status).toBe(200);
  });

  test('sans body → 200', async () => {
    const res = await request(app).post('/api/auth/forgot-password').send({});
    expect(res.status).toBe(200);
  });

  test('réponse identique qu email existe ou non (timing blind)', async () => {
    kcAdminFetch.mockResolvedValue(kcResp([], { status: 200 }));
    const r1 = await request(app).post('/api/auth/forgot-password').send({ email: 'a@k.rw' });
    const r2 = await request(app).post('/api/auth/forgot-password').send({ email: 'b@k.rw' });
    expect(r1.body.message).toBe(r2.body.message);
  });
});

// =============================================================================
//  5. GET /api/users
// =============================================================================

describe('GET /api/users', () => {
  test('sans token → 401', async () => {
    const res = await request(app).get('/api/users');
    expect(res.status).toBe(401);
  });

  test('avec ?role=hospitalStaff → 200 (auth suffisante, pas besoin d être admin)', async () => {
    asUser(STAFF);
    const kcUsers = [
      { id: 'u1', firstName: 'Bob', lastName: 'Smith', email: 'b@k.rw', enabled: true, attributes: { department: ['Chirurgie'] } },
    ];
    kcAdminFetch.mockResolvedValueOnce(kcResp(kcUsers));

    const res = await request(app)
      .get('/api/users?role=hospitalStaff')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(1);
  });

  test('sans ?role, non-admin → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(403);
  });

  test('sans ?role, admin → liste complète', async () => {
    asUser(ADMIN);
    const kcUsers = [
      { id: 'u1', firstName: 'Alice', lastName: 'K', email: 'a@k.rw', enabled: true, attributes: {} },
    ];
    kcAdminFetch.mockResolvedValueOnce(kcResp(kcUsers));
    getUserRoleNames.mockResolvedValueOnce(['hospitalStaff']);

    const res = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(kcAdminFetch).toHaveBeenCalledWith(expect.stringContaining('/users'));
  });
});

// =============================================================================
//  6. POST /api/users (création admin)
// =============================================================================

describe('POST /api/users', () => {
  const valid = {
    first_name: 'Benoit', last_name: 'K', email: 'benoit@kabutare.rw',
    password: 'Pass1234!', department: 'IT', roles: ['technician_it'],
  };

  test('sans token → 401', async () => {
    const res = await request(app).post('/api/users').send(valid);
    expect(res.status).toBe(401);
  });

  test('non-admin → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake')
      .send(valid);
    expect(res.status).toBe(403);
  });

  test('champs requis manquants → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake')
      .send({ email: 'x@k.rw', password: 'Pass1234!' });
    expect(res.status).toBe(400);
  });

  test('rôle invalide → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake')
      .send({ ...valid, roles: ['superadmin'] });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/invalide/);
  });

  test('email déjà utilisé (Keycloak 409) → 409', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 409 }));
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake')
      .send(valid);
    expect(res.status).toBe(409);
  });

  test('création réussie → 201 avec id Keycloak', async () => {
    asUser(ADMIN);
    const kcId = 'new-kc-id-456';
    kcAdminFetch
      .mockResolvedValueOnce(kcResp({}, { status: 201, location: `/users/${kcId}` }))
      .mockResolvedValueOnce(kcResp({}, { status: 204 }));
    assignRolesToUser.mockResolvedValueOnce(undefined);

    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake')
      .send(valid);

    expect(res.status).toBe(201);
    expect(res.body.id).toBe(kcId);
    expect(assignRolesToUser).toHaveBeenCalledWith(kcId, ['technician_it']);
  });
});

// =============================================================================
//  7. DELETE /api/users/:id (admin)
// =============================================================================

describe('DELETE /api/users/:id', () => {
  test('supprimer son propre compte → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .delete(`/api/users/${ADMIN.id}`)
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/propre compte/i);
  });

  test('utilisateur introuvable → 404', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 404 }));
    const res = await request(app)
      .delete('/api/users/uuid-inconnu')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(404);
  });

  test('suppression réussie → 200', async () => {
    asUser(ADMIN);
    const targetUser = { id: 'kc-other-1', firstName: 'Cible', lastName: 'Test', email: 'cible@k.rw', enabled: true, attributes: {} };
    kcAdminFetch
      .mockResolvedValueOnce(kcResp(targetUser))            // GET /users/:id
      .mockResolvedValueOnce(kcResp({}, { status: 204 }));  // DELETE /users/:id
    getUserRoleNames.mockResolvedValueOnce(['hospitalStaff']);

    const res = await request(app)
      .delete('/api/users/kc-other-1')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/supprimé/i);
  });
});

// =============================================================================
//  8. PATCH /api/users/:id/toggle (admin)
// =============================================================================

describe('PATCH /api/users/:id/toggle', () => {
  test('utilisateur introuvable → 404', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 404 }));
    const res = await request(app)
      .patch('/api/users/uuid-inconnu/toggle')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(404);
  });

  test('désactivation d un compte actif → 200 is_active=0', async () => {
    asUser(ADMIN);
    const currentUser = { id: 'kc-active-1', firstName: 'X', lastName: 'Y', email: 'x@k.rw', enabled: true, attributes: {} };
    kcAdminFetch
      .mockResolvedValueOnce(kcResp(currentUser))           // GET /users/:id
      .mockResolvedValueOnce(kcResp({}, { status: 204 }));  // PUT /users/:id (toggle)

    const res = await request(app)
      .patch('/api/users/kc-active-1/toggle')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    expect(res.body.is_active).toBe(0);
  });
});

// =============================================================================
//  9. PUT /api/users/me/department
// =============================================================================

describe('PUT /api/users/me/department', () => {
  test('sans département → 400', async () => {
    asUser(STAFF);
    const res = await request(app)
      .put('/api/users/me/department')
      .set('Authorization', 'Bearer fake')
      .send({});
    expect(res.status).toBe(400);
  });

  test('hospitalStaff sans permission changeDepartment → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .put('/api/users/me/department')
      .set('Authorization', 'Bearer fake')
      .send({ department: 'Pédiatrie' });
    expect(res.status).toBe(403);
  });

  test('admin (a changeDepartment) → 200, appel Keycloak', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 204 }));

    const res = await request(app)
      .put('/api/users/me/department')
      .set('Authorization', 'Bearer fake')
      .send({ department: 'Bloc opératoire' });

    expect(res.status).toBe(200);
    expect(res.body.department).toBe('Bloc opératoire');
    expect(kcAdminFetch).toHaveBeenCalledWith(
      expect.stringContaining(ADMIN.id),
      expect.objectContaining({ method: 'PUT' })
    );
  });
});

// =============================================================================
//  10. POST /api/users/department-request
// =============================================================================

describe('POST /api/users/department-request', () => {
  test('sans token → 401', async () => {
    const res = await request(app).post('/api/users/department-request');
    expect(res.status).toBe(401);
  });

  test('département manquant → 400', async () => {
    asUser(STAFF);
    const res = await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake')
      .send({});
    expect(res.status).toBe(400);
  });

  test('même département que l utilisateur → 400', async () => {
    asUser(STAFF);
    const res = await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_department: STAFF.department });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/déjà dans ce département/);
  });

  test('demande créée → 201 avec id', async () => {
    asUser({ ...STAFF, id: 'kc-dept-req-ok' });
    const res = await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_department: 'Maternité' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
  });

  test('deuxième demande en attente pour le même user → 409', async () => {
    const user = { ...STAFF, id: 'kc-dept-dup' };
    asUser(user);
    await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_department: 'Bloc opératoire' });

    const res = await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_department: 'Pédiatrie' });
    expect(res.status).toBe(409);
  });
});

// =============================================================================
//  11. GET /api/users/department-requests (admin)
// =============================================================================

describe('GET /api/users/department-requests', () => {
  test('non-admin → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .get('/api/users/department-requests')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(403);
  });

  test('admin → 200 tableau', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .get('/api/users/department-requests')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('filtre ?status=pending retourne uniquement les demandes en attente', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .get('/api/users/department-requests?status=pending')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    res.body.forEach((r) => expect(r.status).toBe('pending'));
  });
});

// =============================================================================
//  12. PUT /api/users/department-requests/:id (admin approuve ou rejette)
// =============================================================================

describe('PUT /api/users/department-requests/:id', () => {
  let deptReqId;

  beforeEach(async () => {
    asUser({ ...STAFF, id: 'kc-dept-proc', department: 'Chirurgie' });
    const res = await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_department: 'Pédiatrie' });
    deptReqId = res.body.id;
  });

  test('statut invalide → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put(`/api/users/department-requests/${deptReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'maybe' });
    expect(res.status).toBe(400);
  });

  test('demande introuvable → 404', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put('/api/users/department-requests/uuid-inconnu')
      .set('Authorization', 'Bearer fake')
      .send({ status: 'approved' });
    expect(res.status).toBe(404);
  });

  test('rejet → 200, pas d appel Keycloak', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put(`/api/users/department-requests/${deptReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'rejected', admin_note: 'Motif de refus' });
    expect(res.status).toBe(200);
    expect(kcAdminFetch).not.toHaveBeenCalled();
  });

  test('approbation → 200 et met à jour le département via Keycloak', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 204 }));

    const res = await request(app)
      .put(`/api/users/department-requests/${deptReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'approved' });

    expect(res.status).toBe(200);
    expect(kcAdminFetch).toHaveBeenCalledWith(
      expect.stringContaining('kc-dept-proc'),
      expect.objectContaining({ method: 'PUT' })
    );
  });

  test('demande déjà traitée → 409', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 204 }));
    await request(app)
      .put(`/api/users/department-requests/${deptReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'approved' });

    const res = await request(app)
      .put(`/api/users/department-requests/${deptReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'rejected' });
    expect(res.status).toBe(409);
  });
});

// =============================================================================
//  13. POST /api/users/role-request
// =============================================================================

describe('POST /api/users/role-request', () => {
  test('sans token → 401', async () => {
    const res = await request(app).post('/api/users/role-request');
    expect(res.status).toBe(401);
  });

  test('rôle manquant → 400', async () => {
    asUser(STAFF);
    const res = await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({});
    expect(res.status).toBe(400);
  });

  test('rôle non demandable (admin) → 400', async () => {
    asUser(STAFF);
    const res = await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_role: 'admin' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/invalide/i);
  });

  test('utilisateur possède déjà le rôle → 400', async () => {
    asUser({ ...STAFF, roles: ['hospitalStaff', 'technician_it'] });
    const res = await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_role: 'technician_it' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/déjà ce rôle/);
  });

  test('demande créée → 201 avec id', async () => {
    asUser({ ...STAFF, id: 'kc-role-req-ok' });
    const res = await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_role: 'technician_biomedical' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
  });

  test('doublon pour le même rôle en attente → 409', async () => {
    const user = { ...STAFF, id: 'kc-role-dup' };
    asUser(user);
    await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_role: 'supervisor' });

    const res = await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_role: 'supervisor' });
    expect(res.status).toBe(409);
  });
});

// =============================================================================
//  14. GET /api/users/role-requests (admin)
// =============================================================================

describe('GET /api/users/role-requests', () => {
  test('non-admin → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .get('/api/users/role-requests')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(403);
  });

  test('admin → 200 tableau', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .get('/api/users/role-requests')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});

// =============================================================================
//  15. PUT /api/users/role-requests/:id (admin approuve ou rejette)
// =============================================================================

describe('PUT /api/users/role-requests/:id', () => {
  let roleReqId;

  beforeEach(async () => {
    asUser({ ...STAFF, id: 'kc-role-proc' });
    const res = await request(app)
      .post('/api/users/role-request')
      .set('Authorization', 'Bearer fake')
      .send({ requested_role: 'technician_it' });
    roleReqId = res.body.id;
  });

  test('statut invalide → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put(`/api/users/role-requests/${roleReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'peut-etre' });
    expect(res.status).toBe(400);
  });

  test('demande introuvable → 404', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put('/api/users/role-requests/uuid-inconnu')
      .set('Authorization', 'Bearer fake')
      .send({ status: 'approved' });
    expect(res.status).toBe(404);
  });

  test('rejet → 200, aucun appel assignRolesToUser', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put(`/api/users/role-requests/${roleReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'rejected' });
    expect(res.status).toBe(200);
    expect(assignRolesToUser).not.toHaveBeenCalled();
  });

  test('approbation → assigne le rôle dans Keycloak', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put(`/api/users/role-requests/${roleReqId}`)
      .set('Authorization', 'Bearer fake')
      .send({ status: 'approved' });
    expect(res.status).toBe(200);
    expect(assignRolesToUser).toHaveBeenCalledWith('kc-role-proc', ['technician_it']);
  });
});

// =============================================================================
//  16. GET /api/roles (admin)
// =============================================================================

describe('GET /api/roles', () => {
  test('sans token → 401', async () => {
    const res = await request(app).get('/api/roles');
    expect(res.status).toBe(401);
  });

  test('non-admin → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .get('/api/roles')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(403);
  });

  test('admin → rôles Keycloak enrichis des permissions SQLite', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp([
      { name: 'hospitalStaff', description: 'Personnel hospitalier', composite: false },
      { name: 'admin',         description: 'Administrateur',        composite: false },
      { name: 'offline_access', description: '',                     composite: false }, // filtré
    ]));

    const res = await request(app)
      .get('/api/roles')
      .set('Authorization', 'Bearer fake');

    expect(res.status).toBe(200);
    // offline_access doit être filtré (SYSTEM_ROLES)
    expect(res.body.map((r) => r.name)).not.toContain('offline_access');

    const staffRole = res.body.find((r) => r.name === 'hospitalStaff');
    expect(staffRole).toBeDefined();
    expect(Array.isArray(staffRole.permissions)).toBe(true);
    expect(staffRole.permissions).toContain('viewEquipment');

    const adminRole = res.body.find((r) => r.name === 'admin');
    expect(adminRole.permissions).toContain('manageUsers');
  });

  test('erreur Keycloak → 502', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 500 }));
    const res = await request(app)
      .get('/api/roles')
      .set('Authorization', 'Bearer fake');
    expect(res.status).toBe(502);
  });
});

// =============================================================================
//  17. PUT /api/roles/:name/permissions (admin)
// =============================================================================

describe('PUT /api/roles/:name/permissions', () => {
  test('non-admin → 403', async () => {
    asUser(STAFF);
    const res = await request(app)
      .put('/api/roles/supervisor/permissions')
      .set('Authorization', 'Bearer fake')
      .send({ permissions: ['viewEquipment'] });
    expect(res.status).toBe(403);
  });

  test('modifier les permissions du rôle admin → 403', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put('/api/roles/admin/permissions')
      .set('Authorization', 'Bearer fake')
      .send({ permissions: ['viewEquipment'] });
    expect(res.status).toBe(403);
    expect(res.body.error).toMatch(/administrateur/i);
  });

  test('permissions non-tableau → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put('/api/roles/supervisor/permissions')
      .set('Authorization', 'Bearer fake')
      .send({ permissions: 'viewEquipment' });
    expect(res.status).toBe(400);
  });

  test('permission inconnue → 400', async () => {
    asUser(ADMIN);
    const res = await request(app)
      .put('/api/roles/supervisor/permissions')
      .set('Authorization', 'Bearer fake')
      .send({ permissions: ['volerUnAvion'] });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/invalide/i);
  });

  test('rôle introuvable dans Keycloak → 404', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({}, { status: 404 }));
    const res = await request(app)
      .put('/api/roles/role-inexistant/permissions')
      .set('Authorization', 'Bearer fake')
      .send({ permissions: ['viewEquipment'] });
    expect(res.status).toBe(404);
  });

  test('mise à jour réussie → 200 et permissions persistées en SQLite', async () => {
    asUser(ADMIN);
    kcAdminFetch.mockResolvedValueOnce(kcResp({ name: 'supervisor' }));

    const newPerms = ['viewEquipment', 'reportIssue', 'approveRequests'];
    const res = await request(app)
      .put('/api/roles/supervisor/permissions')
      .set('Authorization', 'Bearer fake')
      .send({ permissions: newPerms });

    expect(res.status).toBe(200);
    expect(res.body.permissions).toEqual(newPerms);

    // Vérifier via GET /api/roles que les permissions sont bien en BDD
    kcAdminFetch.mockResolvedValueOnce(kcResp([{ name: 'supervisor', composite: false }]));
    asUser(ADMIN);
    const rolesRes = await request(app)
      .get('/api/roles')
      .set('Authorization', 'Bearer fake');
    const sup = rolesRes.body.find((r) => r.name === 'supervisor');
    expect(sup.permissions).toEqual(expect.arrayContaining(newPerms));
    expect(sup.permissions).toHaveLength(newPerms.length);
  });
});

// =============================================================================
//  18. SÉCURITÉ — Configuration et endpoints
// =============================================================================

describe('Sécurité — Configuration', () => {
  test('INTERNAL_SECRET est défini et non vide', () => {
    const { INTERNAL_SECRET } = require('../src/config');
    expect(INTERNAL_SECRET).toBeDefined();
    expect(typeof INTERNAL_SECRET).toBe('string');
    expect(INTERNAL_SECRET.length).toBeGreaterThan(0);
  });

  test('KC_ISSUER est configuré avec le realm kabutare-hospital', () => {
    const { KC_ISSUER } = require('../src/config');
    expect(KC_ISSUER).toBeDefined();
    expect(KC_ISSUER).toContain('kabutare-hospital');
  });

  test('les endpoints protégés retournent 401 sans token', async () => {
    const endpoints = [
      ['get',  '/api/auth/me'],
      ['get',  '/api/users'],
      ['get',  '/api/roles'],
      ['get',  '/api/users/department-requests'],
      ['get',  '/api/users/role-requests'],
      ['post', '/api/users/department-request'],
      ['post', '/api/users/role-request'],
    ];
    for (const [method, path] of endpoints) {
      const res = await request(app)[method](path);
      expect(res.status).toBe(401);
    }
  });

  test('les endpoints admin retournent 403 pour un non-admin authentifié', async () => {
    asUser(STAFF);
    const adminEndpoints = [
      ['get', '/api/users/department-requests'],
      ['get', '/api/users/role-requests'],
      ['get', '/api/roles'],
    ];
    for (const [method, path] of adminEndpoints) {
      const res = await request(app)[method](path).set('Authorization', 'Bearer fake');
      expect(res.status).toBe(403);
    }
  });
});
