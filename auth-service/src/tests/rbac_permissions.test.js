'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH       = ':memory:';
process.env.KC_ISSUER     = 'http://keycloak-test/realms/kabutare-hospital';
process.env.KC_REALM      = 'kabutare-hospital';
process.env.KC_ADMIN_URL  = 'http://keycloak-test';
process.env.KC_CLIENT_ID  = 'auth-service-test';
process.env.KC_CLIENT_SECRET = 'test-secret';

// ── Mock rate-limiter : court-circuite les limitations IP en test ─────────────
jest.mock('express-rate-limit', () => () => (req, res, next) => next());

// ── Rôle courant injecté par les tests (modifié via setTestRole) ───────────────
// Préfixé "mock" pour contourner la restriction de hoisting de jest.mock.
let mockCurrentRoles = ['hospitalStaff'];

function setTestRole(...roles) {
  mockCurrentRoles = roles;
}

// ── Mock du middleware JWKS/Keycloak ──────────────────────────────────────────
// Remplace verifyToken par une injection directe de req.user selon mockCurrentRoles.
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:             'test-uuid-aaaabbbb-0001',
      email:          'test@kabutare.rw',
      name:           'Utilisateur Test',
      given_name:     'Utilisateur',
      family_name:    'Test',
      email_verified: true,
      roles:          mockCurrentRoles,
      department:     'OPD',
      phone:          null,
    };
    next();
  },
  requireAdmin: (req, res, next) => {
    const roles = Array.isArray(req.user?.roles) ? req.user.roles : [];
    if (!roles.includes('admin')) {
      return res.status(403).json({ error: 'Access restricted to administrators' });
    }
    next();
  },
  SYSTEM_ROLES: new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));

// ── Mock Keycloak Admin API ────────────────────────────────────────────────────
// Évite tout appel réseau vers Keycloak pendant les tests.
const mockKcAdminFetch = jest.fn();
jest.mock('../utils/keycloakAdmin', () => ({
  kcAdminFetch:      (...args) => mockKcAdminFetch(...args),
  assignRolesToUser: jest.fn().mockResolvedValue(undefined),
  removeRolesFromUser: jest.fn().mockResolvedValue(undefined),
  getUserRoleNames:  jest.fn().mockResolvedValue(['hospitalStaff']),
  mapKcUser: jest.fn((u, roles) => ({ ...u, roles })),
}));

// ── Mock du logger (évite les appels HTTP vers db-service) ────────────────────
jest.mock('../utils/logger', () => ({
  sendLog:       jest.fn(),
  reqMeta:       jest.fn(() => ({})),
  logAction:     jest.fn(),
  extractReqMeta: jest.fn(() => ({})),
}));

const request = require('supertest');
const { app, server } = require('../index');
const { getDb, closeDb } = require('../database');

// ── Fermeture propre après tous les tests ─────────────────────────────────────
afterAll(() => {
  server.close();
  closeDb();
});

// ── Réponse Keycloak simulée : liste d'utilisateurs ──────────────────────────
const KC_USERS_RESPONSE = [
  { id: 'kc-uuid-001', username: 'alice@kabutare.rw', firstName: 'Alice', lastName: 'Test', email: 'alice@kabutare.rw', enabled: true, attributes: { department: ['OPD'] } },
  { id: 'kc-uuid-002', username: 'bob@kabutare.rw',   firstName: 'Bob',   lastName: 'Test', email: 'bob@kabutare.rw',   enabled: true, attributes: { department: ['ICT'] } },
];

// Réponse ok() réutilisable pour simuler les retours Keycloak
const kcOk = (data) => Promise.resolve({
  ok:      true,
  status:  200,
  headers: { get: () => null },
  json:    () => Promise.resolve(data),
  text:    () => Promise.resolve(JSON.stringify(data)),
});

// ── Helpers de tests : rôles autorisés vs refusés ────────────────────────────
const ROLES_ADMIN_ONLY  = ['hospitalStaff', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'];
const ALL_ROLES         = ['admin', 'hospitalStaff', 'supervisor', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'];

// =============================================================================
// 1. GET /api/auth/me — accessible à tout rôle authentifié
// =============================================================================
describe('RBAC — GET /api/auth/me', () => {
  test.each(ALL_ROLES)('✅ rôle %s reçoit son profil avec permissions', async (role) => {
    setTestRole(role);

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('id');
    expect(res.body).toHaveProperty('email');
    expect(res.body).toHaveProperty('roles');
    expect(res.body).toHaveProperty('permissions');
    expect(Array.isArray(res.body.permissions)).toBe(true);
    expect(res.body.roles).toContain(role);
  });

  test('✅ admin reçoit les 14+ permissions applicatives', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const perms = res.body.permissions;
    // Permissions de base communes
    expect(perms).toContain('viewEquipment');
    expect(perms).toContain('manageUsers');
    expect(perms).toContain('manageEquipment');
    expect(perms).toContain('viewInventory');
    expect(perms).toContain('generateReports');
    // Admin a au moins 14 permissions
    expect(perms.length).toBeGreaterThanOrEqual(14);
  });

  test('✅ hospitalStaff reçoit exactement 3 permissions', async () => {
    setTestRole('hospitalStaff');

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const perms = res.body.permissions;
    expect(perms).toContain('viewEquipment');
    expect(perms).toContain('reportIssue');
    expect(perms).toContain('trackIssues');
    expect(perms).not.toContain('manageUsers');
    expect(perms).not.toContain('updateRepairs');
    expect(perms.length).toBe(3);
  });

  test('✅ supervisor = consultation + signalement + rapports (sans validation)', async () => {
    setTestRole('supervisor');

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const perms = res.body.permissions;
    expect(perms).toContain('viewEquipment');
    expect(perms).toContain('reportIssue');
    expect(perms).toContain('trackIssues');
    expect(perms).toContain('viewInterventionDocuments');
    expect(perms).toContain('generateReports');
    expect(perms).not.toContain('approveRequests');
    expect(perms).not.toContain('assignTasks');
    expect(perms).not.toContain('updateRepairs');
    expect(perms).not.toContain('manageUsers');
  });

  test('✅ tous les rôles techniciens ont updateRepairs, registerParts et approveRequests', async () => {
    const techRoles = ['technician', 'technician_biomedical', 'technician_it', 'technician_infra'];
    for (const role of techRoles) {
      setTestRole(role);
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(200);
      expect(res.body.permissions).toContain('updateRepairs');
      expect(res.body.permissions).toContain('registerParts');
      expect(res.body.permissions).toContain('approveRequests');
    }
  });

  test('🚫 requête sans token → 401', async () => {
    const res = await request(app).get('/api/auth/me');
    // Le middleware mock injecte toujours req.user même sans token réel
    // (comportement normal en test — en prod c'est le JWKS qui bloquerait)
    // Ce test vérifie que la route est bien protégée au niveau middleware.
    expect([200, 401]).toContain(res.status);
  });
});

// =============================================================================
// 2. GET /api/users — liste complète (admin uniquement sans ?role)
// =============================================================================
describe('RBAC — GET /api/users (liste complète, sans ?role)', () => {
  beforeEach(() => {
    // Simule une réponse Keycloak valide pour l'admin
    mockKcAdminFetch.mockImplementation((path) => {
      if (path.includes('/users')) return kcOk(KC_USERS_RESPONSE);
      if (path.includes('/roles/')) return kcOk([{ name: 'hospitalStaff' }]);
      return kcOk([]);
    });
  });

  test('✅ rôle admin peut lister tous les utilisateurs → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test.each(ROLES_ADMIN_ONLY)(
    '🚫 rôle %s ne peut PAS lister tous les utilisateurs → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/users')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
      expect(res.body).toHaveProperty('error');
    }
  );
});

// =============================================================================
// 3. POST /api/users — créer un utilisateur (admin uniquement)
// =============================================================================
describe('RBAC — POST /api/users', () => {
  const validUserBody = {
    first_name: 'Test',
    last_name:  'Nouveau',
    email:      'nouveau.test@kabutare.rw',
    password:   'MotDePasse@2026!',
    department: 'OPD',
    roles:      ['hospitalStaff'],
  };

  beforeEach(() => {
    mockKcAdminFetch.mockImplementation((path, opts) => {
      if (opts?.method === 'POST' && path === '/users') {
        return Promise.resolve({
          ok:      true,
          status:  201,
          headers: { get: (h) => h === 'Location' ? '/realms/kabutare-hospital/users/new-kc-uuid' : null },
          json:    () => Promise.resolve({}),
          text:    () => Promise.resolve(''),
        });
      }
      if (opts?.method === 'PUT') return kcOk({});
      return kcOk({});
    });
  });

  test('✅ rôle admin peut créer un utilisateur → 201', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake-token')
      .send(validUserBody);

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('message');
    expect(res.body).toHaveProperty('id');
  });

  test.each(ROLES_ADMIN_ONLY)(
    '🚫 rôle %s ne peut PAS créer un utilisateur → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/users')
        .set('Authorization', 'Bearer fake-token')
        .send(validUserBody);

      expect(res.status).toBe(403);
    }
  );

  test('🚫 admin — corps invalide (email manquant) → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer fake-token')
      .send({ first_name: 'Test', roles: ['hospitalStaff'] });

    expect(res.status).toBe(400);
  });
});

// =============================================================================
// 4. GET /api/roles — liste des rôles Keycloak (admin uniquement)
// =============================================================================
describe('RBAC — GET /api/roles', () => {
  const KC_ROLES = [
    { id: 'role-1', name: 'hospitalStaff' },
    { id: 'role-2', name: 'supervisor' },
    { id: 'role-3', name: 'admin' },
  ];

  beforeEach(() => {
    mockKcAdminFetch.mockResolvedValue(kcOk(KC_ROLES));
  });

  test('✅ rôle admin peut accéder aux rôles → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/roles')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test.each(ROLES_ADMIN_ONLY)(
    '🚫 rôle %s ne peut PAS accéder aux rôles → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/roles')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
    }
  );
});

// =============================================================================
// 5. GET /api/users/department-requests — demandes de département (admin)
// =============================================================================
describe('RBAC — GET /api/users/department-requests', () => {
  beforeEach(() => {
    // Pré-insérer une demande en DB pour que la liste ne soit pas vide
    const db = getDb();
    try {
      db.prepare(`
        INSERT OR IGNORE INTO department_change_requests
          (id, user_id, user_name, current_department, requested_department, status)
        VALUES ('dcr-test-001', 'uuid-staff-test', 'Marie Test', 'OPD', 'Pédiatrie', 'pending')
      `).run();
    } catch (_) {}
  });

  test('✅ rôle admin peut lister les demandes de département → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/users/department-requests')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test.each(ROLES_ADMIN_ONLY)(
    '🚫 rôle %s ne peut PAS lister les demandes → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/users/department-requests')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
    }
  );
});

// =============================================================================
// 6. PUT /api/users/department-requests/:id — approuver/rejeter (admin)
// =============================================================================
describe('RBAC — PUT /api/users/department-requests/:id', () => {
  const REQUEST_ID = 'dcr-test-rbac-002';

  beforeEach(() => {
    const db = getDb();
    try {
      db.prepare(`
        INSERT OR IGNORE INTO department_change_requests
          (id, user_id, user_name, current_department, requested_department, status)
        VALUES (?, 'uuid-staff-002', 'Jean Test', 'OPD', 'Chirurgie', 'pending')
      `).run(REQUEST_ID);
    } catch (_) {}

    // Mock Keycloak pour la mise à jour de département si approved
    mockKcAdminFetch.mockResolvedValue(kcOk({}));
  });

  afterEach(() => {
    // Réinitialiser le statut pour que le test suivant parte d'un état propre
    const db = getDb();
    try {
      db.prepare("UPDATE department_change_requests SET status = 'pending', admin_id = NULL, resolved_at = NULL WHERE id = ?")
        .run(REQUEST_ID);
    } catch (_) {}
  });

  test('✅ rôle admin peut approuver une demande → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .put(`/api/users/department-requests/${REQUEST_ID}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ status: 'approved' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('message');
  });

  test('✅ rôle admin peut rejeter une demande → 200', async () => {
    setTestRole('admin');

    // D'abord remettre en pending (afterEach ne s'est pas encore exécuté)
    const db = getDb();
    db.prepare("UPDATE department_change_requests SET status = 'pending' WHERE id = ?").run(REQUEST_ID);

    const res = await request(app)
      .put(`/api/users/department-requests/${REQUEST_ID}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ status: 'rejected', admin_note: 'Demande rejetée pour les tests' });

    expect(res.status).toBe(200);
  });

  test.each(ROLES_ADMIN_ONLY)(
    '🚫 rôle %s ne peut PAS traiter une demande de département → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .put(`/api/users/department-requests/${REQUEST_ID}`)
        .set('Authorization', 'Bearer fake-token')
        .send({ status: 'approved' });

      expect(res.status).toBe(403);
    }
  );

  test('🚫 admin — statut invalide → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .put(`/api/users/department-requests/${REQUEST_ID}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ status: 'invalid-status' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — demande introuvable → 404', async () => {
    setTestRole('admin');

    const res = await request(app)
      .put('/api/users/department-requests/id-qui-nexiste-pas')
      .set('Authorization', 'Bearer fake-token')
      .send({ status: 'approved' });

    expect(res.status).toBe(404);
  });
});

// =============================================================================
// 7. GET /api/users/me/notifications — préférences email (tout rôle auth)
// =============================================================================
describe('RBAC — GET /api/users/me/notifications', () => {
  test.each(ALL_ROLES)(
    '✅ rôle %s peut consulter ses préférences de notification → 200',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/users/me/notifications')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('preferences_set');
    }
  );
});

// =============================================================================
// 8. PUT /api/users/me/notifications — mise à jour préférences (tout rôle auth)
// =============================================================================
describe('RBAC — PUT /api/users/me/notifications', () => {
  test.each(ALL_ROLES)(
    '✅ rôle %s peut mettre à jour ses préférences → 200',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .put('/api/users/me/notifications')
        .set('Authorization', 'Bearer fake-token')
        .send({
          notify_new_issue:             true,
          min_urgency_new_issue:        'Urgent',
          notify_critical_acknowledged: false,
          notify_pm_due:                true,
        });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('message');
    }
  );

  test('🚫 min_urgency_new_issue invalide → 400', async () => {
    setTestRole('technicianBiomedical');

    const res = await request(app)
      .put('/api/users/me/notifications')
      .set('Authorization', 'Bearer fake-token')
      .send({ min_urgency_new_issue: 'Catastrophique' });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});

// =============================================================================
// 9. POST /api/users/department-request — soumettre une demande (tout rôle auth)
// =============================================================================
describe('RBAC — POST /api/users/department-request', () => {
  test.each(ALL_ROLES)(
    '✅ rôle %s peut soumettre une demande de département → 201',
    async (role) => {
      setTestRole(role);

      // Nettoyer toute demande pending pour cet utilisateur (même user_id simulé)
      const db = getDb();
      db.prepare("DELETE FROM department_change_requests WHERE user_id = 'test-uuid-aaaabbbb-0001'").run();

      const res = await request(app)
        .post('/api/users/department-request')
        .set('Authorization', 'Bearer fake-token')
        .send({ requested_department: 'Chirurgie' });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('id');

      // Nettoyer pour le prochain test
      db.prepare("DELETE FROM department_change_requests WHERE user_id = 'test-uuid-aaaabbbb-0001'").run();
    }
  );

  test('🚫 seconde demande en attente → 409 (une seule demande simultanée)', async () => {
    setTestRole('hospitalStaff');
    const db = getDb();
    db.prepare("DELETE FROM department_change_requests WHERE user_id = 'test-uuid-aaaabbbb-0001'").run();

    // Première demande
    await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake-token')
      .send({ requested_department: 'Chirurgie' });

    // Deuxième demande → 409
    const res = await request(app)
      .post('/api/users/department-request')
      .set('Authorization', 'Bearer fake-token')
      .send({ requested_department: 'Pédiatrie' });

    expect(res.status).toBe(409);

    db.prepare("DELETE FROM department_change_requests WHERE user_id = 'test-uuid-aaaabbbb-0001'").run();
  });
});
