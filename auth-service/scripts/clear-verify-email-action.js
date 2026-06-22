#!/usr/bin/env node
// ── Déblocage one-shot : retrait de VERIFY_EMAIL des comptes existants ────────
// Avant le correctif "suppression du blocage de connexion par email non vérifié",
// /register et /access-request posaient requiredActions: ['VERIFY_EMAIL'] à la
// création, ce qui empêche le Direct Grant login Keycloak (invalid_grant /
// "Account is not fully set up"). Ce script retire VERIFY_EMAIL de la liste des
// requiredActions de tous les comptes du realm qui l'ont encore, sans toucher à
// emailVerified ni aux autres requiredActions éventuels (ex. UPDATE_PASSWORD).
//
// Usage :
//   node scripts/clear-verify-email-action.js [--dry-run]
//
// Variables d'environnement (mêmes défauts que scripts/migrate-users.js) :
//   KC_ADMIN_URL       URL Keycloak (défaut: http://localhost:8080)
//   KC_ADMIN_USER      utilisateur admin Keycloak (défaut: admin)
//   KC_ADMIN_PASSWORD  mot de passe admin
//   KC_REALM           realm cible (défaut: kabutare-hospital)
//
// Idempotent : une seconde exécution n'a plus rien à traiter (0 utilisateur).

'use strict';

const KC_ADMIN_URL      = process.env.KC_ADMIN_URL      || 'http://localhost:8080';
const KC_ADMIN_USER     = process.env.KC_ADMIN_USER     || 'admin';
const KC_ADMIN_PASSWORD = process.env.KC_ADMIN_PASSWORD || 'admin';
const KC_REALM          = process.env.KC_REALM          || 'kabutare-hospital';

const DRY_RUN = process.argv.includes('--dry-run');

// ── Auth Keycloak (realm master, admin-cli) — pattern repris de migrate-users.js
let _token = null;
let _expiresAt = 0;

async function masterToken() {
  if (_token && Date.now() < _expiresAt - 30_000) return _token;
  const resp = await fetch(`${KC_ADMIN_URL}/realms/master/protocol/openid-connect/token`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    new URLSearchParams({
      grant_type: 'password',
      client_id:  'admin-cli',
      username:   KC_ADMIN_USER,
      password:   KC_ADMIN_PASSWORD,
    }),
  });
  if (!resp.ok) throw new Error(`Auth Keycloak admin échouée: ${resp.status} ${await resp.text()}`);
  const data = await resp.json();
  _token     = data.access_token;
  _expiresAt = Date.now() + data.expires_in * 1000;
  return _token;
}

async function kc(method, path, body) {
  const token = await masterToken();
  const resp  = await fetch(`${KC_ADMIN_URL}/admin/realms/${KC_REALM}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  return resp;
}

async function fetchAllUsers() {
  const users = [];
  let offset = 0;
  for (;;) {
    const resp = await kc('GET', `/users?first=${offset}&max=100&briefRepresentation=false`);
    if (!resp.ok) throw new Error(`Liste utilisateurs échouée: ${resp.status} ${await resp.text()}`);
    const page = await resp.json();
    if (page.length === 0) break;
    users.push(...page);
    offset += 100;
  }
  return users;
}

async function main() {
  console.log('════════════════════════════════════════════════════════');
  console.log(' Déblocage des comptes : retrait de VERIFY_EMAIL');
  console.log(`  Keycloak : ${KC_ADMIN_URL}/realms/${KC_REALM}`);
  console.log(DRY_RUN ? '  MODE     : DRY-RUN (aucune modification)' : '  MODE     : LIVE');
  console.log('════════════════════════════════════════════════════════\n');

  const users = await fetchAllUsers();
  console.log(`Utilisateurs scannés : ${users.length}`);

  let modifies = 0;
  let erreurs  = 0;

  for (const u of users) {
    if (!Array.isArray(u.requiredActions) || !u.requiredActions.includes('VERIFY_EMAIL')) continue;

    const nouvelleListe = u.requiredActions.filter((a) => a !== 'VERIFY_EMAIL');

    if (DRY_RUN) {
      console.log(`[DRY-RUN] ${u.email} : ${JSON.stringify(u.requiredActions)} → ${JSON.stringify(nouvelleListe)}`);
      modifies++;
      continue;
    }

    const resp = await kc('PUT', `/users/${u.id}`, { requiredActions: nouvelleListe });

    if (resp.status === 404) {
      console.warn(`⚠️  ${u.email} : utilisateur introuvable (supprimé entre temps) — ignoré`);
      erreurs++;
      continue;
    }
    if (!resp.ok) {
      console.error(`✗ ${u.email} : échec PUT (${resp.status}) ${await resp.text()}`);
      erreurs++;
      continue;
    }

    console.log(`✓ ${u.email} : ${JSON.stringify(u.requiredActions)} → ${JSON.stringify(nouvelleListe)}`);
    modifies++;
  }

  console.log('\n── Résumé ──────────────────────────────────────────────');
  console.log(`  Scannés  : ${users.length}`);
  console.log(`  Modifiés : ${modifies}`);
  console.log(`  Erreurs  : ${erreurs}`);
  if (DRY_RUN) console.log('  ℹ️  Dry-run : aucune modification n\'a été effectuée.');
}

main().catch((err) => {
  console.error('\n✗ Erreur fatale :', err.message);
  process.exit(1);
});
