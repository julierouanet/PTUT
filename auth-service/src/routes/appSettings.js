// ── Routes Paramètres Application ─────────────────────────────────────────────
// Permet à l'admin de piloter contact de connexion et config Brevo via l'UI.
// La table `app_settings` est dans auth.db (clé/valeur, certaines secrètes).

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { sendLog, reqMeta } = require('../utils/logger');
const { sendEmail } = require('../utils/email_service');

const router = express.Router();

// Clés exposées publiquement (sans auth) — jamais de clés secrètes ici
const PUBLIC_KEYS = ['login_contact_title', 'login_contact_email', 'login_contact_phone'];

// Toutes les clés gérées — toute autre clé est rejetée en 400
const ALL_KEYS = [
  'login_contact_title',
  'login_contact_email',
  'login_contact_phone',
  'brevo_api_key',
  'brevo_sender_email',
  'brevo_sender_name',
];

// ── GET /api/app-settings/public ──────────────────────────────────────────────
// Route publique : pas d'auth. Renvoie uniquement les clés de contact.
router.get('/public', (req, res) => {
  try {
    const db = getDb();
    const rows = db.prepare(
      `SELECT key, value FROM app_settings WHERE key IN (${PUBLIC_KEYS.map(() => '?').join(',')})`
    ).all(...PUBLIC_KEYS);

    const result = {};
    for (const key of PUBLIC_KEYS) result[key] = '';
    for (const row of rows) result[row.key] = row.value || '';

    res.json(result);
  } catch (err) {
    console.error('[SETTINGS] Erreur GET /public:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

/** Formate une ligne app_settings pour la réponse admin (masque les secrets). */
function _formatRow(row) {
  if (row.is_secret) {
    const hint = row.value && row.value.length >= 4
      ? row.value.slice(-4)
      : null;
    return {
      key:        row.key,
      is_secret:  true,
      configured: !!(row.value && row.value.length > 0),
      hint,
    };
  }
  return { key: row.key, value: row.value || '', is_secret: false };
}

// ── GET /api/app-settings ──────────────────────────────────────────────────────
// Admin : renvoie toutes les clés. Les secrets sont masqués (configured + hint).
router.get('/', verifyToken, requireAdmin, (req, res) => {
  try {
    const db   = getDb();
    const rows = db.prepare('SELECT key, value, is_secret FROM app_settings ORDER BY key').all();
    res.json(rows.map(_formatRow));
  } catch (err) {
    console.error('[SETTINGS] Erreur GET /app-settings:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── PUT /api/app-settings ──────────────────────────────────────────────────────
// Admin : met à jour un ou plusieurs paramètres en transaction.
// Règle secret : '' = inchangé ; '__CLEAR__' = vider ; autre = écrire.
router.put('/', verifyToken, requireAdmin, (req, res) => {
  const { settings } = req.body;

  if (!settings || typeof settings !== 'object' || Array.isArray(settings)) {
    return res.status(400).json({ error: 'Champ settings (objet) requis' });
  }

  const keys = Object.keys(settings);
  if (keys.length === 0) return res.status(400).json({ error: 'Aucune clé fournie' });

  // Valider que toutes les clés sont connues
  const unknownKeys = keys.filter(k => !ALL_KEYS.includes(k));
  if (unknownKeys.length > 0) {
    return res.status(400).json({ error: `Clé(s) inconnue(s) : ${unknownKeys.join(', ')}` });
  }

  const db = getDb();

  try {
    const updatedKeys  = [];
    const existingStmt = db.prepare('SELECT is_secret FROM app_settings WHERE key = ?');
    const updateStmt   = db.prepare(
      `UPDATE app_settings
       SET value = ?, updated_at = datetime('now','localtime'), updated_by = ?
       WHERE key = ?`
    );

    const transaction = db.transaction(() => {
      for (const key of keys) {
        const raw      = settings[key];
        const existing = existingStmt.get(key);
        if (!existing) continue;

        // Clé secrète : vide/undefined/null = inchangé (ne pas écraser)
        if (existing.is_secret && (raw === '' || raw === undefined || raw === null)) continue;

        const newVal = raw === '__CLEAR__' ? '' : (raw || '');
        updateStmt.run(newVal, req.user.id, key);
        updatedKeys.push(key);
      }
    });

    transaction();

    if (updatedKeys.length > 0) {
      sendLog({
        user_id:     req.user.id,
        user_name:   req.user.name,
        user_role:   req.user.roles[0],
        action:      'update_app_settings',
        target_type: 'app_settings',
        target_id:   'app_settings',
        target_name: 'Paramètres application',
        details:     JSON.stringify({ updated_keys: updatedKeys }),
        ...reqMeta(req),
      });
    }

    // Renvoyer l'état complet mis à jour (même format que le GET admin)
    const rows = db.prepare('SELECT key, value, is_secret FROM app_settings ORDER BY key').all();
    res.json(rows.map(_formatRow));
  } catch (err) {
    console.error('[SETTINGS] Erreur PUT /app-settings:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── POST /api/app-settings/test-email ─────────────────────────────────────────
// Admin : envoie un email de test avec la configuration Brevo actuelle.
router.post('/test-email', verifyToken, requireAdmin, async (req, res) => {
  const { to_email } = req.body;

  if (!to_email || typeof to_email !== 'string') {
    return res.status(400).json({ error: 'Champ to_email requis' });
  }
  // Validation basique de l'email
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to_email)) {
    return res.status(400).json({ error: 'Adresse email invalide' });
  }

  const subject     = '✅ Test de configuration Brevo — GMAO Kabutare';
  const htmlContent = `
    <div style="font-family:Arial,sans-serif;max-width:600px;color:#212121">
      <div style="background:#388E3C;padding:16px 24px;border-radius:6px 6px 0 0">
        <h2 style="color:#fff;margin:0;font-size:18px">✅ Email de test — GMAO Kabutare</h2>
      </div>
      <div style="border:1px solid #e0e0e0;border-top:none;border-radius:0 0 6px 6px;padding:20px 24px">
        <p style="font-size:14px">
          La configuration Brevo est opérationnelle. Les emails de notification
          seront envoyés via ce compte expéditeur.
        </p>
        <p style="font-size:12px;color:#757575">
          Envoyé depuis l'interface « Paramètres application » par <strong>${req.user.name || req.user.id}</strong>.
        </p>
      </div>
      <hr style="margin-top:28px;border:none;border-top:1px solid #e0e0e0">
      <p style="color:#757575;font-size:11px;margin:8px 0 0">
        GMAO — Hôpital de District de Kabutare · Rwanda<br>
        Cet email est envoyé automatiquement — merci de ne pas y répondre.
      </p>
    </div>
  `;

  try {
    await sendEmail({ to: to_email, subject, htmlContent });

    sendLog({
      user_id:     req.user.id,
      user_name:   req.user.name,
      user_role:   req.user.roles[0],
      action:      'test_email_sent',
      target_type: 'app_settings',
      target_id:   'brevo_config',
      target_name: 'Test email Brevo',
      details:     JSON.stringify({ to: to_email }),
      ...reqMeta(req),
    });

    res.json({ sent: true });
  } catch (err) {
    console.error('[SETTINGS] Erreur POST /test-email:', err.message);
    res.status(500).json({ sent: false, error: err.message });
  }
});

module.exports = router;
