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
