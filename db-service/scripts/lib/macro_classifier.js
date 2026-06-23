// ── Classification macro-catégorie (Biomedical / Infrastructure / IT) par
// mots-clés sur le nom d'équipement — partagée entre import_inventory.js
// (fichier "Equipment Migration Template") et import_infra_inventory.js
// (fichier combiné mobilier/IT non trié), pour qu'un même nom d'équipement
// reçoive toujours la même macro-catégorie quel que soit le fichier source.
//
// Ordre de test : IT, puis Biomedical, puis Infrastructure (mobilier connu en
// confiance, sinon défaut non confiant — voir `confident` dans le retour).

const IT_KEYWORDS = [
  'clavier', 'cpu', 'desktop', 'ecran', 'écran', 'flat screen', 'raptop',
  'laptop', 'unite cental', 'unité cental', 'ups', 'ondurair', 'ondulair',
  'machine desk top',
];

// Matériel de rééducation/physiothérapie + dispositifs thérapeutiques :
// classé Biomedical (suivi PM / plan de remplacement biomédical).
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

// Termes cliniques composés contenant un mot de mobilier générique
// ('bed'/'table'/'chair'...) qui ne doivent JAMAIS être classés Infrastructure
// par la couche FURNITURE_KEYWORDS — ce sont de vrais dispositifs médicaux.
const CLINICAL_FURNITURE_OVERRIDES = [
  'autopsy table', 'delivery bed', 'dental chair', 'examination table',
  'operating table', 'hydraulic delivery bed',
];

/** Teste un mot-clé en respectant les frontières de mot (évite "table" dans "portable"). */
function matchesKeyword(haystack, keyword) {
  const escaped = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`\\b${escaped}\\b`, 'i').test(haystack);
}

/**
 * Détermine la macro-catégorie d'un nom d'équipement.
 *
 * Les mots-clés explicites (IT/Biomedical/mobilier) priment toujours, quel
 * que soit le fichier source. Si aucun mot-clé ne correspond, on retombe sur
 * [defaultMacro] — qui doit refléter le contenu *majoritaire* du fichier
 * source (ex. 'Biomedical' pour l'inventaire médical où la quasi-totalité
 * des noms sont des dispositifs cliniques inconnus de nos listes de
 * mots-clés ; 'Infrastructure' pour un inventaire mobilier/IT générique).
 *
 * Retourne `{ macro: 'Biomedical'|'Infrastructure'|'IT', confident: boolean }`.
 * `confident: false` signifie "aucun mot-clé reconnu, [defaultMacro] appliqué
 * par défaut" — à signaler en warning par l'appelant si besoin.
 */
function classifyMacro(rawName, defaultMacro = 'Infrastructure') {
  const s = String(rawName || '').trim().toLowerCase();
  if (!s) return { macro: defaultMacro, confident: false };
  if (CLINICAL_FURNITURE_OVERRIDES.some(k => s.includes(k))) return { macro: 'Biomedical', confident: true };
  if (IT_KEYWORDS.some(k => matchesKeyword(s, k)))         return { macro: 'IT', confident: true };
  if (BIOMEDICAL_KEYWORDS.some(k => s.includes(k)))        return { macro: 'Biomedical', confident: true };
  if (FURNITURE_KEYWORDS.some(k => matchesKeyword(s, k)))  return { macro: 'Infrastructure', confident: true };
  return { macro: defaultMacro, confident: false };
}

module.exports = { classifyMacro, IT_KEYWORDS, BIOMEDICAL_KEYWORDS, FURNITURE_KEYWORDS };
