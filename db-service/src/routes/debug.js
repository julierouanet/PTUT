const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

// ── POST /clear-issues ────────────────────────────────────────────────────────
// Supprime tous les incidents (réservé admin, usage debug/test uniquement)
router.post('/clear-issues', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const result = db.prepare('DELETE FROM issues').run();

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'debug_clear_all_issues',
    target_type: 'issues',
    target_id:   null,
    target_name: 'Tous les incidents',
    details:     JSON.stringify({ deleted_count: result.changes, note: 'Nettoyage complet des incidents' }),
    ...extractReqMeta(req),
  });

  res.json({ message: `${result.changes} incident(s) supprimé(s)`, deleted: result.changes });
});

router.get('/', (req, res) => {
  const db = getDb();

  const equipment  = db.prepare('SELECT * FROM equipment ORDER BY department, name').all();
  const issues     = db.prepare('SELECT * FROM issues ORDER BY created_at DESC').all();
  const inventory  = db.prepare('SELECT * FROM inventory ORDER BY name').all();

  const stats = {
    equipment:  equipment.length,
    issues:     issues.length,
    inventory:  inventory.length,
    issuesOpen: issues.filter(i => i.status === 'Ouvert').length,
    issuesInProgress: issues.filter(i => i.status === 'En cours').length,
    issuesResolved: issues.filter(i => i.status === 'Résolu').length,
    stockLow: inventory.filter(i => i.status === 'Faible').length,
    stockOut: inventory.filter(i => i.status === 'Rupture').length,
  };

  const statusColors = {
    'Operational':    '#27ae60',
    'Maintenance':    '#f39c12',
    'Out of service': '#e74c3c',
    'To be disposal': '#e67e22',
    'Disposed':       '#95a5a6',
    'Ouvert':         '#e74c3c',
    'En cours':       '#f39c12',
    'Résolu':         '#27ae60',
    'Normal':         '#27ae60',
    'Faible':         '#f39c12',
    'Rupture':        '#e74c3c',
  };

  const badge = (val) => `<span style="background:${statusColors[val]||'#95a5a6'};color:white;padding:2px 8px;border-radius:12px;font-size:11px;white-space:nowrap">${val}</span>`;

  const equipRows = equipment.map(e => `
    <tr>
      <td><code>${e.id}</code></td>
      <td>${e.name}</td>
      <td>${e.department}</td>
      <td>${e.category}</td>
      <td>${badge(e.status)}</td>
      <td>${e.serial_number || '-'}</td>
      <td>${e.supplier || '-'}</td>
      <td>${e.location || '-'}</td>
    </tr>`).join('');

  const issueRows = issues.map(i => `
    <tr>
      <td><code>${i.id}</code></td>
      <td>${i.equipment_name}</td>
      <td>${i.department}</td>
      <td>${i.description.substring(0, 60)}${i.description.length > 60 ? '…' : ''}</td>
      <td>${badge(i.status)}</td>
      <td>${i.reporter}</td>
      <td>${i.assigned_technician || '-'}</td>
      <td>${i.created_at}</td>
    </tr>`).join('');

  const inventoryRows = inventory.map(i => `
    <tr>
      <td><code>${i.id}</code></td>
      <td>${i.name}</td>
      <td>${i.category}</td>
      <td>${i.current_stock} ${i.unit}</td>
      <td>${i.min_stock} ${i.unit}</td>
      <td>${badge(i.status)}</td>
      <td>${i.last_restocked || '-'}</td>
    </tr>`).join('');

  res.send(`<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DB Service - Debug</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0f2f5; color: #333; }
    .header { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 24px 32px; }
    .header h1 { font-size: 24px; font-weight: 700; }
    .header p { opacity: 0.85; font-size: 14px; margin-top: 4px; }
    .container { max-width: 1400px; margin: 0 auto; padding: 24px 32px; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 16px; margin-bottom: 32px; }
    .stat-card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .stat-card .value { font-size: 32px; font-weight: 700; color: #11998e; }
    .stat-card .label { font-size: 13px; color: #888; margin-top: 4px; }
    .tabs { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
    .tab-btn { padding: 8px 20px; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; font-weight: 600; background: #e0e0e0; color: #555; transition: all 0.2s; }
    .tab-btn.active { background: #11998e; color: white; }
    .section { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); overflow-x: auto; }
    .section h2 { font-size: 18px; font-weight: 600; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; min-width: 700px; }
    th { text-align: left; padding: 10px 12px; background: #f8f9fa; font-weight: 600; color: #555; border-bottom: 2px solid #eee; }
    td { padding: 9px 12px; border-bottom: 1px solid #f0f0f0; vertical-align: middle; }
    tr:hover td { background: #f0fdf8; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-size: 11px; }
    .panel { display: none; }
    .panel.active { display: block; }
    .env-badge { background: #f39c12; color: white; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🗄️ DB Service — Debug Dashboard</h1>
    <p>Hôpital de Kabutare — Environnement: <span class="env-badge">${process.env.NODE_ENV || 'development'}</span></p>
  </div>
  <div class="container">
    <div class="stats">
      <div class="stat-card"><div class="value">${stats.equipment}</div><div class="label">Équipements</div></div>
      <div class="stat-card"><div class="value">${stats.issuesOpen}</div><div class="label">Incidents ouverts</div></div>
      <div class="stat-card"><div class="value">${stats.issuesInProgress}</div><div class="label">En cours</div></div>
      <div class="stat-card"><div class="value">${stats.issuesResolved}</div><div class="label">Résolus</div></div>
      <div class="stat-card"><div class="value">${stats.inventory}</div><div class="label">Articles stock</div></div>
      <div class="stat-card"><div class="value" style="color:#e74c3c">${stats.stockOut}</div><div class="label">En rupture</div></div>
      <div class="stat-card"><div class="value" style="color:#f39c12">${stats.stockLow}</div><div class="label">Stock faible</div></div>
    </div>

    <div class="tabs">
      <button class="tab-btn active" onclick="showTab('equipment')">🔧 Équipements (${stats.equipment})</button>
      <button class="tab-btn" onclick="showTab('issues')">⚠️ Incidents (${stats.issues})</button>
      <button class="tab-btn" onclick="showTab('inventory')">📦 Inventaire (${stats.inventory})</button>
    </div>

    <div id="tab-equipment" class="panel active section">
      <h2>🔧 Équipements</h2>
      <table>
        <thead><tr><th>ID</th><th>Nom</th><th>Département</th><th>Catégorie</th><th>Statut</th><th>N° Série</th><th>Fournisseur</th><th>Localisation</th></tr></thead>
        <tbody>${equipRows || '<tr><td colspan="8" style="text-align:center;color:#999">Aucun équipement</td></tr>'}</tbody>
      </table>
    </div>

    <div id="tab-issues" class="panel section">
      <h2>⚠️ Incidents</h2>
      <table>
        <thead><tr><th>ID</th><th>Équipement</th><th>Département</th><th>Description</th><th>Statut</th><th>Signalé par</th><th>Technicien</th><th>Date</th></tr></thead>
        <tbody>${issueRows || '<tr><td colspan="8" style="text-align:center;color:#999">Aucun incident</td></tr>'}</tbody>
      </table>
    </div>

    <div id="tab-inventory" class="panel section">
      <h2>📦 Inventaire</h2>
      <table>
        <thead><tr><th>ID</th><th>Nom</th><th>Catégorie</th><th>Stock actuel</th><th>Stock min</th><th>Statut</th><th>Dernier réapprovisionnement</th></tr></thead>
        <tbody>${inventoryRows || '<tr><td colspan="7" style="text-align:center;color:#999">Aucun article</td></tr>'}</tbody>
      </table>
    </div>
  </div>

  <script>
    function showTab(name) {
      document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.getElementById('tab-' + name).classList.add('active');
      event.target.classList.add('active');
    }
  </script>
</body>
</html>`);
});

router.get('/health', (req, res) => {
  let dbStatus = 'ko';
  try {
    getDb().prepare('SELECT 1').get();
    dbStatus = 'ok';
  } catch (_) {}

  res.json({
    status:    dbStatus === 'ok' ? 'ok' : 'degraded',
    service:   'db-service',
    timestamp: new Date().toISOString(),
    checks:    { database: dbStatus },
  });
});

module.exports = router;
