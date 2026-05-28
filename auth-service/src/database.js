// ── Base de données auth.db ───────────────────────────────────────────────────
// Après migration Keycloak, auth.db conserve uniquement :
//   - role_permissions : permissions applicatives par rôle (Keycloak gère les rôles)
//   - department_change_requests : workflow de changement de département
//
// Les tables users, user_roles, refresh_tokens, roles sont des tables legacy
// qui peuvent encore exister sur des déploiements existants mais ne sont plus
// utilisées ni créées sur de nouvelles installations.

'use strict';

const Database = require('better-sqlite3');
const config   = require('./config');

let db;

function getDb() {
  if (!db) {
    db = new Database(config.DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initTables();
  }
  return db;
}

function initTables() {
  // ── Tables actives post-migration ─────────────────────────────────────────

  // role_permissions : mapping rôle (nom Keycloak) → permissions applicatives
  // La FK vers `roles` est supprimée : les rôles vivent désormais dans Keycloak.
  // Si la table existe avec la FK legacy, elle est migrée ci-dessous.
  db.exec(`
    CREATE TABLE IF NOT EXISTS role_permissions_v2 (
      role_name  TEXT NOT NULL,
      permission TEXT NOT NULL,
      PRIMARY KEY (role_name, permission)
    );
  `);

  // Migrer role_permissions → role_permissions_v2 si la table legacy existe
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map((t) => t.name);
  if (tables.includes('role_permissions') && !tables.includes('_rp_migrated')) {
    db.transaction(() => {
      db.exec(`
        INSERT OR IGNORE INTO role_permissions_v2 (role_name, permission)
          SELECT role_name, permission FROM role_permissions;
        DROP TABLE role_permissions;
        ALTER TABLE role_permissions_v2 RENAME TO role_permissions;
      `);
      // Marqueur idempotence
      db.exec(`CREATE TABLE IF NOT EXISTS _rp_migrated (done INTEGER)`);
      db.prepare(`INSERT OR IGNORE INTO _rp_migrated VALUES (1)`).run();
    })();
    console.log('[DB] Migration role_permissions : FK vers roles supprimée.');
  } else if (!tables.includes('role_permissions')) {
    db.exec(`ALTER TABLE role_permissions_v2 RENAME TO role_permissions;`);
  } else {
    // Supprimer la table temporaire si elle existe toujours
    if (tables.includes('role_permissions_v2')) {
      db.exec(`DROP TABLE role_permissions_v2;`);
    }
  }

  // department_change_requests : sans FK vers users (Keycloak gère les users)
  db.exec(`
    CREATE TABLE IF NOT EXISTS department_change_requests (
      id                   TEXT PRIMARY KEY,
      user_id              TEXT NOT NULL,
      user_name            TEXT NOT NULL,
      current_department   TEXT NOT NULL,
      requested_department TEXT NOT NULL,
      status               TEXT NOT NULL DEFAULT 'pending',
      admin_id             TEXT,
      admin_note           TEXT,
      created_at           TEXT DEFAULT CURRENT_TIMESTAMP,
      resolved_at          TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_dept_req_user   ON department_change_requests(user_id);
    CREATE INDEX IF NOT EXISTS idx_dept_req_status ON department_change_requests(status);
  `);

  // Migrer department_change_requests si elle existe avec une FK vers users
  const dcrFks = db.prepare("SELECT * FROM pragma_foreign_key_list('department_change_requests')").all();
  if (dcrFks.some((fk) => fk.table === 'users')) {
    db.transaction(() => {
      db.exec(`
        CREATE TABLE department_change_requests_new (
          id                   TEXT PRIMARY KEY,
          user_id              TEXT NOT NULL,
          user_name            TEXT NOT NULL,
          current_department   TEXT NOT NULL,
          requested_department TEXT NOT NULL,
          status               TEXT NOT NULL DEFAULT 'pending',
          admin_id             TEXT,
          admin_note           TEXT,
          created_at           TEXT DEFAULT CURRENT_TIMESTAMP,
          resolved_at          TEXT
        );
        INSERT INTO department_change_requests_new
          SELECT id, user_id, user_name, current_department, requested_department,
                 status, admin_id, admin_note, created_at, resolved_at
          FROM department_change_requests;
        DROP TABLE department_change_requests;
        ALTER TABLE department_change_requests_new RENAME TO department_change_requests;
        CREATE INDEX IF NOT EXISTS idx_dept_req_user   ON department_change_requests(user_id);
        CREATE INDEX IF NOT EXISTS idx_dept_req_status ON department_change_requests(status);
      `);
    })();
    console.log('[DB] Migration department_change_requests : FK vers users supprimée.');
  }

  // role_change_requests : sans FK vers users (Keycloak gère les users)
  db.exec(`
    CREATE TABLE IF NOT EXISTS role_change_requests (
      id             TEXT PRIMARY KEY,
      user_id        TEXT NOT NULL,
      user_name      TEXT NOT NULL,
      current_roles  TEXT NOT NULL,
      requested_role TEXT NOT NULL,
      status         TEXT NOT NULL DEFAULT 'pending',
      admin_id       TEXT,
      admin_note     TEXT,
      created_at     TEXT DEFAULT CURRENT_TIMESTAMP,
      resolved_at    TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_role_req_user   ON role_change_requests(user_id);
    CREATE INDEX IF NOT EXISTS idx_role_req_status ON role_change_requests(status);
  `);

  // ── Seed des permissions par défaut (idempotent) ───────────────────────────
  const techPerms = ['viewEquipment', 'reportIssue', 'trackIssues', 'updateRepairs', 'registerParts'];
  const defaultPerms = {
    hospitalStaff:         ['viewEquipment', 'reportIssue', 'trackIssues'],
    supervisor:            ['viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks'],
    technician:            techPerms,
    technician_biomedical: techPerms,
    technician_it:         techPerms,
    technician_infra:      techPerms,
    admin: [
      'viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks',
      'updateRepairs', 'registerParts', 'manageEquipment', 'manageUsers',
      'manageDepartments', 'manageCategories', 'generateReports', 'viewInventory',
      'changeDepartment', 'manageFeatures', 'manageBackups',
    ],
  };
  const insertPerm = db.prepare('INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES (?, ?)');
  for (const [roleName, perms] of Object.entries(defaultPerms)) {
    for (const perm of perms) insertPerm.run(roleName, perm);
  }
}

function closeDb() {
  if (db) { db.close(); db = null; }
}

function resetDb() { closeDb(); }

module.exports = { getDb, closeDb, resetDb };
