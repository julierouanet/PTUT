const { DB_SERVICE_URL, INTERNAL_SECRET } = require('../config');

/**
 * Extrait l'IP réelle depuis la requête (supporte les proxys inverses).
 */
function extractIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) return forwarded.split(',')[0].trim();
  return req.socket?.remoteAddress || req.ip || null;
}

/**
 * Envoie un log vers db-service. Ne bloque jamais en cas d'échec.
 */
async function sendLog({ user_id, user_name, user_role, action, target_type, target_id, target_name, details, ip_address, user_agent }) {
  try {
    await fetch(`${DB_SERVICE_URL}/api/logs/internal`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-internal-secret': INTERNAL_SECRET },
      body: JSON.stringify({ user_id, user_name, user_role, action, target_type, target_id, target_name, details, ip_address, user_agent }),
    });
  } catch (err) {
    console.error('[LOG] Impossible d\'envoyer le log:', err.message);
  }
}

/**
 * Helper pour extraire ip + user-agent d'une requête Express.
 */
function reqMeta(req) {
  return {
    ip_address: extractIp(req),
    user_agent: req.headers['user-agent'] || null,
  };
}

module.exports = { sendLog, reqMeta, extractIp };
