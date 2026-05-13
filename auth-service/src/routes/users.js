const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcrypt');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');
const { sendLog, reqMeta } = require('../utils/logger');
const { getUserRoles, getUserPermissions, setUserRoles } = require('../utils/userRoles');

const router = express.Router();

// Rôles assignables aux utilisateurs (le rôle générique `technician` est déprécié
// et n'apparaît plus ici : on ne peut plus créer un user avec ce rôle, mais il
// reste présent dans la table `roles` pour ne pas casser les FK legacy).
const VALID_ROLES = ['hospitalStaff', 'supervisor', 'technician_biomedical', 'technician_it', 'technician_infra', 'admin'];

// Sérialise le tableau de rôles d'un user (pour les logs `user_role`).
const rolesCsv = (roles) => (Array.isArray(roles) ? roles.join(',') : '');

// Middleware inline : réservé aux admins
const requireAdmin = (req, res, next) => {
  const roles = Array.isArray(req.user?.roles) ? req.user.roles : [];
  if (!roles.includes('admin')) {
    return res.status(403).json({ error: 'Access restricted to administrators' });
  }
  next();
};

// Enrichit un user (objet du SELECT) avec son tableau de rôles.
function attachRoles(db, user) {
  return { ...user, roles: getUserRoles(db, user.id) };
}

// GET /api/users
//   - Sans query : liste complète (admin seulement).
//   - Avec ?role=<roleName> : filtre les utilisateurs actifs ayant ce rôle (accessible
//     à tout utilisateur authentifié — projection minimale). Permet aux superviseurs
//     et techniciens de récupérer la liste des techniciens assignables.
router.get('/', verifyToken, (req, res) => {
  const db = getDb();
  const { role } = req.query;

  if (role) {
    const users = db.prepare(`
      SELECT u.id, u.name, u.first_name, u.last_name, u.email, u.department, u.is_active
        FROM users u
        JOIN user_roles ur ON ur.user_id = u.id
       WHERE ur.role_name = ? AND u.is_active = 1
       ORDER BY u.name ASC
    `).all(role);
    return res.json(users.map((u) => attachRoles(db, u)));
  }

  // Listing complet : admin uniquement
  const userRoles = Array.isArray(req.user?.roles) ? req.user.roles : [];
  if (!userRoles.includes('admin')) {
    return res.status(403).json({ error: 'Access restricted to administrators' });
  }

  const users = db.prepare(
    'SELECT id, name, first_name, last_name, email, department, phone, is_active, created_at FROM users ORDER BY name ASC'
  ).all();
  res.json(users.map((u) => attachRoles(db, u)));
});

// POST /api/users/restore — restaurer un utilisateur supprimé (admin)
router.post('/restore', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { snapshot } = req.body;

  if (!snapshot || !snapshot.id || !snapshot.email || !snapshot.name) {
    return res.status(400).json({ error: 'Données de restauration incomplètes' });
  }

  // Le snapshot peut contenir soit `roles: string[]` (nouveau format), soit `role: string` (legacy).
  let snapshotRoles = Array.isArray(snapshot.roles) ? snapshot.roles : (snapshot.role ? [snapshot.role] : ['hospitalStaff']);
  snapshotRoles = snapshotRoles.filter((r) => VALID_ROLES.includes(r));
  if (snapshotRoles.length === 0) snapshotRoles = ['hospitalStaff'];

  const tempPassword = crypto.randomBytes(8).toString('hex');
  const passwordHash = await bcrypt.hash(tempPassword, 10);

  try {
    const tx = db.transaction(() => {
      db.prepare(`
        INSERT INTO users (id, name, first_name, last_name, email, password_hash, department, phone, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
      `).run(snapshot.id, snapshot.name, snapshot.first_name || null, snapshot.last_name || null,
             snapshot.email, passwordHash, snapshot.department || null,
             snapshot.phone || null, new Date().toISOString());
      setUserRoles(db, snapshot.id, snapshotRoles);
    });
    tx();

    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'restore_user', target_type: 'user',
      target_id: snapshot.id, target_name: snapshot.name,
      details: { roles: snapshotRoles },
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
    'SELECT id, name, first_name, last_name, email, department, phone, is_active, created_at FROM users WHERE id = ?'
  ).get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });
  res.json(attachRoles(db, user));
});

// POST /api/users — créer un utilisateur (admin seulement)
router.post('/', verifyToken, requireAdmin, async (req, res) => {
  const { first_name, last_name, name: rawName, email, password, department, roles, phone } = req.body;

  // Supporter first_name/last_name ou name legacy
  const firstName = first_name || (rawName ? rawName.split(' ')[0] : '');
  const lastName = last_name || (rawName ? rawName.split(' ').slice(1).join(' ') : '');
  const name = `${firstName} ${lastName}`.trim();

  if (!name || !email || !password || !department) {
    return res.status(400).json({ error: 'Champs requis: first_name, last_name, email, password, department, roles' });
  }

  if (!Array.isArray(roles) || roles.length === 0) {
    return res.status(400).json({ error: 'Au moins un rôle est requis (champ `roles` doit être un tableau non vide)' });
  }

  const invalidRoles = roles.filter((r) => !VALID_ROLES.includes(r));
  if (invalidRoles.length > 0) {
    return res.status(400).json({ error: `Rôle(s) invalide(s): ${invalidRoles.join(', ')}. Valeurs acceptées: ${VALID_ROLES.join(', ')}` });
  }

  try {
    const db = getDb();
    const id = `user-${crypto.randomUUID()}`;
    const passwordHash = await bcrypt.hash(password, 10);
    const createdAt = new Date().toISOString();

    const tx = db.transaction(() => {
      db.prepare(`
        INSERT INTO users (id, name, first_name, last_name, email, password_hash, department, phone, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
      `).run(id, name, firstName, lastName, email, passwordHash, department, phone || null, createdAt);
      setUserRoles(db, id, roles);
    });
    tx();

    console.log(`[AUDIT] Utilisateur créé: ${email} (id: ${id}, rôles: ${roles.join(',')}) par ${req.user.email}`);

    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'create_user', target_type: 'user', target_id: id, target_name: name,
      details: { email, roles, department },
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
  const { first_name, last_name, name: rawName, email, password, department, roles, phone } = req.body;
  const db = getDb();

  const existing = db.prepare('SELECT id, name, first_name, last_name, email, phone, department FROM users WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Utilisateur introuvable' });
  const existingRoles = getUserRoles(db, req.params.id);

  // Valider les nouveaux rôles si fournis
  if (roles !== undefined) {
    if (!Array.isArray(roles) || roles.length === 0) {
      return res.status(400).json({ error: 'Le champ `roles` doit être un tableau non vide' });
    }
    const invalidRoles = roles.filter((r) => !VALID_ROLES.includes(r));
    if (invalidRoles.length > 0) {
      return res.status(400).json({ error: `Rôle(s) invalide(s): ${invalidRoles.join(', ')}. Valeurs acceptées: ${VALID_ROLES.join(', ')}` });
    }
  }

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
    const tx = db.transaction(() => {
      if (passwordHash) {
        db.prepare(`
          UPDATE users
          SET name = COALESCE(?, name),
              first_name = COALESCE(?, first_name),
              last_name = COALESCE(?, last_name),
              email = COALESCE(?, email),
              password_hash = ?,
              department = COALESCE(?, department),
              phone = COALESCE(?, phone)
          WHERE id = ?
        `).run(computedName, newFirstName, newLastName, email, passwordHash, department, phone, req.params.id);
      } else {
        db.prepare(`
          UPDATE users
          SET name = COALESCE(?, name),
              first_name = COALESCE(?, first_name),
              last_name = COALESCE(?, last_name),
              email = COALESCE(?, email),
              department = COALESCE(?, department),
              phone = COALESCE(?, phone)
          WHERE id = ?
        `).run(computedName, newFirstName, newLastName, email, department, phone, req.params.id);
      }
      if (roles !== undefined) {
        setUserRoles(db, req.params.id, roles);
      }
    });
    tx();
    const name = computedName;

    console.log(`[AUDIT] Utilisateur modifié: ${req.params.id} par ${req.user.email}`);

    // Détecter précisément ce qui a changé
    const changes = {};
    if (name     && name     !== existing.name)       changes.name  = { old: existing.name,  new: name };
    if (email    && email    !== existing.email)       changes.email = { old: existing.email, new: email };
    if (phone    && phone    !== existing.phone)       changes.phone = { old: existing.phone, new: phone };
    if (department && department !== existing.department) changes.department = { old: existing.department, new: department };
    if (password) changes.password = 'modifié';

    // Diff de rôles (ajoutés / retirés)
    let rolesChanged = false;
    if (roles !== undefined) {
      const added = roles.filter((r) => !existingRoles.includes(r));
      const removed = existingRoles.filter((r) => !roles.includes(r));
      if (added.length || removed.length) {
        rolesChanged = true;
        changes.roles = { old: existingRoles, new: roles, added, removed };
      }
    }

    // Un log par type de modification pour plus de clarté
    if (password) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
        action: 'change_password', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        ...reqMeta(req),
      });
    }
    if (name && name !== existing.name) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
        action: 'change_name', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: { old: existing.name, new: name },
        ...reqMeta(req),
      });
    }
    if (email && email !== existing.email) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
        action: 'change_email', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: { old: existing.email, new: email },
        ...reqMeta(req),
      });
    }
    if (phone && phone !== existing.phone) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
        action: 'change_phone', target_type: 'user',
        target_id: req.params.id, target_name: existing.name,
        details: { old: existing.phone, new: phone },
        ...reqMeta(req),
      });
    }
    // Si rôles ou département ont changé sans cas spécifique
    if (rolesChanged || (department && department !== existing.department)) {
      sendLog({
        user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
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
  const user = db.prepare('SELECT id, name, is_active FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });

  const newStatus = user.is_active ? 0 : 1;
  db.prepare('UPDATE users SET is_active = ? WHERE id = ?').run(newStatus, req.params.id);

  console.log(`[AUDIT] Utilisateur ${newStatus ? 'activé' : 'désactivé'}: ${req.params.id} par ${req.user.email}`);

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
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
    return res.status(400).json({ error: 'Cannot delete your own account' });
  }
  let reason = req.query.reason;
  if (reason && reason.length > 200) reason = reason.substring(0, 200);
  const target = db.prepare('SELECT id, name, first_name, last_name, email, department, phone FROM users WHERE id = ?').get(req.params.id);
  if (!target) return res.status(404).json({ error: 'Utilisateur introuvable' });
  const targetRoles = getUserRoles(db, req.params.id);

  db.prepare('DELETE FROM users WHERE id = ?').run(req.params.id);

  console.log(`[AUDIT] Utilisateur supprimé: ${req.params.id} par ${req.user.email}`);

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
    action: 'delete_user', target_type: 'user',
    target_id: req.params.id, target_name: target.name,
    details: { snapshot: { ...target, roles: targetRoles }, ...(reason ? { reason } : {}) },
    ...reqMeta(req),
  });

  res.json({ message: 'Utilisateur supprimé' });
});

// ── Demandes de changement de département ──────────────────────────────────

// PUT /api/users/me/department  (changement direct si permission changeDepartment)
router.put('/me/department', verifyToken, (req, res) => {
  const db = getDb();
  const { department } = req.body;
  if (!department) {
    return res.status(400).json({ error: 'Département requis' });
  }
  const user = db.prepare('SELECT id, name, department FROM users WHERE id = ?').get(req.user.id);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });

  // Vérifier la permission changeDepartment via l'union des permissions des rôles
  const userRoles = getUserRoles(db, user.id);
  const isAdmin = userRoles.includes('admin');
  if (!isAdmin) {
    const perms = getUserPermissions(db, user.id);
    if (!perms.includes('changeDepartment')) {
      return res.status(403).json({ error: 'Permission insuffisante' });
    }
  }

  db.prepare('UPDATE users SET department = ? WHERE id = ?').run(department, user.id);

  sendLog({
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
    action: 'direct_dept_change', target_type: 'user',
    target_id: user.id, target_name: user.name,
    details: { from: user.department, to: department },
    ...reqMeta(req),
  });

  res.json({ message: 'Département mis à jour', department });
});

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
  const id = crypto.randomUUID();
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
    user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
    action: status === 'approved' ? 'approve_dept_request' : 'reject_dept_request',
    target_type: 'user', target_id: request.user_id, target_name: request.user_name,
    details: { from: request.current_department, to: request.requested_department, admin_note },
    ...reqMeta(req),
  });

  res.json({ message: status === 'approved' ? 'Demande approuvée, département mis à jour' : 'Demande rejetée' });
});

module.exports = router;
