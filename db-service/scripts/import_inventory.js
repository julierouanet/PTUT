#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// import_inventory.js — Importe l'inventaire physique 2025-2026 dans la DB.
//
// Lecture directe du fichier XLSX (feuilles 'Standard_Departments',
// 'Standard_Equipment_Names', 'Equipment Migration Template') et insertion /
// mise à jour idempotente dans `equipment`, `equipment_tags`, `departments`,
// `equipment_categories`. Toute mutation est tracée via `logAction`.
//
// Usage :
//   node scripts/import_inventory.js [--xlsx <path>] [--dry-run] [--insert-only]
//
//   --xlsx <path>   Fichier source. Défaut : recherche relative au repo
//                   (cf. DEFAULT_XLSX_CANDIDATES ci-dessous).
//   --dry-run       Parse + valide sans rien écrire en DB.
//   --insert-only   Ignore les équipements existants (équivalent INSERT OR IGNORE
//                   pour `equipment`). Tags nouveaux toujours ajoutés.
// ─────────────────────────────────────────────────────────────────────────────

const path = require('path');
const fs   = require('fs');
const XLSX = require('xlsx');

const { getDb, closeDb } = require('../src/database');
const { logAction }      = require('../src/utils/logger');
const N = require('./lib/inventory_normalizer');
const { classifyMacro }  = require('./lib/macro_classifier');

// ── Constantes du fichier source ─────────────────────────────────────────────
const SHEET_DEPARTMENTS = 'Standard_Departments';
const SHEET_CATEGORIES  = 'Standard_Equipment_Names';
const SHEET_INVENTORY   = 'Equipment Migration Template';

// Index de colonnes attendus (header reconnu dynamiquement, fallback)
const COL = {
  No: 0, Name: 1, Department: 2, Manufacturer: 3, Model: 4,
  SerialNumber: 5, TagNumber: 6, ManufYear: 7, InstallDate: 8, Status: 9,
};

// Le fichier XLSX vit hors du dépôt git, deux niveaux au-dessus de la racine
// du repo (cf. structure E:\stage rwanda fichier\PHYISICAL...xlsx + repo dans
// .\code\PTUT\). On teste les emplacements plausibles dans l'ordre.
const DEFAULT_XLSX_CANDIDATES = [
  path.resolve(__dirname, '../../../..',  'PHYISICAL INVENTORY OF MEDICAL EQUIPMENTS 2025-2026 -.xlsx'),
  path.resolve(__dirname, '../../..',     'PHYISICAL INVENTORY OF MEDICAL EQUIPMENTS 2025-2026 -.xlsx'),
  path.resolve(__dirname, '../..',        'PHYISICAL INVENTORY OF MEDICAL EQUIPMENTS 2025-2026 -.xlsx'),
  path.resolve(process.cwd(),             'PHYISICAL INVENTORY OF MEDICAL EQUIPMENTS 2025-2026 -.xlsx'),
];

// ── Parsing des arguments CLI ────────────────────────────────────────────────
function parseArgs(argv) {
  const args = { xlsx: null, dryRun: false, insertOnly: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--xlsx')             args.xlsx = argv[++i];
    else if (a === '--dry-run')     args.dryRun = true;
    else if (a === '--insert-only') args.insertOnly = true;
    else if (a === '--help' || a === '-h') {
      printHelp();
      process.exit(0);
    } else {
      console.warn(`[WARN] argument inconnu ignoré : ${a}`);
    }
  }
  return args;
}

function printHelp() {
  console.log(`
Usage : node scripts/import_inventory.js [options]

Options :
  --xlsx <path>     Chemin du fichier XLSX source.
  --dry-run         Parse + valide sans écrire en DB.
  --insert-only     N'écrase pas les équipements déjà présents.
  -h, --help        Affiche cette aide.
`);
}

// ── Localisation du fichier XLSX ─────────────────────────────────────────────
function resolveXlsxPath(explicit) {
  if (explicit) {
    if (!fs.existsSync(explicit)) {
      throw new Error(`Fichier XLSX introuvable : ${explicit}`);
    }
    return explicit;
  }
  for (const candidate of DEFAULT_XLSX_CANDIDATES) {
    if (fs.existsSync(candidate)) return candidate;
  }
  throw new Error(
    `Aucun fichier XLSX trouvé. Précisez --xlsx <path>. ` +
    `Candidats testés :\n  - ${DEFAULT_XLSX_CANDIDATES.join('\n  - ')}`
  );
}

// ── Phase A : seed des tables de référence ───────────────────────────────────
function seedReferences(db, workbook, dryRun) {
  const stats = { departments: 0, categories: 0 };

  // Departments (1 colonne)
  const sheetDep = workbook.Sheets[SHEET_DEPARTMENTS];
  if (!sheetDep) throw new Error(`Feuille manquante : ${SHEET_DEPARTMENTS}`);
  const depRows = XLSX.utils.sheet_to_json(sheetDep, { header: 1, blankrows: false });

  const insertDep = dryRun ? null : db.prepare('INSERT OR IGNORE INTO departments(name) VALUES (?)');
  for (let i = 0; i < depRows.length; i++) {
    const cell = depRows[i][0];
    const name = N.normalizeRefName(cell);
    if (!name || /department\s*name/i.test(name)) continue; // skip header
    if (!dryRun) {
      const r = insertDep.run(name);
      if (r.changes === 1) stats.departments++;
    } else {
      stats.departments++;
    }
  }

  // Equipment categories (1 colonne effective, le reste vide)
  const sheetCat = workbook.Sheets[SHEET_CATEGORIES];
  if (!sheetCat) throw new Error(`Feuille manquante : ${SHEET_CATEGORIES}`);
  const catRows = XLSX.utils.sheet_to_json(sheetCat, { header: 1, blankrows: false });

  const insertCat = dryRun ? null : db.prepare('INSERT OR IGNORE INTO equipment_categories(name) VALUES (?)');
  for (let i = 0; i < catRows.length; i++) {
    const cell = catRows[i][0];
    const name = N.normalizeRefName(cell);
    if (!name || /^name$/i.test(name)) continue; // skip header
    if (!dryRun) {
      const r = insertCat.run(name);
      if (r.changes === 1) stats.categories++;
    } else {
      stats.categories++;
    }
  }

  return stats;
}

// ── Construit les caches (LOWER(name) → id) pour résoudre les FK ─────────────
function buildRefCaches(db) {
  const deps = db.prepare('SELECT id, name FROM departments').all();
  const cats = db.prepare('SELECT id, name FROM equipment_categories').all();
  const subs = db.prepare('SELECT id, name, macro_category_id FROM equipment_subcategories').all();
  const depMap = new Map(deps.map(r => [r.name.toLowerCase(), r.id]));
  const catMap = new Map(cats.map(r => [r.name.toLowerCase(), r.id]));
  // subMap : name → { id, macro_category_id }
  const subMap = new Map(subs.map(r => [r.name.toLowerCase(), { id: r.id, macroId: r.macro_category_id }]));
  return { depMap, catMap, subMap };
}

// ── Détection de la ligne d'en-tête dans la feuille d'inventaire ────────────
function findHeaderRow(rows) {
  for (let i = 0; i < Math.min(rows.length, 30); i++) {
    const r = rows[i] || [];
    if (String(r[COL.No] || '').trim() === 'No' &&
        /equim?ent\s*name/i.test(String(r[COL.Name] || ''))) {
      return i;
    }
  }
  // Fallback : la position observée dans le fichier 2025-2026 est l'index 8.
  return 8;
}

// ── Phase B : import des équipements ─────────────────────────────────────────
function importEquipment(db, workbook, opts) {
  const sheet = workbook.Sheets[SHEET_INVENTORY];
  if (!sheet) throw new Error(`Feuille manquante : ${SHEET_INVENTORY}`);

  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, blankrows: false, defval: null });
  const headerIdx = findHeaderRow(rows);

  const { depMap, catMap, subMap } = buildRefCaches(db);

  // Préparation des statements (une seule fois)
  const upsert = db.prepare(`
    INSERT INTO equipment (
      id, name, department, category, serial_number, status, location,
      manufacturer, model, manuf_year, install_date, department_id, category_id,
      subcategory_id, macro_category_id
    ) VALUES (
      @id, @name, @department, @category, @serial_number, @status, @location,
      @manufacturer, @model, @manuf_year, @install_date, @department_id, @category_id,
      @subcategory_id, @macro_category_id
    )
    ON CONFLICT(id) DO UPDATE SET
      name              = excluded.name,
      department        = excluded.department,
      category          = excluded.category,
      serial_number     = excluded.serial_number,
      status            = excluded.status,
      location          = COALESCE(excluded.location, equipment.location),
      manufacturer      = excluded.manufacturer,
      model             = excluded.model,
      manuf_year        = excluded.manuf_year,
      install_date      = excluded.install_date,
      department_id     = excluded.department_id,
      category_id       = excluded.category_id,
      subcategory_id    = excluded.subcategory_id,
      macro_category_id = excluded.macro_category_id,
      updated_at        = datetime('now','localtime')
  `);

  const insertOnly = db.prepare(`
    INSERT OR IGNORE INTO equipment (
      id, name, department, category, serial_number, status, location,
      manufacturer, model, manuf_year, install_date, department_id, category_id,
      subcategory_id, macro_category_id
    ) VALUES (
      @id, @name, @department, @category, @serial_number, @status, @location,
      @manufacturer, @model, @manuf_year, @install_date, @department_id, @category_id,
      @subcategory_id, @macro_category_id
    )
  `);

  const insertTag        = db.prepare('INSERT OR IGNORE INTO equipment_tags(equipment_id, tag_number) VALUES (?, ?)');
  const insertDepRuntime = db.prepare('INSERT OR IGNORE INTO departments(name) VALUES (?)');
  const insertCatRuntime = db.prepare('INSERT OR IGNORE INTO equipment_categories(name) VALUES (?)');
  const insertSubRuntime  = db.prepare('INSERT OR IGNORE INTO equipment_subcategories(name, macro_category_id) VALUES (?, ?)');
  const findMacroIdByName = db.prepare('SELECT id FROM equipment_macro_categories WHERE name = ?');
  const findEquipById    = db.prepare('SELECT id FROM equipment WHERE id = ?');

  const stats = {
    parsed: 0, created: 0, updated: 0, skipped: 0, errors: 0,
    tagsInserted: 0, depAdded: 0, catAdded: 0,
  };
  const errors = [];

  // Une seule transaction = atomicité + perf better-sqlite3
  const runImport = db.transaction(() => {
    for (let i = headerIdx + 1; i < rows.length; i++) {
      const r = rows[i] || [];
      const noCell = r[COL.No];
      if (noCell === null || noCell === undefined || noCell === '') continue;
      // La colonne "No" contient parfois un texte (signature/footer) → ignorer
      if (typeof noCell !== 'number' && !/^\d+$/.test(String(noCell).trim())) continue;

      stats.parsed++;

      try {
        const rawName     = N.cleanCell(r[COL.Name]);
        const rawDept     = N.normalizeRefName(r[COL.Department]);
        const rawCat      = rawName; // EquimentName sert de catégorie pour cet inventaire
        const manufacturer= N.cleanCell(r[COL.Manufacturer]);
        const model       = N.cleanCell(r[COL.Model]);
        const serial      = N.cleanCell(r[COL.SerialNumber]);
        const tag         = N.cleanCell(r[COL.TagNumber]);
        const status      = N.normalizeStatus(r[COL.Status]);
        const manufYear   = N.normalizeYear(r[COL.ManufYear]);
        const installDate = N.normalizeDate(r[COL.InstallDate]);

        if (!rawName || !rawDept) {
          stats.skipped++;
          errors.push(`Ligne ${i + 1} (No=${noCell}) : nom ou département manquant — ignorée`);
          continue;
        }

        // Le TagNumber est désormais la clé primaire (equipment.id) : sans tag
        // exploitable, on ne peut pas insérer la ligne.
        const id = N.tagToId(tag);
        if (!id) {
          stats.skipped++;
          errors.push(`Ligne ${i + 1} (No=${noCell}) : tag_number manquant ou invalide — ignorée`);
          continue;
        }

        // Résolution FK departement (insertion à la volée si inconnu)
        let departmentId = depMap.get(rawDept.toLowerCase());
        if (!departmentId) {
          const result = insertDepRuntime.run(rawDept);
          if (result.changes === 1) {
            departmentId = result.lastInsertRowid;
            stats.depAdded++;
            console.warn(`[WARN] Département ajouté à la volée : "${rawDept}"`);
          } else {
            // Race condition improbable : recharger
            const found = db.prepare('SELECT id FROM departments WHERE name = ?').get(rawDept);
            departmentId = found ? found.id : null;
          }
          if (departmentId) depMap.set(rawDept.toLowerCase(), departmentId);
        }

        // Résolution FK catégorie (le nom d'équipement sert de catégorie)
        let categoryId = catMap.get(rawCat.toLowerCase());
        if (!categoryId) {
          const result = insertCatRuntime.run(rawCat);
          if (result.changes === 1) {
            categoryId = result.lastInsertRowid;
            stats.catAdded++;
            console.warn(`[WARN] Catégorie ajoutée à la volée : "${rawCat}"`);
          } else {
            const found = db.prepare('SELECT id FROM equipment_categories WHERE name = ?').get(rawCat);
            categoryId = found ? found.id : null;
          }
          if (categoryId) catMap.set(rawCat.toLowerCase(), categoryId);
        }

        // Résolution FK sous-catégorie (miroir de equipment_categories dans equipment_subcategories)
        let subcategoryId = null;
        let macroCategoryId = null;
        const subEntry = subMap.get(rawCat.toLowerCase());
        if (subEntry) {
          subcategoryId   = subEntry.id;
          macroCategoryId = subEntry.macroId;
        } else {
          // Ajouter la sous-catégorie à la volée — classification par mots-clés
          // (cf. lib/macro_classifier.js), défaut 'Biomedical' si aucun mot-clé
          // ne correspond (le fichier source est l'inventaire médical : la
          // quasi-totalité des noms non reconnus sont bien des dispositifs
          // cliniques, contrairement au fichier infra/IT générique).
          const { macro, confident } = classifyMacro(rawCat, 'Biomedical');
          if (!confident) {
            errors.push(`Ligne ${i + 1} : "${rawCat}" non reconnu par mots-clés — classé ${macro} par défaut, à vérifier`);
          }
          const macroRow = findMacroIdByName.get(macro);
          const result = insertSubRuntime.run(rawCat, macroRow ? macroRow.id : null);
          if (result.changes === 1) {
            subcategoryId   = result.lastInsertRowid;
            macroCategoryId = macroRow ? macroRow.id : null;
            subMap.set(rawCat.toLowerCase(), { id: subcategoryId, macroId: macroCategoryId });
          } else {
            const found = db.prepare('SELECT id, macro_category_id FROM equipment_subcategories WHERE LOWER(name) = LOWER(?)').get(rawCat);
            if (found) {
              subcategoryId   = found.id;
              macroCategoryId = found.macro_category_id;
              subMap.set(rawCat.toLowerCase(), { id: subcategoryId, macroId: macroCategoryId });
            }
          }
        }

        const payload = {
          id,
          name: rawName,
          department: rawDept,
          category: rawCat,
          serial_number: serial,
          status,
          location: null,            // non fourni dans le XLSX
          manufacturer,
          model,
          manuf_year: manufYear,
          install_date: installDate,
          department_id: departmentId,
          category_id: categoryId,
          subcategory_id: subcategoryId,
          macro_category_id: macroCategoryId,
        };

        const existedBefore = !!findEquipById.get(id);
        const stmt = opts.insertOnly ? insertOnly : upsert;
        const result = stmt.run(payload);

        if (existedBefore) {
          if (opts.insertOnly) {
            stats.skipped++;
          } else {
            stats.updated++;
            logAction({
              user_role: 'system', user_name: 'import_inventory',
              action: 'update_equipment_import', target_type: 'equipment',
              target_id: id, target_name: rawName,
              details: { source: 'xlsx', tag_number: tag, serial_number: serial, status, department: rawDept },
            });
          }
        } else if (result.changes === 1) {
          stats.created++;
          logAction({
            user_role: 'system', user_name: 'import_inventory',
            action: 'create_equipment_import', target_type: 'equipment',
            target_id: id, target_name: rawName,
            details: { source: 'xlsx', tag_number: tag, serial_number: serial, status, department: rawDept },
          });
        } else {
          // INSERT OR IGNORE qui n'a rien fait → existait déjà mais findEquipById l'avait
          // raté (ne devrait pas arriver). Sécurité :
          stats.skipped++;
        }

        // Tags : on ne les insère que si l'équipement existe en DB
        if (tag) {
          const tagResult = insertTag.run(id, tag);
          if (tagResult.changes === 1) stats.tagsInserted++;
        }

        if (stats.parsed % 50 === 0) {
          console.log(`  ... ${stats.parsed} lignes traitées (créés=${stats.created}, MAJ=${stats.updated}, ignorés=${stats.skipped})`);
        }
      } catch (err) {
        stats.errors++;
        errors.push(`Ligne ${i + 1} (No=${noCell}) : ${err.message}`);
      }
    }
  });

  runImport();

  return { stats, errors };
}

// ── Point d'entrée ───────────────────────────────────────────────────────────
function main() {
  const args = parseArgs(process.argv);
  console.log('═══ Import inventaire physique 2025-2026 ═══');
  console.log(`  Mode      : ${args.dryRun ? 'DRY-RUN (lecture seule)' : args.insertOnly ? 'INSERT-ONLY' : 'UPSERT'}`);

  let xlsxPath;
  try {
    xlsxPath = resolveXlsxPath(args.xlsx);
  } catch (err) {
    console.error(`[ERREUR] ${err.message}`);
    process.exit(1);
  }
  console.log(`  Fichier   : ${xlsxPath}`);

  const workbook = XLSX.readFile(xlsxPath, { cellDates: true });
  console.log(`  Feuilles  : ${workbook.SheetNames.join(', ')}`);
  console.log('');

  if (args.dryRun) {
    // Mode dry-run : on ne touche pas la DB
    const tmpDbPath = ':memory:';
    process.env.DB_PATH = tmpDbPath;
    // Force la création d'une nouvelle instance in-memory
    require('../src/database').resetDb();
    const db = getDb();

    console.log('▶ Phase A : seed départements + catégories (dry-run via DB :memory:)…');
    const refStats = seedReferences(db, workbook, false);
    console.log(`  Départements seedés : ${refStats.departments}`);
    console.log(`  Catégories seedées  : ${refStats.categories}`);
    console.log('');

    console.log('▶ Phase B : import équipements (dry-run)…');
    const { stats, errors } = importEquipment(db, workbook, { insertOnly: false });
    printSummary(stats, errors);
    closeDb();
    return;
  }

  const db = getDb();

  console.log('▶ Phase A : seed départements + catégories…');
  const refStats = seedReferences(db, workbook, false);
  console.log(`  Départements ajoutés : ${refStats.departments}`);
  console.log(`  Catégories ajoutées  : ${refStats.categories}`);
  console.log('');

  console.log('▶ Phase B : import équipements…');
  const { stats, errors } = importEquipment(db, workbook, { insertOnly: args.insertOnly });
  printSummary(stats, errors);

  closeDb();
}

function printSummary(stats, errors) {
  console.log('');
  console.log('─── Résumé ──────────────────────────────');
  console.log(`  Lignes parsées       : ${stats.parsed}`);
  console.log(`  Équipements créés    : ${stats.created}`);
  console.log(`  Équipements MAJ      : ${stats.updated}`);
  console.log(`  Lignes ignorées      : ${stats.skipped}`);
  console.log(`  Erreurs              : ${stats.errors}`);
  console.log(`  Tags ajoutés         : ${stats.tagsInserted}`);
  console.log(`  Dépts ajoutés (run)  : ${stats.depAdded}`);
  console.log(`  Catégories ajoutées  : ${stats.catAdded}`);
  if (errors.length) {
    console.log('');
    console.log('Détail des erreurs / lignes ignorées :');
    for (const e of errors.slice(0, 20)) console.log(`  - ${e}`);
    if (errors.length > 20) console.log(`  … et ${errors.length - 20} de plus`);
  }
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error('[ERREUR FATALE]', err.message);
    if (process.env.DEBUG) console.error(err.stack);
    process.exit(1);
  }
}

module.exports = { parseArgs, resolveXlsxPath, seedReferences, importEquipment, findHeaderRow };
