const { getDb } = require('../database');

/**
 * Insère une entrée dans la table logs.
 * Ne lève jamais d'exception — une erreur de log ne doit pas casser la requête principale.
 *
 * @param {object} opts
 * @param {string}  opts.user_id      - ID de l'utilisateur
 * @param {string}  opts.user_name    - Nom affiché
 * @param {string}  opts.user_role    - Rôle (admin, technician, …)
 * @param {string}  opts.action       - Identifiant de l'action (ex: 'create_equipment')
 * @param {string}  [opts.target_type] - Type de la ressource ciblée ('equipment', 'issue', …)
 * @param {string}  [opts.target_id]   - ID de la ressource ciblée
 * @param {string}  [opts.target_name] - Nom lisible de la ressource ciblée
 * @param {object}  [opts.details]     - Données supplémentaires (sérialisées en JSON)
 */
function logAction({ user_id, user_name, user_role, action, target_type, target_id, target_name, details }) {
  try {
    const db = getDb();
    db.prepare(`
      INSERT INTO logs (user_id, user_name, user_role, action, target_type, target_id, target_name, details)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      user_id    || null,
      user_name  || 'Système',
      user_role  || 'system',
      action,
      target_type  || null,
      target_id    || null,
      target_name  || null,
      details ? JSON.stringify(details) : null,
    );
  } catch (err) {
    console.error('[LOG] Erreur enregistrement:', err.message);
  }
}

module.exports = { logAction };
