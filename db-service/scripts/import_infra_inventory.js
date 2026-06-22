#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// import_infra_inventory.js — Importe l'inventaire mobilier/IT (fichier combiné
// non trié, ex. "INVENTORY combined october.xlsx").
//
// Contrairement à import_inventory.js (qui cible le fichier "Equipment
// Migration Template" déjà bien structuré), ce fichier source est un export
// brut hétérogène : colonnes qui se décalent en cours de feuille, en-têtes
// absents sur certaines feuilles. On ne peut donc pas se fier à des index de
// colonnes fixes — chaque ligne est analysée cellule par cellule (scan par
// motif) pour retrouver le nom, le tag, le département, le statut et la
// quantité, indépendamment de leur position.
//
// Chaque équipement reçoit une macro-catégorie (Biomedical / Infrastructure /
// IT) déterminée par une liste de mots-clés sur le nom (cf. CLASSIFICATION
// ci-dessous). Les noms non reconnus sont classés "Infrastructure" par
// défaut et listés en warning — à reclasser manuellement si besoin depuis
// l'onglet Catégories de l'application.
//
// Usage :
//   node scripts/import_infra_inventory.js [--xlsx <path>] [--dry-run] [--insert-only]
// ─────────────────────────────────────────────────────────────────────────────

const fs   = require('fs');
const XLSX = require('xlsx');

const { getDb, closeDb } = require('../src/database');
const { logAction }      = require('../src/utils/logger');
const N = require('./lib/inventory_normalizer');

// ── Feuilles à traiter (dans l'ordre) ────────────────────────────────────────
const SHEETS = ['Sheet1', 'Sheet2'];

// ── Départements connus dans ce fichier (avec variantes orthographiques) ────
// Clé = forme normalisée reconnue dans le fichier, valeur = nom canonique à
// insérer dans `departments`.
const DEPARTMENT_ALIASES = {
  'maternity':     'Maternity',
  'physiotherapy': 'Physiotherapy',
  'stock pharmac': 'Pharmacy',
  'stoc pharmac':  'Pharmacy',
  'stock pharm':   'Pharmacy',
};

// ── Statuts reconnus dans ce fichier (mots-clés → recherché dans la cellule) ─
const STATUS_TOKENS = ['good', 'fonctionnel', 'damaged', 'b'];

// ── Classification macro-catégorie par mots-clés sur le nom d'équipement ────
// Ordre de test : IT, puis Biomedical, puis défaut Infrastructure.
// "Ondulaire"/"Ondureire" = onduleur/UPS (confirmé par numéro de série
// BR1100C, modèle APC connu, sur la ligne source correspondante).
const IT_KEYWORDS = [
  'clavier', 'cpu', 'desktop', 'ecran', 'écran', 'flat screen', 'raptop',
  'laptop', 'unite cental', 'unité cental', 'ups', 'ondurair', 'ondulair',
  'machine desk top',
];

// Matériel de rééducation/physiothérapie + dispositifs thérapeutiques :
// classé Biomedical (suivi PM / plan de remplacement biomédical), conforme
// à la décision validée pour cette campagne d'import.
const BIOMEDICAL_KEYWORDS = [
  'aspirateur', 'balance adulte', 'balance bebe', 'balance bébé',
  'blood warmer', 'ctg', 'doppler', 'echographie', 'échographie',
  'frigo', 'refrigerator', 'réfrigérateur', 'glucometre', 'glucomètre',
  'lampe chaufante', 'lampe gynecologique', 'lampe gynécologique',
  'patient monitor', 'pulse  oxymeter', 'pulse oxymeter', 'radiant warmer',
  'tansiometre', 'tansiomètre', 'tens', 'vibromasseur',
  "tabled'accouchement", "table d'accouchement", 'blancard', 'brancard',
  'infrared', 'monark', 'parrallel bar', 'parallel bar', 'standing frame',
  'wall bar', 'mats', 'physioball', "table d'exercises", "tatble d'exercises",
];

// Mobilier courant : classé Infrastructure avec confiance (pas un warning).
const FURNITURE_KEYWORDS = [
  'armoire', 'armore', 'bed', 'lit', 'chair', 'chaise', 'table', 'etagere',
  'étagère', 'chariot', 'long banc', 'banc', 'paravent', 'roll', 'stretcher',
  'trolley', 'troly', 'wheel chair', 'whell chair', 'stabilisateur',
];

function classifyMacro(rawName) {
  const s = String(rawName || '').trim().toLowerCase();
  if (!s) return { macro: 'Infrastructure', confident: false };
  if (IT_KEYWORDS.some(k => s.includes(k)))         return { macro: 'IT', confident: true };
  if (BIOMEDICAL_KEYWORDS.some(k => s.includes(k))) return { macro: 'Biomedical', confident: true };
  if (FURNITURE_KEYWORDS.some(k => s.includes(k)))  return { macro: 'Infrastructure', confident: true };
  return { macro: 'Infrastructure', confident: false };
}

// ── Détection de cellule "code tag" : toute valeur contenant '/' (les codes
// KABDH/..., AHFRW/..., HOP KABUTARE/... varient trop dans leur format
// interne — points, tirets, espaces — pour un motif rigide par segment).
function looksLikeTag(v) {
  if (v === null || v === undefined) return false;
  const s = String(v).trim();
  if (s.length < 4 || !s.includes('/')) return false;
  if (looksLikeDepartment(s) || looksLikeStatus(s)) return false;
  return true;
}

function looksLikeDepartment(v) {
  if (v === null || v === undefined) return false;
  const s = String(v).trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(DEPARTMENT_ALIASES, s);
}

function looksLikeStatus(v) {
  if (v === null || v === undefined) return false;
  const s = String(v).trim().toLowerCase();
  return STATUS_TOKENS.includes(s);
}

function looksLikeQty(v) {
  return typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= 1000;
}

/**
 * Analyse une ligne hétérogène (colonnes non fixes) et en extrait les champs
 * reconnus. `no` (colonne 0) sert uniquement à détecter le début d'une ligne
 * de données valide (entier) — il n'est pas réutilisé ensuite.
 */
function parseRow(row) {
  const cells = row.slice(1); // on ignore la colonne "No" déjà validée par l'appelant
  let name = null, tag = null, department = null, status = null, qty = null;

  for (const cell of cells) {
    if (cell === null || cell === undefined || cell === '') continue;
    if (tag === null && looksLikeTag(cell))               { tag = String(cell).trim(); continue; }
    if (department === null && looksLikeDepartment(cell)) { department = String(cell).trim(); continue; }
    if (status === null && looksLikeStatus(cell))          { status = String(cell).trim(); continue; }
    if (qty === null && looksLikeQty(cell))                { qty = cell; continue; }
    // Premier texte restant, non reconnu comme tag/département/statut : le nom.
    if (name === null && typeof cell === 'string') { name = cell.trim(); continue; }
  }
  return { name, tag, department, status, qty };
}

// ── Parsing des arguments CLI (calque import_inventory.js) ─────────────────
function parseArgs(argv) {
  const args = { xlsx: null, dryRun: false, insertOnly: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--xlsx')             args.xlsx = argv[++i];
    else if (a === '--dry-run')     args.dryRun = true;
    else if (a === '--insert-only') args.insertOnly = true;
    else if (a === '--help' || a === '-h') { printHelp(); process.exit(0); }
    else console.warn(`[WARN] argument inconnu ignoré : ${a}`);
  }
  return args;
}

function printHelp() {
  console.log(`
Usage : node scripts/import_infra_inventory.js --xlsx <path> [options]

Options :
  --xlsx <path>     Chemin du fichier XLSX source (obligatoire).
  --dry-run         Parse + valide sans écrire en DB.
  --insert-only     N'écrase pas les équipements déjà présents.
  -h, --help        Affiche cette aide.
`);
}

function buildRefCaches(db) {
  const deps    = db.prepare('SELECT id, name FROM departments').all();
  const subs    = db.prepare('SELECT id, name, macro_category_id FROM equipment_subcategories').all();
  const macros  = db.prepare('SELECT id, name FROM equipment_macro_categories').all();
  const depMap   = new Map(deps.map(r => [r.name.toLowerCase(), r.id]));
  const subMap   = new Map(subs.map(r => [r.name.toLowerCase(), { id: r.id, macroId: r.macro_category_id }]));
  const macroMap = new Map(macros.map(r => [r.name, r.id]));
  return { depMap, subMap, macroMap };
}

function importSheet(db, workbook, sheetName, caches, opts, stats, warnings) {
  const sheet = workbook.Sheets[sheetName];
  if (!sheet) { console.warn(`[WARN] Feuille absente, ignorée : ${sheetName}`); return; }
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, blankrows: false, defval: null });

  const upsert = db.prepare(`
    INSERT INTO equipment (
      id, name, department, category, status, location,
      department_id, category_id, subcategory_id, macro_category_id
    ) VALUES (
      @id, @name, @department, @category, @status, @location,
      @department_id, @category_id, @subcategory_id, @macro_category_id
    )
    ON CONFLICT(id) DO UPDATE SET
      name              = excluded.name,
      department         = excluded.department,
      category           = excluded.category,
      status              = excluded.status,
      department_id      = excluded.department_id,
      category_id         = excluded.category_id,
      subcategory_id      = excluded.subcategory_id,
      macro_category_id   = excluded.macro_category_id,
      updated_at          = datetime('now','localtime')
  `);
  const insertOnly = db.prepare(`
    INSERT OR IGNORE INTO equipment (
      id, name, department, category, status, location,
      department_id, category_id, subcategory_id, macro_category_id
    ) VALUES (
      @id, @name, @department, @category, @status, @location,
      @department_id, @category_id, @subcategory_id, @macro_category_id
    )
  `);
  const insertTag        = db.prepare('INSERT OR IGNORE INTO equipment_tags(equipment_id, tag_number) VALUES (?, ?)');
  const insertDepRuntime = db.prepare('INSERT OR IGNORE INTO departments(name) VALUES (?)');
  const insertCatRuntime = db.prepare('INSERT OR IGNORE INTO equipment_categories(name) VALUES (?)');
  const insertSubRuntime = db.prepare('INSERT OR IGNORE INTO equipment_subcategories(name, macro_category_id) VALUES (?, ?)');
  const findEquipById     = db.prepare('SELECT id FROM equipment WHERE id = ?');

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i] || [];
    const noCell = row[0];
    if (noCell === null || noCell === undefined || noCell === '') continue;
    if (typeof noCell !== 'number' && !/^\d+$/.test(String(noCell).trim())) continue;

    stats.parsed++;
    try {
      const { name, tag, department, status: rawStatus, qty } = parseRow(row);

      const rawName = N.cleanCell(name);
      const rawDept = department ? (DEPARTMENT_ALIASES[department.toLowerCase()] || N.normalizeRefName(department)) : null;

      if (!rawName || !rawDept) {
        stats.skipped++;
        warnings.push(`[${sheetName}] Ligne ${i + 1} (No=${noCell}) : nom ou département non identifié — ignorée`);
        continue;
      }

      const id = N.tagToId(tag);
      if (!id) {
        stats.skipped++;
        warnings.push(`[${sheetName}] Ligne ${i + 1} (No=${noCell}, "${rawName}") : tag/code non identifié — ignorée`);
        continue;
      }

      const status = N.normalizeStatus(rawStatus);
      const { macro, confident } = classifyMacro(rawName);
      if (!confident) {
        warnings.push(`[${sheetName}] Ligne ${i + 1} : "${rawName}" non reconnu par mots-clés — classé Infrastructure par défaut, à vérifier`);
      }

      // Résolution département (insertion à la volée si inconnu)
      let departmentId = caches.depMap.get(rawDept.toLowerCase());
      if (!departmentId) {
        const r = insertDepRuntime.run(rawDept);
        departmentId = r.changes === 1
          ? r.lastInsertRowid
          : db.prepare('SELECT id FROM departments WHERE name = ?').get(rawDept).id;
        caches.depMap.set(rawDept.toLowerCase(), departmentId);
        stats.depAdded += r.changes;
      }

      // Catégorie standard (le nom d'équipement en sert)
      const catResult = insertCatRuntime.run(rawName);
      let categoryId = catResult.changes === 1
        ? catResult.lastInsertRowid
        : db.prepare('SELECT id FROM equipment_categories WHERE name = ?').get(rawName)?.id ?? null;
      stats.catAdded += catResult.changes;

      // Sous-catégorie (miroir), liée à la macro-catégorie déterminée par mots-clés
      const macroCategoryId = caches.macroMap.get(macro);
      let subEntry = caches.subMap.get(rawName.toLowerCase());
      let subcategoryId;
      if (subEntry) {
        subcategoryId = subEntry.id;
      } else {
        const r = insertSubRuntime.run(rawName, macroCategoryId);
        subcategoryId = r.changes === 1
          ? r.lastInsertRowid
          : db.prepare('SELECT id FROM equipment_subcategories WHERE LOWER(name) = LOWER(?)').get(rawName).id;
        caches.subMap.set(rawName.toLowerCase(), { id: subcategoryId, macroId: macroCategoryId });
      }

      const payload = {
        id, name: rawName, department: rawDept, category: rawName, status,
        location: null,
        department_id: departmentId, category_id: categoryId,
        subcategory_id: subcategoryId, macro_category_id: macroCategoryId,
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
            user_role: 'system', user_name: 'import_infra_inventory',
            action: 'update_equipment_import', target_type: 'equipment',
            target_id: id, target_name: rawName,
            details: { source: 'xlsx_infra', tag_number: tag, status, department: rawDept, macro },
          });
        }
      } else if (result.changes === 1) {
        stats.created++;
        logAction({
          user_role: 'system', user_name: 'import_infra_inventory',
          action: 'create_equipment_import', target_type: 'equipment',
          target_id: id, target_name: rawName,
          details: { source: 'xlsx_infra', tag_number: tag, status, department: rawDept, macro },
        });
      } else {
        stats.skipped++;
      }

      if (tag) {
        const tagResult = insertTag.run(id, tag);
        if (tagResult.changes === 1) stats.tagsInserted++;
      }
      if (qty && qty > 1) {
        warnings.push(`[${sheetName}] Ligne ${i + 1} ("${rawName}") : quantité=${qty} mais un seul équipement créé (tag unique requis pour ${qty - 1} exemplaire(s) supplémentaire(s) — non importés)`);
      }
    } catch (err) {
      stats.errors++;
      warnings.push(`[${sheetName}] Ligne ${i + 1} (No=${noCell}) : ${err.message}`);
    }
  }
}

function main() {
  const args = parseArgs(process.argv);
  if (!args.xlsx) {
    console.error('[ERREUR] --xlsx <path> est obligatoire pour ce script.');
    process.exit(1);
  }
  if (!fs.existsSync(args.xlsx)) {
    console.error(`[ERREUR] Fichier introuvable : ${args.xlsx}`);
    process.exit(1);
  }

  console.log('═══ Import inventaire Infrastructure/IT (fichier combiné) ═══');
  console.log(`  Mode      : ${args.dryRun ? 'DRY-RUN (lecture seule)' : args.insertOnly ? 'INSERT-ONLY' : 'UPSERT'}`);
  console.log(`  Fichier   : ${args.xlsx}`);

  const workbook = XLSX.readFile(args.xlsx, { cellDates: true });
  console.log(`  Feuilles  : ${workbook.SheetNames.join(', ')}`);
  console.log('');

  if (args.dryRun) {
    process.env.DB_PATH = ':memory:';
    require('../src/database').resetDb();
  }
  const db = getDb();
  const caches = buildRefCaches(db);

  const stats = { parsed: 0, created: 0, updated: 0, skipped: 0, errors: 0, tagsInserted: 0, depAdded: 0, catAdded: 0 };
  const warnings = [];

  const runImport = db.transaction(() => {
    for (const sheetName of SHEETS) {
      importSheet(db, workbook, sheetName, caches, { insertOnly: args.insertOnly }, stats, warnings);
    }
  });
  runImport();

  console.log('─── Résumé ──────────────────────────────');
  console.log(`  Lignes parsées       : ${stats.parsed}`);
  console.log(`  Équipements créés    : ${stats.created}`);
  console.log(`  Équipements MAJ      : ${stats.updated}`);
  console.log(`  Lignes ignorées      : ${stats.skipped}`);
  console.log(`  Erreurs              : ${stats.errors}`);
  console.log(`  Tags ajoutés         : ${stats.tagsInserted}`);
  console.log(`  Dépts ajoutés (run)  : ${stats.depAdded}`);
  console.log(`  Catégories ajoutées  : ${stats.catAdded}`);
  if (warnings.length) {
    console.log('');
    console.log(`Détail des avertissements / lignes ignorées (${warnings.length}) :`);
    for (const w of warnings) console.log(`  - ${w}`);
  }

  closeDb();
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

module.exports = { parseArgs, classifyMacro, parseRow, looksLikeTag, looksLikeDepartment, looksLikeStatus };
