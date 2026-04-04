const express = require('express');
const { getDb } = require('../database');

const router = express.Router();

// GET / - Dashboard debug HTML
router.get('/', (req, res) => {
  const db = getDb();

  const users = db.prepare('SELECT id, name, email, role, department, phone, is_active, created_at FROM users ORDER BY created_at DESC').all();
  const tokens = db.prepare(`
    SELECT rt.id, rt.user_id, u.name as user_name, u.email, rt.expires_at, rt.created_at
    FROM refresh_tokens rt
    JOIN users u ON rt.user_id = u.id
    ORDER BY rt.created_at DESC
    LIMIT 50
  `).all();

  const now = new Date();
  const activeTokens = tokens.filter(t => new Date(t.expires_at) > now);
  const expiredTokens = tokens.filter(t => new Date(t.expires_at) <= now);

  const roleColors = {
    admin: '#e74c3c',
    supervisor: '#e67e22',
    technician: '#3498db',
    hospitalStaff: '#27ae60',
  };

  const usersHtml = users.map(u => `
    <tr>
      <td><code>${u.id}</code></td>
      <td>${u.name}</td>
      <td>${u.email}</td>
      <td><span style="background:${roleColors[u.role]||'#95a5a6'};color:white;padding:2px 8px;border-radius:12px;font-size:12px">${u.role}</span></td>
      <td>${u.department}</td>
      <td>${u.phone || '-'}</td>
      <td><span style="color:${u.is_active ? '#27ae60' : '#e74c3c'}">${u.is_active ? '✓ Actif' : '✗ Inactif'}</span></td>
      <td>${u.created_at}</td>
    </tr>
  `).join('');

  const tokensHtml = activeTokens.map(t => `
    <tr>
      <td>${t.user_name}</td>
      <td>${t.email}</td>
      <td>${t.expires_at}</td>
      <td>${t.created_at}</td>
    </tr>
  `).join('');

  res.send(`<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Auth Service - Debug</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f0f2f5; color: #333; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 24px 32px; }
    .header h1 { font-size: 24px; font-weight: 700; }
    .header p { opacity: 0.8; font-size: 14px; margin-top: 4px; }
    .container { max-width: 1200px; margin: 0 auto; padding: 24px 32px; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 32px; }
    .stat-card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .stat-card .value { font-size: 32px; font-weight: 700; color: #667eea; }
    .stat-card .label { font-size: 13px; color: #888; margin-top: 4px; }
    .section { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); margin-bottom: 24px; }
    .section h2 { font-size: 18px; font-weight: 600; margin-bottom: 16px; color: #333; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th { text-align: left; padding: 10px 12px; background: #f8f9fa; font-weight: 600; color: #555; border-bottom: 2px solid #eee; }
    td { padding: 10px 12px; border-bottom: 1px solid #f0f0f0; }
    tr:hover td { background: #fafbff; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-size: 12px; }
    .env-badge { background: #f39c12; color: white; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🔐 Auth Service — Debug Dashboard</h1>
    <p>Hôpital de Kabutare — Environnement: <span class="env-badge">${process.env.NODE_ENV || 'development'}</span></p>
  </div>
  <div class="container">
    <div class="stats">
      <div class="stat-card"><div class="value">${users.length}</div><div class="label">Utilisateurs total</div></div>
      <div class="stat-card"><div class="value">${users.filter(u => u.is_active).length}</div><div class="label">Utilisateurs actifs</div></div>
      <div class="stat-card"><div class="value">${activeTokens.length}</div><div class="label">Sessions actives</div></div>
      <div class="stat-card"><div class="value">${tokens.length}</div><div class="label">Tokens (50 derniers)</div></div>
    </div>

    <div class="section">
      <h2>👥 Utilisateurs (${users.length})</h2>
      <table>
        <thead><tr><th>ID</th><th>Nom</th><th>Email</th><th>Rôle</th><th>Département</th><th>Téléphone</th><th>Statut</th><th>Créé le</th></tr></thead>
        <tbody>${usersHtml || '<tr><td colspan="8" style="text-align:center;color:#999">Aucun utilisateur</td></tr>'}</tbody>
      </table>
    </div>

    <div class="section">
      <h2>🔑 Sessions actives (${activeTokens.length})</h2>
      <table>
        <thead><tr><th>Utilisateur</th><th>Email</th><th>Expire le</th><th>Créé le</th></tr></thead>
        <tbody>${tokensHtml || '<tr><td colspan="4" style="text-align:center;color:#999">Aucune session active</td></tr>'}</tbody>
      </table>
    </div>
  </div>
</body>
</html>`);
});

// GET /health
router.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'auth-service', timestamp: new Date().toISOString() });
});

module.exports = router;
