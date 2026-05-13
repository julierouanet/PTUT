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
  // Schéma legacy avec colonne `role` : conservé pour compatibilité avec les
  // bases existantes. La migration plus bas crée user_roles puis supprime la
  // colonne. Sur fresh DB (tests :memory:), la colonne est créée puis supprimée.
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
  // Le rôle `technician` générique est conservé pour rétro-compat (FK et logs existants)
  // mais n'est plus assigné aux nouveaux utilisateurs : les 3 rôles spécialisés le remplacent.
  const builtinRoles = [
    { name: 'hospitalStaff',          display_name: 'Personnel hospitalier',    description: 'Médecins, infirmiers, techniciens de laboratoire', is_builtin: 1 },
    { name: 'supervisor',             display_name: 'Superviseur',              description: 'Responsables de département',                       is_builtin: 1 },
    { name: 'technician',             display_name: 'Technicien',               description: 'Rôle générique déprécié (remplacé par les 3 spécialisés)', is_builtin: 1 },
    { name: 'technician_biomedical',  display_name: 'Technicien biomédical',    description: 'Maintenance des équipements biomédicaux',           is_builtin: 1 },
    { name: 'technician_it',          display_name: 'Technicien IT',            description: 'Maintenance informatique et réseau',                is_builtin: 1 },
    { name: 'technician_infra',       display_name: 'Technicien infrastructure', description: 'Maintenance bâtiment et infrastructure',           is_builtin: 1 },
    { name: 'admin',                  display_name: 'Administrateur ICT',       description: 'Service informatique',                              is_builtin: 1 },
  ];
  const insertRole = db.prepare('INSERT OR IGNORE INTO roles (name, display_name, description, is_builtin) VALUES (?, ?, ?, ?)');
  for (const r of builtinRoles) {
    insertRole.run(r.name, r.display_name, r.description, r.is_builtin);
  }

  // Seed des permissions par défaut (INSERT OR IGNORE)
  // Les 3 rôles techniciens spécialisés héritent des mêmes permissions que `technician`.
  const techPerms = ['viewEquipment', 'reportIssue', 'trackIssues', 'updateRepairs', 'registerParts'];
  const defaultPerms = {
    hospitalStaff:         ['viewEquipment', 'reportIssue', 'trackIssues'],
    supervisor:            ['viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks'],
    technician:            techPerms,
    technician_biomedical: techPerms,
    technician_it:         techPerms,
    technician_infra:      techPerms,
    admin:                 ['viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks',
                            'updateRepairs', 'registerParts', 'manageEquipment', 'manageUsers',
                            'manageDepartments', 'manageCategories', 'generateReports', 'viewInventory',
                            'changeDepartment'],
  };
  const insertPerm = db.prepare('INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES (?, ?)');
  for (const [roleName, perms] of Object.entries(defaultPerms)) {
    for (const perm of perms) {
      insertPerm.run(roleName, perm);
    }
  }

  // ── Migration : passage à un système multi-rôles ──────────────────────────
  // 1) Crée la table de jonction user_roles
  // 2) Backfill depuis la colonne users.role (les techniciens reçoivent les 3 rôles spécialisés)
  // 3) Recrée la table users sans la colonne role
  // Idempotent : la présence de users.role déclenche la migration ; sinon no-op.
  db.exec(`
    CREATE TABLE IF NOT EXISTS user_roles (
      user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role_name TEXT NOT NULL REFERENCES roles(name) ON DELETE CASCADE,
      PRIMARY KEY (user_id, role_name)
    );
    CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
    CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role_name);
  `);

  const usersCols = db.prepare("PRAGMA table_info(users)").all().map(c => c.name);
  if (usersCols.includes('role')) {
    const migrate = db.transaction(() => {
      // Backfill : récupère le rôle legacy de chaque user et l'insère dans user_roles
      const legacyUsers = db.prepare('SELECT id, role FROM users WHERE role IS NOT NULL').all();
      const insertUserRole = db.prepare('INSERT OR IGNORE INTO user_roles (user_id, role_name) VALUES (?, ?)');
      for (const u of legacyUsers) {
        if (u.role === 'technician') {
          // Tous les techniciens existants reçoivent les 3 rôles spécialisés (à affiner manuellement ensuite)
          insertUserRole.run(u.id, 'technician_biomedical');
          insertUserRole.run(u.id, 'technician_it');
          insertUserRole.run(u.id, 'technician_infra');
        } else {
          insertUserRole.run(u.id, u.role);
        }
      }

      // Recrée la table users sans la colonne role (SQLite < 3.35 ne supporte pas DROP COLUMN)
      db.exec(`
        CREATE TABLE users_new (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          department TEXT NOT NULL,
          phone TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          first_name TEXT,
          last_name TEXT
        );
        INSERT INTO users_new (id, name, email, password_hash, department, phone, is_active, created_at, first_name, last_name)
          SELECT id, name, email, password_hash, department, phone, is_active, created_at, first_name, last_name FROM users;
        DROP TABLE users;
        ALTER TABLE users_new RENAME TO users;
        CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
      `);

      console.log(`[DB] Migration multi-rôles: ${legacyUsers.length} utilisateurs migrés vers user_roles, colonne users.role supprimée`);
    });
    migrate();
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
