// ── Routes : Web Push Notifications ──────────────────────────────────────────
const express = require('express');
const { getDb }  = require('../database');
const { verifyToken } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const config = require('../config');

const router = express.Router();

const rolesCsv = (req) =>
  (Array.isArray(req.user?.roles) ? req.user.roles : [])
    .filter((r) => !['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital'].includes(r))
    .join(',');

// ── GET /api/notifications/vapid-key ─────────────────────────────────────────
// Public — renvoie la clé publique VAPID pour que le frontend puisse s'abonner.
router.get('/vapid-key', (req, res) => {
  if (!config.VAPID_PUBLIC_KEY) {
    return res.status(503).json({ error: 'Web Push non configuré sur ce serveur' });
  }
  res.json({ publicKey: config.VAPID_PUBLIC_KEY });
});

// ── POST /api/notifications/subscribe ────────────────────────────────────────
// Enregistre (ou met à jour) la souscription push de l'utilisateur connecté.
// Body : { endpoint, keys: { p256dh, auth } }
router.post('/subscribe', verifyToken, (req, res) => {
  const { endpoint, keys } = req.body;

  if (!endpoint || !keys?.p256dh || !keys?.auth) {
    return res.status(400).json({ error: 'endpoint, keys.p256dh et keys.auth sont requis' });
  }
  if (typeof endpoint !== 'string' || endpoint.length > 2000) {
    return res.status(400).json({ error: 'endpoint invalide' });
  }

  const db     = getDb();
  const userId = req.user.id;
  const roles  = rolesCsv(req);

  try {
    db.prepare(`
      INSERT INTO push_subscriptions (user_id, endpoint, p256dh, auth, user_roles)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(endpoint) DO UPDATE SET
        user_id    = excluded.user_id,
        p256dh     = excluded.p256dh,
        auth       = excluded.auth,
        user_roles = excluded.user_roles,
        created_at = datetime('now','localtime')
    `).run(userId, endpoint, keys.p256dh, keys.auth, roles);

    logAction({
      user_id: userId, user_name: req.user.name, user_role: roles,
      action: 'push_subscribe', target_type: 'push_subscription',
      target_id: userId, target_name: req.user.email || userId,
      details: { endpoint: endpoint.substring(0, 80) },
      ...extractReqMeta(req),
    });

    res.status(201).json({ message: 'Souscription enregistrée' });
  } catch (err) {
    console.error('[PUSH] Erreur subscribe :', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/notifications/unsubscribe ──────────────────────────────────────
// Supprime la souscription push de l'utilisateur connecté pour cet endpoint.
// Body : { endpoint }  (optionnel — si absent, supprime toutes les souscriptions)
router.post('/unsubscribe', verifyToken, (req, res) => {
  const db     = getDb();
  const userId = req.user.id;
  const { endpoint } = req.body;

  try {
    if (endpoint) {
      db.prepare('DELETE FROM push_subscriptions WHERE user_id = ? AND endpoint = ?').run(userId, endpoint);
    } else {
      // Logout sans endpoint connu → on purge toutes les souscriptions de l'utilisateur
      db.prepare('DELETE FROM push_subscriptions WHERE user_id = ?').run(userId);
    }

    logAction({
      user_id: userId, user_name: req.user.name, user_role: rolesCsv(req),
      action: 'push_unsubscribe', target_type: 'push_subscription',
      target_id: userId, target_name: req.user.email || userId,
      details: { endpoint: endpoint ? endpoint.substring(0, 80) : 'all' },
      ...extractReqMeta(req),
    });

    res.json({ message: 'Souscription supprimée' });
  } catch (err) {
    console.error('[PUSH] Erreur unsubscribe :', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
