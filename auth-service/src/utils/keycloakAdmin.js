// ── Utilitaire Keycloak Admin REST API ────────────────────────────────────────
// Gère le token de service account (client_credentials) avec cache automatique.
// Utiliser kcAdminFetch(path, options) pour tous les appels à l'Admin API.

'use strict';

const { KC_ADMIN_URL, KC_REALM, KC_CLIENT_ID, KC_CLIENT_SECRET } = require('../config');

let _token     = null;
let _expiresAt = 0;

async function getAdminToken() {
  if (_token && Date.now() < _expiresAt - 30_000) return _token;

  const resp = await fetch(
    `${KC_ADMIN_URL}/realms/${KC_REALM}/protocol/openid-connect/token`,
    {
      method:  'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body:    new URLSearchParams({
        grant_type:    'client_credentials',
        client_id:     KC_CLIENT_ID,
        client_secret: KC_CLIENT_SECRET,
      }),
    },
  );

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`[KC Admin] Échec obtention token service account : ${resp.status} ${text}`);
  }

  const data   = await resp.json();
  _token       = data.access_token;
  _expiresAt   = Date.now() + data.expires_in * 1000;
  return _token;
}

async function kcAdminFetch(path, options = {}) {
  const token = await getAdminToken();
  const url   = `${KC_ADMIN_URL}/admin/realms/${KC_REALM}${path}`;

  const resp = await fetch(url, {
    ...options,
    headers: {
      Authorization:  `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  return resp;
}

// ── Helpers métier ─────────────────────────────────────────────────────────────

// Récupère l'objet rôle Keycloak par nom (nécessaire pour assigner un rôle à un user)
async function getRealmRole(roleName) {
  const resp = await kcAdminFetch(`/roles/${encodeURIComponent(roleName)}`);
  if (!resp.ok) return null;
  return resp.json();
}

// Assigne une liste de rôles (strings) à un utilisateur Keycloak
async function assignRolesToUser(kcUserId, roleNames) {
  const roleObjects = (await Promise.all(roleNames.map(getRealmRole))).filter(Boolean);
  if (!roleObjects.length) return;
  const r = await kcAdminFetch(`/users/${kcUserId}/role-mappings/realm`, {
    method: 'POST',
    body:   JSON.stringify(roleObjects),
  });
  if (!r.ok) throw new Error(`[KC Admin] Assignation rôles échouée : ${r.status}`);
}

// Retire une liste de rôles (strings) d'un utilisateur Keycloak
async function removeRolesFromUser(kcUserId, roleNames) {
  const roleObjects = (await Promise.all(roleNames.map(getRealmRole))).filter(Boolean);
  if (!roleObjects.length) return;
  const r = await kcAdminFetch(`/users/${kcUserId}/role-mappings/realm`, {
    method: 'DELETE',
    body:   JSON.stringify(roleObjects),
  });
  if (!r.ok) throw new Error(`[KC Admin] Retrait rôles échoué : ${r.status}`);
}

// Récupère les rôles de realm d'un utilisateur (filtre les rôles système)
const SYSTEM_ROLES = new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']);

async function getUserRoleNames(kcUserId) {
  const resp = await kcAdminFetch(`/users/${kcUserId}/role-mappings/realm`);
  if (!resp.ok) return [];
  const roles = await resp.json();
  return roles.map((r) => r.name).filter((n) => !SYSTEM_ROLES.has(n));
}

// Normalise un objet utilisateur Keycloak vers le shape attendu par le frontend Flutter
function mapKcUser(u, roles = []) {
  const firstName = u.firstName ?? '';
  const lastName  = u.lastName  ?? '';
  return {
    id:         u.id,
    name:       `${firstName} ${lastName}`.trim() || u.username,
    first_name: firstName,
    last_name:  lastName,
    email:      u.email || u.username,
    department: u.attributes?.department?.[0] ?? '',
    phone:      u.attributes?.phone?.[0]       ?? null,
    is_active:  u.enabled ? 1 : 0,
    created_at: u.createdTimestamp
      ? new Date(u.createdTimestamp).toISOString()
      : '',
    roles,
  };
}

module.exports = {
  kcAdminFetch,
  getRealmRole,
  assignRolesToUser,
  removeRolesFromUser,
  getUserRoleNames,
  mapKcUser,
  SYSTEM_ROLES,
};
