'use strict';

// ── GET /api/analytics — statistiques d'utilisation (admin uniquement) ─────────
// Query params optionnels : from, to  (ISO datetime, ex. 2024-01-01T00:00:00)

const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { from, to } = req.query;

  // ── Helper : construit la clause WHERE pour un champ date ─────────────────
  const dateClause = (field) => {
    const parts  = [];
    const params = [];
    if (from) { parts.push(`${field} >= ?`); params.push(from); }
    if (to)   { parts.push(`${field} <= ?`); params.push(to); }
    return { clause: parts.length ? `AND ${parts.join(' AND ')}` : '', params };
  };

  const logF  = dateClause('timestamp');
  const issF  = dateClause('created_at');

  // ── Comptages dans les logs ────────────────────────────────────────────────
  const countLog = (action) =>
    db.prepare(`SELECT COUNT(*) AS n FROM logs WHERE action = ? ${logF.clause}`)
      .get(action, ...logF.params).n;

  const logins        = countLog('login');
  const failedLogins  = countLog('login_failed');
  const issuesCreated = countLog('create_issue');
  const usersCreated  = countLog('create_user');

  const activeUsers = db.prepare(
    `SELECT COUNT(DISTINCT user_id) AS n FROM logs WHERE action = 'login' ${logF.clause}`
  ).get(...logF.params).n;

  // Top 5 actions (toutes, dans la période)
  const topActions = db.prepare(
    `SELECT action, COUNT(*) AS count FROM logs WHERE 1=1 ${logF.clause}
     GROUP BY action ORDER BY count DESC LIMIT 5`
  ).all(...logF.params);

  // ── Incidents (filtrés par created_at) ────────────────────────────────────
  const issuesTotal = db.prepare(
    `SELECT COUNT(*) AS n FROM issues WHERE 1=1 ${issF.clause}`
  ).get(...issF.params).n;

  const issuesResolved = db.prepare(
    `SELECT COUNT(*) AS n FROM issues
     WHERE status IN ('Completed','Verified','Closed') ${issF.clause}`
  ).get(...issF.params).n;

  const issuesOpen = db.prepare(
    `SELECT COUNT(*) AS n FROM issues WHERE status = 'Reported' ${issF.clause}`
  ).get(...issF.params).n;

  // ── Équipements (instantané — pas de filtre de date) ──────────────────────
  const equipByStatus = db.prepare(
    `SELECT status, COUNT(*) AS count FROM equipment GROUP BY status ORDER BY count DESC`
  ).all();

  const equipTotal = equipByStatus.reduce((s, r) => s + r.count, 0);

  res.json({
    period:            { from: from ?? null, to: to ?? null },
    logins,
    failed_logins:     failedLogins,
    active_users:      activeUsers,
    issues_created:    issuesCreated,
    issues_total:      issuesTotal,
    issues_open:       issuesOpen,
    issues_resolved:   issuesResolved,
    users_created:     usersCreated,
    equipment_total:   equipTotal,
    equipment_by_status: Object.fromEntries(equipByStatus.map((r) => [r.status, r.count])),
    top_actions:       topActions,
  });
});

module.exports = router;
