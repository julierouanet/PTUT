const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { getDb } = require('../database');
const { JWT_SECRET, JWT_REFRESH_SECRET, ACCESS_TOKEN_EXPIRY, REFRESH_TOKEN_EXPIRY, REFRESH_TOKEN_EXPIRY_MS } = require('../config');
const { verifyToken } = require('../middleware/auth');

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
    console.log(`[AUTH] Échec login — email inconnu ou inactif: ${email}`);
    return res.status(401).json({ error: 'Identifiants invalides' });
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    console.log(`[AUTH] Échec login — mauvais mot de passe: ${email}`);
    return res.status(401).json({ error: 'Identifiants invalides' });
  }

  // Nettoyage des tokens expirés à chaque login
  cleanExpiredTokens(db);

  const payload = { id: user.id, email: user.email, role: user.role, name: user.name, department: user.department };

  const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: ACCESS_TOKEN_EXPIRY });
  const refreshToken = jwt.sign({ id: user.id }, JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_EXPIRY });

  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_MS).toISOString();
  db.prepare('INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (?, ?, ?)').run(user.id, refreshToken, expiresAt);

  console.log(`[AUTH] Login réussi: ${email} (rôle: ${user.role})`);

  res.json({
    accessToken,
    refreshToken,
    user: { id: user.id, name: user.name, email: user.email, role: user.role, department: user.department, phone: user.phone },
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

    console.log(`[AUTH] Token refresh réussi pour user ${user.email}`);

    res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (err) {
    return res.status(403).json({ error: 'Refresh token invalide' });
  }
});

// ── POST /api/auth/logout ────────────────────────────────────────────────────

router.post('/logout', (req, res) => {
  const { refreshToken } = req.body;

  if (refreshToken) {
    const db = getDb();
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
  const user = db.prepare('SELECT id, name, email, role, department, phone, created_at FROM users WHERE id = ?').get(req.user.id);

  if (!user) {
    return res.status(404).json({ error: 'Utilisateur introuvable' });
  }

  res.json(user);
});

module.exports = router;
