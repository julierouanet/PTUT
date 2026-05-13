const express = require('express');
const router  = express.Router();
const { getDb } = require('../database');

// Middleware d'authentification léger (vérifie l'en-tête Authorization)
const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

function verifyToken(req, res, next) {
  const auth = req.headers['authorization'];
  if (!auth || !auth.startsWith('Bearer ')) return res.status(401).json({ error: 'Non authentifié' });
  try {
    req.user = jwt.verify(auth.slice(7), JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ error: 'Token invalide' });
  }
}

function requireAdmin(req, res, next) {
  const roles = Array.isArray(req.user?.roles) ? req.user.roles : [];
  if (!roles.includes('admin')) return res.status(403).json({ error: 'Réservé aux administrateurs' });
  next();
}

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
router.put('/', verifyToken, requireAdmin, (req, res) => {
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
