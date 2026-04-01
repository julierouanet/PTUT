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
    'SELECT id, name, first_name, last_name, email, department, role, phone, is_active, created_at FROM users ORDER BY name ASC'
  ).all();
  res.json(users);
});

// POST /api/users/restore — restaurer un utilisateur supprimé (admin)
router.post('/restore', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { snapshot } = req.body;

  if (!snapshot || !snapshot.id || !snapshot.email || !snapshot.name) {
    return res.status(400).json({ error: 'Données de restauration incomplètes' });
  }

  const tempPassword = crypto.randomBytes(8).toString('hex');
  const passwordHash = await bcrypt.hash(tempPassword, 10);

  try {
    db.prepare(`
      INSERT INTO users (id, name, email, password_hash, department, role, phone, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
    `).run(snapshot.id, snapshot.name, snapshot.email, passwordHash,
           snapshot.department || null, snapshot.role || 'hospitalStaff',
           snapshot.phone || null, new Date().toISOString());

    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
      action: 'restore_user', target_type: 'user',
      target_id: snapshot.id, target_name: snapshot.name,
      ...reqMeta(req),
    });

    res.status(201).json({ message: 'Utilisateur restauré', tempPassword });
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Cet utilisateur existe déjà (email ou ID déjà utilisé)' });
    }
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// GET /api/users/:id
router.get('/:id', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const user = db.prepare(
    'SELECT id, name, first_name, last_name, email, department, role, phone, is_active, created_at FROM users WHERE id = ?'
  ).get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });
  res.json(user);
});

// POST /api/users — créer un utilisateur (admin seulement)
router.post('/', verifyToken, requireAdmin, async (req, res) => {
  const { first_name, last_name, name: rawName, email, password, department, role, phone } = req.body;

  // Supporter first_name/last_name ou name legacy
  const firstName = first_name || (rawName ? rawName.split(' ')[0] : '');
  const lastName = last_name || (rawName ? rawName.split(' ').slice(1).join(' ') : '');
  const name = `${firstName} ${lastName}`.trim();

  if (!name || !email || !password || !department || !role) {
    return res.status(400).json({ error: 'Champs requis: first_name, last_name, email, password, department, role' });
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
      INSERT INTO users (id, name, first_name, last_name, email, password_hash, department, role, phone, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
    `).run(id, name, firstName, lastName, email, passwordHash, department, role, phone || null, createdAt);

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
  const { first_name, last_name, name: rawName, email, password, department, role, phone } = req.body;
  const db = getDb();

  const existing = db.prepare('SELECT id, name, first_name, last_name, email, role, phone, department FROM users WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Utilisateur introuvable' });

  // Calculer first_name/last_name et garder name synchronise
  const newFirstName = first_name !== undefined ? first_name : (rawName ? rawName.split(' ')[0] : null);
  const newLastName = last_name !== undefined ? last_name : (rawName ? rawName.split(' ').slice(1).join(' ') : null);
  const computedName = (newFirstName || newLastName)
    ? `${newFirstName || existing.first_name || ''} ${newLastName || existing.last_name || ''}`.trim()
    : rawName;

  let passwordHash = undefined;
  if (password) {
    passwordHash = await bcrypt.hash(password, 10);
  }

  try {
    if (passwordHash) {
      db.prepare(`
        UPDATE users
        SET name = COALESCE(?, name),
            first_name = COALESCE(?, first_name),
            last_name = COALESCE(?, last_name),
            email = COALESCE(?, email),
            password_hash = ?,
            department = COALESCE(?, department),
            role = COALESCE(?, role),
            phone = COALESCE(?, phone)
        WHERE id = ?
      `).run(computedName, newFirstName, newLastName, email, passwordHash, department, role, phone, req.params.id);
    } else {
      db.prepare(`
        UPDATE users
        SET name = COALESCE(?, name),
            first_name = COALESCE(?, first_name),
            last_name = COALESCE(?, last_name),
            email = COALESCE(?, email),
            department = COALESCE(?, department),
            role = COALESCE(?, role),
            phone = COALESCE(?, phone)
        WHERE id = ?
      `).run(computedName, newFirstName, newLastName, email, department, role, phone, req.params.id);
    }
    const name = computedName;

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
  const reason = req.query.reason;
  const target = db.prepare('SELECT id, name, role, email, department, phone FROM users WHERE id = ?').get(req.params.id);
  if (!target) return res.status(404).json({ error: 'Utilisateur introuvable' });

  db.prepare('DELETE FROM users WHERE id = ?').run(req.params.id);

  console.log(`[AUDIT] Utilisateur supprimé: ${req.params.id} par ${req.user.email}`);

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: 'delete_user', target_type: 'user',
    target_id: req.params.id, target_name: target.name,
    details: { snapshot: target, ...(reason ? { reason } : {}) },
    ...reqMeta(req),
  });

  res.json({ message: 'Utilisateur supprimé' });
});

// ── Demandes de changement de département ──────────────────────────────────

// POST /api/users/department-request  (user connecté)
router.post('/department-request', verifyToken, (req, res) => {
  const db = getDb();
  const { requested_department } = req.body;
  if (!requested_department) {
    return res.status(400).json({ error: 'Département demandé requis' });
  }
  const user = db.prepare('SELECT id, name, department FROM users WHERE id = ?').get(req.user.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });
  if (user.department === requested_department) {
    return res.status(400).json({ error: 'Vous êtes déjà dans ce département' });
  }
  // Vérifier qu'il n'y a pas déjà une demande en attente
  const existing = db.prepare(
    "SELECT id FROM department_change_requests WHERE user_id = ? AND status = 'pending'"
  ).get(req.user.id);
  if (existing) {
    return res.status(409).json({ error: 'Une demande est déjà en attente' });
  }
  const { v4: uuidv4 } = require('uuid');
  const id = uuidv4();
  db.prepare(`
    INSERT INTO department_change_requests (id, user_id, user_name, current_department, requested_department, status, created_at)
    VALUES (?, ?, ?, ?, ?, 'pending', ?)
  `).run(id, user.id, user.name, user.department, requested_department, new Date().toISOString());
  res.status(201).json({ id, message: 'Demande envoyée, en attente de validation admin' });
});

// GET /api/users/department-requests  (admin seulement)
router.get('/department-requests', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { status } = req.query;
  let query = 'SELECT * FROM department_change_requests';
  const params = [];
  if (status) { query += ' WHERE status = ?'; params.push(status); }
  query += ' ORDER BY created_at DESC';
  const rows = db.prepare(query).all(...params);
  res.json(rows);
});

// PUT /api/users/department-requests/:id  (admin approuve ou rejette)
router.put('/department-requests/:id', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { status, admin_note } = req.body;
  if (!['approved', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'Statut invalide (approved | rejected)' });
  }
  const request = db.prepare('SELECT * FROM department_change_requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ error: 'Demande introuvable' });
  if (request.status !== 'pending') {
    return res.status(409).json({ error: 'Demande déjà traitée' });
  }
  const now = new Date().toISOString();
  db.prepare(`
    UPDATE department_change_requests
    SET status = ?, admin_id = ?, admin_note = ?, resolved_at = ?
    WHERE id = ?
  `).run(status, req.user.id, admin_note || null, now, req.params.id);

  if (status === 'approved') {
    db.prepare('UPDATE users SET department = ? WHERE id = ?')
      .run(request.requested_department, request.user_id);
  }

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.role,
    action: status === 'approved' ? 'approve_dept_request' : 'reject_dept_request',
    target_type: 'user', target_id: request.user_id, target_name: request.user_name,
    details: { from: request.current_department, to: request.requested_department, admin_note },
    ...reqMeta(req),
  });

  res.json({ message: status === 'approved' ? 'Demande approuvée, département mis à jour' : 'Demande rejetée' });
});

module.exports = router;
