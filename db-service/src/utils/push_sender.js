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

const emptyResult = () => ({ attempted: 0, succeeded: 0, failed: 0, expired: 0 });

/**
 * Envoie une notification push à tous les endpoints d'un utilisateur donné.
 * @param {string} userId  - ID Keycloak de l'utilisateur cible
 * @param {object} payload - { title, body, icon?, data? }
 */
async function sendPushToUser(userId, payload) {
  ensureInit();
  if (!initialized) return emptyResult();
  const db  = getDb();
  const subs = db.prepare('SELECT * FROM push_subscriptions WHERE user_id = ?').all(userId);
  return await _sendToSubs(subs, payload);
}

/**
 * Envoie une notification push à tous les abonnés ayant au moins un des rôles listés.
 * @param {string[]} roles   - Ex : ['technician_biomedical']
 * @param {object}   payload - { title, body, icon?, data? }
 */
async function sendPushToRoles(roles, payload) {
  ensureInit();
  if (!initialized || !roles.length) return emptyResult();
  const db  = getDb();
  const all = db.prepare('SELECT * FROM push_subscriptions').all();
  // user_roles est stocké en CSV (ex : "technician_biomedical,supervisor")
  const targets = all.filter(
    (s) => s.user_roles && roles.some((r) => s.user_roles.split(',').includes(r))
  );
  return await _sendToSubs(targets, payload);
}

async function _sendToSubs(subs, payload) {
  if (!subs.length) return emptyResult();
  const db           = getDb();
  const notification = JSON.stringify(payload);
  const now          = new Date().toISOString();
  let succeeded = 0, failed = 0, expired = 0;

  // Statements préparés une seule fois pour tout le lot (évite une recompilation
  // SQLite par souscription — jusqu'à 3x le nombre de préparations sur un envoi broadcast).
  const markSent    = db.prepare('UPDATE push_subscriptions SET last_sent_at = ? WHERE endpoint = ?');
  const markSuccess = db.prepare('UPDATE push_subscriptions SET last_success_at = ?, last_error = NULL WHERE endpoint = ?');
  const markError   = db.prepare('UPDATE push_subscriptions SET last_error = ? WHERE endpoint = ?');
  const deleteSub   = db.prepare('DELETE FROM push_subscriptions WHERE endpoint = ?');

  await Promise.allSettled(
    subs.map(async (sub) => {
      markSent.run(now, sub.endpoint);
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          notification
        );
        succeeded++;
        // Accepté par le service de push — PAS une confirmation de réception sur l'appareil
        // (voir last_delivered_at, renseigné séparément par POST /delivery-ack depuis le SW).
        markSuccess.run(now, sub.endpoint);
      } catch (err) {
        if (err.statusCode === 410 || err.statusCode === 404) {
          expired++;
          deleteSub.run(sub.endpoint);
          console.log(`[PUSH] Souscription expirée supprimée : ${sub.endpoint.substring(0, 70)}…`);
        } else {
          failed++;
          const errMsg = `${err.statusCode || '?'} ${err.message || ''}`.trim().substring(0, 300);
          markError.run(errMsg, sub.endpoint);
          console.error(`[PUSH] Erreur envoi (${err.statusCode || '?'}) : ${err.message}`);
        }
      }
    })
  );

  return { attempted: subs.length, succeeded, failed, expired };
}

module.exports = { sendPushToUser, sendPushToRoles };
