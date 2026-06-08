// ── Routes : Web Push Notifications ──────────────────────────────────────────
const express = require('express');
const { getDb }  = require('../database');
const { verifyToken } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');
const { rolesCsv } = require('../utils/roles');
const config = require('../config');

const router = express.Router();

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

// ── GET /api/notifications ─────────────────────────────────────────────────────
// Retourne les notifications in-app de l'utilisateur connecté (+ broadcasts par rôle)
router.get('/', verifyToken, (req, res) => {
  const db      = getDb();
  const userId  = req.user.id;
  const roles   = req.user.roles || [];
  const { unread_only, limit = 50 } = req.query;

  try {
    // Construit la liste de paramètres : userId + un paramètre par rôle + limit
    const rolePlaceholders = roles.map(() => '?').join(',') || "''";
    const unreadClause = unread_only === 'true' ? 'AND is_read = 0' : '';

    const rows = db.prepare(`
      SELECT * FROM notifications
      WHERE (user_id = ? OR role IN (${rolePlaceholders}))
      ${unreadClause}
      ORDER BY created_at DESC
      LIMIT ?
    `).all(userId, ...roles, Number(limit));

    res.json(rows);
  } catch (err) {
    console.error('[notifications/get] Erreur:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── PATCH /api/notifications/read-all ─────────────────────────────────────────
// Marque toutes les notifications non lues de l'utilisateur comme lues
router.patch('/read-all', verifyToken, (req, res) => {
  const db     = getDb();
  const userId = req.user.id;

  try {
    db.prepare(`UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0`).run(userId);

    logAction({
      user_id: userId, user_name: req.user.name, user_role: req.user.roles?.[0] || '',
      action: 'notifications_mark_all_read', target_type: 'notifications',
      target_id: null, target_name: userId,
      details: JSON.stringify({ note: 'Toutes les notifications marquées comme lues' }),
      ...extractReqMeta(req),
    });

    res.json({ message: 'Toutes les notifications marquées comme lues' });
  } catch (err) {
    console.error('[notifications/read-all] Erreur:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── PATCH /api/notifications/:id/read ─────────────────────────────────────────
// Marque une notification spécifique comme lue
router.patch('/:id/read', verifyToken, (req, res) => {
  const db     = getDb();
  const { id } = req.params;
  const userId = req.user.id;

  const notif = db.prepare('SELECT * FROM notifications WHERE id = ?').get(id);
  if (!notif) return res.status(404).json({ error: 'Notification introuvable' });

  try {
    db.prepare('UPDATE notifications SET is_read = 1 WHERE id = ?').run(id);
    res.json({ message: 'Notification marquée comme lue' });
  } catch (err) {
    console.error('[notifications/:id/read] Erreur:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
