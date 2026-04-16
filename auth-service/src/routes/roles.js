const express = require('express');
const { getDb } = require('../database');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// Liste blanche des permissions valides
const VALID_PERMISSIONS = [
  'viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks',
  'updateRepairs', 'registerParts', 'manageEquipment', 'manageUsers',
  'manageDepartments', 'manageCategories', 'generateReports', 'viewInventory',
];

// Middleware admin
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Accès réservé aux administrateurs' });
  }
  next();
};

// GET /api/roles — tous les rôles avec leurs permissions (admin seulement)
router.get('/', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const roles = db.prepare('SELECT name, display_name, description, is_builtin, created_at FROM roles ORDER BY is_builtin DESC, name ASC').all();
  const result = roles.map(role => {
    const perms = db.prepare('SELECT permission FROM role_permissions WHERE role_name = ?').all(role.name);
    return { ...role, permissions: perms.map(p => p.permission) };
  });
  res.json(result);
});

// POST /api/roles — créer un rôle personnalisé (admin)
router.post('/', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { name, display_name, description, permissions = [] } = req.body;

  if (!name || !display_name) {
    return res.status(400).json({ error: 'name et display_name sont requis' });
  }
  if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(name)) {
    return res.status(400).json({ error: 'Le nom du rôle ne doit contenir que des lettres, chiffres et underscores' });
  }

  const invalidPerms = permissions.filter(p => !VALID_PERMISSIONS.includes(p));
  if (invalidPerms.length > 0) {
    return res.status(400).json({ error: `Permissions invalides : ${invalidPerms.join(', ')}` });
  }

  const existing = db.prepare('SELECT name FROM roles WHERE name = ?').get(name);
  if (existing) {
    return res.status(409).json({ error: 'Un rôle avec ce nom existe déjà' });
  }

  try {
    db.transaction(() => {
      db.prepare('INSERT INTO roles (name, display_name, description, is_builtin) VALUES (?, ?, ?, 0)')
        .run(name, display_name, description || null);
      const insertPerm = db.prepare('INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES (?, ?)');
      for (const perm of permissions) {
        insertPerm.run(name, perm);
      }
    })();

    const created = db.prepare('SELECT name, display_name, description, is_builtin FROM roles WHERE name = ?').get(name);
    const perms = db.prepare('SELECT permission FROM role_permissions WHERE role_name = ?').all(name);
    res.status(201).json({ ...created, permissions: perms.map(p => p.permission) });
  } catch (e) {
    res.status(500).json({ error: 'Erreur lors de la création du rôle' });
  }
});

// PUT /api/roles/:name/permissions — mettre à jour les permissions d'un rôle (admin)
router.put('/:name/permissions', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { name } = req.params;
  const { permissions } = req.body;

  if (!Array.isArray(permissions)) {
    return res.status(400).json({ error: 'permissions doit être un tableau' });
  }

  const invalidPerms = permissions.filter(p => !VALID_PERMISSIONS.includes(p));
  if (invalidPerms.length > 0) {
    return res.status(400).json({ error: `Permissions invalides : ${invalidPerms.join(', ')}` });
  }

  if (name === 'admin') {
    return res.status(403).json({ error: 'Les permissions du rôle administrateur ne peuvent pas être modifiées' });
  }

  const role = db.prepare('SELECT name FROM roles WHERE name = ?').get(name);
  if (!role) return res.status(404).json({ error: 'Rôle introuvable' });

  db.transaction(() => {
    db.prepare('DELETE FROM role_permissions WHERE role_name = ?').run(name);
    const insertPerm = db.prepare('INSERT INTO role_permissions (role_name, permission) VALUES (?, ?)');
    for (const perm of permissions) {
      insertPerm.run(name, perm);
    }
  })();

  res.json({ message: 'Permissions mises à jour', role: name, permissions });
});

// DELETE /api/roles/:name — supprimer un rôle personnalisé (admin)
router.delete('/:name', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { name } = req.params;

  const role = db.prepare('SELECT name, is_builtin FROM roles WHERE name = ?').get(name);
  if (!role) return res.status(404).json({ error: 'Rôle introuvable' });
  if (role.is_builtin) return res.status(400).json({ error: 'Impossible de supprimer un rôle intégré' });

  db.prepare('DELETE FROM roles WHERE name = ?').run(name);
  res.json({ message: 'Rôle supprimé', name });
});

module.exports = router;
