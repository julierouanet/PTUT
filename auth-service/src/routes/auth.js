// ── Routes d'authentification ─────────────────────────────────────────────────
// Après migration Keycloak :
//   - Login / refresh / logout : gérés par Keycloak (endpoint OIDC /token)
//   - GET /verify : supprimé (db-service valide le JWT localement via JWKS)
//   - GET /me     : conservé — lit les claims du token + permissions depuis SQLite

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// ── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Retourne l'union des permissions applicatives pour une liste de noms de rôles,
 * en lisant la table `role_permissions` (conservée dans auth.db).
 * @param {import('better-sqlite3').Database} db
 * @param {string[]} roles
 * @returns {string[]}
 */
function getPermissionsForRoles(db, roles) {
  if (!roles || roles.length === 0) return [];
  const placeholders = roles.map(() => '?').join(',');
  return db
    .prepare(`SELECT DISTINCT permission FROM role_permissions WHERE role_name IN (${placeholders}) ORDER BY permission`)
    .all(...roles)
    .map((r) => r.permission);
}

// ── GET /api/auth/me — profil de l'utilisateur connecté ──────────────────────
// Lit les claims du token Keycloak (peuplé par le middleware JWKS) et enrichit
// la réponse avec les permissions applicatives depuis la table role_permissions.
// Conserve le même shape de réponse pour ne pas casser le client Flutter.

router.get('/me', verifyToken, (req, res) => {
  const db          = getDb();
  const permissions = getPermissionsForRoles(db, req.user.roles);

  res.json({
    id:          req.user.id,
    name:        req.user.name,
    first_name:  req.user.given_name  ?? req.user.name.split(' ')[0] ?? '',
    last_name:   req.user.family_name ?? req.user.name.split(' ').slice(1).join(' ') ?? '',
    email:       req.user.email,
    department:  req.user.department,
    phone:       req.user.phone ?? null,
    roles:       req.user.roles,
    permissions,
  });
});

module.exports = router;
