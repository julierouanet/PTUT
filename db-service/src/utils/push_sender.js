// ── Utilitaire d'envoi Web Push ───────────────────────────────────────────────
const webpush = require('web-push');
const { VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_CONTACT } = require('../config');
const { getDb } = require('../database');

// Initialisation lazy : évite le crash si les clés VAPID sont absentes (tests).
let initialized = false;
function ensureInit() {
  if (initialized || !VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) return;
  webpush.setVapidDetails(VAPID_CONTACT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
  initialized = true;
}

/**
 * Envoie une notification push à tous les endpoints d'un utilisateur donné.
 * @param {string} userId  - ID Keycloak de l'utilisateur cible
 * @param {object} payload - { title, body, icon?, data? }
 */
async function sendPushToUser(userId, payload) {
  ensureInit();
  if (!initialized) return;
  const db  = getDb();
  const subs = db.prepare('SELECT * FROM push_subscriptions WHERE user_id = ?').all(userId);
  await _sendToSubs(subs, payload);
}

/**
 * Envoie une notification push à tous les abonnés ayant au moins un des rôles listés.
 * @param {string[]} roles   - Ex : ['technician_biomedical']
 * @param {object}   payload - { title, body, icon?, data? }
 */
async function sendPushToRoles(roles, payload) {
  ensureInit();
  if (!initialized || !roles.length) return;
  const db  = getDb();
  const all = db.prepare('SELECT * FROM push_subscriptions').all();
  // user_roles est stocké en CSV (ex : "technician_biomedical,supervisor")
  const targets = all.filter(
    (s) => s.user_roles && roles.some((r) => s.user_roles.split(',').includes(r))
  );
  await _sendToSubs(targets, payload);
}

async function _sendToSubs(subs, payload) {
  if (!subs.length) return;
  const db           = getDb();
  const notification = JSON.stringify(payload);
  await Promise.allSettled(
    subs.map(async (sub) => {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          notification
        );
      } catch (err) {
        if (err.statusCode === 410 || err.statusCode === 404) {
          // Endpoint expiré ou invalide → supprimer proprement
          db.prepare('DELETE FROM push_subscriptions WHERE endpoint = ?').run(sub.endpoint);
          console.log(`[PUSH] Souscription expirée supprimée : ${sub.endpoint.substring(0, 70)}…`);
        } else {
          console.error(`[PUSH] Erreur envoi (${err.statusCode || '?'}) : ${err.message}`);
        }
      }
    })
  );
}

module.exports = { sendPushToUser, sendPushToRoles };
