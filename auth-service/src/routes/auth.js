const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { getDb } = require('../database');
const { JWT_SECRET, JWT_REFRESH_SECRET, ACCESS_TOKEN_EXPIRY, REFRESH_TOKEN_EXPIRY, REFRESH_TOKEN_EXPIRY_MS } = require('../config');
const { verifyToken } = require('../middleware/auth');

const { sendLog, reqMeta, extractIp } = require('../utils/logger');

const sendAuthLog = ({ user_id, user_name, user_role, action, details, ip_address, user_agent }) =>
  sendLog({ user_id, user_name, user_role, action, target_type: 'auth', details, ip_address, user_agent });

const router = express.Router();

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Supprime les refresh tokens expirés pour garder la table propre. */
function cleanExpiredTokens(db) {
  db.prepare("DELETE FROM refresh_tokens WHERE expires_at < datetime('now')").run();
}

// ── POST /api/auth/login ─────────────────────────────────────────────────────

router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email et mot de passe requis' });
  }

  const db = getDb();
  const user = db.prepare('SELECT * FROM users WHERE email = ? AND is_active = 1').get(email);

  if (!user) {
    console.log('[AUTH] Échec login — email inconnu ou inactif');
    sendAuthLog({ user_id: null, user_name: email, user_role: 'unknown', action: 'login_failed', details: { reason: 'email_inconnu' }, ip_address: extractIp(req), user_agent: req.headers['user-agent'] });
    return res.status(401).json({ error: 'Identifiants invalides' });
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    console.log('[AUTH] Échec login — mot de passe incorrect');
    sendAuthLog({ user_id: user.id, user_name: user.name, user_role: user.role, action: 'login_failed', details: { reason: 'mot_de_passe_incorrect' }, ip_address: extractIp(req), user_agent: req.headers['user-agent'] });
    return res.status(401).json({ error: 'Identifiants invalides' });
  }

  // Nettoyage des tokens expirés à chaque login
  cleanExpiredTokens(db);

  const payload = { id: user.id, email: user.email, role: user.role, name: user.name, department: user.department };

  const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRY });
  const refreshToken = jwt.sign({ id: user.id }, JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_EXPIRY });

  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_MS).toISOString();
  db.prepare('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (?, ?, ?)').run(user.id, refreshToken, expiresAt);

  console.log(`[AUTH] Login réussi (rôle: ${user.role})`);
  sendAuthLog({ user_id: user.id, user_name: user.name, user_role: user.role, action: 'login', ip_address: extractIp(req), user_agent: req.headers['user-agent'] });

  res.json({
    accessToken,
    refreshToken,
    user: { id: user.id, name: user.name, first_name: user.first_name, last_name: user.last_name, email: user.email, role: user.role, department: user.department, phone: user.phone },
  });
});

// ── POST /api/auth/refresh (avec rotation du refresh token) ──────────────────

router.post('/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ error: 'Refresh token manquant' });
  }

  const db = getDb();
  const stored = db.prepare('SELECT * FROM refresh_tokens WHERE token = ?').get(refreshToken);

  if (!stored || new Date(stored.expires_at) < new Date()) {
    return res.status(403).json({ error: 'Refresh token invalide ou expiré' });
  }

  try {
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);
    const user = db.prepare('SELECT * FROM users WHERE id = ? AND is_active = 1').get(decoded.id);

    if (!user) {
      return res.status(403).json({ error: 'Utilisateur introuvable' });
    }

    // Supprimer l'ancien refresh token (rotation)
    db.prepare('DELETE FROM refresh_tokens WHERE token = ?').run(refreshToken);

    // Émettre un nouveau couple access + refresh
    const payload = { id: user.id, email: user.email, role: user.role, name: user.name, department: user.department };
    const newAccessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRY });
    const newRefreshToken = jwt.sign({ id: user.id }, JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_EXPIRY });

    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_MS).toISOString();
    db.prepare('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (?, ?, ?)').run(user.id, newRefreshToken, expiresAt);

    // Nettoyage opportuniste
    cleanExpiredTokens(db);

    console.log('[AUTH] Token refresh réussi');

    res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (err) {
    return res.status(403).json({ error: 'Refresh token invalide' });
  }
});

// ── POST /api/auth/logout ────────────────────────────────────────────────────

router.post('/logout', (req, res) => {
  const { refreshToken } = req.body;
  const ip = extractIp(req);
  const ua = req.headers['user-agent'];

  if (refreshToken) {
    const db = getDb();
    // Lire d'abord, supprimer ensuite (ordre crucial pour le log)
    try {
      const stored = db.prepare('SELECT user_id FROM refresh_tokens WHERE token = ?').get(refreshToken);
      if (stored) {
        const u = db.prepare('SELECT id, name, role FROM users WHERE id = ?').get(stored.user_id);
        if (u) sendAuthLog({ user_id: u.id, user_name: u.name, user_role: u.role, action: 'logout', ip_address: ip, user_agent: ua });
      }
    } catch (_) {}
    db.prepare('DELETE FROM refresh_tokens WHERE token = ?').run(refreshToken);
  }

  console.log('[AUTH] Déconnexion effectuée');
  res.json({ message: 'Déconnexion réussie' });
});

// ── GET /api/auth/verify — pour les autres services ──────────────────────────

router.get('/verify', verifyToken, (req, res) => {
  res.json({ valid: true, user: req.user });
});

// ── GET /api/auth/me — profil de l'utilisateur connecté ──────────────────────

router.get('/me', verifyToken, (req, res) => {
  const db = getDb();
  const user = db.prepare('SELECT id, name, first_name, last_name, email, role, department, phone, created_at FROM users WHERE id = ?').get(req.user.id);

  if (!user) {
    return res.status(404).json({ error: 'Utilisateur introuvable' });
  }

  res.json(user);
});

module.exports = router;
