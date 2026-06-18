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

    -- ── Lieux (infrastructure) ────────────────────────────────────────
    CREATE TABLE IF NOT EXISTS locations (
      id         TEXT PRIMARY KEY,
      name       TEXT NOT NULL,
      building   TEXT NOT NULL,
      department TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_locations_dept ON locations(department);

    CREATE TABLE IF NOT EXISTS issues (
      id TEXT PRIMARY KEY,
      equipment_id TEXT NOT NULL,
      equipment_name TEXT NOT NULL,
      department TEXT NOT NULL,
      type TEXT NOT NULL,
      description TEXT NOT NULL,
      reporter TEXT NOT NULL,
      created_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'Reported',
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

  // Migration : colonne description sur departments (idempotente)
  try { db.exec('ALTER TABLE departments ADD COLUMN description TEXT'); } catch (_) {}

  // Seed des départements de l'hôpital de Kabutare (idempotent via INSERT OR IGNORE)
  {
    const insertDept = db.prepare('INSERT OR IGNORE INTO departments(name) VALUES (?)');
    const hospitalDepts = [
      'OPD (Outpatient Department)', 'Internal Medicine', 'Pediatrics', 'Emergency',
      'Laboratory', 'Stomatology', 'Kinesitherapy', 'Neonatology', 'Maternity', 'Surgery',
      'Theater', 'Ophthalmology', 'TB-MR', 'GBV (Gender-Based Violence Unit)',
      'Mental Health', 'ARV (HIV/AIDS Treatment Unit)', 'Pharmacy', 'ICT',
    ];
    for (const name of hospitalDepts) insertDept.run(name);
  }

  // Migration : ajout des colonnes ip_address et user_agent si elles n'existent pas
  try { db.exec('ALTER TABLE logs ADD COLUMN ip_address TEXT'); } catch (_) {}
  try { db.exec('ALTER TABLE logs ADD COLUMN user_agent TEXT'); } catch (_) {}

  // Migration : ajout des colonnes reporter_id, reporter_email, reporter_phone dans issues si elles n'existent pas
  try { db.exec("ALTER TABLE issues ADD COLUMN reporter_id TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE issues ADD COLUMN reporter_email TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE issues ADD COLUMN reporter_phone TEXT"); } catch (_) {}

  // Migration : ajout de la colonne urgency dans issues
  try { db.exec("ALTER TABLE issues ADD COLUMN urgency TEXT DEFAULT 'Moyen'"); } catch (_) {}

  // Migration : localisation libre (infrastructure sans location_id DB)
  try { db.exec("ALTER TABLE issues ADD COLUMN location_text TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE issues ADD COLUMN location_tag  TEXT"); } catch (_) {}

  // Migration : horodatage de prise en charge (chronomètre persistant côté technicien)
  try { db.exec("ALTER TABLE issues ADD COLUMN taken_at TEXT"); } catch (_) {}

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

  // Migration : rebuild issues — rend equipment_id/equipment_name nullable,
  // ajoute location_id, issue_category, assigned_group.
  // Idempotent : ne s'exécute que si la colonne location_id est absente.
  // NB : conserve location_text/location_tag/taken_at (ajoutés par ALTER plus
  // haut) — sans quoi un boot unique (tests, nouvelle install) les perdrait.
  const issuesCols = db.pragma('table_info(issues)');
  if (!issuesCols.some(c => c.name === 'location_id')) {
    db.exec(`
      BEGIN TRANSACTION;
      ALTER TABLE issues RENAME TO issues_old;
      CREATE TABLE issues (
        id                  TEXT PRIMARY KEY,
        equipment_id        TEXT,
        equipment_name      TEXT,
        location_id         TEXT REFERENCES locations(id),
        location_text       TEXT,
        location_tag        TEXT,
        issue_category      TEXT NOT NULL DEFAULT 'Biomédical',
        assigned_group      TEXT,
        department          TEXT NOT NULL,
        type                TEXT NOT NULL,
        description         TEXT NOT NULL,
        reporter            TEXT NOT NULL,
        created_at          TEXT NOT NULL,
        status              TEXT NOT NULL DEFAULT 'Reported',
        assigned_technician TEXT,
        diagnosis           TEXT,
        actions             TEXT,
        parts_replaced      TEXT,
        updated_at          TEXT DEFAULT (datetime('now','localtime')),
        reporter_id         TEXT,
        reporter_email      TEXT,
        taken_at            TEXT,
        urgency             TEXT DEFAULT 'Moyen'
      );
      INSERT INTO issues (
        id, equipment_id, equipment_name, location_text, location_tag,
        department, type, description, reporter,
        created_at, status, assigned_technician, diagnosis, actions, parts_replaced,
        updated_at, reporter_id, reporter_email, taken_at, urgency
      )
      SELECT
        id, equipment_id, equipment_name, location_text, location_tag,
        department, type, description, reporter,
        created_at, status, assigned_technician, diagnosis, actions, parts_replaced,
        updated_at, reporter_id, reporter_email, taken_at, urgency
      FROM issues_old;
      DROP TABLE issues_old;
      CREATE INDEX IF NOT EXISTS idx_issues_status    ON issues(status);
      CREATE INDEX IF NOT EXISTS idx_issues_equipment ON issues(equipment_id);
      CREATE INDEX IF NOT EXISTS idx_issues_location  ON issues(location_id);
      CREATE INDEX IF NOT EXISTS idx_issues_group     ON issues(assigned_group);
      COMMIT;
    `);
  }

  // Migration : refonte des statuts d'issues (français → anglais, 5 → 9 valeurs).
  // Idempotent : ne touche que les lignes qui ont encore une valeur FR héritée.
  try {
    db.exec(`
      UPDATE issues SET status = CASE status
        WHEN 'Ouvert'   THEN 'Reported'
        WHEN 'Approuvé' THEN 'Acknowledged'
        WHEN 'En cours' THEN 'In Progress'
        WHEN 'Résolu'   THEN 'Completed'
        WHEN 'Annulé'   THEN 'Closed'
        ELSE status
      END
      WHERE status IN ('Ouvert','Approuvé','En cours','Résolu','Annulé')
    `);
  } catch (_) {}

  // Migration : noms de catégories français → anglais dans equipment.
  // Idempotent : ne touche que les lignes qui ont encore une valeur FR héritée.
  try {
    db.exec(`
      UPDATE equipment SET category = CASE category
        WHEN 'Équipement biomédical'      THEN 'Biomedical Equipment'
        WHEN 'Équipement ICT'             THEN 'ICT Equipment'
        WHEN 'Équipement électrique'      THEN 'Electrical Equipment'
        WHEN 'Matériel d''hygiène'        THEN 'Hygiene Materials'
        WHEN 'Stérilisation et buanderie' THEN 'Sterilization and Laundry'
        WHEN 'Pharmacie'                  THEN 'Pharmacy'
        ELSE category END
      WHERE category IN (
        'Équipement biomédical','Équipement ICT','Équipement électrique',
        'Matériel d''hygiène','Stérilisation et buanderie','Pharmacie'
      )
    `);
  } catch (_) {}

  // Migration : noms de départements français → anglais dans equipment, issues et locations.
  // Idempotent : ne touche que les lignes qui ont encore une valeur FR héritée.
  try {
    const deptMap = `CASE department
      WHEN 'OPD (Consultations externes)'          THEN 'OPD (Outpatient Department)'
      WHEN 'Médecine interne'                       THEN 'Internal Medicine'
      WHEN 'Pédiatrie'                              THEN 'Pediatrics'
      WHEN 'Urgences'                               THEN 'Emergency'
      WHEN 'Laboratoire'                            THEN 'Laboratory'
      WHEN 'Stomatologie'                           THEN 'Stomatology'
      WHEN 'Kinésithérapie'                         THEN 'Kinesitherapy'
      WHEN 'Néonatologie'                           THEN 'Neonatology'
      WHEN 'Maternité'                              THEN 'Maternity'
      WHEN 'Chirurgie'                              THEN 'Surgery'
      WHEN 'Bloc opératoire'                        THEN 'Theater'
      WHEN 'Ophtalmologie'                          THEN 'Ophthalmology'
      WHEN 'TB-MR (Tuberculose)'                    THEN 'TB-MR'
      WHEN 'GBV (Violences basées sur le genre)'    THEN 'GBV (Gender-Based Violence Unit)'
      WHEN 'Santé mentale'                          THEN 'Mental Health'
      WHEN 'ARV (Traitement VIH/SIDA)'              THEN 'ARV (HIV/AIDS Treatment Unit)'
      WHEN 'Pharmacie'                              THEN 'Pharmacy'
      ELSE department END`;
    const frDepts = `('OPD (Consultations externes)','Médecine interne','Pédiatrie','Urgences',
      'Laboratoire','Stomatologie','Kinésithérapie','Néonatologie','Maternité','Chirurgie',
      'Bloc opératoire','Ophtalmologie','TB-MR (Tuberculose)',
      'GBV (Violences basées sur le genre)','Santé mentale','ARV (Traitement VIH/SIDA)','Pharmacie')`;
    db.exec(`UPDATE equipment SET department = ${deptMap} WHERE department IN ${frDepts}`);
    db.exec(`UPDATE issues    SET department = ${deptMap} WHERE department IN ${frDepts}`);
    db.exec(`UPDATE locations SET department = ${deptMap} WHERE department IN ${frDepts}`);
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

  // Migration : dédupliquer preventive_maintenance_plans + UNIQUE index sur equipment_id
  // (nécessaire pour les UPSERT ON CONFLICT(equipment_id))
  try {
    db.exec(`
      DELETE FROM preventive_maintenance_plans
      WHERE id NOT IN (
        SELECT MIN(id) FROM preventive_maintenance_plans GROUP BY equipment_id
      )
    `);
  } catch (_) {}
  try {
    db.exec(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_pm_plans_equipment_unique
      ON preventive_maintenance_plans(equipment_id)
    `);
  } catch (_) {}

  // Migration : nouvelles colonnes sur maintenance_records (PM v3)
  const mrCols = db.prepare('PRAGMA table_info(maintenance_records)').all().map(c => c.name);
  if (!mrCols.includes('technician_id')) {
    db.prepare('ALTER TABLE maintenance_records ADD COLUMN technician_id TEXT').run();
  }
  if (!mrCols.includes('checklist_snapshot')) {
    db.prepare('ALTER TABLE maintenance_records ADD COLUMN checklist_snapshot TEXT').run();
  }
  if (!mrCols.includes('duration_minutes')) {
    db.prepare('ALTER TABLE maintenance_records ADD COLUMN duration_minutes INTEGER').run();
  }
  if (!mrCols.includes('parts_used')) {
    db.prepare('ALTER TABLE maintenance_records ADD COLUMN parts_used TEXT').run();
  }
  if (!mrCols.includes('maintenance_type')) {
    db.prepare("ALTER TABLE maintenance_records ADD COLUMN maintenance_type TEXT DEFAULT 'corrective'").run();
  }

  // Table de configuration de la sidebar par rôle
  db.exec(`
    CREATE TABLE IF NOT EXISTS sidebar_config (
      role        TEXT NOT NULL,
      screen_type TEXT NOT NULL,
      sort_order  INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (role, screen_type)
    );
  `);

  // ── Souscriptions Web Push ─────────────────────────────────────────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS push_subscriptions (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    TEXT NOT NULL,
      endpoint   TEXT NOT NULL UNIQUE,
      p256dh     TEXT NOT NULL,
      auth       TEXT NOT NULL,
      user_roles TEXT,
      created_at TEXT DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_push_user ON push_subscriptions(user_id);
  `);

  // ── Feature Flags ──────────────────────────────────────────────────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS features (
      id               TEXT PRIMARY KEY,
      name             TEXT NOT NULL,
      description      TEXT,
      is_global_active INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS feature_role_overrides (
      feature_id TEXT NOT NULL REFERENCES features(id) ON DELETE CASCADE,
      role_name  TEXT NOT NULL,
      is_active  INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (feature_id, role_name)
    );
  `);

  // Seed features de base (idempotent via INSERT OR IGNORE)
  const insertFeature = db.prepare(
    'INSERT OR IGNORE INTO features (id, name, description, is_global_active) VALUES (?, ?, ?, ?)'
  );
  insertFeature.run('inventory_module', 'Inventaire', "Module de gestion de l'inventaire physique des equipements", 1);
  insertFeature.run('environmental_health_module', 'Sante environnementale', "Module de suivi hygiene des mains et tri des dechets (futur)", 0);
  insertFeature.run('analytics_module', 'Analytiques', "Module de rapports et analyses avancees", 1);
  insertFeature.run('reports_module', 'Rapports', "Module de generation de rapports PDF", 1);
  insertFeature.run('push_notifications_module', 'Notifications Push', "Activation des notifications push navigateur", 1);

  // ── Paramètres et historique des sauvegardes ───────────────────────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS backup_settings (
      id          TEXT PRIMARY KEY,
      cron_schedule TEXT,
      is_automated INTEGER NOT NULL DEFAULT 0,
      updated_at  TEXT DEFAULT (datetime('now','localtime'))
    );

    CREATE TABLE IF NOT EXISTS backup_history (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      filename    TEXT NOT NULL,
      backup_type TEXT NOT NULL DEFAULT 'manual',
      status      TEXT NOT NULL DEFAULT 'success',
      file_size   TEXT,
      created_at  TEXT DEFAULT (datetime('now','localtime'))
    );
  `);

  // Seed des paramètres par défaut (idempotent)
  const existingSettings = db.prepare("SELECT id FROM backup_settings WHERE id = 'default'").get();
  if (!existingSettings) {
    db.prepare(`
      INSERT INTO backup_settings (id, cron_schedule, is_automated, updated_at)
      VALUES ('default', '0 0 * * *', 0, datetime('now','localtime'))
    `).run();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── GMAO Phase 2 : Hiérarchie des équipements & Protocoles PM ───────────────
  // ════════════════════════════════════════════════════════════════════════════

  // ── Table des macro-catégories (Biomedical, Infrastructure, IT) ──────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS equipment_macro_categories (
      id   INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    );
  `);
  // Seed des 3 macro-catégories (idempotent)
  const insertMacro = db.prepare('INSERT OR IGNORE INTO equipment_macro_categories(name) VALUES (?)');
  insertMacro.run('Biomedical');
  insertMacro.run('Infrastructure');
  insertMacro.run('IT');

  // ── Table des sous-catégories (héritée des ~626 equipment_categories) ────
  db.exec(`
    CREATE TABLE IF NOT EXISTS equipment_subcategories (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      name              TEXT NOT NULL UNIQUE,
      macro_category_id INTEGER NOT NULL REFERENCES equipment_macro_categories(id)
    );
    CREATE INDEX IF NOT EXISTS idx_subcategories_macro ON equipment_subcategories(macro_category_id);
  `);

  // Migration : peuplement de equipment_subcategories à partir de equipment_categories.
  // N'insère que les entrées absentes (idempotent via INSERT OR IGNORE).
  // Le mapping macro-catégorie utilise une heuristique sur le nom de la sous-catégorie.
  try {
    const macroIds = db.prepare('SELECT id, name FROM equipment_macro_categories').all()
      .reduce((acc, r) => { acc[r.name] = r.id; return acc; }, {});

    const bioId   = macroIds['Biomedical']     || 1;
    const infraId = macroIds['Infrastructure'] || 2;
    const itId    = macroIds['IT']             || 3;

    // Mots-clés → IT
    const itKeywords = [
      'computer', 'server', 'printer', 'network', 'software', 'laptop', 'tablet',
      'desktop', 'ict', 'information', 'digital', 'router', 'switch', 'ups for',
      'copier', 'scanner ict', 'photocopier',
    ];
    // Mots-clés → Infrastructure
    const infraKeywords = [
      'bed ', 'chair', 'table ', 'furniture', 'electrical', 'generator', 'air condition',
      'elevator', 'plumbing', 'hvac', 'fire', 'infrastructure', 'vehicle', 'refrigerator',
      'washing', 'laundry', 'sterilization', 'incinerator', 'boiler', 'pump', 'fan ',
      'lighting', 'curtain', 'door ', 'window ', 'flooring', 'ceiling', 'roof ',
      'hygiene', 'sanitation', 'waste', 'mattress', 'stretcher', 'trolley',
    ];

    const insertSub = db.prepare(
      'INSERT OR IGNORE INTO equipment_subcategories(name, macro_category_id) VALUES (?, ?)'
    );

    const cats = db.prepare('SELECT id, name FROM equipment_categories').all();
    for (const cat of cats) {
      const lower = cat.name.toLowerCase();
      let macroId = bioId; // Biomédical par défaut
      if (itKeywords.some(kw => lower.includes(kw))) {
        macroId = itId;
      } else if (infraKeywords.some(kw => lower.includes(kw))) {
        macroId = infraId;
      }
      insertSub.run(cat.name, macroId);
    }

    // Insérer aussi les catégories héritées du seed legacy (pas dans equipment_categories)
    const legacySeedCats = [
      { name: 'Biomedical Equipment',       macro: bioId   },
      { name: 'ICT Equipment',              macro: itId    },
      { name: 'Electrical Equipment',       macro: infraId },
      { name: 'Hygiene Materials',          macro: infraId },
      { name: 'Sterilization and Laundry',  macro: infraId },
      { name: 'Pharmacy',                   macro: bioId   },
      { name: 'Informatique',               macro: itId    },
      { name: 'Imagerie',                   macro: bioId   },
      { name: 'Chirurgie',                  macro: bioId   },
      { name: 'Monitoring',                 macro: bioId   },
      { name: 'Thérapeutique',              macro: bioId   },
      { name: 'Mobilier',                   macro: infraId },
      { name: 'Autre',                      macro: bioId   },
    ];
    for (const { name, macro } of legacySeedCats) {
      insertSub.run(name, macro);
    }
  } catch (_) {}

  // ── Nouvelles colonnes sur equipment (idempotentes via try/catch) ─────────
  try { db.exec('ALTER TABLE equipment ADD COLUMN subcategory_id INTEGER REFERENCES equipment_subcategories(id)'); } catch (_) {}
  try { db.exec('ALTER TABLE equipment ADD COLUMN macro_category_id INTEGER REFERENCES equipment_macro_categories(id)'); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN warranty_end_date TEXT"); } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN criticality TEXT"); } catch (_) {}

  // ── Cycle de vie : réforme / décommissionnement (soft delete) ─────────────
  // Un équipement réformé passe status='Disposed' mais n'est jamais effacé :
  // il conserve son historique pour l'audit d'accréditation. Ces colonnes
  // tracent le qui/quand/pourquoi/comment et le lien vers le remplaçant.
  // Pas de FK SQL sur replaced_by_id (ALTER ne permet pas d'ajouter une FK en
  // SQLite) → l'existence de l'équipement cible est validée côté Node.
  try { db.exec("ALTER TABLE equipment ADD COLUMN decommissioned_at TEXT");        } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN decommission_reason TEXT");      } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN disposal_method TEXT");          } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN decommissioned_by_id TEXT");     } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN decommissioned_by_name TEXT");   } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN decommission_notes TEXT");       } catch (_) {}
  try { db.exec("ALTER TABLE equipment ADD COLUMN replaced_by_id TEXT");           } catch (_) {}
  // Index : les sous-requêtes corrélées du lien inverse « remplace » (BASE_SELECT)
  // filtrent sur replaced_by_id pour chaque ligne ; sans index → full scan.
  try { db.exec("CREATE INDEX IF NOT EXISTS idx_equipment_replaced_by ON equipment(replaced_by_id)"); } catch (_) {}

  // ── Plan de remplacement biomédical (RA3 S5) ──────────────────────────────
  // Durée de vie de référence d'une sous-catégorie (en années). NULL = non
  // définie (l'admin la saisit ; aucun seed). Sert au calcul serveur du statut
  // de remplacement et de l'horizon budgétaire des équipements biomédicaux.
  try { db.exec("ALTER TABLE equipment_subcategories ADD COLUMN expected_lifespan_years INTEGER"); } catch (_) {}

  // ── Rétro-remplissage : subcategory_id + macro_category_id pour l'existant.
  // Priorité : cherche dans equipment_subcategories un nom = equipment.category.
  // Idempotent : ne met à jour que les lignes qui n'ont pas encore de subcategory_id.
  try {
    db.exec(`
      UPDATE equipment
      SET
        subcategory_id    = (
          SELECT s.id
          FROM   equipment_subcategories s
          WHERE  LOWER(s.name) = LOWER(equipment.category)
          LIMIT  1
        ),
        macro_category_id = (
          SELECT s.macro_category_id
          FROM   equipment_subcategories s
          WHERE  LOWER(s.name) = LOWER(equipment.category)
          LIMIT  1
        )
      WHERE subcategory_id IS NULL
    `);
  } catch (_) {}

  // ── Protocoles de maintenance préventive (PM) liés aux sous-catégories ────
  // Distinct de preventive_maintenance_plans (qui est par équipement) :
  // pm_protocols = modèles de protocoles par type d'équipement.
  db.exec(`
    CREATE TABLE IF NOT EXISTS pm_protocols (
      id                       INTEGER PRIMARY KEY AUTOINCREMENT,
      subcategory_id           INTEGER NOT NULL REFERENCES equipment_subcategories(id) ON DELETE CASCADE,
      name                     TEXT NOT NULL,
      frequency_months         INTEGER NOT NULL,
      estimated_duration_hours REAL,
      checklist                TEXT,
      created_at               TEXT DEFAULT (datetime('now','localtime')),
      updated_at               TEXT DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_pm_protocols_subcategory ON pm_protocols(subcategory_id);
  `);

  // Seed de protocoles PM pour les équipements biomédicaux courants.
  // Chaque INSERT utilise une sous-requête : si la sous-catégorie n'existe pas,
  // NULL déclenche une violation FK et la ligne est ignorée (idempotent).
  // On vérifie l'existence avec une table de sentinelle _pm_seeded.
  db.exec(`
    CREATE TABLE IF NOT EXISTS _pm_seeded (
      marker TEXT PRIMARY KEY
    );
  `);
  // N'insère les protocoles que si la sous-catégorie existe ET que le protocole
  // n'est pas déjà présent (vérifié par (subcategory_id, name)).
  // Pas de sentinel : on tente à chaque démarrage mais l'INSERT OR IGNORE garantit l'idempotence.
  const insertPm = db.prepare(`
    INSERT OR IGNORE INTO pm_protocols (subcategory_id, name, frequency_months, estimated_duration_hours, checklist)
    SELECT s.id, ?, ?, ?, ?
    FROM   equipment_subcategories s
    WHERE  LOWER(s.name) = LOWER(?)
      AND  NOT EXISTS (
        SELECT 1 FROM pm_protocols p2
        WHERE p2.subcategory_id = s.id AND LOWER(p2.name) = LOWER(?)
      )
    LIMIT  1
  `);
  {

    const bioProtocols = [
      {
        cat: 'Anaesthesia Machine',
        name: 'Quarterly preventive maintenance',
        freq: 3, dur: 3.0,
        checklist: JSON.stringify([
          'Check gas leaks on all circuits',
          'Verify O2/N2O/Air calibration',
          'Test all alarms and safety limits',
          'Inspect breathing circuits and valves',
          'Check bellows and APL valve',
          'Clean and disinfect accessible surfaces',
          'Verify vaporiser output',
          'Check emergency O2 flush',
          'Test battery backup',
          'Document findings in maintenance log',
        ]),
      },
      {
        cat: 'Autoclave',
        name: 'Semi-annual preventive maintenance',
        freq: 6, dur: 2.5,
        checklist: JSON.stringify([
          'Check door gasket and locking mechanism',
          'Verify pressure gauge calibration',
          'Test safety valve',
          'Inspect heating elements',
          'Check water quality and drain filter',
          'Run Bowie-Dick test',
          'Verify cycle time and temperature accuracy',
          'Clean chamber and trays',
          'Inspect steam traps and pipework',
        ]),
      },
      {
        cat: 'Patient Monitor',
        name: 'Annual preventive maintenance',
        freq: 12, dur: 2.0,
        checklist: JSON.stringify([
          'Calibrate SpO2, NIBP and ECG channels',
          'Inspect all cables and sensors for damage',
          'Test all alarms (high/low thresholds)',
          'Verify battery capacity and replace if < 80%',
          'Check display brightness and contrast',
          'Clean all sensors and connectors',
          'Verify electrical safety (ground test)',
          'Test nurse call output',
          'Update firmware if available',
        ]),
      },
      {
        cat: 'Defibrillator',
        name: 'Annual preventive maintenance',
        freq: 12, dur: 2.5,
        checklist: JSON.stringify([
          'Verify delivered energy accuracy at 200 J and 360 J',
          'Test sync mode (cardioversion)',
          'Check AED pads / manual paddles condition',
          'Test all alarms and patient leads',
          'Inspect battery — replace if capacity < 75%',
          'Test ECG recording/printing',
          'Check charge time at max energy',
          'Verify electrical safety compliance',
          'Document test results with strip printout',
        ]),
      },
      {
        cat: 'X-Ray Machine',
        name: 'Semi-annual preventive maintenance',
        freq: 6, dur: 4.0,
        checklist: JSON.stringify([
          'Inspect X-ray tube for signs of wear',
          'Check collimator alignment and field light',
          'Verify kVp and mAs accuracy',
          'Inspect high-voltage cables and connectors',
          'Check radiation leakage at tube housing',
          'Test anode heat sensor and thermal protection',
          'Inspect mechanical movement (arm, column)',
          'Verify detector calibration (digital systems)',
          'Check radiation warning indicators',
          'Perform radiation dose measurement',
        ]),
      },
      {
        cat: 'Ventilator',
        name: 'Quarterly preventive maintenance',
        freq: 3, dur: 3.0,
        checklist: JSON.stringify([
          'Check all circuit connections for leaks',
          'Verify tidal volume accuracy',
          'Test all alarms (apnoea, high pressure, disconnect)',
          'Inspect inspiratory/expiratory valves',
          'Check humidifier operation',
          'Clean reusable components',
          'Test battery backup duration',
          'Verify oxygen sensor calibration',
          'Check exhalation port and PEEP valve',
        ]),
      },
      {
        cat: 'Ultrasound',
        name: 'Annual preventive maintenance',
        freq: 12, dur: 2.0,
        checklist: JSON.stringify([
          'Inspect all transducers for cracks or delamination',
          'Clean transducer connectors',
          'Verify image quality with test phantom',
          'Check all cable routing',
          'Test all imaging modes (B, M, Doppler)',
          'Verify electrical safety compliance',
          'Check and clean ventilation filters',
          'Test printer/archiving function if equipped',
        ]),
      },
      {
        cat: 'Centrifuge',
        name: 'Semi-annual preventive maintenance',
        freq: 6, dur: 1.5,
        checklist: JSON.stringify([
          'Inspect rotor for cracks or corrosion',
          'Check rotor locking mechanism',
          'Verify speed accuracy with tachometer',
          'Check timer accuracy',
          'Inspect lid and safety lock',
          'Lubricate moving parts per manufacturer spec',
          'Check motor brush wear',
          'Clean chamber and drain',
          'Verify imbalance detection system',
        ]),
      },
    ];

    for (const p of bioProtocols) {
      try {
        insertPm.run(p.name, p.freq, p.dur, p.checklist, p.cat, p.name);
      } catch (_) {}
    }
  }

  // ── Gestion documentaire équipements ──────────────────────────────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS equipment_documents (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      equipment_id  TEXT    NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
      document_type TEXT    NOT NULL DEFAULT 'technical',
      original_name TEXT    NOT NULL,
      stored_name   TEXT    NOT NULL UNIQUE,
      mime_type     TEXT    NOT NULL,
      file_size_kb  INTEGER NOT NULL,
      uploaded_by   TEXT    NOT NULL,
      uploader_name TEXT    NOT NULL,
      uploaded_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
      deleted_at    TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_eq_docs_equipment
      ON equipment_documents(equipment_id)
      WHERE deleted_at IS NULL;
  `);

  // ── Rapports d'intervention par incident (1:1 avec issues) ─────────────────
  // Construit tout au long de l'intervention puis figé à la clôture.
  // Ne duplique PAS diagnosis/actions/parts_replaced : ces champs sont lus en
  // direct depuis la table `issues`.
  db.exec(`
    CREATE TABLE IF NOT EXISTS issue_intervention_reports (
      id                      INTEGER PRIMARY KEY AUTOINCREMENT,
      issue_id                TEXT    NOT NULL UNIQUE REFERENCES issues(id) ON DELETE CASCADE,
      summary                 TEXT,
      root_cause              TEXT,
      recommendations         TEXT,
      duration_hours          REAL,
      returned_to_service_at  TEXT,
      estimated_cost          REAL,
      final_equipment_status  TEXT,
      author_id               TEXT,
      author_name             TEXT,
      validated_by_id         TEXT,
      validated_by_name       TEXT,
      validated_at            TEXT,
      report_status           TEXT NOT NULL DEFAULT 'draft',
      created_at              TEXT DEFAULT (datetime('now','localtime')),
      updated_at              TEXT DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_intervention_reports_issue
      ON issue_intervention_reports(issue_id);
  `);

  // ════════════════════════════════════════════════════════════════════════════
  // CATALOGUE FABRICANT → MODÈLE (fiche technique partagée)
  // Aligne l'app sur les GMAO du marché : la fiche technique appartient au couple
  // (fabricant + modèle). Tables auto-seedées depuis equipment.manufacturer/model.
  // ════════════════════════════════════════════════════════════════════════════

  // ── Fabricants (marques) ──────────────────────────────────────────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS equipment_brands (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT NOT NULL COLLATE NOCASE UNIQUE,
      created_at  TEXT DEFAULT (datetime('now','localtime')),
      updated_at  TEXT
    );
  `);

  // ── Modèles (couple fabricant + référence, rattaché à une sous-catégorie) ──
  db.exec(`
    CREATE TABLE IF NOT EXISTS equipment_models (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      brand_id        INTEGER NOT NULL REFERENCES equipment_brands(id) ON DELETE CASCADE,
      subcategory_id  INTEGER REFERENCES equipment_subcategories(id),
      name            TEXT NOT NULL,
      created_at      TEXT DEFAULT (datetime('now','localtime')),
      updated_at      TEXT,
      UNIQUE(brand_id, subcategory_id, name COLLATE NOCASE)
    );
    CREATE INDEX IF NOT EXISTS idx_models_brand ON equipment_models(brand_id);
    CREATE INDEX IF NOT EXISTS idx_models_subcat ON equipment_models(subcategory_id);
  `);

  // ── Documents de modèle (mêmes 3 types que equipment_documents) ────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS model_documents (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      model_id      INTEGER NOT NULL REFERENCES equipment_models(id) ON DELETE CASCADE,
      document_type TEXT NOT NULL,
      original_name TEXT NOT NULL,
      stored_name   TEXT NOT NULL UNIQUE,
      mime_type     TEXT,
      file_size_kb  INTEGER,
      uploaded_by   TEXT,
      uploader_name TEXT,
      uploaded_at   TEXT,
      deleted_at    TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_model_documents_model ON model_documents(model_id);
  `);

  // ── Liaison N-N modèle ↔ protocoles PM (en plus de ceux de la sous-cat) ────
  db.exec(`
    CREATE TABLE IF NOT EXISTS model_pm_protocols (
      model_id    INTEGER NOT NULL REFERENCES equipment_models(id) ON DELETE CASCADE,
      protocol_id INTEGER NOT NULL REFERENCES pm_protocols(id) ON DELETE CASCADE,
      PRIMARY KEY (model_id, protocol_id)
    );
  `);

  // ── Colonne de rattachement modèle sur equipment (idempotent, nullable) ────
  try { db.exec('ALTER TABLE equipment ADD COLUMN model_id INTEGER REFERENCES equipment_models(id)'); } catch (_) {}

  // ── Auto-seed + backfill idempotent du catalogue ──────────────────────────
  // 1. Fabricants distincts présents dans equipment.manufacturer.
  // 2. Modèles distincts (fabricant + modèle + sous-cat).
  // 3. Backfill equipment.model_id pour les lignes encore non rattachées.
  // Idempotent : INSERT OR IGNORE + WHERE model_id IS NULL. Rejouable sans effet.
  try {
    db.exec(`
      INSERT OR IGNORE INTO equipment_brands(name)
      SELECT DISTINCT TRIM(manufacturer)
      FROM   equipment
      WHERE  manufacturer IS NOT NULL AND TRIM(manufacturer) <> ''
    `);

    db.exec(`
      INSERT OR IGNORE INTO equipment_models(brand_id, subcategory_id, name)
      SELECT DISTINCT b.id, e.subcategory_id, TRIM(e.model)
      FROM   equipment e
      JOIN   equipment_brands b ON b.name = TRIM(e.manufacturer)
      WHERE  e.model IS NOT NULL AND TRIM(e.model) <> ''
    `);

    db.exec(`
      UPDATE equipment
      SET    model_id = (
        SELECT m.id
        FROM   equipment_models m
        JOIN   equipment_brands b ON b.id = m.brand_id
        WHERE  b.name = TRIM(equipment.manufacturer)
          AND  m.name = TRIM(equipment.model)
          AND  (m.subcategory_id IS equipment.subcategory_id)
        LIMIT  1
      )
      WHERE  model_id IS NULL
        AND  manufacturer IS NOT NULL AND TRIM(manufacturer) <> ''
        AND  model IS NOT NULL AND TRIM(model) <> ''
    `);
  } catch (_) {}

  // ── Photos d'incidents ─────────────────────────────────────────────────────
  db.exec(`
    CREATE TABLE IF NOT EXISTS issue_photos (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      issue_id      TEXT    NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
      stored_name   TEXT    NOT NULL UNIQUE,
      original_name TEXT    NOT NULL,
      mime_type     TEXT    NOT NULL DEFAULT 'image/jpeg',
      file_size_kb  INTEGER NOT NULL,
      uploaded_at   TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
    );
    CREATE INDEX IF NOT EXISTS idx_issue_photos_issue
      ON issue_photos(issue_id);
  `);

  // Créer le dossier d'upload au démarrage
  const fs = require('fs');
  const uploadDir = process.env.UPLOAD_DIR || '/data/uploads/documents';
  if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

  // ── Migration : table notifications in-app ───────────────────────────────────
  // Vérifie l'existence avant de créer (idempotent)
  const notifCols = db.prepare("PRAGMA table_info('notifications')").all().map(c => c.name);
  if (!notifCols.includes('id')) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS notifications (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     TEXT,
        role        TEXT,
        type        TEXT NOT NULL,
        title       TEXT NOT NULL,
        body        TEXT NOT NULL,
        target_id   TEXT,
        target_type TEXT,
        is_read     INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT DEFAULT (datetime('now','localtime'))
      );
      CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id);
      CREATE INDEX IF NOT EXISTS idx_notif_role ON notifications(role);
      CREATE INDEX IF NOT EXISTS idx_notif_read ON notifications(is_read);
    `);
  }
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
