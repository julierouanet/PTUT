const express = require('express');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// ── GET /api/locations ─────────────────────────────────────────────────────
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  res.json(db.prepare('SELECT * FROM locations ORDER BY building, name ASC').all());
});

module.exports = router;
