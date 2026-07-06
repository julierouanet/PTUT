#!/usr/bin/env node
// ── Seed des comptes de démonstration dans Keycloak ───────────────────────────
// Crée les utilisateurs de base avec leurs rôles et mots de passe définitifs.
//
// Idempotent au sens strict : le realm est marqué via l'attribut "demoSeeded"
// après le premier passage réussi. Ce script est appelé automatiquement par le
// Jenkinsfile à CHAQUE déploiement (prod + dev) — sans ce marqueur, un admin
// qui supprime un compte démo via l'app le voyait recréé au build suivant
// (findUserByEmail() ne fait pas la différence entre "jamais créé" et "supprimé
// volontairement"). Voir le fix du 2026-07-07.
// Pour forcer un re-seed (ex: realm recréé de zéro) : retirer l'attribut
// "demoSeeded" du realm via la console admin, ou le recréer entièrement.
//
// Usage : node scripts/keycloak-seed.js
//
// Variables d'environnement :
//   KC_ADMIN_URL      (défaut: http://localhost:8080)
//   KC_ADMIN_USER     (défaut: admin)
//   KC_ADMIN_PASSWORD

'use strict';

const KC_ADMIN_URL      = process.env.KC_ADMIN_URL      || 'http://localhost:8080';
const KC_ADMIN_USER     = process.env.KC_ADMIN_USER     || 'admin';
const KC_ADMIN_PASSWORD = process.env.KC_ADMIN_PASSWORD || 'admin';
const KC_REALM          = 'kabutare-hospital';

const USERS = [
  { firstName: 'Admin',   lastName: 'Système',         email: 'admin@kabutare.rw',      password: 'Admin1234!', roles: ['admin'],                                                      department: 'Administration'  },
  { firstName: 'Jean',    lastName: 'Habimana',         email: 'j.habimana@kabutare.rw', password: 'Password1!', roles: ['supervisor'],                                                 department: 'Chirurgie'       },
  { firstName: 'Claire',  lastName: 'Uwimana',          email: 'c.uwimana@kabutare.rw',  password: 'Password1!', roles: ['supervisor'],                                                 department: 'Maternité'       },
  { firstName: 'Moussa',  lastName: 'Baldé',            email: 'm.balde@kabutare.rw',    password: 'Password1!', roles: ['technician_biomedical', 'technician_it', 'technician_infra'], department: 'Administration'  },
  { firstName: 'Amadou',  lastName: 'Cissé',            email: 'a.cisse@kabutare.rw',    password: 'Password1!', roles: ['technician_biomedical', 'technician_it', 'technician_infra'], department: 'Administration'  },
  { firstName: 'Ibrahim', lastName: 'Traoré',           email: 'i.traore@kabutare.rw',   password: 'Password1!', roles: ['hospitalStaff'],                                              department: 'Bloc opératoire' },
  { firstName: 'Fatou',   lastName: 'Keita',            email: 'f.keita@kabutare.rw',    password: 'Password1!', roles: ['hospitalStaff'],                                              department: 'Urgences'        },
  { firstName: 'Oumar',   lastName: 'Diallo',           email: 'o.diallo@kabutare.rw',   password: 'Password1!', roles: ['hospitalStaff'],                                              department: 'Laboratoire'     },
];

// ── Helpers ────────────────────────────────────────────────────────────────────

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
  if (!resp.ok) throw new Error(`Auth admin Keycloak échouée : ${resp.status} ${await resp.text()}`);
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

async function findUserByEmail(email) {
  const resp = await kc('GET', `/users?email=${encodeURIComponent(email)}&exact=true`);
  if (!resp.ok) return null;
  const list = await resp.json();
  return list.length > 0 ? list[0] : null;
}

async function getRealmRole(roleName) {
  const resp = await kc('GET', `/roles/${encodeURIComponent(roleName)}`);
  return resp.ok ? resp.json() : null;
}

async function getRealmRepresentation() {
  const resp = await kc('GET', '');
  if (!resp.ok) throw new Error(`Lecture du realm échouée : ${resp.status} ${await resp.text()}`);
  return resp.json();
}

async function isAlreadySeeded() {
  const realm = await getRealmRepresentation();
  return realm.attributes?.demoSeeded === 'true';
}

async function markAsSeeded() {
  const realm = await getRealmRepresentation();
  const attributes = { ...(realm.attributes || {}), demoSeeded: 'true' };
  const resp = await kc('PUT', '', { ...realm, attributes });
  if (!resp.ok) console.warn(`  ⚠  Marquage du realm "demoSeeded" échoué : ${resp.status}`);
}

async function assignRoles(kcId, roleNames) {
  const roles = (await Promise.all(roleNames.map(getRealmRole))).filter(Boolean);
  if (!roles.length) return;
  const r = await kc('POST', `/users/${kcId}/role-mappings/realm`, roles);
  if (!r.ok) console.warn(`  ⚠  Assignation rôles échouée : ${r.status}`);
}

// ── Seed ───────────────────────────────────────────────────────────────────────

async function seedUser(u) {
  console.log(`\n→ ${u.email} (${u.roles.join(', ')})`);

  const existing = await findUserByEmail(u.email);

  if (existing) {
    console.log(`  ✓ Existant (${existing.id}) — synchronisation des rôles.`);
    await assignRoles(existing.id, u.roles);
    return;
  }

  const createResp = await kc('POST', '/users', {
    username:        u.email,
    email:           u.email,
    firstName:       u.firstName,
    lastName:        u.lastName,
    enabled:         true,
    attributes:      { department: [u.department] },
    requiredActions: [],
  });

  if (!createResp.ok) {
    console.error(`  ✗ Erreur création : ${createResp.status} ${await createResp.text()}`);
    return;
  }

  const kcId = (createResp.headers.get('Location') ?? '').split('/').pop();
  console.log(`  ✓ Créé (${kcId})`);

  const pwdResp = await kc('PUT', `/users/${kcId}/reset-password`, {
    type:      'password',
    value:     u.password,
    temporary: false,
  });
  if (!pwdResp.ok) console.warn(`  ⚠  Set password échoué : ${pwdResp.status}`);
  else console.log(`  ✓ Mot de passe défini`);

  await assignRoles(kcId, u.roles);
  console.log(`  ✓ Rôles assignés : ${u.roles.join(', ')}`);
}

async function main() {
  console.log('════════════════════════════════════════════');
  console.log(' Seed Keycloak — comptes de démonstration');
  console.log(`  Realm    : ${KC_REALM}`);
  console.log(`  Keycloak : ${KC_ADMIN_URL}`);
  console.log('════════════════════════════════════════════\n');

  if (await isAlreadySeeded()) {
    console.log('ℹ️  Realm déjà marqué "demoSeeded" — comptes de démonstration non re-créés.');
    console.log('   Les suppressions volontaires effectuées via l\'app sont donc respectées.');
    console.log('   Pour forcer un re-seed : retirer l\'attribut "demoSeeded" du realm (console admin).');
    return;
  }

  for (const u of USERS) {
    await seedUser(u);
  }

  await markAsSeeded();

  console.log('\n✅ Seed terminé — realm marqué "demoSeeded" (ne sera plus re-exécuté automatiquement).');
  console.log('\nComptes créés :');
  for (const u of USERS) {
    console.log(`  ${u.email.padEnd(30)} ${u.password}  [${u.roles.join(', ')}]`);
  }
}

main().catch((err) => {
  console.error('\n✗ Erreur fatale :', err.message);
  process.exit(1);
});
