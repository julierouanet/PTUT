#!/usr/bin/env node
// ── Script d'initialisation idempotent du realm Keycloak ─────────────────────
// Usage : node scripts/keycloak-init.js
// Variables d'environnement requises :
//   KC_ADMIN_URL  (ex: http://localhost:8080 ou https://keycloak.lucaslopvet.fr)
//   KC_ADMIN_USER (ex: kcadmin)
//   KC_ADMIN_PASSWORD
//   KC_CLIENT_SECRET_AUTH  (secret du client auth-service)

'use strict';

const KC_ADMIN_URL      = process.env.KC_ADMIN_URL      || 'http://localhost:8080';
const KC_ADMIN_USER     = process.env.KC_ADMIN_USER     || 'admin';
const KC_ADMIN_PASSWORD = process.env.KC_ADMIN_PASSWORD || 'admin';
const KC_CLIENT_SECRET  = process.env.KC_CLIENT_SECRET_AUTH || 'changeme-auth-service-secret';
const REALM             = 'kabutare-hospital';

const ROLES = [
  'hospitalStaff',
  'supervisor',
  'technician',
  'technician_biomedical',
  'technician_it',
  'technician_infra',
  'admin',
];

// ── Helpers HTTP ───────────────────────────────────────────────────────────────

async function masterToken() {
  const resp = await fetch(`${KC_ADMIN_URL}/realms/master/protocol/openid-connect/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'password',
      client_id:  'admin-cli',
      username:   KC_ADMIN_USER,
      password:   KC_ADMIN_PASSWORD,
    }),
  });
  if (!resp.ok) throw new Error(`[init] Échec authentification admin Keycloak : ${resp.status} ${await resp.text()}`);
  return (await resp.json()).access_token;
}

async function kc(token, method, path, body) {
  const resp = await fetch(`${KC_ADMIN_URL}/admin/realms${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  return resp;
}

async function exists(token, path) {
  const resp = await kc(token, 'GET', path);
  return resp.ok;
}

// ── Création / vérification du realm ──────────────────────────────────────────

async function ensureRealm(token) {
  const resp = await kc(token, 'GET', `/${REALM}`);
  if (resp.ok) {
    console.log(`[init] Realm "${REALM}" déjà présent.`);
    return;
  }
  const r = await fetch(`${KC_ADMIN_URL}/admin/realms`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      realm:                    REALM,
      enabled:                  true,
      displayName:              'Hôpital de Kabutare',
      accessTokenLifespan:      900,       // 15 min
      ssoSessionIdleTimeout:    604800,    // 7 jours
      ssoSessionMaxLifespan:    2592000,   // 30 jours
      refreshTokenMaxReuse:     0,
      revokeRefreshToken:       true,      // rotation stricte des refresh tokens
      bruteForceProtected:      true,
      loginWithEmailAllowed:    true,
      duplicateEmailsAllowed:   false,
      resetPasswordAllowed:     true,
      editUsernameAllowed:      false,
      sslRequired:              'external',
    }),
  });
  if (!r.ok) throw new Error(`[init] Création realm échouée : ${r.status} ${await r.text()}`);
  console.log(`[init] Realm "${REALM}" créé.`);
}

// ── Rôles de realm ─────────────────────────────────────────────────────────────

async function ensureRoles(token) {
  for (const name of ROLES) {
    const resp = await kc(token, 'GET', `/${REALM}/roles/${name}`);
    if (resp.ok) {
      console.log(`[init] Rôle "${name}" déjà présent.`);
      continue;
    }
    const r = await kc(token, 'POST', `/${REALM}/roles`, {
      name,
      description: name === 'technician' ? 'Déprécié — conservé pour compatibilité' : '',
    });
    if (!r.ok) throw new Error(`[init] Création rôle "${name}" échouée : ${r.status}`);
    console.log(`[init] Rôle "${name}" créé.`);
  }
}

// ── Clients ────────────────────────────────────────────────────────────────────

async function ensureClient(token, clientDef) {
  const listResp = await kc(token, 'GET', `/${REALM}/clients?clientId=${encodeURIComponent(clientDef.clientId)}`);
  const list = await listResp.json();
  if (list.length > 0) {
    const existingId = list[0].id;
    console.log(`[init] Client "${clientDef.clientId}" déjà présent (id: ${existingId}).`);
    // Mettre à jour le secret et la config si le client est confidentiel avec service account
    if (clientDef.secret) {
      const r = await kc(token, 'PUT', `/${REALM}/clients/${existingId}`, { ...clientDef, id: existingId });
      if (!r.ok) console.warn(`[init] Mise à jour client "${clientDef.clientId}" échouée : ${r.status}`);
      else console.log(`[init] Client "${clientDef.clientId}" mis à jour (secret synchronisé).`);
    }
    return existingId;
  }
  const r = await kc(token, 'POST', `/${REALM}/clients`, clientDef);
  if (!r.ok) throw new Error(`[init] Création client "${clientDef.clientId}" échouée : ${r.status} ${await r.text()}`);
  const location = r.headers.get('Location');
  const id = location.split('/').pop();
  console.log(`[init] Client "${clientDef.clientId}" créé (id: ${id}).`);
  return id;
}

async function ensureClients(token) {
  // ── flutter-app : public, Direct Grant activé ──────────────────────────────
  const flutterClientId = await ensureClient(token, {
    clientId:                  'flutter-app',
    name:                      'Application Flutter Hôpital de Kabutare',
    enabled:                   true,
    publicClient:              true,
    directAccessGrantsEnabled: true,  // Direct Grant (ROPC)
    standardFlowEnabled:       true,
    implicitFlowEnabled:       false,
    serviceAccountsEnabled:    false,
    redirectUris: [
      'https://app.lucaslopvet.fr/*',
      'https://dev.app.lucaslopvet.fr/*',
      'http://localhost:*/*',
    ],
    webOrigins: [
      'https://app.lucaslopvet.fr',
      'https://dev.app.lucaslopvet.fr',
      'http://localhost',
    ],
  });

  // Protocol mapper : attribut department → claim
  await ensureDepartmentMapper(token, flutterClientId);

  // ── auth-service : confidential, service account pour Admin API ────────────
  const authClientId = await ensureClient(token, {
    clientId:                  'auth-service',
    name:                      'Auth Service — proxy Admin API',
    enabled:                   true,
    publicClient:              false,
    secret:                    KC_CLIENT_SECRET,
    directAccessGrantsEnabled: false,
    standardFlowEnabled:       false,
    serviceAccountsEnabled:    true,
  });

  // Assigner les rôles realm-management au service account
  await assignRealmManagementRoles(token, authClientId);
  await ensureDepartmentMapper(token, authClientId);

  // ── db-service : bearer-only ───────────────────────────────────────────────
  await ensureClient(token, {
    clientId:                  'db-service',
    name:                      'DB Service — resource server',
    enabled:                   true,
    publicClient:              false,
    bearerOnly:                true,
    directAccessGrantsEnabled: false,
    standardFlowEnabled:       false,
    serviceAccountsEnabled:    false,
  });
}

// ── Protocol mapper : attribut utilisateur "department" → claim JWT ────────────

async function ensureDepartmentMapper(token, clientId) {
  const mappersResp = await kc(token, 'GET', `/${REALM}/clients/${clientId}/protocol-mappers/models`);
  if (!mappersResp.ok) return;
  const mappers = await mappersResp.json();
  if (mappers.some((m) => m.name === 'department')) {
    console.log(`[init] Mapper "department" déjà présent sur client ${clientId}.`);
    return;
  }
  const r = await kc(token, 'POST', `/${REALM}/clients/${clientId}/protocol-mappers/models`, {
    name:           'department',
    protocol:       'openid-connect',
    protocolMapper: 'oidc-usermodel-attribute-mapper',
    config: {
      'user.attribute':         'department',
      'claim.name':             'department',
      'jsonType.label':         'String',
      'id.token.claim':         'true',
      'access.token.claim':     'true',
      'userinfo.token.claim':   'true',
      'multivalued':            'false',
      'aggregate.attrs':        'false',
    },
  });
  if (!r.ok) console.warn(`[init] Mapper "department" création échouée : ${r.status}`);
  else console.log(`[init] Mapper "department" créé sur client ${clientId}.`);
}

// ── Rôles Admin API pour le service account auth-service ──────────────────────

async function assignRealmManagementRoles(token, authServiceClientId) {
  // Trouver l'id du client realm-management
  const rmResp = await kc(token, 'GET', `/${REALM}/clients?clientId=realm-management`);
  const rmList = await rmResp.json();
  if (!rmList.length) { console.warn('[init] Client realm-management introuvable.'); return; }
  const rmId = rmList[0].id;

  const neededRoles = ['manage-users', 'manage-realm', 'query-realms', 'view-users', 'query-users'];

  // Rôles déjà assignés au service account
  const saResp = await kc(token, 'GET', `/${REALM}/clients/${authServiceClientId}/service-account-user`);
  if (!saResp.ok) { console.warn('[init] Impossible de récupérer le service account.'); return; }
  const saUser = await saResp.json();

  const assignedResp = await kc(token, 'GET', `/${REALM}/users/${saUser.id}/role-mappings/clients/${rmId}`);
  const assigned = assignedResp.ok ? await assignedResp.json() : [];
  const assignedNames = new Set(assigned.map((r) => r.name));

  // Récupérer les objets rôle pour ceux qui manquent
  const toAssign = [];
  for (const roleName of neededRoles) {
    if (assignedNames.has(roleName)) continue;
    const rResp = await kc(token, 'GET', `/${REALM}/clients/${rmId}/roles/${roleName}`);
    if (rResp.ok) toAssign.push(await rResp.json());
  }

  if (!toAssign.length) { console.log('[init] Rôles realm-management déjà assignés.'); return; }

  const r = await kc(token, 'POST', `/${REALM}/users/${saUser.id}/role-mappings/clients/${rmId}`, toAssign);
  if (!r.ok) console.warn(`[init] Assignation rôles realm-management échouée : ${r.status}`);
  else console.log(`[init] Rôles realm-management assignés : ${toAssign.map((r) => r.name).join(', ')}.`);
}

// ── Point d'entrée ─────────────────────────────────────────────────────────────

async function main() {
  console.log(`[init] Connexion à Keycloak : ${KC_ADMIN_URL}`);
  const token = await masterToken();

  await ensureRealm(token);
  await ensureRoles(token);
  await ensureClients(token);

  console.log('\n[init] ✅ Initialisation du realm terminée.');
  console.log(`[init] JWKS URI : ${KC_ADMIN_URL}/realms/${REALM}/protocol/openid-connect/certs`);
  console.log(`[init] Token URL: ${KC_ADMIN_URL}/realms/${REALM}/protocol/openid-connect/token`);
}

main().catch((err) => {
  console.error('[init] ❌', err.message);
  process.exit(1);
});
