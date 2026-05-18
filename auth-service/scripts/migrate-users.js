#!/usr/bin/env node
// ── Migration one-shot : auth.db → Keycloak ───────────────────────────────────
// Importe tous les utilisateurs de la base SQLite locale vers le realm Keycloak.
// Chaque utilisateur reçoit un mot de passe temporaire aléatoire et est forcé
// à en définir un nouveau lors de son premier login (requiredActions: UPDATE_PASSWORD).
//
// Usage :
//   node scripts/migrate-users.js [--dry-run] [--output <fichier.csv>]
//
// Variables d'environnement :
//   AUTH_DB_PATH       chemin de auth.db (défaut: /data/auth.db)
//   KC_ADMIN_URL       URL Keycloak (défaut: http://localhost:8080)
//   KC_ADMIN_USER      utilisateur admin Keycloak (défaut: admin)
//   KC_ADMIN_PASSWORD  mot de passe admin
//   KC_REALM           realm cible (défaut: kabutare-hospital)
//
// Idempotent : si l'email existe déjà dans Keycloak, l'utilisateur est mis à jour
// (pas de doublon). Le mapping ancien_id → keycloak_id est écrit dans le CSV.

'use strict';

const Database = require('better-sqlite3');
const crypto   = require('crypto');
const fs       = require('fs');
const path     = require('path');

const AUTH_DB_PATH      = process.env.AUTH_DB_PATH      || '/data/auth.db';
const KC_ADMIN_URL      = process.env.KC_ADMIN_URL      || 'http://localhost:8080';
const KC_ADMIN_USER     = process.env.KC_ADMIN_USER     || 'admin';
const KC_ADMIN_PASSWORD = process.env.KC_ADMIN_PASSWORD || 'admin';
const KC_REALM          = process.env.KC_REALM          || 'kabutare-hospital';

const DRY_RUN   = process.argv.includes('--dry-run');
const outputIdx = process.argv.indexOf('--output');
const OUTPUT    = outputIdx >= 0 ? process.argv[outputIdx + 1] : null;

// ── Auth Keycloak ──────────────────────────────────────────────────────────────

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

// ── Logique de migration ───────────────────────────────────────────────────────

async function findUserByEmail(email) {
  const resp = await kc('GET', `/users?email=${encodeURIComponent(email)}&exact=true`);
  if (!resp.ok) return null;
  const users = await resp.json();
  return users.length > 0 ? users[0] : null;
}

async function getRealmRole(roleName) {
  const resp = await kc('GET', `/roles/${encodeURIComponent(roleName)}`);
  if (!resp.ok) return null;
  return resp.json();
}

async function assignRoles(kcUserId, roleNames) {
  const roles = (await Promise.all(roleNames.map(getRealmRole))).filter(Boolean);
  if (!roles.length) return;
  const r = await kc('POST', `/users/${kcUserId}/role-mappings/realm`, roles);
  if (!r.ok) console.warn(`  ⚠️  Assignation rôles échouée: ${r.status}`);
}

async function migrateUser(u, roles, mapping) {
  const tempPassword = crypto.randomBytes(10).toString('base64url');
  const firstName = u.first_name || (u.name ? u.name.split(' ')[0] : '');
  const lastName  = u.last_name  || (u.name ? u.name.split(' ').slice(1).join(' ') : '');

  console.log(`\n→ Migration de ${u.email} (rôles: ${roles.join(',')})`);

  if (DRY_RUN) {
    console.log('  [DRY-RUN] Aucune modification effectuée.');
    mapping.push({ old_id: u.id, email: u.email, kc_id: 'DRY-RUN', temp_password: tempPassword });
    return;
  }

  // Vérifier si l'utilisateur existe déjà (idempotence)
  let existing = await findUserByEmail(u.email);
  let kcId;

  if (existing) {
    console.log(`  ✓ Utilisateur existant (kcId: ${existing.id}) — mise à jour des attributs.`);
    kcId = existing.id;

    await kc('PUT', `/users/${kcId}`, {
      firstName,
      lastName,
      enabled: u.is_active === 1,
      attributes: {
        department: [u.department || ''],
        legacy_id:  [u.id],
        ...(u.phone ? { phone: [u.phone] } : {}),
      },
    });
  } else {
    const createResp = await kc('POST', '/users', {
      username:   u.email,
      email:      u.email,
      firstName,
      lastName,
      enabled:    u.is_active === 1,
      attributes: {
        department:      [u.department || ''],
        legacy_id:       [u.id],
        ...(u.phone ? { phone: [u.phone] } : {}),
      },
      requiredActions: ['UPDATE_PASSWORD'],
    });

    if (!createResp.ok) {
      const body = await createResp.text();
      console.error(`  ✗ Erreur création: ${createResp.status} ${body}`);
      mapping.push({ old_id: u.id, email: u.email, kc_id: 'ERREUR', temp_password: '' });
      return;
    }

    const location = createResp.headers.get('Location') ?? '';
    kcId = location.split('/').pop();
    console.log(`  ✓ Créé dans Keycloak (kcId: ${kcId})`);

    // Définir le mot de passe temporaire
    const pwdResp = await kc('PUT', `/users/${kcId}/reset-password`, {
      type:      'password',
      value:     tempPassword,
      temporary: true,
    });
    if (!pwdResp.ok) console.warn(`  ⚠️  Set password échoué: ${pwdResp.status}`);
  }

  // Assigner les rôles
  await assignRoles(kcId, roles);
  console.log(`  ✓ Rôles assignés: ${roles.join(', ')}`);

  mapping.push({ old_id: u.id, email: u.email, kc_id: kcId, temp_password: tempPassword });
}

async function migrateUserIds(db, mapping) {
  // Mettre à jour department_change_requests avec les nouveaux IDs Keycloak
  const idMap = new Map(mapping.map((m) => [m.old_id, m.kc_id]));
  const requests = db.prepare("SELECT id, user_id FROM department_change_requests WHERE status = 'pending'").all();
  let updated = 0;
  const stmt = db.prepare('UPDATE department_change_requests SET user_id = ? WHERE id = ?');
  for (const req of requests) {
    const newId = idMap.get(req.user_id);
    if (newId && newId !== 'ERREUR' && newId !== 'DRY-RUN') {
      stmt.run(newId, req.id);
      updated++;
    }
  }
  if (updated > 0) console.log(`\n[Migration] ${updated} demandes de département mises à jour avec les nouveaux IDs Keycloak.`);
}

async function main() {
  console.log('════════════════════════════════════════════════════════');
  console.log(' Migration auth.db → Keycloak');
  console.log(`  DB path  : ${AUTH_DB_PATH}`);
  console.log(`  Keycloak : ${KC_ADMIN_URL}/realms/${KC_REALM}`);
  console.log(DRY_RUN ? '  MODE     : DRY-RUN (aucune modification)' : '  MODE     : LIVE');
  console.log('════════════════════════════════════════════════════════\n');

  if (!fs.existsSync(AUTH_DB_PATH)) {
    console.error(`✗ Base de données introuvable : ${AUTH_DB_PATH}`);
    process.exit(1);
  }

  const db = new Database(AUTH_DB_PATH, { readonly: DRY_RUN });

  // Charger les utilisateurs avec leurs rôles
  const tablesInDb = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map((t) => t.name);
  if (!tablesInDb.includes('users')) {
    console.error('✗ Table `users` introuvable — la migration a peut-être déjà été effectuée.');
    process.exit(1);
  }

  let users;
  if (tablesInDb.includes('user_roles')) {
    users = db.prepare(`
      SELECT u.id, u.name, u.first_name, u.last_name, u.email, u.department,
             u.phone, u.is_active, u.created_at,
             GROUP_CONCAT(ur.role_name) AS roles_csv
        FROM users u
        LEFT JOIN user_roles ur ON ur.user_id = u.id
       GROUP BY u.id
       ORDER BY u.email ASC
    `).all();
  } else {
    // Fallback : colonne `role` legacy
    users = db.prepare('SELECT *, role AS roles_csv FROM users ORDER BY email ASC').all();
  }

  console.log(`Utilisateurs à migrer : ${users.length}`);

  const mapping = [];
  for (const u of users) {
    const roles = u.roles_csv ? u.roles_csv.split(',').filter(Boolean) : ['hospitalStaff'];
    await migrateUser(u, roles, mapping);
  }

  // Mise à jour des IDs dans department_change_requests
  if (!DRY_RUN) await migrateUserIds(db, mapping);

  // Sortie CSV
  const csvLines = ['old_id,email,kc_id,temp_password'];
  for (const m of mapping) {
    csvLines.push(`"${m.old_id}","${m.email}","${m.kc_id}","${m.temp_password}"`);
  }
  const csv = csvLines.join('\n');

  if (OUTPUT) {
    fs.writeFileSync(OUTPUT, csv, 'utf8');
    console.log(`\n[Migration] Résultats écrits dans ${OUTPUT}`);
  } else {
    console.log('\n── Résultats (CSV) ──────────────────────────────────');
    console.log(csv);
  }

  const success = mapping.filter((m) => m.kc_id !== 'ERREUR' && m.kc_id !== 'DRY-RUN').length;
  const errors  = mapping.filter((m) => m.kc_id === 'ERREUR').length;
  console.log(`\n✅ Migration terminée : ${success} succès, ${errors} erreurs.`);
  if (DRY_RUN) console.log('ℹ️  Dry-run : aucune modification n\'a été effectuée.');
}

main().catch((err) => {
  console.error('\n✗ Erreur fatale :', err.message);
  process.exit(1);
});
