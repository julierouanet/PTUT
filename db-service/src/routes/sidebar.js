const express = require('express');
const router  = express.Router();
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');

// Ordre de priorité utilisé pour choisir le rôle "principal" quand le user en cumule plusieurs.
const ROLE_PRIORITY = ['admin', 'supervisor', 'technician_biomedical', 'technician_it', 'technician_infra', 'technician', 'hospitalStaff'];
function primaryRole(req) {
  const userRoles = Array.isArray(req.user?.roles) ? req.user.roles : [];
  for (const r of ROLE_PRIORITY) {
    if (userRoles.includes(r)) return r;
  }
  return userRoles[0] || null;
}

/**
 * GET /api/sidebar/config
 * Retourne la configuration sidebar pour le rôle "principal" de l'utilisateur
 * (ou pour le rôle passé en query string).
 * Résultat : { role: string, order: string[] }
 */
router.get('/', verifyToken, (req, res) => {
  const db   = getDb();
  const role = req.query.role || primaryRole(req);
  if (!role) {
    return res.json({ role: null, order: [] });
  }
  const rows = db.prepare(
    'SELECT screen_type FROM sidebar_config WHERE role = ? ORDER BY sort_order ASC'
  ).all(role);
  res.json({ role, order: rows.map(r => r.screen_type) });
});

/**
 * PUT /api/sidebar/config
 * Body : { role: string, order: string[] }
 * Remplace entièrement la configuration pour ce rôle.
 * Réservé aux admins.
 */
router.put('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { role, order } = req.body;
  if (!role || !Array.isArray(order)) {
    return res.status(400).json({ error: 'role (string) et order (array) requis' });
  }

  const deleteStmt = db.prepare('DELETE FROM sidebar_config WHERE role = ?');
  const insertStmt = db.prepare(
    'INSERT INTO sidebar_config (role, screen_type, sort_order) VALUES (?, ?, ?)'
  );

  db.transaction(() => {
    deleteStmt.run(role);
    order.forEach((screenType, idx) => {
      insertStmt.run(role, screenType, idx);
    });
  })();

  res.json({ message: 'Configuration sauvegardée', role, count: order.length });
});

module.exports = router;
