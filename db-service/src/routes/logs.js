const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction } = require('../utils/logger');
const { INTERNAL_SECRET } = require('../config');

const router = express.Router();

// ── GET /api/logs — admin uniquement ────────────────────────────────────────

router.get('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { action, user_id, target_type, from, to } = req.query;
  const limit = Math.min(parseInt(req.query.limit, 10) || 500, 1000);

  let query = 'SELECT * FROM logs WHERE 1=1';
  const params = [];

  if (action)      { query += ' AND action = ?';      params.push(action); }
  if (user_id)     { query += ' AND user_id = ?';     params.push(user_id); }
  if (target_type) { query += ' AND target_type = ?'; params.push(target_type); }
  if (from)        { query += ' AND timestamp >= ?';  params.push(from); }
  if (to)          { query += ' AND timestamp <= ?';  params.push(to); }

  query += ' ORDER BY timestamp DESC LIMIT ?';
  params.push(limit);

  res.json(db.prepare(query).all(...params));
});

// ── POST /api/logs/internal — service-to-service (auth-service → db-service) ─

router.post('/internal', (req, res) => {
  const secret = req.headers['x-internal-secret'];
  if (!secret || secret !== INTERNAL_SECRET) {
    return res.status(403).json({ error: 'Accès interdit' });
  }

  const { user_id, user_name, user_role, action, target_type, target_id, target_name, details, ip_address, user_agent } = req.body;

  if (!user_name || !user_role || !action) {
    return res.status(400).json({ error: 'Champs requis: user_name, user_role, action' });
  }

  logAction({ user_id, user_name, user_role, action, target_type, target_id, target_name, details, ip_address, user_agent });
  res.status(201).json({ message: 'Log enregistré' });
});

module.exports = router;
