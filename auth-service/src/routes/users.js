const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcrypt');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');
const { sendLog, reqMeta } = require('../utils/logger');

const router = express.Router();

// Middleware inline : réservé aux admins
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Accès réservé aux administrateurs' });
  }
  next();
};

// GET /api/users — liste tous les utilisateurs (admin seulement)
router.get('/', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const users = db.prepare(
    'SELECT id, name, email, department, role, phone, is_active, created_at FROM users ORDER BY name ASC'
  ).all();
  res.json(users);
});

// GET /api/users/:id
router.get('/:id', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const user = db.prepare(
    'SELECT id, name, email, department, role, phone, is_active, created_at FROM users WHERE id = ?'
  ).get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });
  res.json(user);
});

// POST /api/users — créer un utilisateur (admin seulement)
router.post('/', verifyToken, requireAdmin, async (req, res) => {
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
    const id = `user-${crypto.randomUUID()}`;
    const passwordHash = await bcrypt.hash(password, 10);
    const createdAt = new Date().toISOString();

    db.prepare(`
      INSERT INTO users (id, name, email, password_hash, department, role, phone, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
    `).run(id, name, email, passwordHash, department, role, phone || null, createdAt);

    console.log(`[AUDIT] Utilisateur créé: ${email} (id: ${id}, rôle: ${role}) par ${req.user.email}`);

    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
      action: 'create_user', target_type: 'user', target_id: id, target_name: name,
      details: { email, role, department },
      ...reqMeta(req),
    });

    res.status(201).json({ message: 'Utilisateur créé', id });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Email déjà utilisé' });
    }
    console.error('[USERS] Erreur interne:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// PUT /api/users/:id — modifier un utilisateur (admin seulement)
router.put('/:id', verifyToken, requireAdmin, async (req, res) => {
  const { name, email, password, department, role, phone } = req.body;
  const db = getDb();

  const existing = db.prepare('SELECT id, name, email, role, phone, department FROM users WHERE id = ?').get(req.params.id);
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

    console.log(`[AUDIT] Utilisateur modifié: ${req.params.id} par ${req.user.email}`);

    // Détecter précisément ce qui a changé
    const changes = {};
    if (name     && name     !== existing.name)       changes.name  = { old: existing.name,  new: name };
    if (email    && email    !== existing.email)       changes.email = { old: existing.email, new: email };
    if (phone    && phone    !== existing.phone)       changes.phone = { old: existing.phone, new: phone };
    if (role     && role     !== existing.role)        changes.role  = { old: existing.role,  new: role };
    if (department && department !== existing.department) changes.department = { old: existing.department, new: department };
    if (password) changes.password = 'modifié';

    // Un log par type de modification pour plus de clarté
    if (password) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
        action: 'change_password', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        ...reqMeta(req),
      });
    }
    if (name && name !== existing.name) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
        action: 'change_name', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: { old: existing.name, new: name },
        ...reqMeta(req),
      });
    }
    if (email && email !== existing.email) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
        action: 'change_email', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: { old: existing.email, new: email },
        ...reqMeta(req),
      });
    }
    if (phone && phone !== existing.phone) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
        action: 'change_phone', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: { old: existing.phone, new: phone },
        ...reqMeta(req),
      });
    }
    // Si d'autres champs ont changé sans cas spécifique
    if (role && role !== existing.role || department && department !== existing.department) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
        action: 'update_user', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: changes,
        ...reqMeta(req),
      });
    }

    res.json({ message: 'Utilisateur mis à jour' });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Email déjà utilisé' });
    }
    console.error('[USERS] Erreur interne:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// PATCH /api/users/:id/toggle — activer/désactiver un compte (admin seulement)
router.patch('/:id/toggle', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const user = db.prepare('SELECT id, name, role, is_active FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });

  const newStatus = user.is_active ? 0 : 1;
  db.prepare('UPDATE users SET is_active = ? WHERE id = ?').run(newStatus, req.params.id);

  console.log(`[AUDIT] Utilisateur ${newStatus ? 'activé' : 'désactivé'}: ${req.params.id} par ${req.user.email}`);

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: newStatus ? 'activate_user' : 'suspend_user',
    target_type: 'user', target_id: req.params.id, target_name: user.name,
    details: { new_status: newStatus ? 'actif' : 'suspendu' },
    ...reqMeta(req),
  });

  res.json({ message: newStatus ? 'Compte activé' : 'Compte désactivé', is_active: newStatus });
});

// DELETE /api/users/:id (admin seulement)
router.delete('/:id', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  if (req.user.id === req.params.id) {
    return res.status(400).json({ error: 'Impossible de supprimer votre propre compte' });
  }
  const target = db.prepare('SELECT id, name, role, email FROM users WHERE id = ?').get(req.params.id);
  const result = db.prepare('DELETE FROM users WHERE id = ?').run(req.params.id);
  if (result.changes === 0) return res.status(404).json({ error: 'Utilisateur introuvable' });

  console.log(`[AUDIT] Utilisateur supprimé: ${req.params.id} par ${req.user.email}`);

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: 'delete_user', target_type: 'user',
    target_id: req.params.id, target_name: target?.name,
    details: { email: target?.email, role: target?.role },
    ...reqMeta(req),
  });

  res.json({ message: 'Utilisateur supprimé' });
});

module.exports = router;
