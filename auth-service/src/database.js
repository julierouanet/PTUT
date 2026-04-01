const Database = require('better-sqlite3');
const config = require('./config');

let db;

/**
 * Get or create database connection
 */
function getDb() {
  if (!db) {
    db = new Database(config.DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initTables();
  }
  return db;
}

/**
 * Create tables if they don't exist
 */
function initTables() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      department TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('hospitalStaff','supervisor','technician','admin')),
      phone TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token TEXT UNIQUE NOT NULL,
      expires_at TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token ON refresh_tokens(token);
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
  `);

  // Table des demandes de changement de département
  db.exec(`
    CREATE TABLE IF NOT EXISTS department_change_requests (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      user_name TEXT NOT NULL,
      current_department TEXT NOT NULL,
      requested_department TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      admin_id TEXT,
      admin_note TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      resolved_at TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_dept_req_user   ON department_change_requests(user_id);
    CREATE INDEX IF NOT EXISTS idx_dept_req_status ON department_change_requests(status);
  `);

  // Migration : ajout des colonnes first_name et last_name
  const cols = db.prepare("PRAGMA table_info(users)").all().map(c => c.name);
  if (!cols.includes('first_name')) {
    db.exec(`ALTER TABLE users ADD COLUMN first_name TEXT`);
    db.exec(`ALTER TABLE users ADD COLUMN last_name TEXT`);
    // Migrer les donnees existantes : splitter 'name' en first_name / last_name
    const users = db.prepare('SELECT id, name FROM users').all();
    const updateStmt = db.prepare('UPDATE users SET first_name = ?, last_name = ? WHERE id = ?');
    for (const u of users) {
      const parts = (u.name || '').split(' ');
      const firstName = parts[0] || '';
      const lastName = parts.slice(1).join(' ') || '';
      updateStmt.run(firstName, lastName, u.id);
    }
    console.log(`[DB] Migration first_name/last_name: ${users.length} utilisateurs migrés`);
  }

  // Tables des rôles et permissions
  db.exec(`
    CREATE TABLE IF NOT EXISTS roles (
      name TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      description TEXT,
      is_builtin INTEGER DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS role_permissions (
      role_name TEXT NOT NULL REFERENCES roles(name) ON DELETE CASCADE,
      permission TEXT NOT NULL,
      PRIMARY KEY (role_name, permission)
    );
  `);

  // Seed des rôles intégrés (INSERT OR IGNORE pour idempotence)
  const builtinRoles = [
    { name: 'hospitalStaff', display_name: 'Personnel hospitalier', description: 'Médecins, infirmiers, techniciens de laboratoire', is_builtin: 1 },
    { name: 'supervisor',    display_name: 'Superviseur',           description: 'Responsables de département',                        is_builtin: 1 },
    { name: 'technician',   display_name: 'Technicien',            description: 'Équipe technique de maintenance',                     is_builtin: 1 },
    { name: 'admin',        display_name: 'Administrateur ICT',     description: 'Service informatique',                               is_builtin: 1 },
  ];
  const insertRole = db.prepare('INSERT OR IGNORE INTO roles (name, display_name, description, is_builtin) VALUES (?, ?, ?, ?)');
  for (const r of builtinRoles) {
    insertRole.run(r.name, r.display_name, r.description, r.is_builtin);
  }

  // Seed des permissions par défaut (INSERT OR IGNORE)
  const defaultPerms = {
    hospitalStaff: ['viewEquipment', 'reportIssue', 'trackIssues'],
    supervisor:    ['viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks'],
    technician:    ['viewEquipment', 'reportIssue', 'trackIssues', 'updateRepairs', 'registerParts'],
    admin:         ['viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks',
                    'updateRepairs', 'registerParts', 'manageEquipment', 'manageUsers',
                    'manageDepartments', 'manageCategories', 'generateReports', 'viewInventory'],
  };
  const insertPerm = db.prepare('INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES (?, ?)');
  for (const [roleName, perms] of Object.entries(defaultPerms)) {
    for (const perm of perms) {
      insertPerm.run(roleName, perm);
    }
  }
}

/**
 * Close the database connection
 */
function closeDb() {
  if (db) {
    db.close();
    db = null;
  }
}

/**
 * Reset database connection (for testing)
 */
function resetDb() {
  closeDb();
}

module.exports = { getDb, closeDb, resetDb };
