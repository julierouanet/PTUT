// Outil d'audit i18n — compare les clés de app_fr.arb et app_en.arb
// Usage : node audit/tools/diff_arb.js (depuis la racine du projet)
// Lecture seule — n'écrit rien.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const frPath = path.join(root, 'flutter-app', 'lib', 'l10n', 'app_fr.arb');
const enPath = path.join(root, 'flutter-app', 'lib', 'l10n', 'app_en.arb');

function loadKeys(file) {
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  // Ignore les métadonnées ARB (clés commençant par @)
  return new Set(Object.keys(json).filter((k) => !k.startsWith('@')));
}

const frKeys = loadKeys(frPath);
const enKeys = loadKeys(enPath);

const onlyFr = [...frKeys].filter((k) => !enKeys.has(k));
const onlyEn = [...enKeys].filter((k) => !frKeys.has(k));

console.log(`Clés app_fr.arb : ${frKeys.size}`);
console.log(`Clés app_en.arb : ${enKeys.size}`);
console.log(`Orphelines FR (absentes de EN) : ${onlyFr.length}`);
onlyFr.forEach((k) => console.log(`  FR only: ${k}`));
console.log(`Orphelines EN (absentes de FR) : ${onlyEn.length}`);
onlyEn.forEach((k) => console.log(`  EN only: ${k}`));

if (onlyFr.length === 0 && onlyEn.length === 0) {
  console.log('✅ Clés strictement synchronisées.');
} else {
  process.exitCode = 1;
}
