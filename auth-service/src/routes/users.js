const express = require('express');
const bcrypt = require('bcrypt');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');

const router = express.Router();

// GET /api/users — liste tous les utilisateurs (admin seulement)
router.get('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const users = db.prepare(
    'SELECT id, name, email, department, role, phone, is_active, created_at FROM users ORDER BY name ASC'
  ).all();
  res.json(users);
});

// GET /api/users/:id
router.get('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const user = db.prepare(
    'SELECT id, name, email, department, role, phone, is_active, created_at FROM users WHERE id = ?'
  ).get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });
  res.json(user);
});

// POST /api/users — créer un utilisateur (admin seulement)
router.post('/', verifyToken, requireRole('admin'), async (req, res) => {
  const { name, email, password, department, role, phone } = req.body;

  if (!name || !email || !password || !department || !role) {
    return res.status(400).json({ error: 'Champs requis: name, email, password, department, role' });
  }

  const validRoles = ['hospitalStaff', 'supervisor', 'technician', 'admin'];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ error: `Rôle invalide. Valeurs acceptées: ${validRoles.join(', ')}` });
  }

  try {
    const db = getDb();
    const id = `user-${Date.now()}`;
    const passwordHash = await bcrypt.hash(password, 10);
    const createdAt = new Date().toISOString();

    db.prepare(`
      INSERT INTO users (id, name, email, password_hash, department, role, phone, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
    `).run(id, name, email, passwordHash, department, role, phone || null, createdAt);

    res.status(201).json({ message: 'Utilisateur créé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Email déjà utilisé' });
    }
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/users/:id — modifier un utilisateur (admin seulement)
router.put('/:id', verifyToken, requireRole('admin'), async (req, res) => {
  const { name, email, password, department, role, phone } = req.body;
  const db = getDb();

  const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Utilisateur introuvable' });

  let passwordHash = undefined;
  if (password) {
    passwordHash = await bcrypt.hash(password, 10);
  }

  try {
    if (passwordHash) {
      db.prepare(`
        UPDATE users
        SET name = COALESCE(?, name),
            email = COALESCE(?, email),
            password_hash = ?,
            department = COALESCE(?, department),
            role = COALESCE(?, role),
            phone = COALESCE(?, phone)
        WHERE id = ?
      `).run(name, email, passwordHash, department, role, phone, req.params.id);
    } else {
      db.prepare(`
        UPDATE users
        SET name = COALESCE(?, name),
            email = COALESCE(?, email),
            department = COALESCE(?, department),
            role = COALESCE(?, role),
            phone = COALESCE(?, phone)
        WHERE id = ?
      `).run(name, email, department, role, phone, req.params.id);
    }
    res.json({ message: 'Utilisateur mis à jour' });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Email déjà utilisé' });
    }
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/users/:id/toggle — activer/désactiver un compte (admin seulement)
router.patch('/:id/toggle', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const user = db.prepare('SELECT id, is_active FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });

  const newStatus = user.is_active ? 0 : 1;
  db.prepare('UPDATE users SET is_active = ? WHERE id = ?').run(newStatus, req.params.id);
  res.json({ message: newStatus ? 'Compte activé' : 'Compte désactivé', is_active: newStatus });
});

// DELETE /api/users/:id (admin seulement)
router.delete('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  // Empêcher la suppression de soi-même
  if (req.user.id === req.params.id) {
    return res.status(400).json({ error: 'Impossible de supprimer votre propre compte' });
  }
  const result = db.prepare('DELETE FROM users WHERE id = ?').run(req.params.id);
  if (result.changes === 0) return res.status(404).json({ error: 'Utilisateur introuvable' });
  res.json({ message: 'Utilisateur supprimé' });
});

module.exports = router;
