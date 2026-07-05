'use strict';

// ── Tests de la migration one-shot _supervisor_role_v2 ────────────────────────
// Le rôle supervisor devient « consultation + signalement + rapports » :
// retrait de approveRequests/assignTasks, ajout de generateReports.
// La migration ne doit s'exécuter qu'UNE fois (marqueur en DB) pour ne pas
// écraser les réglages admin ultérieurs faits via PUT /api/roles/:name/permissions.
//
// ⚠️ Ce fichier utilise une DB FICHIER temporaire (pas :memory:) : c'est le seul
// moyen de simuler plusieurs démarrages successifs du service (closeDb + getDb)
// sans perdre les données entre les boots.

const os   = require('os');
const fs   = require('fs');
const path = require('path');

const TEST_DB_PATH = path.join(os.tmpdir(), `auth-test-supervisor-migration-${process.pid}-${Date.now()}.db`);
process.env.DB_PATH   = TEST_DB_PATH;
process.env.KC_ISSUER = 'http://keycloak-test/realms/kabutare-hospital';

// ── Mock rate-limiter ─────────────────────────────────────────────────────────
jest.mock('express-rate-limit', () => () => (req, res, next) => next());

const { getDb, closeDb } = require('../database');

const SUPERVISOR_EXPECTED = [
  'generateReports',
  'reportIssue',
  'trackIssues',
  'viewEquipment',
  'viewInterventionDocuments',
];

function supervisorPerms(db) {
  return db.prepare(
    "SELECT permission FROM role_permissions WHERE role_name = 'supervisor' ORDER BY permission"
  ).all().map((r) => r.permission);
}

afterAll(() => {
  closeDb();
  // Nettoyage du fichier temporaire (+ fichiers WAL/SHM éventuels)
  for (const suffix of ['', '-wal', '-shm']) {
    try { fs.unlinkSync(TEST_DB_PATH + suffix); } catch (_) {}
  }
});

describe('Migration _supervisor_role_v2 — rôle supervisor consultation + rapports', () => {
  test('✅ 1er démarrage : supervisor = exactement les 5 permissions attendues', () => {
    const db = getDb();
    expect(supervisorPerms(db)).toEqual(SUPERVISOR_EXPECTED);
  });

  test('✅ le marqueur _supervisor_role_v2 est posé', () => {
    const db = getDb();
    const marker = db.prepare('SELECT done FROM _supervisor_role_v2 WHERE done = 1').get();
    expect(marker).toBeDefined();
  });

  test('✅ rejouable sans effet : un réglage admin ultérieur survit au redémarrage', () => {
    let db = getDb();

    // Simule un réglage admin post-migration via PUT /api/roles/supervisor/permissions
    db.prepare(
      "INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES ('supervisor', 'approveRequests')"
    ).run();

    // Redémarrage du service (relance initTables sur la même DB fichier)
    closeDb();
    db = getDb();

    // La migration ne s'est PAS rejouée : le réglage admin est intact
    const perms = supervisorPerms(db);
    expect(perms).toContain('approveRequests');
    // Et les permissions du nouveau rôle sont toujours là
    for (const p of SUPERVISOR_EXPECTED) expect(perms).toContain(p);
  });
});
