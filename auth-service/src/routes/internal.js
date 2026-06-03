// ── Endpoints internes (service-à-service) ────────────────────────────────────
// Protégés par le header x-internal-secret, jamais exposés au client Flutter.
// Montés sous /internal dans index.js.

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { INTERNAL_SECRET } = require('../config');
const { sendEmail, buildEmailContent } = require('../utils/email_service');
const { kcAdminFetch, mapKcUser } = require('../utils/keycloakAdmin');

const router = express.Router();

// ── Middleware de sécurité interne ────────────────────────────────────────────
function requireInternalSecret(req, res, next) {
  if (req.headers['x-internal-secret'] !== INTERNAL_SECRET) {
    return res.status(403).json({ error: 'Accès non autorisé' });
  }
  next();
}

// ── POST /internal/notifications/send-email ────────────────────────────────────
// Envoie un email à un utilisateur spécifique si ses préférences le permettent.
// Body: { type, to_email, to_name, user_id, payload }
router.post('/notifications/send-email', requireInternalSecret, (req, res) => {
  const { type, to_email, to_name, user_id, payload } = req.body;

  if (!type || !to_email) {
    return res.status(400).json({ error: 'type et to_email sont requis' });
  }

  const db    = getDb();
  // Si user_id fourni : vérifier les préférences ; sinon envoyer par défaut
  const prefs = user_id
    ? db.prepare('SELECT * FROM user_notification_preferences WHERE user_id = ?').get(user_id)
    : null;

  const getPref = (key) => (prefs ? !!prefs[key] : true);

  const shouldSend = (() => {
    switch (type) {
      case 'new_issue':           return getPref('notify_new_issue');
      case 'issue_assigned':      return getPref('notify_issue_assigned');
      case 'issue_resolved':      return getPref('notify_issue_resolved');
      case 'issue_status_update': return getPref('notify_issue_status_update');
      case 'pm_due':              return getPref('notify_pm_due');
      default:                    return false;
    }
  })();

  if (!shouldSend) {
    return res.json({ sent: false, reason: 'preference_disabled' });
  }

  const content = buildEmailContent(type, payload || {});
  if (!content) {
    return res.status(400).json({ error: `Type d'email inconnu: ${type}` });
  }

  // Envoi non-bloquant — la réponse HTTP est renvoyée immédiatement
  sendEmail({ to: to_email, toName: to_name, ...content }).catch(() => {});

  res.json({ sent: true });
});

// ── POST /internal/notifications/send-to-roles ─────────────────────────────────
// Envoie un email à tous les utilisateurs ayant l'un des rôles spécifiés,
// en respectant leurs préférences individuelles.
// Body: { type, roles: string[], payload }
router.post('/notifications/send-to-roles', requireInternalSecret, async (req, res) => {
  const { type, roles, payload } = req.body;

  if (!type || !Array.isArray(roles) || roles.length === 0) {
    return res.status(400).json({ error: 'type et roles[] sont requis' });
  }

  const content = buildEmailContent(type, payload || {});
  if (!content) {
    return res.status(400).json({ error: `Type d'email inconnu: ${type}` });
  }

  // Répondre immédiatement — l'envoi est asynchrone
  res.json({ queued: true });

  // Récupérer les utilisateurs par rôle depuis Keycloak (parallèle)
  setImmediate(async () => {
    try {
      const db = getDb();
      // Dédupliquer les utilisateurs si quelqu'un a plusieurs des rôles cibles
      const seen = new Set();
      for (const role of roles) {
        let kcResp;
        try {
          kcResp = await kcAdminFetch(`/roles/${encodeURIComponent(role)}/users?max=200`);
        } catch (_) { continue; }
        if (!kcResp.ok) continue;

        const users = await kcResp.json().catch(() => []);
        for (const u of users) {
          const email = u.email;
          const kcId  = u.id;
          if (!email || seen.has(kcId)) continue;
          seen.add(kcId);

          // Vérifier les préférences de l'utilisateur
          const prefs = db.prepare(
            'SELECT * FROM user_notification_preferences WHERE user_id = ?'
          ).get(kcId);

          const getPref = (key) => (prefs ? !!prefs[key] : true);
          const shouldSend = (() => {
            switch (type) {
              case 'new_issue':    return getPref('notify_new_issue');
              case 'pm_due':       return getPref('notify_pm_due');
              default:             return getPref('notify_new_issue');
            }
          })();

          if (!shouldSend) continue;

          const name = `${u.firstName || ''} ${u.lastName || ''}`.trim() || email;
          sendEmail({ to: email, toName: name, ...content }).catch(() => {});
        }
      }
    } catch (err) {
      console.error('[INTERNAL] Erreur send-to-roles:', err.message);
    }
  });
});

module.exports = router;
