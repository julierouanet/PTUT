'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

let mockCurrentRoles = ['admin'];
function setTestRole(...roles) {
  mockCurrentRoles = roles;
}

jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = {
      id:         'test-uuid-import-0001',
      email:      'test@kabutare.rw',
      name:       'Utilisateur Import',
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
const { logAction } = require('../utils/logger');

let db;

beforeAll(() => {
  db = getDb();
});

afterAll(() => {
  if (server) server.close();
  closeDb();
});

afterEach(() => {
  jest.clearAllMocks();
});

const csvBuffer = (text) => Buffer.from(text, 'utf-8');

const HEADER = 'name,department,category,serial_number,status,location,manufacturer,model,manuf_year,install_date,building,tag_number,criticality';

describe('POST /api/equipment/import-csv — RBAC', () => {
  const ROLES_AUTORISÉS = ['admin', 'supervisor', 'technician_biomedical', 'technician_it', 'technician_infra'];
  const ROLES_REFUSÉS   = ['hospitalStaff', 'technician'];

  test.each(ROLES_AUTORISÉS)('✅ rôle %s peut importer via CSV → 200', async (role) => {
    setTestRole(role);
    const csv = `${HEADER}\nÉquip ${role},OPD,Monitoring,SN-RBAC-${role},,,,,,,,,\n`;

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(1);
  });

  test.each(ROLES_REFUSÉS)('🚫 rôle %s ne peut PAS importer via CSV → 403', async (role) => {
    setTestRole(role);
    const csv = `${HEADER}\nÉquip refusé,OPD,Monitoring,SN-RBAC-refuse-${role},,,,,,,,,\n`;

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(403);
  });

  test.each(['technician_biomedical', 'technician_it', 'technician_infra'])(
    '✅ rôle %s peut créer un équipement via POST unitaire → 201',
    async (role) => {
      setTestRole(role);

      const res = await request(app)
        .post('/api/equipment')
        .set('Authorization', 'Bearer fake-token')
        .send({ id: `eq-unit-${role}`, name: 'Test', department: 'OPD', category: 'Monitoring', tag_number: `TAG-unit-${role}` });

      expect(res.status).toBe(201);
    }
  );
});

describe('POST /api/equipment/import-csv — import valide', () => {
  test('✅ toutes les lignes insérées, created_by renseigné, pas de reason', async () => {
    setTestRole('admin');
    const csv = `${HEADER}\n`
      + 'Moniteur Import A,OPD,Monitoring,SN-IMPORT-A,,,,,,,,,\n'
      + 'Moniteur Import B,ICU,Monitoring,SN-IMPORT-B,Maintenance,,,,,,,,B\n';

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(2);
    expect(res.body.errors).toHaveLength(0);

    const rowA = db.prepare('SELECT * FROM equipment WHERE serial_number = ?').get('SN-IMPORT-A');
    expect(rowA).toBeDefined();
    expect(rowA.created_by_id).toBe('test-uuid-import-0001');
    expect(rowA.created_by_name).toBe('Utilisateur Import');
    expect(rowA.status).toBe('Operational');

    expect(logAction).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'create_equipment_import_csv' })
    );
  });
});

describe('POST /api/equipment/import-csv — dry-run', () => {
  test('✅ dry-run : aucune écriture en base, would_insert correct, aucun logAction', async () => {
    setTestRole('admin');
    const before = db.prepare('SELECT COUNT(*) c FROM equipment').get().c;

    const csv = `${HEADER}\nMoniteur Dry Run,OPD,Monitoring,SN-DRYRUN-1,,,,,,,,,\n`;

    const res = await request(app)
      .post('/api/equipment/import-csv?dry_run=true')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.dry_run).toBe(true);
    expect(res.body.would_insert).toBe(1);

    const after = db.prepare('SELECT COUNT(*) c FROM equipment').get().c;
    expect(after).toBe(before);
    expect(logAction).not.toHaveBeenCalled();
  });
});

describe('POST /api/equipment/import-csv — doublon serial_number', () => {
  test('🚫 ligne rejetée pour doublon, les autres lignes valides restent importées', async () => {
    setTestRole('admin');

    db.prepare(`
      INSERT OR IGNORE INTO equipment (id, name, department, category, serial_number, status)
      VALUES ('eq-existant-serial', 'Déjà en base', 'OPD', 'Monitoring', 'SN-DEJA-EXISTANT', 'Operational')
    `).run();

    const csv = `${HEADER}\n`
      + 'Nouveau Valide,OPD,Monitoring,SN-NOUVEAU-VALIDE,,,,,,,,,\n'
      + 'Doublon Serial,OPD,Monitoring,SN-DEJA-EXISTANT,,,,,,,,,\n';

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(1);
    expect(res.body.errors).toHaveLength(1);
    expect(res.body.errors[0]).toEqual({
      line: 3,
      reason: 'équipement déjà existant (numéro de série en doublon)',
    });

    const valid = db.prepare('SELECT * FROM equipment WHERE serial_number = ?').get('SN-NOUVEAU-VALIDE');
    expect(valid).toBeDefined();
  });
});

describe('POST /api/equipment/import-csv — doublon tag_number', () => {
  test('🚫 ligne rejetée pour tag physique déjà utilisé, les autres lignes valides restent importées', async () => {
    setTestRole('admin');

    db.prepare(`
      INSERT OR IGNORE INTO equipment (id, name, department, category, serial_number, status)
      VALUES ('eq-existant-tag', 'Déjà en base tag', 'OPD', 'Monitoring', 'SN-DEJA-TAG', 'Operational')
    `).run();
    db.prepare(`
      INSERT OR IGNORE INTO equipment_tags (equipment_id, tag_number) VALUES ('eq-existant-tag', 'TAG-DEJA-EXISTANT')
    `).run();

    const csv = `${HEADER}\n`
      + 'Nouveau Valide Tag,OPD,Monitoring,SN-NOUVEAU-TAG-VALIDE,,,,,,,,TAG-NOUVEAU,\n'
      + 'Doublon Tag,OPD,Monitoring,SN-NOUVEAU-TAG-2,,,,,,,,TAG-DEJA-EXISTANT,\n';

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(1);
    expect(res.body.errors).toHaveLength(1);
    expect(res.body.errors[0]).toEqual({
      line: 3,
      reason: 'tag physique déjà utilisé (doublon)',
    });

    const valid = db.prepare('SELECT * FROM equipment WHERE serial_number = ?').get('SN-NOUVEAU-TAG-VALIDE');
    expect(valid).toBeDefined();
  });
});

describe('POST /api/equipment/import-csv — collision de slug intra-fichier', () => {
  test('✅ 2ème ligne avec même nom (pas de serial) obtient un slug suffixé -2, pas rejetée', async () => {
    setTestRole('admin');

    const csv = `${HEADER}\n`
      + 'Nom Identique Collision,OPD,Monitoring,,,,,,,,,,\n'
      + 'Nom Identique Collision,ICU,Monitoring,,,,,,,,,,\n';

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(2);
    expect(res.body.errors).toHaveLength(0);

    const rows = db.prepare("SELECT id FROM equipment WHERE name = 'Nom Identique Collision' ORDER BY id").all();
    expect(rows).toHaveLength(2);
    expect(rows.some((r) => r.id.endsWith('-2'))).toBe(true);
  });
});

describe('POST /api/equipment/import-csv — erreurs de fichier', () => {
  test('🚫 fichier absent → 400', async () => {
    setTestRole('admin');

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token');

    expect(res.status).toBe(400);
  });

  test('🚫 colonnes requises manquantes → 400', async () => {
    setTestRole('admin');
    const csv = 'foo,bar\nval1,val2\n';

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Colonne/);
  });

  test('🚫 contenu binaire (xlsx renommé .csv) → 400 explicite, pas de crash', async () => {
    setTestRole('admin');
    // Buffer binaire aléatoire, ne ressemble à aucun format connu
    const binary = Buffer.from([0x50, 0x4b, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00, 0x99, 0x88, 0x77, 0x66]);

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', binary, 'fake.csv');

    expect(res.status).toBe(400);
    expect(typeof res.body.error).toBe('string');
    expect(res.body.error.length).toBeGreaterThan(0);
  });

  test('🚫 status invalide dans une ligne → erreur ligne, pas de crash', async () => {
    setTestRole('admin');
    const csv = `${HEADER}\nÉquip Statut Invalide,OPD,Monitoring,SN-STATUT-INVALIDE,StatutBidon,,,,,,,,\n`;

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(0);
    expect(res.body.errors[0].reason).toBe('status invalide');
  });

  test('🚫 champ requis manquant (department vide) → erreur ligne', async () => {
    setTestRole('admin');
    const csv = `${HEADER}\nÉquip Sans Departement,,Monitoring,SN-SANS-DEPT,,,,,,,,,\n`;

    const res = await request(app)
      .post('/api/equipment/import-csv')
      .set('Authorization', 'Bearer fake-token')
      .attach('file', csvBuffer(csv), 'import.csv');

    expect(res.status).toBe(200);
    expect(res.body.inserted).toBe(0);
    expect(res.body.errors[0]).toEqual({ line: 2, reason: "champ 'department' manquant" });
  });
});
