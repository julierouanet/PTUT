// ── Routes d'authentification ─────────────────────────────────────────────────
// Après migration Keycloak :
//   - Login / refresh / logout : gérés par Keycloak (endpoint OIDC /token)
//   - GET /verify : supprimé (db-service valide le JWT localement via JWKS)
//   - GET /me     : conservé — lit les claims du token + permissions depuis SQLite

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');
const { kcAdminFetch, assignRolesToUser } = require('../utils/keycloakAdmin');
const { sendLog, reqMeta } = require('../utils/logger');

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
    id:             req.user.id,
    name:           req.user.name,
    first_name:     req.user.given_name  ?? req.user.name.split(' ')[0] ?? '',
    last_name:      req.user.family_name ?? req.user.name.split(' ').slice(1).join(' ') ?? '',
    email:          req.user.email,
    email_verified: req.user.email_verified,
    department:     req.user.department,
    phone:          req.user.phone ?? null,
    roles:          req.user.roles,
    permissions,
  });
});

// ── POST /api/auth/register — inscription libre ───────────────────────────────
// Endpoint public : crée un compte via l'Admin API Keycloak, assigne hospitalStaff,
// force VERIFY_EMAIL et envoie l'email de vérification immédiatement.
router.post('/register', async (req, res) => {
  const { first_name, last_name, email, password, department, phone } = req.body;

  if (!first_name || !last_name || !email || !password || !department) {
    return res.status(400).json({ error: 'Champs requis : first_name, last_name, email, password, department' });
  }
  if (typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ error: 'Mot de passe trop court (minimum 8 caractères)' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Adresse email invalide' });
  }

  try {
    const createResp = await kcAdminFetch('/users', {
      method: 'POST',
      body: JSON.stringify({
        username:        email,
        email,
        firstName:       first_name,
        lastName:        last_name,
        enabled:         true,
        emailVerified:   false,
        requiredActions: ['VERIFY_EMAIL'],
        attributes: {
          department: [department],
          ...(phone ? { phone: [phone] } : {}),
        },
      }),
    });

    if (createResp.status === 409) return res.status(409).json({ error: 'Email déjà utilisé' });
    if (!createResp.ok) {
      const t = await createResp.text();
      console.error('[AUTH] Keycloak register error:', t);
      return res.status(502).json({ error: 'Erreur lors de la création du compte' });
    }

    const kcId = (createResp.headers.get('Location') ?? '').split('/').pop();

    await kcAdminFetch(`/users/${kcId}/reset-password`, {
      method: 'PUT',
      body: JSON.stringify({ type: 'password', value: password, temporary: false }),
    });

    await assignRolesToUser(kcId, ['hospitalStaff']);

    // Envoi immédiat de l'email de vérification (fire-and-forget)
    kcAdminFetch(`/users/${kcId}/send-verify-email`, { method: 'PUT' }).catch((err) => {
      console.error('[AUTH] Envoi email vérification échoué:', err.message);
    });

    sendLog({
      user_id:     kcId,
      user_name:   `${first_name} ${last_name}`.trim(),
      user_role:   'hospitalStaff',
      action:      'self_register',
      target_type: 'user',
      target_id:   kcId,
      target_name: `${first_name} ${last_name}`.trim(),
      details:     { email, department },
      ...reqMeta(req),
    });

    res.status(201).json({
      id:      kcId,
      message: 'Compte créé. Vérifiez votre email pour activer votre compte.',
    });
  } catch (err) {
    console.error('[AUTH] Erreur POST /register:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── POST /api/auth/forgot-password ────────────────────────────────────────────
// Endpoint public : déclenche un email de reset via l'Admin API Keycloak.
// Répond toujours 200 pour éviter l'énumération d'emails (timing attack).
router.post('/forgot-password', (req, res) => {
  res.json({ message: 'Si cet email existe, un lien de réinitialisation vous a été envoyé.' });

  const { email } = req.body;
  if (!email || typeof email !== 'string' || !email.trim()) return;

  (async () => {
    try {
      const searchResp = await kcAdminFetch(`/users?email=${encodeURIComponent(email.trim())}&exact=true`);
      if (!searchResp.ok) return;
      const users = await searchResp.json();
      if (!users.length) return;

      await kcAdminFetch(`/users/${users[0].id}/execute-actions-email`, {
        method: 'PUT',
        body:   JSON.stringify(['UPDATE_PASSWORD']),
      });
    } catch (err) {
      console.error('[AUTH] Erreur forgot-password:', err.message);
    }
  })();
});

// ── POST /api/auth/access-request ─────────────────────────────────────────────
// Endpoint public : enregistre une demande d'accès soumise depuis l'écran de connexion.
// Aucune authentification requise — la demande est stockée en DB pour traitement admin.
router.post('/access-request', (req, res) => {
  const { first_name, last_name, email, department, role } = req.body;

  if (!first_name || !last_name || !email) {
    return res.status(400).json({ error: 'Champs requis : first_name, last_name, email' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email))) {
    return res.status(400).json({ error: 'Adresse email invalide' });
  }

  const db = getDb();
  db.prepare(
    `INSERT INTO access_requests (first_name, last_name, email, department, role)
     VALUES (?, ?, ?, ?, ?)`
  ).run(
    String(first_name).trim(),
    String(last_name).trim(),
    String(email).trim().toLowerCase(),
    department ? String(department).trim() : null,
    role       ? String(role).trim()       : null,
  );

  console.log(`[AUTH] Demande d'accès enregistrée : ${String(email).trim().toLowerCase()}`);
  res.status(201).json({ message: 'Demande enregistrée. Un administrateur vous contactera.' });
});

module.exports = router;
