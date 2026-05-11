const Database = require('better-sqlite3');
const config = require('./config');

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
  db.exec(`
    CREATE TABLE IF NOT EXISTS equipment (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      department TEXT NOT NULL,
      category TEXT NOT NULL,
      serial_number TEXT,
      status TEXT NOT NULL DEFAULT 'Operational',
      supplier TEXT,
      location TEXT,
      created_at TEXT DEFAULT (datetime('now','localtime')),
      updated_at TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS maintenance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
      date TEXT NOT NULL,
      intervention TEXT NOT NULL,
      technician TEXT NOT NULL,
      is_future INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS issues (
      id TEXT PRIMARY KEY,
      equipment_id TEXT NOT NULL,
      equipment_name TEXT NOT NULL,
      department TEXT NOT NULL,
      type TEXT NOT NULL,
      description TEXT NOT NULL,
      reporter TEXT NOT NULL,
      created_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'Ouvert',
      assigned_technician TEXT,
      diagnosis TEXT,
      actions TEXT,
      parts_replaced TEXT,
      updated_at TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS inventory (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      current_stock INTEGER NOT NULL DEFAULT 0,
      min_stock INTEGER NOT NULL DEFAULT 0,
      unit TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'Normal',
      last_restocked TEXT,
      updated_at TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT DEFAULT (datetime('now','localtime')),
      user_id TEXT,
      user_name TEXT NOT NULL,
      user_role TEXT NOT NULL,
      action TEXT NOT NULL,
      target_type TEXT,
      target_id TEXT,
      target_name TEXT,
      details TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_equipment_dept ON equipment(department);
    CREATE INDEX IF NOT EXISTS idx_equipment_status ON equipment(status);
    CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);
    CREATE INDEX IF NOT EXISTS idx_issues_equipment ON issues(equipment_id);
    CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp);
    CREATE INDEX IF NOT EXISTS idx_logs_user ON logs(user_id);
    CREATE INDEX IF NOT EXISTS idx_logs_action ON logs(action);

    -- ── Tables de référence pour l'inventaire physique ───────────────
    CREATE TABLE IF NOT EXISTS departments (
      id   INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS equipment_categories (
      id   INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    );

    -- ── Tags d'équipement (relation N tags ↔ 1 équipement) ───────────
    CREATE TABLE IF NOT EXISTS equipment_tags (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
      tag_number   TEXT NOT NULL,
      UNIQUE(equipment_id, tag_number)
    );
    CREATE INDEX IF NOT EXISTS idx_equipment_tags_tag ON equipment_tags(tag_number);
  `);

  // Migration : ajout des colonnes ip_address et user_agent si elles n'existent pas
  try { db.exec('ALTER TABLE logs ADD COLUMN ip_address TEXT'); } catch (_) {}
  try { db.exec('ALTER TABLE logs ADD COLUMN user_agent TEXT'); } catch (_) {}

  // Migration : ajout des colonnes reporter_id, reporter_email dans issues si elles n'existent pas
  try { db.exec("ALTER TABLE issues ADD COLUMN reporter_id TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE issues ADD COLUMN reporter_email TEXT"); } catch (_) {}

  // Migration : ajout de la colonne urgency dans issues
  try { db.exec("ALTER TABLE issues ADD COLUMN urgency TEXT DEFAULT 'Moyen'"); } catch (_) {}

  // Migration : ajout de la colonne next_revision_date dans equipment
  try { db.exec("ALTER TABLE equipment ADD COLUMN next_revision_date TEXT"); } catch (_) {}

  // Migration : colonnes additionnelles pour l'inventaire physique 2025-2026
  try { db.exec("ALTER TABLE equipment ADD COLUMN manufacturer TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN model TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN manuf_year INTEGER"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN install_date TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN department_id INTEGER REFERENCES departments(id)"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN category_id INTEGER REFERENCES equipment_categories(id)"); } catch (_) {}

  // Migration : fusion supplier -> manufacturer (le XLSX d'inventaire physique
  // ne distingue pas les deux concepts ; la colonne supplier devient redondante).
  // 1) On copie supplier vers manufacturer si manufacturer est encore NULL
  //    (idempotent : ne fait rien si la colonne supplier a déjà été droppée).
  try {
    db.exec(`
      UPDATE equipment
         SET manufacturer = supplier
       WHERE manufacturer IS NULL AND supplier IS NOT NULL
    `);
  } catch (_) {}
  // 2) Suppression définitive de la colonne supplier (SQLite >= 3.35)
  try { db.exec("ALTER TABLE equipment DROP COLUMN supplier"); } catch (_) {}

  // Migration : maintenance préventive (dates planifiées sur l'équipement)
  try { db.exec("ALTER TABLE equipment ADD COLUMN last_preventive_maintenance TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN next_preventive_maintenance TEXT"); } catch (_) {}

  // Migration : refonte des statuts d'équipement (français → anglais, 7 → 5 valeurs).
  // Idempotent : ne touche que les lignes qui ont encore une valeur FR héritée.
  try {
    db.exec(`
      UPDATE equipment SET status = CASE status
        WHEN 'Disponible'     THEN 'Operational'
        WHEN 'En service'     THEN 'Operational'
        WHEN 'En usage'       THEN 'Operational'
        WHEN 'En maintenance' THEN 'Maintenance'
        WHEN 'Hors service'   THEN 'Out of service'
        WHEN 'Inactif'        THEN 'Out of service'
        WHEN 'À éliminer'     THEN 'To be disposal'
        WHEN 'Transféré'      THEN 'Out of service'
        ELSE status
      END
      WHERE status IN ('Disponible','En service','En usage','En maintenance',
                       'Hors service','Inactif','À éliminer','Transféré')
    `);
  } catch (_) {}

  // Plans de maintenance préventive (1 équipement → N plans, ex : trimestriel,
  // annuel, calibration, etc.). Le `next_preventive_maintenance` de equipment
  // peut être calculé/dénormalisé à partir du plus proche plan actif.
  db.exec(`
    CREATE TABLE IF NOT EXISTS preventive_maintenance_plans (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      equipment_id          TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
      frequency_months      INTEGER NOT NULL,
      last_completed_date   TEXT,
      description           TEXT,
      created_at            TEXT DEFAULT (datetime('now','localtime')),
      updated_at            TEXT DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_pm_plans_equipment ON preventive_maintenance_plans(equipment_id);
  `);

  // Table de configuration de la sidebar par rôle
  db.exec(`
    CREATE TABLE IF NOT EXISTS sidebar_config (
      role        TEXT NOT NULL,
      screen_type TEXT NOT NULL,
      sort_order  INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (role, screen_type)
    );
  `);
}

function closeDb() {
  if (db) {
    db.close();
    db = null;
  }
}

function resetDb() {
  closeDb();
}

module.exports = { getDb, closeDb, resetDb };
