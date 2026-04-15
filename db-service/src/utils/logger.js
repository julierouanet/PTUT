const { getDb } = require('../database');

/**
 * Extrait l'IP réelle depuis la requête (supporte les proxys inverses).
 */
function extractIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) return forwarded.split(',')[0].trim();
  return req.socket?.remoteAddress || req.ip || null;
}

/**
 * Détermine le type d'appareil depuis le User-Agent.
 * @returns {'mobile'|'desktop'|'unknown'}
 */
function extractDeviceType(userAgent) {
  if (!userAgent) return 'unknown';
  const ua = userAgent.toLowerCase();
  if (/mobile|android|iphone|ipad|ipod|blackberry|windows phone/.test(ua)) return 'mobile';
  return 'desktop';
}

/**
 * Insère une entrée dans la table logs.
 * Ne lève jamais d'exception — une erreur de log ne doit pas casser la requête principale.
 */
function logAction({ user_id, user_name, user_role, action, target_type, target_id, target_name, details, ip_address, user_agent }) {
  try {
    const db = getDb();
    // Heure locale au format "YYYY-MM-DD HH:MM:SS" pour cohérence avec les autres tables
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const timestamp = `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    db.prepare(`
      INSERT INTO logs (timestamp, user_id, user_name, user_role, action, target_type, target_id, target_name, details, ip_address, user_agent)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      timestamp,
      user_id      || null,
      user_name    || 'Système',
      user_role    || 'system',
      action,
      target_type  || null,
      target_id    || null,
      target_name  || null,
      details ? JSON.stringify(details) : null,
      ip_address   || null,
      user_agent   || null,
    );
  } catch (err) {
    console.error('[LOG] Erreur enregistrement:', err.message);
  }
}

/**
 * Helper pour extraire ip_address et user_agent depuis un objet req Express.
 */
function extractReqMeta(req) {
  return {
    ip_address: extractIp(req),
    user_agent: req.headers['user-agent'] || null,
  };
}

module.exports = { logAction, extractReqMeta, extractDeviceType };
