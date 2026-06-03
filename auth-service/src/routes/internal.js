// ── Endpoints internes (service-à-service) ────────────────────────────────────
// Protégés par le header x-internal-secret, jamais exposés au client Flutter.
// Montés sous /internal dans index.js.
//
// Types d'événements reconnus :
//   critical_new_issue    → techniciens : nouvel incident critique dans leur groupe
//   critical_acknowledged → superviseurs/admins : technicien a pris en charge un critique
//   critical_diagnosed    → superviseurs/admins : diagnostic posé sur un critique
//   critical_resolved     → superviseurs/admins : incident critique résolu (avec KPIs)
//   pm_due                → techniciens/admins  : maintenance préventive à planifier

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { INTERNAL_SECRET } = require('../config');
const { sendEmail, buildEmailContent } = require('../utils/email_service');
const { kcAdminFetch } = require('../utils/keycloakAdmin');

const router = express.Router();

// ── Middleware de sécurité interne ────────────────────────────────────────────
function requireInternalSecret(req, res, next) {
  if (req.headers['x-internal-secret'] !== INTERNAL_SECRET) {
    return res.status(403).json({ error: 'Accès non autorisé' });
  }
  next();
}

// ── Résolution de la colonne préférence selon le type d'événement ─────────────
function _prefColumnFor(type) {
  switch (type) {
    case 'critical_new_issue':    return 'notify_critical_new_issue';
    case 'critical_acknowledged': return 'notify_critical_acknowledged';
    case 'critical_diagnosed':    return 'notify_critical_diagnosed';
    case 'critical_resolved':     return 'notify_critical_resolved';
    case 'pm_due':                return 'notify_pm_due';
    default:                      return null;
  }
}

// ── POST /internal/notifications/send-email ────────────────────────────────────
// Envoie un email à un utilisateur spécifique si ses préférences le permettent.
// Body: { type, to_email, to_name, user_id, payload }
router.post('/notifications/send-email', requireInternalSecret, (req, res) => {
  const { type, to_email, to_name, user_id, payload } = req.body;

  if (!type || !to_email) {
    return res.status(400).json({ error: 'type et to_email sont requis' });
  }

  const prefCol = _prefColumnFor(type);
  if (!prefCol) {
    return res.status(400).json({ error: `Type d'email inconnu: ${type}` });
  }

  const db    = getDb();
  const prefs = user_id
    ? db.prepare('SELECT * FROM user_notification_preferences WHERE user_id = ?').get(user_id)
    : null;

  // Si pas de préférences enregistrées → envoyer par défaut (consentement implicite)
  const shouldSend = prefs ? !!prefs[prefCol] : true;
  if (!shouldSend) {
    return res.json({ sent: false, reason: 'preference_disabled' });
  }

  const content = buildEmailContent(type, payload || {});
  if (!content) {
    return res.status(400).json({ error: `Template introuvable pour: ${type}` });
  }

  // Envoi non-bloquant
  sendEmail({ to: to_email, toName: to_name, ...content }).catch(() => {});
  res.json({ sent: true });
});

// ── POST /internal/notifications/send-to-roles ─────────────────────────────────
// Notifie tous les utilisateurs Keycloak ayant l'un des rôles spécifiés,
// en respectant leurs préférences individuelles.
// Body: { type, roles: string[], payload }
router.post('/notifications/send-to-roles', requireInternalSecret, async (req, res) => {
  const { type, roles, payload } = req.body;

  if (!type || !Array.isArray(roles) || roles.length === 0) {
    return res.status(400).json({ error: 'type et roles[] sont requis' });
  }

  const prefCol = _prefColumnFor(type);
  if (!prefCol) {
    return res.status(400).json({ error: `Type d'email inconnu: ${type}` });
  }

  const content = buildEmailContent(type, payload || {});
  if (!content) {
    return res.status(400).json({ error: `Template introuvable pour: ${type}` });
  }

  // Répondre immédiatement — l'envoi est asynchrone
  res.json({ queued: true });

  // Récupérer les utilisateurs par rôle depuis Keycloak puis vérifier préférences
  setImmediate(async () => {
    try {
      const db   = getDb();
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

          // Vérifier les préférences individuelles
          const prefs = db.prepare(
            'SELECT * FROM user_notification_preferences WHERE user_id = ?'
          ).get(kcId);
          const shouldSend = prefs ? !!prefs[prefCol] : true;
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
