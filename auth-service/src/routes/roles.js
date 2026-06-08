// ── Routes de gestion des rôles ───────────────────────────────────────────────
// Les rôles sont stockés dans Keycloak (realm roles).
// Les permissions applicatives restent dans la table SQLite `role_permissions`.
// L'API retourne le même shape qu'avant pour ne pas casser le client Flutter.

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { kcAdminFetch } = require('../utils/keycloakAdmin');

const router = express.Router();

// Rôles système Keycloak à masquer dans les réponses API
const SYSTEM_ROLES = new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']);

// Liste blanche des permissions valides
const VALID_PERMISSIONS = [
  'viewEquipment', 'reportIssue', 'trackIssues', 'approveRequests', 'assignTasks',
  'updateRepairs', 'registerParts', 'manageEquipment', 'manageUsers',
  'manageDepartments', 'manageCategories', 'generateReports', 'viewInventory',
  'changeDepartment',
];

// ── GET /api/roles — rôles Keycloak enrichis des permissions SQLite ────────────
router.get('/', verifyToken, requireAdmin, async (req, res) => {
  try {
    const resp = await kcAdminFetch('/roles');
    if (!resp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
    const kcRoles = await resp.json();

    const db = getDb();
    const result = kcRoles
      .filter((r) => !SYSTEM_ROLES.has(r.name))
      .map((r) => {
        const perms = db.prepare('SELECT permission FROM role_permissions WHERE role_name = ? ORDER BY permission')
          .all(r.name).map((p) => p.permission);
        return {
          name:        r.name,
          display_name: r.name,
          description: r.description ?? '',
          is_builtin:  r.composite ? 0 : 1,
          permissions: perms,
        };
      });

    res.json(result);
  } catch (err) {
    console.error('[ROLES] Erreur GET /roles:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── POST /api/roles — créer un rôle personnalisé (admin) ──────────────────────
router.post('/', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { name, display_name, description, permissions = [] } = req.body;

  if (!name || !display_name) {
    return res.status(400).json({ error: 'name et display_name sont requis' });
  }
  if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(name)) {
    return res.status(400).json({ error: 'Le nom du rôle ne doit contenir que des lettres, chiffres et underscores' });
  }

  const invalidPerms = permissions.filter((p) => !VALID_PERMISSIONS.includes(p));
  if (invalidPerms.length > 0) {
    return res.status(400).json({ error: `Permissions invalides : ${invalidPerms.join(', ')}` });
  }

  try {
    // Créer dans Keycloak
    const kcResp = await kcAdminFetch('/roles', {
      method: 'POST',
      body:   JSON.stringify({ name, description: description || '' }),
    });
    if (kcResp.status === 409) return res.status(409).json({ error: 'Un rôle avec ce nom existe déjà' });
    if (!kcResp.ok) return res.status(502).json({ error: 'Erreur Keycloak lors de la création du rôle' });

    // Insérer les permissions dans SQLite
    db.transaction(() => {
      const insertPerm = db.prepare('INSERT OR IGNORE INTO role_permissions (role_name, permission) VALUES (?, ?)');
      for (const perm of permissions) insertPerm.run(name, perm);
    })();

    res.status(201).json({ name, display_name, description, is_builtin: 0, permissions });
  } catch (err) {
    console.error('[ROLES] Erreur POST /roles:', err.message);
    res.status(500).json({ error: 'Erreur lors de la création du rôle' });
  }
});

// ── PUT /api/roles/:name/permissions — modifier les permissions (admin) ────────
// Keycloak ne connaît pas les permissions applicatives : mise à jour SQLite uniquement.
router.put('/:name/permissions', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { name } = req.params;
  const { permissions } = req.body;

  if (!Array.isArray(permissions)) {
    return res.status(400).json({ error: 'permissions doit être un tableau' });
  }
  const invalidPerms = permissions.filter((p) => !VALID_PERMISSIONS.includes(p));
  if (invalidPerms.length > 0) {
    return res.status(400).json({ error: `Permissions invalides : ${invalidPerms.join(', ')}` });
  }
  if (name === 'admin') {
    return res.status(403).json({ error: 'Les permissions du rôle administrateur ne peuvent pas être modifiées' });
  }

  // Vérifier que le rôle existe dans Keycloak
  const kcResp = await kcAdminFetch(`/roles/${encodeURIComponent(name)}`);
  if (kcResp.status === 404) return res.status(404).json({ error: 'Rôle introuvable' });

  db.transaction(() => {
    db.prepare('DELETE FROM role_permissions WHERE role_name = ?').run(name);
    const ins = db.prepare('INSERT INTO role_permissions (role_name, permission) VALUES (?, ?)');
    for (const perm of permissions) ins.run(name, perm);
  })();

  res.json({ message: 'Permissions mises à jour', role: name, permissions });
});

// ── GET /api/roles/:name/permissions — permissions d'un rôle spécifique ────────
router.get('/:name/permissions', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { name } = req.params;
  const perms = db.prepare('SELECT permission FROM role_permissions WHERE role_name = ? ORDER BY permission')
    .all(name).map((p) => p.permission);
  res.json({ role: name, permissions: perms });
});

// ── GET /api/roles/:name/hierarchy — hiérarchie parent/enfants d'un rôle ───────
router.get('/:name/hierarchy', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { name } = req.params;
  const parentRow  = db.prepare('SELECT parent_role FROM role_hierarchy WHERE child_role = ?').get(name);
  const childRows  = db.prepare('SELECT child_role FROM role_hierarchy WHERE parent_role = ? ORDER BY child_role').all(name);
  res.json({
    parent:        parentRow ? parentRow.parent_role : null,
    children:      childRows.map((r) => r.child_role),
    inheritedFrom: parentRow ? parentRow.parent_role : null,
  });
});

// ── GET /api/roles/:name/users — utilisateurs Keycloak ayant ce rôle ────────────
router.get('/:name/users', verifyToken, requireAdmin, async (req, res) => {
  const { name } = req.params;
  const page  = Math.max(1, parseInt(req.query.page  || '1', 10));
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit || '20', 10)));
  const first = (page - 1) * limit;
  try {
    // Récupère la page demandée
    const resp = await kcAdminFetch(`/roles/${encodeURIComponent(name)}/users?first=${first}&max=${limit}`);
    if (!resp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
    const users = await resp.json();
    // Comptage total (appel séparé avec max élevé — acceptable pour des listes de rôles)
    const countResp = await kcAdminFetch(`/roles/${encodeURIComponent(name)}/users?max=500`);
    const total = countResp.ok ? (await countResp.json()).length : users.length;
    res.json({
      users: users.map((u) => ({
        id:       u.id,
        name:     `${u.firstName ?? ''} ${u.lastName ?? ''}`.trim() || u.username || '',
        email:    u.email    ?? '',
        username: u.username ?? '',
      })),
      total,
      page,
      limit,
    });
  } catch (err) {
    console.error(`[ROLES] Erreur GET /roles/${name}/users:`, err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── DELETE /api/roles/:name — supprimer un rôle personnalisé (admin) ───────────
router.delete('/:name', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { name } = req.params;

  // Vérifier que le rôle existe dans Keycloak et n'est pas un rôle intégré essentiel
  const builtinRoles = new Set(['hospitalStaff', 'supervisor', 'technician_biomedical',
    'technician_it', 'technician_infra', 'technician', 'admin']);
  if (builtinRoles.has(name)) {
    return res.status(400).json({ error: 'Impossible de supprimer un rôle intégré' });
  }

  const kcResp = await kcAdminFetch(`/roles/${encodeURIComponent(name)}`);
  if (kcResp.status === 404) return res.status(404).json({ error: 'Rôle introuvable' });

  const deleteResp = await kcAdminFetch(`/roles/${encodeURIComponent(name)}`, { method: 'DELETE' });
  if (!deleteResp.ok) return res.status(502).json({ error: 'Erreur Keycloak lors de la suppression' });

  db.prepare('DELETE FROM role_permissions WHERE role_name = ?').run(name);

  res.json({ message: 'Rôle supprimé', name });
});

module.exports = router;
