// ── Fonctions pures de normalisation pour l'import de l'inventaire physique ──
// Toutes ces fonctions sont déterministes et n'effectuent aucune I/O — elles sont
// destinées à être unitairement testables via Jest.

// Marqueurs de "valeur absente" rencontrés dans le XLSX original.
// "uknown" est la faute d'orthographe du fichier source (≠ "unknown").
const ABSENT_MARKERS = /^(n\/?a|unknown|uknown|none|-)$/i;

/**
 * Renvoie la chaîne nettoyée, ou null si la cellule est vide ou contient un
 * marqueur "absent" (`n/a`, `N/A`, `UNKNOWN`, `UKNOWN`, `none`, `-`).
 */
function cleanCell(v) {
  if (v === null || v === undefined) return null;
  if (v instanceof Date) return v.toISOString();
  const s = String(v).trim();
  if (!s) return null;
  if (ABSENT_MARKERS.test(s)) return null;
  return s;
}

/**
 * Normalise les variantes de statut observées dans le XLSX vers la whitelist
 * anglaise (cf. `routes/equipment.js > VALID_STATUSES_EQ`).
 * Retourne 'Operational' par défaut si l'entrée est vide ou inconnue.
 */
function normalizeStatus(raw) {
  if (raw === null || raw === undefined) return 'Operational';
  const s = String(raw).trim().toLowerCase();
  if (!s) return 'Operational';

  if (/^op[eéa]?r?ational$/.test(s) || s === 'opeational') return 'Operational';
  if (/^under\s*m/.test(s) || s === 'underm')              return 'Maintenance';
  if (/^idd?le/.test(s))                                   return 'Out of service';
  if (s === 'disposed')                                    return 'Disposed';
  if (/to\s+be\s+disposal/.test(s))                        return 'To be disposal';
  if (/kibirizi/.test(s))                                  return 'Out of service';

  return 'Operational';
}

/**
 * Nettoie un nom de département / catégorie : retire tabulations et espaces en
 * début/fin, normalise les espaces internes. Retourne null pour entrée vide.
 */
function normalizeRefName(raw) {
  if (raw === null || raw === undefined) return null;
  const s = String(raw).replace(/^[\s\t]+|[\s\t]+$/g, '').replace(/\s+/g, ' ');
  return s || null;
}

/**
 * Convertit une valeur date hétérogène (Date JS, nombre série Excel, string
 * "DD/MM/YYYY" ou "D/M/YYYY", entier année) en ISO 'YYYY-MM-DD' ou null.
 */
function normalizeDate(raw) {
  if (raw === null || raw === undefined) return null;
  if (raw instanceof Date && !isNaN(raw.getTime())) {
    return raw.toISOString().slice(0, 10);
  }
  if (typeof raw === 'number') {
    // Si c'est un entier dans une plage plausible d'année, on l'interprète comme année
    if (Number.isInteger(raw) && raw >= 1900 && raw <= 2100) {
      return `${raw}-01-01`;
    }
    // Sinon on suppose un serial Excel (jours depuis 1899-12-30)
    const epoch = Date.UTC(1899, 11, 30);
    const d = new Date(epoch + Math.round(raw) * 86400000);
    if (!isNaN(d.getTime())) return d.toISOString().slice(0, 10);
    return null;
  }
  const s = String(raw).trim();
  if (!s || ABSENT_MARKERS.test(s)) return null;

  // Format ISO déjà
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (m) return `${m[1]}-${pad2(m[2])}-${pad2(m[3])}`;

  // Format DD/MM/YYYY ou D/M/YYYY
  m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
  if (m) return `${m[3]}-${pad2(m[2])}-${pad2(m[1])}`;

  // Année seule
  m = s.match(/^(\d{4})$/);
  if (m) return `${m[1]}-01-01`;

  return null;
}

/**
 * Extrait l'année (INTEGER) à partir d'une cellule "Manuf Year" qui peut être
 * un Date, un entier (2023), ou une chaîne ('18/3/2022', '2022'). Retourne
 * null si non reconnu.
 */
function normalizeYear(raw) {
  if (raw === null || raw === undefined) return null;
  if (raw instanceof Date && !isNaN(raw.getTime())) return raw.getFullYear();
  if (typeof raw === 'number' && Number.isInteger(raw)) {
    if (raw >= 1900 && raw <= 2100) return raw;
    // Serial Excel improbable pour une année, on tente quand même
    const iso = normalizeDate(raw);
    return iso ? parseInt(iso.slice(0, 4), 10) : null;
  }
  const s = String(raw).trim();
  if (!s || ABSENT_MARKERS.test(s)) return null;

  const iso = normalizeDate(s);
  if (iso) return parseInt(iso.slice(0, 4), 10);

  const m = s.match(/(\d{4})/);
  if (m) {
    const y = parseInt(m[1], 10);
    if (y >= 1900 && y <= 2100) return y;
  }
  return null;
}

/**
 * Convertit un SerialNumber en `equipment.id` slugifié (alphanumérique, `_`,
 * `-`, longueur ≤ 100, validable par /^[a-zA-Z0-9_-]+$/). Si vide, génère un
 * id séquentiel `noserial-XXX` à partir de fallbackIndex (1-indexé).
 */
function serialToId(serial, fallbackIndex) {
  const cleaned = cleanCell(serial);
  if (!cleaned) return `noserial-${String(fallbackIndex).padStart(3, '0')}`;
  const slug = cleaned
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 100);
  return slug || `noserial-${String(fallbackIndex).padStart(3, '0')}`;
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

module.exports = {
  cleanCell,
  normalizeStatus,
  normalizeRefName,
  normalizeDate,
  normalizeYear,
  serialToId,
};
