'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Rôle courant injecté par les tests ────────────────────────────────────────
// Préfixé "mock" pour contourner la restriction de hoisting de jest.mock.
let mockCurrentRoles = ['hospitalStaff'];

function setTestRole(...roles) {
  mockCurrentRoles = roles;
}

// ── Mock du middleware d'auth ─────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-db-0001',
      email:      'test@kabutare.rw',
      name:       'Utilisateur Test',
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

// ── Données de test insérées avant chaque suite ───────────────────────────────
let db;

beforeAll(() => {
  db = getDb();

  // ── Correction schéma issues en DB :memory: ──────────────────────────────────
  // La migration "rebuild issues" crée une nouvelle table sans les colonnes
  // ajoutées par les ALTER TABLE précédents (location_text, location_tag,
  // reporter_phone, taken_at). Sur un déploiement existant cela ne se produit
  // pas car les migrations s'appliquent en plusieurs démarrages successifs.
  // Sur une DB :memory: fraîche, les colonnes manquent après le rebuild.
  const existingCols = new Set(db.pragma('table_info(issues)').map((c) => c.name));
  const missingCols = ['location_text', 'location_tag', 'reporter_phone', 'taken_at'];
  for (const col of missingCols) {
    if (!existingCols.has(col)) {
      try { db.exec(`ALTER TABLE issues ADD COLUMN ${col} TEXT`); } catch (_) {}
    }
  }

  // Équipement de référence utilisé par plusieurs tests
  db.prepare(`
    INSERT OR IGNORE INTO equipment (id, name, department, category, status)
    VALUES ('eq-rbac-test', 'Moniteur cardiaque test', 'OPD', 'Monitoring', 'Operational')
  `).run();

  // Incident de référence pour les tests PUT /api/issues/:id
  db.prepare(`
    INSERT OR IGNORE INTO issues (
      id, equipment_id, equipment_name, issue_category, assigned_group,
      department, type, description, reporter, urgency, status, created_at
    ) VALUES (
      'iss-rbac-test', 'eq-rbac-test', 'Moniteur cardiaque test', 'Biomédical', 'Biomédical',
      'OPD', 'Panne', 'Écran noir depuis ce matin', 'Dr. Test', 'Urgent', 'Assigned',
      datetime('now','localtime')
    )
  `).run();

  // Article d'inventaire de référence
  db.prepare(`
    INSERT OR IGNORE INTO inventory (id, name, category, current_stock, min_stock, unit, status)
    VALUES ('inv-rbac-test', 'Gants stériles test', 'Consommable médical', 50, 10, 'boîte', 'Normal')
  `).run();
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

// =============================================================================
// 1. GET /api/equipment — accessible à tout rôle authentifié
// =============================================================================
describe('RBAC — GET /api/equipment', () => {
  const ALL_ROLES = ['admin', 'hospitalStaff', 'supervisor', 'technician',
    'technician_biomedical', 'technician_it', 'technician_infra'];

  test.each(ALL_ROLES)(
    '✅ rôle %s peut lister les équipements → 200',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/equipment')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    }
  );

  test('✅ la liste contient l\'équipement de référence', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/equipment')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    const eq = res.body.find((e) => e.id === 'eq-rbac-test');
    expect(eq).toBeDefined();
    expect(eq.name).toBe('Moniteur cardiaque test');
  });
});

// =============================================================================
// 2. POST /api/equipment — créer un équipement (admin et supervisor)
// =============================================================================
describe('RBAC — POST /api/equipment', () => {
  const ROLES_AUTORISÉS = ['admin', 'supervisor', 'technician_biomedical', 'technician_it', 'technician_infra'];
  const ROLES_REFUSÉS   = ['hospitalStaff', 'technician'];

  let counter = 0;
  const newEq = () => ({
    id:         `eq-nouveau-${++counter}`,
    name:       'Équipement créé en test',
    department: 'OPD',
    category:   'Monitoring',
    status:     'Operational',
    tag_number: `TAG-${counter}`,
  });

  test.each(ROLES_AUTORISÉS)(
    '✅ rôle %s peut créer un équipement → 201',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/equipment')
        .set('Authorization', 'Bearer fake-token')
        .send(newEq());

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('message');
    }
  );

  test.each(ROLES_REFUSÉS)(
    '🚫 rôle %s ne peut PAS créer un équipement → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/equipment')
        .set('Authorization', 'Bearer fake-token')
        .send(newEq());

      expect(res.status).toBe(403);
    }
  );

  test('🚫 admin — champs requis manquants → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ name: 'Équipement sans ID ni département' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — statut invalide → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-bad-status', name: 'Test', department: 'OPD', category: 'Monitoring', status: 'StatutInvalide', tag_number: 'TAG-bad-status' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — ID dupliqué → 409', async () => {
    setTestRole('admin');

    // Première insertion
    await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-duplicate-test', name: 'Dupliqué', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-dup-1' });

    // Deuxième insertion avec le même ID (tag différent pour ne tester que le conflit d'ID)
    const res = await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-duplicate-test', name: 'Dupliqué 2', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-dup-2' });

    expect(res.status).toBe(409);
  });

  test('🚫 admin — création sans tag physique → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-sans-tag', name: 'Sans tag', department: 'OPD', category: 'Monitoring' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — tag physique déjà utilisé par un autre équipement → 409', async () => {
    setTestRole('admin');

    await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-tag-owner', name: 'Propriétaire du tag', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-conflit' });

    const res = await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-tag-conflit', name: 'Conflit de tag', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-conflit' });

    expect(res.status).toBe(409);
  });
});

// =============================================================================
// 2 bis. PUT /api/equipment/:id — tag physique obligatoire et unique
// =============================================================================
describe('RBAC — PUT /api/equipment/:id — tag physique', () => {
  test('🚫 admin — retirer le seul tag existant sans en fournir un autre → 400', async () => {
    setTestRole('admin');

    await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-put-tag-1', name: 'Équipement PUT tag', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-put-1' });

    const res = await request(app)
      .put('/api/equipment/eq-put-tag-1')
      .set('Authorization', 'Bearer fake-token')
      .send({ tag_number: '' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — tag physique déjà utilisé par un autre équipement → 409', async () => {
    setTestRole('admin');

    await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-put-tag-2a', name: 'Équipement A', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-put-2a' });

    await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-put-tag-2b', name: 'Équipement B', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-put-2b' });

    const res = await request(app)
      .put('/api/equipment/eq-put-tag-2b')
      .set('Authorization', 'Bearer fake-token')
      .send({ tag_number: 'TAG-put-2a' });

    expect(res.status).toBe(409);
  });

  test('✅ admin — modifier le département sans toucher au tag existant → 200', async () => {
    setTestRole('admin');

    await request(app)
      .post('/api/equipment')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'eq-put-tag-3', name: 'Équipement C', department: 'OPD', category: 'Monitoring', tag_number: 'TAG-put-3' });

    const res = await request(app)
      .put('/api/equipment/eq-put-tag-3')
      .set('Authorization', 'Bearer fake-token')
      .send({ department: 'ICU' });

    expect(res.status).toBe(200);
  });
});

// =============================================================================
// 3. DELETE /api/equipment/:id — supprimer (admin uniquement)
// =============================================================================
describe('RBAC — DELETE /api/equipment/:id', () => {
  const ROLES_NON_ADMIN = ['hospitalStaff', 'supervisor', 'technician',
    'technician_biomedical', 'technician_it', 'technician_infra'];

  // Créer un équipement dédié à la suppression
  const EQ_TO_DELETE = 'eq-to-delete-rbac';
  beforeEach(() => {
    db.prepare(`
      INSERT OR IGNORE INTO equipment (id, name, department, category)
      VALUES ('${EQ_TO_DELETE}', 'Équipement à supprimer', 'OPD', 'Monitoring')
    `).run();
  });

  test('✅ rôle admin peut supprimer un équipement → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .delete(`/api/equipment/${EQ_TO_DELETE}`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('message');

    // Vérifier que l'équipement n'existe plus
    const eq = db.prepare('SELECT id FROM equipment WHERE id = ?').get(EQ_TO_DELETE);
    expect(eq).toBeUndefined();
  });

  test.each(ROLES_NON_ADMIN)(
    '🚫 rôle %s ne peut PAS supprimer un équipement → 403',
    async (role) => {
      setTestRole(role);

      // Re-créer l'équipement au cas où le test admin l'aurait supprimé
      db.prepare(`
        INSERT OR IGNORE INTO equipment (id, name, department, category)
        VALUES ('${EQ_TO_DELETE}', 'Équipement à supprimer', 'OPD', 'Monitoring')
      `).run();

      const res = await request(app)
        .delete(`/api/equipment/${EQ_TO_DELETE}`)
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
    }
  );

  test('🚫 admin — équipement introuvable → 404', async () => {
    setTestRole('admin');

    const res = await request(app)
      .delete('/api/equipment/eq-qui-nexiste-absolument-pas')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(404);
  });
});

// =============================================================================
// 4. POST /api/issues — signaler un incident (tous les rôles authentifiés)
// =============================================================================
describe('RBAC — POST /api/issues', () => {
  const ALL_ROLES = ['admin', 'hospitalStaff', 'supervisor', 'technician',
    'technician_biomedical', 'technician_it', 'technician_infra'];

  let issueCounter = 0;
  const newIssue = (extra = {}) => ({
    id:             `iss-new-${Date.now()}-${++issueCounter}`,
    equipment_id:   'eq-rbac-test',
    equipment_name: 'Moniteur cardiaque test',
    department:     'OPD',
    type:           'Panne',
    description:    'Description de test pour RBAC',
    reporter:       'Testeur RBAC',
    urgency:        'Moyen',
    ...extra,
  });

  test.each(ALL_ROLES)(
    '✅ rôle %s peut signaler un incident → 201',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/issues')
        .set('Authorization', 'Bearer fake-token')
        .send(newIssue());

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('id');
    }
  );

  test('🚫 champs requis manquants → 400', async () => {
    setTestRole('hospitalStaff');

    const res = await request(app)
      .post('/api/issues')
      .set('Authorization', 'Bearer fake-token')
      .send({ id: 'iss-bad', department: 'OPD' });

    expect(res.status).toBe(400);
  });

  test('✅ incident critique → status initial Reported', async () => {
    setTestRole('hospitalStaff');

    const res = await request(app)
      .post('/api/issues')
      .set('Authorization', 'Bearer fake-token')
      .send(newIssue({ urgency: 'Critique', description: 'Panne critique en test' }));

    expect(res.status).toBe(201);

    // Vérifier le statut initial en base
    const iss = db.prepare('SELECT status FROM issues WHERE id = ?').get(res.body.id);
    expect(iss.status).toBe('Reported');
  });
});

// =============================================================================
// 5. PUT /api/issues/:id — mettre à jour (admin, technician*)
//    ⚠️ Le rôle générique `technician` n'est PAS dans TECH_ROLES du service.
//    Seuls technician_biomedical, technician_it, technician_infra sont autorisés.
//    Le supervisor (consultation + rapports) ne peut plus agir sur les incidents.
// =============================================================================
describe('RBAC — PUT /api/issues/:id', () => {
  // TECH_ROLES dans db-service : ['technician_biomedical', 'technician_it', 'technician_infra']
  const ROLES_AUTORISÉS = ['admin', 'technician_biomedical', 'technician_it', 'technician_infra'];
  // hospitalStaff, supervisor et technician (générique) ne peuvent pas modifier un incident
  const ROLES_REFUSÉS   = ['hospitalStaff', 'supervisor', 'technician'];

  const ISSUE_ID = 'iss-rbac-test';

  const updateBody = {
    status:    'In Progress',
    diagnosis: 'Diagnostic de test RBAC',
    actions:   'Actions effectuées en test',
  };

  test.each(ROLES_AUTORISÉS)(
    '✅ rôle %s peut mettre à jour un incident → 200',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .put(`/api/issues/${ISSUE_ID}`)
        .set('Authorization', 'Bearer fake-token')
        .send(updateBody);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('message');
    }
  );

  test.each(ROLES_REFUSÉS)(
    '🚫 rôle %s ne peut PAS mettre à jour un incident → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .put(`/api/issues/${ISSUE_ID}`)
        .set('Authorization', 'Bearer fake-token')
        .send(updateBody);

      expect(res.status).toBe(403);
    }
  );

  test('🚫 incident introuvable → 404', async () => {
    setTestRole('admin');

    const res = await request(app)
      .put('/api/issues/iss-qui-nexiste-pas')
      .set('Authorization', 'Bearer fake-token')
      .send(updateBody);

    expect(res.status).toBe(404);
  });

  test('🚫 statut invalide → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .put(`/api/issues/${ISSUE_ID}`)
      .set('Authorization', 'Bearer fake-token')
      .send({ status: 'StatutInvalide' });

    expect(res.status).toBe(400);
  });

  test('✅ transition → Completed pose resolved_at (non nul)', async () => {
    setTestRole('admin');

    // Incident dédié pour ne pas interférer avec les autres tests
    db.prepare(`
      INSERT OR IGNORE INTO issues (
        id, equipment_id, equipment_name, issue_category, assigned_group,
        department, type, description, reporter, urgency, status, created_at
      ) VALUES (
        'iss-resolved-test', 'eq-rbac-test', 'Moniteur cardiaque test', 'Biomédical', 'Biomédical',
        'OPD', 'Panne', 'Test resolved_at', 'Dr. Test', 'Urgent', 'Assigned',
        datetime('now','localtime')
      )
    `).run();

    // Avant : pas de date de résolution
    const before = db.prepare('SELECT resolved_at FROM issues WHERE id = ?').get('iss-resolved-test');
    expect(before.resolved_at).toBeNull();

    const res = await request(app)
      .put('/api/issues/iss-resolved-test')
      .set('Authorization', 'Bearer fake-token')
      .send({ status: 'Completed' });

    expect(res.status).toBe(200);

    // Après : resolved_at renseigné dans la liste GET /
    const after = db.prepare('SELECT resolved_at FROM issues WHERE id = ?').get('iss-resolved-test');
    expect(after.resolved_at).not.toBeNull();
    expect(typeof after.resolved_at).toBe('string');
  });
});

// =============================================================================
// 6. GET /api/inventory — admin et supervisor uniquement (permission viewInventory)
// =============================================================================
describe('RBAC — GET /api/inventory', () => {
  const ROLES_AUTORISÉS = ['admin', 'supervisor'];
  const ROLES_REFUSÉS   = ['hospitalStaff', 'technician', 'technician_biomedical',
    'technician_it', 'technician_infra'];

  test.each(ROLES_AUTORISÉS)(
    '✅ rôle %s peut lire l\'inventaire → 200',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/inventory')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    }
  );

  test.each(ROLES_REFUSÉS)(
    '🚫 rôle %s ne peut PAS lire l\'inventaire → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/inventory')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
    }
  );

  test('✅ admin — GET /api/inventory/:id → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/inventory/inv-rbac-test')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('id', 'inv-rbac-test');
  });

  test('🚫 hospitalStaff — GET /api/inventory/:id → 403', async () => {
    setTestRole('hospitalStaff');

    const res = await request(app)
      .get('/api/inventory/inv-rbac-test')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(403);
  });
});

// =============================================================================
// 7. POST /api/inventory — créer un article (admin et supervisor)
// =============================================================================
describe('RBAC — POST /api/inventory', () => {
  const ROLES_AUTORISÉS = ['admin', 'supervisor'];
  const ROLES_REFUSÉS   = ['hospitalStaff', 'technician', 'technician_biomedical', 'technician_it', 'technician_infra'];

  let invCounter = 0;
  const newItem = () => ({
    id:            `inv-new-${++invCounter}`,
    name:          'Article inventaire test',
    category:      'Consommable médical',
    current_stock: 100,
    min_stock:     10,
    unit:          'unité',
  });

  test.each(ROLES_AUTORISÉS)(
    '✅ rôle %s peut créer un article d\'inventaire → 201',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/inventory')
        .set('Authorization', 'Bearer fake-token')
        .send(newItem());

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('message');
    }
  );

  test.each(ROLES_REFUSÉS)(
    '🚫 rôle %s ne peut PAS créer un article d\'inventaire → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/inventory')
        .set('Authorization', 'Bearer fake-token')
        .send(newItem());

      expect(res.status).toBe(403);
    }
  );
});

// =============================================================================
// 8. DELETE /api/inventory/:id — supprimer (admin uniquement)
// =============================================================================
describe('RBAC — DELETE /api/inventory/:id', () => {
  const ROLES_NON_ADMIN = ['hospitalStaff', 'supervisor', 'technician',
    'technician_biomedical', 'technician_it', 'technician_infra'];

  const INV_TO_DELETE = 'inv-to-delete-rbac';

  beforeEach(() => {
    db.prepare(`
      INSERT OR IGNORE INTO inventory (id, name, category, current_stock, min_stock, unit, status)
      VALUES ('${INV_TO_DELETE}', 'Article à supprimer', 'Consommable médical', 10, 2, 'unité', 'Normal')
    `).run();
  });

  test('✅ rôle admin peut supprimer un article d\'inventaire → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .delete(`/api/inventory/${INV_TO_DELETE}`)
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
  });

  test.each(ROLES_NON_ADMIN)(
    '🚫 rôle %s ne peut PAS supprimer un article d\'inventaire → 403',
    async (role) => {
      setTestRole(role);

      db.prepare(`
        INSERT OR IGNORE INTO inventory (id, name, category, current_stock, min_stock, unit, status)
        VALUES ('${INV_TO_DELETE}', 'Article à supprimer', 'Consommable médical', 10, 2, 'unité', 'Normal')
      `).run();

      const res = await request(app)
        .delete(`/api/inventory/${INV_TO_DELETE}`)
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
    }
  );
});

// =============================================================================
// 9. GET /api/logs — audit trail (admin uniquement)
// =============================================================================
describe('RBAC — GET /api/logs', () => {
  const ROLES_NON_ADMIN = ['hospitalStaff', 'supervisor', 'technician',
    'technician_biomedical', 'technician_it', 'technician_infra'];

  test('✅ rôle admin peut consulter les logs d\'audit → 200', async () => {
    setTestRole('admin');

    const res = await request(app)
      .get('/api/logs')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test.each(ROLES_NON_ADMIN)(
    '🚫 rôle %s ne peut PAS accéder aux logs d\'audit → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .get('/api/logs')
        .set('Authorization', 'Bearer fake-token');

      expect(res.status).toBe(403);
    }
  );
});

// =============================================================================
// 10. PATCH /api/issues/:id/escalate — escalade (admin, technician*)
// =============================================================================
describe('RBAC — PATCH /api/issues/:id/escalate', () => {
  const ROLES_AUTORISÉS = ['admin', 'technician_biomedical', 'technician_it', 'technician_infra'];
  const ROLES_REFUSÉS   = ['hospitalStaff', 'supervisor', 'technician'];
  const ISSUE_ID        = 'iss-rbac-test';

  const escalateBody = {
    escalation_status:  'Waiting Materials',
    escalation_comment: 'En attente de la pièce de rechange, délai estimé 3 jours.',
  };

  test.each(ROLES_AUTORISÉS)(
    '✅ rôle %s peut escalader un incident → 200',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .patch(`/api/issues/${ISSUE_ID}/escalate`)
        .set('Authorization', 'Bearer fake-token')
        .send(escalateBody);

      expect(res.status).toBe(200);
    }
  );

  test.each(ROLES_REFUSÉS)(
    '🚫 rôle %s ne peut PAS escalader un incident → 403',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .patch(`/api/issues/${ISSUE_ID}/escalate`)
        .set('Authorization', 'Bearer fake-token')
        .send(escalateBody);

      expect(res.status).toBe(403);
    }
  );
});

// =============================================================================
// 11. PATCH /api/issues/:id/reject — rejet d'un incident en file de validation
//     (admin et techniciens, depuis le statut 'Reported')
// =============================================================================
describe('PATCH /api/issues/:id/reject', () => {
  // Crée un incident 'Reported' frais avant chaque test
  let rejectCounter = 0;
  const newReportedIssue = () => {
    const id = `iss-reject-${++rejectCounter}`;
    db.prepare(`
      INSERT INTO issues (
        id, equipment_id, equipment_name, issue_category, assigned_group,
        department, type, description, reporter, urgency, status, created_at
      ) VALUES (
        ?, 'eq-rbac-test', 'Moniteur cardiaque test', 'Biomédical', 'Biomédical',
        'OPD', 'Panne', 'Incident à rejeter', 'Dr. Test', 'Moyen', 'Reported',
        datetime('now','localtime')
      )
    `).run(id);
    return id;
  };

  test('✅ admin — rejet d\'un incident Reported → 200 + statut Rejected', async () => {
    setTestRole('admin');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'duplicate', comment: 'Doublon du ticket #42' });

    expect(res.status).toBe(200);
    const iss = db.prepare('SELECT status, actions FROM issues WHERE id = ?').get(id);
    expect(iss.status).toBe('Rejected');
    expect(iss.actions).toContain('Rejet (duplicate)');

    // Une ligne d'audit reject_issue doit avoir été émise
    const { logAction } = require('../utils/logger');
    expect(logAction).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'reject_issue', target_id: id })
    );
  });

  test('🚫 admin — reason_code invalide → 400', async () => {
    setTestRole('admin');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'motif_bidon' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — motif "other" sans commentaire → 400', async () => {
    setTestRole('admin');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'other' });

    expect(res.status).toBe(400);
  });

  test('🚫 admin — incident non Reported → 409', async () => {
    setTestRole('admin');
    const id = newReportedIssue();
    db.prepare("UPDATE issues SET status = 'In Progress' WHERE id = ?").run(id);

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'false_alarm' });

    expect(res.status).toBe(409);
  });

  test('✅ technicien peut rejeter → 200', async () => {
    setTestRole('technician_biomedical');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'duplicate' });

    expect(res.status).toBe(200);
    const iss = db.prepare('SELECT status FROM issues WHERE id = ?').get(id);
    expect(iss.status).toBe('Rejected');
  });

  test('🚫 hospitalStaff ne peut PAS rejeter → 403', async () => {
    setTestRole('hospitalStaff');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'duplicate' });

    expect(res.status).toBe(403);
  });

  test('🚫 supervisor ne peut PAS rejeter → 403 (rôle consultation + rapports)', async () => {
    setTestRole('supervisor');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'duplicate' });

    expect(res.status).toBe(403);
  });

  test('✅ rejet réussi — un document intervention est archivé sur l\'équipement', async () => {
    setTestRole('admin');
    const id = newReportedIssue();

    const res = await request(app)
      .patch(`/api/issues/${id}/reject`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason_code: 'duplicate', comment: 'Doublon' });

    expect(res.status).toBe(200);
    const doc = db.prepare(
      "SELECT * FROM equipment_documents WHERE issue_id = ? AND document_type = 'intervention'"
    ).get(id);
    expect(doc).toBeDefined();
    expect(doc.equipment_id).toBe('eq-rbac-test');
  });
});

// =============================================================================
// 12. PATCH /api/issues/:id/detach — détachement d'un incident pris en charge
//     (admin, supervisor, technician* ; un technicien uniquement les siens)
// =============================================================================
describe('PATCH /api/issues/:id/detach', () => {
  // Crée un incident 'In Progress' assigné à un technicien donné
  let detachCounter = 0;
  const newInProgressIssue = (technicianName) => {
    const id = `iss-detach-${++detachCounter}`;
    db.prepare(`
      INSERT INTO issues (
        id, equipment_id, equipment_name, issue_category, assigned_group,
        department, type, description, reporter, urgency, status, assigned_technician, taken_at, created_at
      ) VALUES (
        ?, 'eq-rbac-test', 'Moniteur cardiaque test', 'Biomédical', 'Biomédical',
        'OPD', 'Panne', 'Incident à détacher', 'Dr. Test', 'Moyen', 'In Progress', ?, datetime('now','localtime'),
        datetime('now','localtime')
      )
    `).run(id, technicianName);
    return id;
  };

  const detachBody = { reason: 'Je ne suis pas disponible cette semaine, à reprendre.' };

  test('✅ technicien assigné — détachement → 200 + retour au pool', async () => {
    setTestRole('technician_biomedical');
    // Le mock auth nomme l'utilisateur "Utilisateur Test"
    const id = newInProgressIssue('Utilisateur Test');

    const res = await request(app)
      .patch(`/api/issues/${id}/detach`)
      .set('Authorization', 'Bearer fake-token')
      .send(detachBody);

    expect(res.status).toBe(200);
    const iss = db.prepare(
      'SELECT status, assigned_technician, taken_at FROM issues WHERE id = ?'
    ).get(id);
    expect(iss.status).toBe('Acknowledged');
    expect(iss.assigned_technician).toBeNull();
    expect(iss.taken_at).toBeNull();
  });

  test('🚫 technicien NON assigné → 403', async () => {
    setTestRole('technician_biomedical');
    const id = newInProgressIssue('Un Autre Technicien');

    const res = await request(app)
      .patch(`/api/issues/${id}/detach`)
      .set('Authorization', 'Bearer fake-token')
      .send(detachBody);

    expect(res.status).toBe(403);
  });

  test('✅ admin — peut détacher l\'incident d\'un autre technicien → 200', async () => {
    setTestRole('admin');
    const id = newInProgressIssue('Un Autre Technicien');

    const res = await request(app)
      .patch(`/api/issues/${id}/detach`)
      .set('Authorization', 'Bearer fake-token')
      .send(detachBody);

    expect(res.status).toBe(200);
  });

  test('🚫 incident non In Progress → 409', async () => {
    setTestRole('admin');
    const id = newInProgressIssue('Utilisateur Test');
    db.prepare("UPDATE issues SET status = 'Reported' WHERE id = ?").run(id);

    const res = await request(app)
      .patch(`/api/issues/${id}/detach`)
      .set('Authorization', 'Bearer fake-token')
      .send(detachBody);

    expect(res.status).toBe(409);
  });

  test('🚫 motif trop court → 400', async () => {
    setTestRole('admin');
    const id = newInProgressIssue('Utilisateur Test');

    const res = await request(app)
      .patch(`/api/issues/${id}/detach`)
      .set('Authorization', 'Bearer fake-token')
      .send({ reason: 'court' });

    expect(res.status).toBe(400);
  });
});

// =============================================================================
// 13. PATCH /api/issues/:id/link-equipment — liaison tardive d'un incident
//     créé sans équipement (admin, supervisor, technician* ; un technicien
//     uniquement ses incidents 'In Progress')
// =============================================================================
describe('PATCH /api/issues/:id/link-equipment', () => {
  let linkCounter = 0;
  // Crée un incident sans équipement (equipment_id NULL), au statut/technicien donnés
  const newUnlinkedIssue = (status, technicianName) => {
    const id = `iss-link-${++linkCounter}`;
    db.prepare(`
      INSERT INTO issues (
        id, equipment_id, equipment_name, issue_category, assigned_group,
        department, type, description, reporter, urgency, status, assigned_technician, created_at
      ) VALUES (
        ?, NULL, NULL, 'Infrastructure', 'Infrastructure',
        'OPD', 'Panne', 'Incident sans équipement identifié', 'Dr. Test', 'Moyen', ?, ?,
        datetime('now','localtime')
      )
    `).run(id, status, technicianName);
    return id;
  };

  const linkBody = { equipment_id: 'eq-rbac-test' };

  test('✅ 200 lie l\'équipement avec succès', async () => {
    setTestRole('technician_biomedical');
    const id = newUnlinkedIssue('In Progress', 'Utilisateur Test');

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send(linkBody);

    expect(res.status).toBe(200);
    const iss = db.prepare(
      'SELECT equipment_id, equipment_name, equipment_linked_at FROM issues WHERE id = ?'
    ).get(id);
    expect(iss.equipment_id).toBe('eq-rbac-test');
    expect(iss.equipment_name).toBe('Moniteur cardiaque test');
    expect(iss.equipment_linked_at).not.toBeNull();
  });

  test('🚫 400 equipment_id manquant', async () => {
    setTestRole('admin');
    const id = newUnlinkedIssue('Reported', null);

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send({});

    expect(res.status).toBe(400);
  });

  test('🚫 403 technicien non assigné', async () => {
    setTestRole('technician_biomedical');
    const id = newUnlinkedIssue('In Progress', 'Un Autre Technicien');

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send(linkBody);

    expect(res.status).toBe(403);
  });

  test('🚫 404 incident introuvable', async () => {
    setTestRole('admin');

    const res = await request(app)
      .patch('/api/issues/iss-inconnu/link-equipment')
      .set('Authorization', 'Bearer fake-token')
      .send(linkBody);

    expect(res.status).toBe(404);
  });

  test('🚫 404 équipement introuvable', async () => {
    setTestRole('admin');
    const id = newUnlinkedIssue('Reported', null);

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send({ equipment_id: 'eq-inconnu' });

    expect(res.status).toBe(404);
  });

  test('🚫 409 déjà lié', async () => {
    setTestRole('admin');
    const id = newUnlinkedIssue('Reported', null);
    db.prepare("UPDATE issues SET equipment_id = 'eq-rbac-test', equipment_name = 'Moniteur cardiaque test' WHERE id = ?").run(id);

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send(linkBody);

    expect(res.status).toBe(409);
  });

  test('🚫 409 incident clôturé', async () => {
    setTestRole('admin');
    const id = newUnlinkedIssue('Completed', null);

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send(linkBody);

    expect(res.status).toBe(409);
  });

  test('🚫 409 équipement Disposed', async () => {
    setTestRole('admin');
    db.prepare(`
      INSERT OR IGNORE INTO equipment (id, name, department, category, status)
      VALUES ('eq-link-disposed', 'Équipement réformé test', 'OPD', 'Monitoring', 'Disposed')
    `).run();
    const id = newUnlinkedIssue('Reported', null);

    const res = await request(app)
      .patch(`/api/issues/${id}/link-equipment`)
      .set('Authorization', 'Bearer fake-token')
      .send({ equipment_id: 'eq-link-disposed' });

    expect(res.status).toBe(409);
  });
});
