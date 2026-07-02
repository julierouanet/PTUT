'use strict';

// ── Configuration DB en mémoire (DOIT être avant tout require du service) ──────
process.env.DB_PATH          = ':memory:';
process.env.KC_ISSUER        = 'http://keycloak-test/realms/kabutare-hospital';
process.env.AUTH_SERVICE_URL = 'http://auth-service-test:3001';
process.env.INTERNAL_SECRET  = 'test-internal-secret';

// ── Mock du middleware d'auth (non sollicité ici, mais requis par backups.js) ──
jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => next(),
  requireRole: () => (req, res, next) => next(),
  SYSTEM_ROLES: new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));

// ── Mock du logger (évite tout appel HTTP vers auth-service) ───────────────────
jest.mock('../utils/logger', () => ({
  logAction:      jest.fn(),
  extractReqMeta: jest.fn(() => ({})),
  sendLog:        jest.fn(),
}));

const fs = require('fs');
const path = require('path');
const { getDb, closeDb } = require('../database');
const { _rotateBackups, BACKUPS_DIR } = require('../routes/backups');

let db;

// ── Helpers ──────────────────────────────────────────────────────────────────
function fname(y, m, d, hh = '00', mm = '00', ss = '00') {
  const pad = (n) => String(n).padStart(2, '0');
  return `hospital_backup_${y}-${pad(m)}-${pad(d)}_${hh}-${mm}-${ss}.db`;
}

// Date fixe et ancienne (toujours > 7 jours avant "aujourd'hui" quelle que soit
// la date d'exécution des tests) — évite toute dépendance au jour courant pour
// les scénarios qui testent uniquement la règle mensuelle.
function oldDate(month, day) {
  return fname(2020, month, day);
}

function daysAgoFilename(n) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - n);
  return fname(d.getFullYear(), d.getMonth() + 1, d.getDate());
}

function writeFile(filename) {
  fs.writeFileSync(path.join(BACKUPS_DIR, filename), 'contenu-test');
}

function insertHistory(filename) {
  db.prepare(`
    INSERT INTO backup_history (filename, backup_type, status, file_size, created_at)
    VALUES (?, 'automated', 'success', '1 KB', datetime('now','localtime'))
  `).run(filename);
}

function historyRow(filename) {
  return db.prepare('SELECT * FROM backup_history WHERE filename = ?').get(filename);
}

beforeAll(() => {
  db = getDb();
});

afterAll(() => {
  closeDb();
  fs.rmSync(BACKUPS_DIR, { recursive: true, force: true });
});

beforeEach(() => {
  fs.rmSync(BACKUPS_DIR, { recursive: true, force: true });
  fs.mkdirSync(BACKUPS_DIR, { recursive: true });
  db.prepare('DELETE FROM backup_history').run();
});

describe('Rétention des sauvegardes — _rotateBackups()', () => {
  test('conserve tous les fichiers de moins de 7 jours', () => {
    const files = [daysAgoFilename(0), daysAgoFilename(1), daysAgoFilename(6)];
    files.forEach(writeFile);

    _rotateBackups();

    const remaining = fs.readdirSync(BACKUPS_DIR);
    files.forEach((f) => expect(remaining).toContain(f));
  });

  test('ne garde que le plus ancien du mois pour les fichiers de plus de 7 jours', () => {
    const oldest = oldDate(3, 5);
    const middle = oldDate(3, 15);
    const newest = oldDate(3, 25);
    [oldest, middle, newest].forEach(writeFile);

    _rotateBackups();

    const remaining = fs.readdirSync(BACKUPS_DIR);
    expect(remaining).toEqual([oldest]);
  });

  test('garde un fichier par mois sur plusieurs mois différents', () => {
    const jan = oldDate(1, 10);
    const feb = oldDate(2, 10);
    const mar = oldDate(3, 10);
    [jan, feb, mar].forEach(writeFile);

    _rotateBackups();

    const remaining = fs.readdirSync(BACKUPS_DIR).sort();
    expect(remaining).toEqual([jan, feb, mar].sort());
  });

  test("ne supprime rien si BACKUPS_DIR n'existe pas", () => {
    fs.rmSync(BACKUPS_DIR, { recursive: true, force: true });

    expect(() => _rotateBackups()).not.toThrow();
  });

  test('supprime la ligne backup_history correspondant au fichier supprimé', () => {
    const kept = oldDate(3, 5);
    const removed = oldDate(3, 15);
    [kept, removed].forEach(writeFile);
    [kept, removed].forEach(insertHistory);

    _rotateBackups();

    expect(historyRow(kept)).toBeDefined();
    expect(historyRow(removed)).toBeUndefined();
  });

  test('ignore un fichier au nom non conforme sans planter', () => {
    const valid = oldDate(3, 5);
    writeFile(valid);
    writeFile('notes-de-service.txt');
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});

    expect(() => _rotateBackups()).not.toThrow();

    const remaining = fs.readdirSync(BACKUPS_DIR);
    expect(remaining).toContain('notes-de-service.txt');
    expect(remaining).toContain(valid);
    warnSpy.mockRestore();
  });

  test('départage deux fichiers du même mois à date identique par ordre alphabétique', () => {
    const fileA = fname(2020, 3, 5, '08', '00', '00'); // alphabétiquement le plus petit
    const fileB = fname(2020, 3, 5, '10', '00', '00');
    [fileB, fileA].forEach(writeFile); // ordre d'écriture inversé — ne doit pas influencer le résultat

    _rotateBackups();

    const remaining = fs.readdirSync(BACKUPS_DIR);
    expect(remaining).toEqual([fileA]);
  });
});
