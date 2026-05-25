const express = require('express');
const { getDb } = require('../database');
const { getUserRoles } = require('../utils/userRoles');
const { KC_ISSUER } = require('../config');

const router = express.Router();

// GET / - Dashboard debug HTML
router.get('/', (req, res) => {
  const db = getDb();

  const usersRaw = db.prepare('SELECT id, name, email, department, phone, is_active, created_at FROM users ORDER BY created_at DESC').all();
  const users = usersRaw.map((u) => ({ ...u, roles: getUserRoles(db, u.id) }));
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
    technician_biomedical: '#2980b9',
    technician_it: '#16a085',
    technician_infra: '#8e44ad',
    hospitalStaff: '#27ae60',
  };

  const renderRoles = (roles) =>
    (roles || []).map((r) =>
      `<span style="background:${roleColors[r]||'#95a5a6'};color:white;padding:2px 8px;border-radius:12px;font-size:12px;margin-right:4px">${r}</span>`
    ).join('');

  const usersHtml = users.map(u => `
    <tr>
      <td><code>${u.id}</code></td>
      <td>${u.name}</td>
      <td>${u.email}</td>
      <td>${renderRoles(u.roles)}</td>
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

// GET /health — vérifie SQLite, Keycloak et Brevo
router.get('/health', async (req, res) => {
  const checks = { database: 'ko', keycloak: 'ko', brevo: null };

  // ── SQLite ──────────────────────────────────────────────────────────────────
  try {
    getDb().prepare('SELECT 1').get();
    checks.database = 'ok';
  } catch (_) {}

  // ── Keycloak (health/ready via URL interne HTTP) ─────────────────────────────
  // On utilise KC_JWKS_URI (http://keycloak:8080/...) plutôt que KC_ISSUER
  // (https://IP_PUBLIQUE/...) pour éviter deux problèmes depuis le conteneur :
  //   1. Certificat self-signed → Node.js rejette la connexion TLS
  //   2. Hairpin NAT → l'IP publique est injoignable depuis le réseau Docker interne
  try {
    // Dériver l'URL de health Keycloak depuis KC_JWKS_URI si disponible (HTTP interne)
    // ex: http://keycloak:8080/keycloak/realms/.../certs → http://keycloak:8080/keycloak/health/ready
    const jwksUri = process.env.KC_JWKS_URI || '';
    // Dériver l'URL OIDC discovery via HTTP interne :
    // KC_JWKS_URI = http://keycloak:8080/keycloak/realms/<realm>/protocol/openid-connect/certs
    // → split('/protocol/')[0] = http://keycloak:8080/keycloak/realms/<realm>
    // → + /.well-known/openid-configuration (toujours disponible, retourne 200 si Keycloak est UP)
    const kcHealthUrl = jwksUri
      ? `${jwksUri.split('/protocol/')[0]}/.well-known/openid-configuration`
      : `${KC_ISSUER}/.well-known/openid-configuration`;
    const r = await fetch(kcHealthUrl, {
      signal: AbortSignal.timeout(3000),
    });
    if (r.ok) {
      const body = await r.json().catch(() => ({}));
      // OIDC discovery → { issuer, token_endpoint, … } (pas de champ status)
      // Si r.ok et JSON valide avec issuer → Keycloak est UP
      checks.keycloak = (body.issuer || !body.status || body.status === 'UP') ? 'ok' : 'ko';
    } else {
      checks.keycloak = 'ko';
    }
  } catch (_) {
    checks.keycloak = 'ko';
  }

  // ── Brevo (GET /v3/account — nécessite BREVO_API_KEY) ─────────────────────
  const brevoKey = process.env.BREVO_API_KEY;
  if (brevoKey) {
    try {
      const r = await fetch('https://api.brevo.com/v3/account', {
        headers: { 'api-key': brevoKey },
        signal: AbortSignal.timeout(3000),
      });
      checks.brevo = r.ok ? 'ok' : 'ko';
    } catch (_) {
      checks.brevo = 'ko';
    }
  }

  const allOk = checks.database === 'ok' && checks.keycloak === 'ok' && checks.brevo !== 'ko';
  res.json({
    status:    allOk ? 'ok' : 'degraded',
    service:   'auth-service',
    timestamp: new Date().toISOString(),
    checks,
  });
});

module.exports = router;
