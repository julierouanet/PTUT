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

  // access_requests : demandes d'accès depuis l'écran de connexion (non authentifié)
  db.exec(`
    CREATE TABLE IF NOT EXISTS access_requests (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      first_name TEXT NOT NULL,
      last_name  TEXT NOT NULL,
      email      TEXT NOT NULL,
      department TEXT,
      role       TEXT,
      status     TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_access_req_status ON access_requests(status);
    CREATE INDEX IF NOT EXISTS idx_access_req_email  ON access_requests(email);
  `);

  // ── Préférences de notifications email par utilisateur ────────────────────
  // Pas de FK vers users : Keycloak gère les utilisateurs.
  // Les notifications superviseur restent centrées sur les incidents CRITIQUES ;
  // la notification technicien "nouvel incident" applique désormais un seuil
  // d'urgence minimal configurable (min_urgency_new_issue).
  // preferences_set = 0 indique une première connexion (modal de configuration à afficher).
  db.exec(`
    CREATE TABLE IF NOT EXISTS user_notification_preferences (
      user_id                     TEXT PRIMARY KEY,
      notify_new_issue            INTEGER NOT NULL DEFAULT 1,
      min_urgency_new_issue       TEXT NOT NULL DEFAULT 'Critique',
      notify_critical_acknowledged INTEGER NOT NULL DEFAULT 1,
      notify_critical_diagnosed   INTEGER NOT NULL DEFAULT 1,
      notify_critical_resolved    INTEGER NOT NULL DEFAULT 1,
      notify_pm_due               INTEGER NOT NULL DEFAULT 1,
      notify_monthly_report       INTEGER NOT NULL DEFAULT 1,
      preferences_set             INTEGER NOT NULL DEFAULT 0,
      updated_at                  TEXT DEFAULT (datetime('now','localtime'))
    );
  `);

  // Migrations idempotentes : ajout des nouvelles colonnes sur les installations existantes
  try { db.exec("ALTER TABLE user_notification_preferences ADD COLUMN notify_critical_new_issue INTEGER NOT NULL DEFAULT 1"); } catch (_) {}
  try { db.exec("ALTER TABLE user_notification_preferences ADD COLUMN notify_critical_acknowledged INTEGER NOT NULL DEFAULT 1"); } catch (_) {}
  try { db.exec("ALTER TABLE user_notification_preferences ADD COLUMN notify_critical_diagnosed INTEGER NOT NULL DEFAULT 1"); } catch (_) {}
  try { db.exec("ALTER TABLE user_notification_preferences ADD COLUMN notify_critical_resolved INTEGER NOT NULL DEFAULT 1"); } catch (_) {}
  try { db.exec("ALTER TABLE access_requests ADD COLUMN phone TEXT"); } catch (_) {}
  // FEAT — Seuil d'urgence minimal pour la notification technicien "nouvel incident"
  try { db.exec("ALTER TABLE user_notification_preferences RENAME COLUMN notify_critical_new_issue TO notify_new_issue"); } catch (_) {}
  try { db.exec("ALTER TABLE user_notification_preferences ADD COLUMN min_urgency_new_issue TEXT NOT NULL DEFAULT 'Critique'"); } catch (_) {}
  // FEAT — Rapport KPI mensuel par email (opt-out individuel, superviseurs et admins)
  try { db.exec("ALTER TABLE user_notification_preferences ADD COLUMN notify_monthly_report INTEGER NOT NULL DEFAULT 1"); } catch (_) {}

  // ── Seed des permissions par défaut (idempotent) ───────────────────────────
  const techPerms = ['viewEquipment', 'reportIssue', 'trackIssues', 'updateRepairs', 'registerParts', 'approveRequests', 'viewInterventionDocuments'];
  const defaultPerms = {
    hospitalStaff:         ['viewEquipment', 'reportIssue', 'trackIssues'],
    // supervisor = chef de département « view-only manager » : consultation +
    // signalement + rapports. La validation des incidents revient aux
    // techniciens et à l'admin (voir migration _supervisor_role_v2 ci-dessous).
    supervisor:            ['viewEquipment', 'reportIssue', 'trackIssues', 'viewInterventionDocuments', 'generateReports'],
    technician:            techPerms,
    technician_biomedical: techPerms,
    technician_it:         techPerms,
    technician_infra:      techPerms,
    admin: [
      'viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks',
      'updateRepairs', 'registerParts', 'manageEquipment', 'manageUsers',
      'manageDepartments', 'manageCategories', 'generateReports', 'viewInventory',
      'changeDepartment', 'manageFeatures', 'manageBackups', 'viewInterventionDocuments',
    ],
  };
  const insertPerm = db.prepare('INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES (?, ?)');
  for (const [roleName, perms] of Object.entries(defaultPerms)) {
    for (const perm of perms) insertPerm.run(roleName, perm);
  }

  // ── Migration one-shot : rôle supervisor → consultation + rapports ─────────
  // Retire approveRequests/assignTasks et ajoute generateReports au supervisor.
  // One-shot (marqueur _supervisor_role_v2) : ne s'exécute qu'une fois pour ne
  // pas écraser d'éventuels réglages admin ultérieurs faits via
  // PUT /api/roles/:name/permissions.
  db.exec('CREATE TABLE IF NOT EXISTS _supervisor_role_v2 (done INTEGER PRIMARY KEY)');
  const supMigrated = db.prepare('SELECT done FROM _supervisor_role_v2 WHERE done = 1').get();
  if (!supMigrated) {
    db.transaction(() => {
      db.prepare("DELETE FROM role_permissions WHERE role_name = 'supervisor' AND permission IN ('approveRequests', 'assignTasks')").run();
      db.prepare("INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES ('supervisor', 'generateReports')").run();
      db.prepare('INSERT OR IGNORE INTO _supervisor_role_v2 (done) VALUES (1)').run();
    })();
    console.log('[AUTH] Migration supervisor_role_v2 : supervisor = consultation + signalement + rapports.');
  }

  // ── Feature flags : table principale + overrides par rôle ─────────────────
  // feature_flags : un flag par module désactivable (Settings est intentionnellement absent).
  // feature_flag_overrides : exceptions par rôle Keycloak (ex: désactiver pour hospitalStaff).
  db.exec(`
    CREATE TABLE IF NOT EXISTS feature_flags (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      description TEXT,
      enabled     INTEGER NOT NULL DEFAULT 1,
      updated_at  TEXT DEFAULT (datetime('now','localtime')),
      updated_by  TEXT
    );

    CREATE TABLE IF NOT EXISTS feature_flag_overrides (
      flag_id  TEXT NOT NULL,
      role     TEXT NOT NULL,
      enabled  INTEGER NOT NULL,
      PRIMARY KEY (flag_id, role),
      FOREIGN KEY (flag_id) REFERENCES feature_flags(id) ON DELETE CASCADE
    );
  `);

  // ── Paramètres applicatifs : table clé/valeur pilotée par l'admin ─────────────
  // Permet de configurer contact de connexion et Brevo sans toucher aux .env.
  db.exec(`
    CREATE TABLE IF NOT EXISTS app_settings (
      key        TEXT PRIMARY KEY,
      value      TEXT,
      is_secret  INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT DEFAULT (datetime('now','localtime')),
      updated_by TEXT
    );
  `);
  const insertSetting = db.prepare(
    'INSERT OR IGNORE INTO app_settings (key, value, is_secret) VALUES (?, ?, ?)'
  );
  insertSetting.run('login_contact_title', 'Urgence ou compte bloqué ?', 0);
  insertSetting.run('login_contact_email', 'nzephmd@gmail.com', 0);
  insertSetting.run('login_contact_phone', '+250 788 823 228', 0);
  insertSetting.run('brevo_api_key',       '', 1);
  insertSetting.run('brevo_sender_email',  '', 0);
  insertSetting.run('brevo_sender_name',   '', 0);

  // ── role_hierarchy : hiérarchie logique des rôles (technician → spécialisés)
  // Keycloak Composite Roles n'est pas utilisé dans ce projet — la hiérarchie
  // est gérée ici. Un rôle enfant hérite des permissions de son parent.
  db.exec(`
    CREATE TABLE IF NOT EXISTS role_hierarchy (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      parent_role TEXT NOT NULL,
      child_role  TEXT NOT NULL,
      created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime')),
      UNIQUE(parent_role, child_role)
    );
  `);
  // Seed : hiérarchie technician (idempotent)
  const insertHierarchy = db.prepare('INSERT OR IGNORE INTO role_hierarchy (parent_role, child_role) VALUES (?, ?)');
  insertHierarchy.run('technician', 'technician_biomedical');
  insertHierarchy.run('technician', 'technician_it');
  insertHierarchy.run('technician', 'technician_infra');

  // Seed des flags par défaut (idempotent — INSERT OR IGNORE)
  const defaultFlags = [
    {
      id:          'equipment',
      name:        'Module Équipement',
      description: 'Gestion des équipements médicaux, incidents et maintenance préventive',
    },
    {
      id:          'inventory',
      name:        'Module Inventaire',
      description: 'Gestion des stocks de fournitures et consommables médicaux',
    },
  ];
  const insertFlag = db.prepare(
    'INSERT OR IGNORE INTO feature_flags (id, name, description, enabled) VALUES (?, ?, ?, 1)'
  );
  for (const flag of defaultFlags) {
    insertFlag.run(flag.id, flag.name, flag.description);
  }
}

function closeDb() {
  if (db) { db.close(); db = null; }
}

function resetDb() { closeDb(); }

module.exports = { getDb, closeDb, resetDb };
