// ── Routes de gestion des utilisateurs ───────────────────────────────────────
// Proxy vers Keycloak Admin REST API.
// Les demandes de changement de département restent dans SQLite (auth.db).

'use strict';

const express = require('express');
const crypto  = require('crypto');
const { getDb } = require('../database');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { sendLog, reqMeta } = require('../utils/logger');
const {
  kcAdminFetch,
  assignRolesToUser,
  removeRolesFromUser,
  getUserRoleNames,
  mapKcUser,
} = require('../utils/keycloakAdmin');

const router = express.Router();

// Rôles assignables (le rôle générique `technician` est déprécié)
const VALID_ROLES = ['hospitalStaff', 'supervisor', 'technician_biomedical', 'technician_it', 'technician_infra', 'admin'];

// Rôles qu'un utilisateur peut demander lui-même (admin exclu volontairement)
const REQUESTABLE_ROLES = ['supervisor', 'technician_biomedical', 'technician_it', 'technician_infra'];

const rolesCsv = (roles) => (Array.isArray(roles) ? roles.join(',') : '');

// Retourne les permissions d'un ensemble de rôles (lus depuis role_permissions SQLite)
function getPermissionsForRoles(db, roles) {
  if (!roles || roles.length === 0) return [];
  const ph = roles.map(() => '?').join(',');
  return db.prepare(`SELECT DISTINCT permission FROM role_permissions WHERE role_name IN (${ph})`)
    .all(...roles).map((r) => r.permission);
}

// ── GET /api/users ─────────────────────────────────────────────────────────────
// Sans ?role : liste complète (admin). Avec ?role=X : users ayant ce rôle (authentifié).
router.get('/', verifyToken, async (req, res) => {
  const { role } = req.query;
  try {
    if (role) {
      const resp = await kcAdminFetch(`/roles/${encodeURIComponent(role)}/users?max=200`);
      if (!resp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
      const users = await resp.json();
      return res.json(users.map((u) => mapKcUser(u, [role])));
    }

    // Listing complet : admin uniquement
    if (!req.user.roles.includes('admin')) {
      return res.status(403).json({ error: 'Access restricted to administrators' });
    }

    const resp = await kcAdminFetch('/users?max=200&briefRepresentation=false');
    if (!resp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
    const users = await resp.json();

    // Enrichir avec les rôles (appels parallèles)
    const usersWithRoles = await Promise.all(
      users.map(async (u) => {
        const roles = await getUserRoleNames(u.id);
        return mapKcUser(u, roles);
      }),
    );
    res.json(usersWithRoles);
  } catch (err) {
    console.error('[USERS] Erreur GET /users:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── POST /api/users — créer un utilisateur (admin) ────────────────────────────
router.post('/', verifyToken, requireAdmin, async (req, res) => {
  const { first_name, last_name, name: rawName, email, password, department, roles, phone } = req.body;

  const firstName = first_name || (rawName ? rawName.split(' ')[0] : '');
  const lastName  = last_name  || (rawName ? rawName.split(' ').slice(1).join(' ') : '');

  if (!email || !password || !department) {
    return res.status(400).json({ error: 'Champs requis: email, password, department, roles' });
  }
  if (!Array.isArray(roles) || roles.length === 0) {
    return res.status(400).json({ error: 'Au moins un rôle est requis' });
  }
  const invalidRoles = roles.filter((r) => !VALID_ROLES.includes(r));
  if (invalidRoles.length > 0) {
    return res.status(400).json({ error: `Rôle(s) invalide(s): ${invalidRoles.join(', ')}` });
  }

  try {
    // 1. Créer l'utilisateur dans Keycloak
    const createResp = await kcAdminFetch('/users', {
      method: 'POST',
      body:   JSON.stringify({
        username:    email,
        email,
        firstName,
        lastName,
        enabled:     true,
        attributes: {
          department: [department],
          ...(phone ? { phone: [phone] } : {}),
        },
      }),
    });

    if (createResp.status === 409) {
      return res.status(409).json({ error: 'Email déjà utilisé' });
    }
    if (!createResp.ok) {
      const body = await createResp.text();
      console.error('[USERS] Keycloak create user error:', body);
      return res.status(502).json({ error: 'Erreur lors de la création dans Keycloak' });
    }

    const location = createResp.headers.get('Location') ?? '';
    const kcId = location.split('/').pop();

    // 2. Définir le mot de passe
    const pwdResp = await kcAdminFetch(`/users/${kcId}/reset-password`, {
      method: 'PUT',
      body:   JSON.stringify({ type: 'password', value: password, temporary: false }),
    });
    if (!pwdResp.ok) {
      console.error('[USERS] Keycloak set password error:', pwdResp.status);
    }

    // 3. Assigner les rôles
    await assignRolesToUser(kcId, roles);

    console.log(`[AUDIT] Utilisateur créé: ${email} (kcId: ${kcId}) par ${req.user.email}`);
    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'create_user', target_type: 'user', target_id: kcId,
      target_name: `${firstName} ${lastName}`.trim() || email,
      details: { email, roles, department },
      ...reqMeta(req),
    });

    res.status(201).json({ message: 'Utilisateur créé', id: kcId });
  } catch (err) {
    console.error('[USERS] Erreur POST /users:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── PUT /api/users/:id — modifier un utilisateur (admin) ──────────────────────
router.put('/:id', verifyToken, requireAdmin, async (req, res) => {
  const { first_name, last_name, email, password, department, roles, phone } = req.body;
  const { id } = req.params;

  try {
    // Récupérer l'état actuel pour l'audit
    const currentResp = await kcAdminFetch(`/users/${id}`);
    if (currentResp.status === 404) return res.status(404).json({ error: 'Utilisateur introuvable' });
    if (!currentResp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
    const current = await currentResp.json();
    const currentRoles = await getUserRoleNames(id);

    // Valider les nouveaux rôles si fournis
    if (roles !== undefined) {
      if (!Array.isArray(roles) || roles.length === 0) {
        return res.status(400).json({ error: 'Le champ `roles` doit être un tableau non vide' });
      }
      const invalidRoles = roles.filter((r) => !VALID_ROLES.includes(r));
      if (invalidRoles.length > 0) {
        return res.status(400).json({ error: `Rôle(s) invalide(s): ${invalidRoles.join(', ')}` });
      }
    }

    // Construire le corps de mise à jour Keycloak
    const updateBody = {
      ...(first_name  !== undefined && { firstName: first_name }),
      ...(last_name   !== undefined && { lastName:  last_name }),
      ...(email       !== undefined && { email, username: email }),
      attributes: {
        ...(current.attributes ?? {}),
        ...(department !== undefined && { department: [department] }),
        ...(phone      !== undefined && { phone: phone ? [phone] : [] }),
      },
    };

    const updateResp = await kcAdminFetch(`/users/${id}`, {
      method: 'PUT',
      body:   JSON.stringify(updateBody),
    });
    if (updateResp.status === 409) return res.status(409).json({ error: 'Email déjà utilisé' });
    if (!updateResp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });

    // Mise à jour du mot de passe si fourni
    if (password) {
      await kcAdminFetch(`/users/${id}/reset-password`, {
        method: 'PUT',
        body:   JSON.stringify({ type: 'password', value: password, temporary: false }),
      });
    }

    // Diff des rôles et mise à jour
    if (roles !== undefined) {
      const toAdd    = roles.filter((r) => !currentRoles.includes(r));
      const toRemove = currentRoles.filter((r) => !roles.includes(r));
      if (toAdd.length)    await assignRolesToUser(id, toAdd);
      if (toRemove.length) await removeRolesFromUser(id, toRemove);
    }

    console.log(`[AUDIT] Utilisateur modifié: ${id} par ${req.user.email}`);
    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'update_user', target_type: 'user', target_id: id,
      target_name: `${current.firstName ?? ''} ${current.lastName ?? ''}`.trim(),
      details: { email, department, roles, passwordChanged: !!password },
      ...reqMeta(req),
    });

    res.json({ message: 'Utilisateur mis à jour' });
  } catch (err) {
    console.error('[USERS] Erreur PUT /users/:id:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── PATCH /api/users/:id/toggle — activer/désactiver (admin) ─────────────────
router.patch('/:id/toggle', verifyToken, requireAdmin, async (req, res) => {
  try {
    const currentResp = await kcAdminFetch(`/users/${req.params.id}`);
    if (currentResp.status === 404) return res.status(404).json({ error: 'Utilisateur introuvable' });
    if (!currentResp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
    const current = await currentResp.json();

    const newEnabled = !current.enabled;
    const r = await kcAdminFetch(`/users/${req.params.id}`, {
      method: 'PUT',
      body:   JSON.stringify({ enabled: newEnabled }),
    });
    if (!r.ok) return res.status(502).json({ error: 'Erreur Keycloak' });

    const targetName = `${current.firstName ?? ''} ${current.lastName ?? ''}`.trim() || current.email;
    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: newEnabled ? 'activate_user' : 'suspend_user',
      target_type: 'user', target_id: req.params.id, target_name: targetName,
      details: { new_status: newEnabled ? 'actif' : 'suspendu' },
      ...reqMeta(req),
    });

    res.json({ message: newEnabled ? 'Compte activé' : 'Compte désactivé', is_active: newEnabled ? 1 : 0 });
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── DELETE /api/users/:id (admin) ─────────────────────────────────────────────
router.delete('/:id', verifyToken, requireAdmin, async (req, res) => {
  if (req.user.id === req.params.id) {
    return res.status(400).json({ error: 'Impossible de supprimer son propre compte' });
  }

  let reason = req.query.reason;
  if (reason && reason.length > 200) reason = reason.substring(0, 200);

  try {
    const currentResp = await kcAdminFetch(`/users/${req.params.id}`);
    if (currentResp.status === 404) return res.status(404).json({ error: 'Utilisateur introuvable' });
    const current      = await currentResp.json();
    const currentRoles = await getUserRoleNames(req.params.id);

    const deleteResp = await kcAdminFetch(`/users/${req.params.id}`, { method: 'DELETE' });
    if (!deleteResp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });

    const targetName = `${current.firstName ?? ''} ${current.lastName ?? ''}`.trim() || current.email;
    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'delete_user', target_type: 'user', target_id: req.params.id, target_name: targetName,
      details: {
        snapshot: mapKcUser(current, currentRoles),
        ...(reason ? { reason } : {}),
      },
      ...reqMeta(req),
    });

    res.json({ message: 'Utilisateur supprimé' });
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── POST /api/users/restore — restaurer un utilisateur supprimé (admin) ────────
router.post('/restore', verifyToken, requireAdmin, async (req, res) => {
  const { snapshot } = req.body;
  if (!snapshot || !snapshot.email) {
    return res.status(400).json({ error: 'Données de restauration incomplètes' });
  }

  let snapshotRoles = Array.isArray(snapshot.roles) ? snapshot.roles : ['hospitalStaff'];
  snapshotRoles = snapshotRoles.filter((r) => VALID_ROLES.includes(r));
  if (snapshotRoles.length === 0) snapshotRoles = ['hospitalStaff'];

  const tempPassword = crypto.randomBytes(8).toString('hex');

  try {
    const createResp = await kcAdminFetch('/users', {
      method: 'POST',
      body:   JSON.stringify({
        username:  snapshot.email,
        email:     snapshot.email,
        firstName: snapshot.first_name || '',
        lastName:  snapshot.last_name  || '',
        enabled:   true,
        attributes: {
          department: [snapshot.department || ''],
          ...(snapshot.phone ? { phone: [snapshot.phone] } : {}),
        },
        requiredActions: ['UPDATE_PASSWORD'],
      }),
    });

    if (createResp.status === 409) return res.status(409).json({ error: 'Cet utilisateur existe déjà' });
    if (!createResp.ok) return res.status(502).json({ error: 'Erreur Keycloak lors de la restauration' });

    const location = createResp.headers.get('Location') ?? '';
    const kcId     = location.split('/').pop();

    await kcAdminFetch(`/users/${kcId}/reset-password`, {
      method: 'PUT',
      body:   JSON.stringify({ type: 'password', value: tempPassword, temporary: true }),
    });
    await assignRolesToUser(kcId, snapshotRoles);

    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'restore_user', target_type: 'user', target_id: kcId,
      target_name: snapshot.email, details: { roles: snapshotRoles },
      ...reqMeta(req),
    });

    res.status(201).json({ message: 'Utilisateur restauré', tempPassword });
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── Demandes de changement de département (SQLite — department_change_requests) ─

// PUT /api/users/me/department (changement direct si permission changeDepartment)
router.put('/me/department', verifyToken, async (req, res) => {
  const { department } = req.body;
  if (!department) return res.status(400).json({ error: 'Département requis' });

  const db          = getDb();
  const isAdmin     = req.user.roles.includes('admin');
  const permissions = getPermissionsForRoles(db, req.user.roles);
  if (!isAdmin && !permissions.includes('changeDepartment')) {
    return res.status(403).json({ error: 'Permission insuffisante' });
  }

  try {
    const r = await kcAdminFetch(`/users/${req.user.id}`, {
      method: 'PUT',
      body:   JSON.stringify({ attributes: { department: [department] } }),
    });
    if (!r.ok) return res.status(502).json({ error: 'Erreur Keycloak' });

    sendLog({
      user_id: req.user.id, user_name: req.user.name, user_role: rolesCsv(req.user.roles),
      action: 'direct_dept_change', target_type: 'user',
      target_id: req.user.id, target_name: req.user.name,
      details: { from: req.user.department, to: department },
      ...reqMeta(req),
    });

    res.json({ message: 'Département mis à jour', department });
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// POST /api/users/department-request
router.post('/department-request', verifyToken, (req, res) => {
  const db = getDb();
  const { requested_department } = req.body;
  if (!requested_department) return res.status(400).json({ error: 'Département demandé requis' });
  if (req.user.department === requested_department) {
    return res.status(400).json({ error: 'Vous êtes déjà dans ce département' });
  }

  const existing = db.prepare(
    "SELECT id FROM department_change_requests WHERE user_id = ? AND status = 'pending'"
  ).get(req.user.id);
  if (existing) return res.status(409).json({ error: 'Une demande est déjà en attente' });

  const id = crypto.randomUUID();
  db.prepare(`
    INSERT INTO department_change_requests (id, user_id, user_name, current_department, requested_department, status, created_at)
    VALUES (?, ?, ?, ?, ?, 'pending', ?)
  `).run(id, req.user.id, req.user.name, req.user.department, requested_department, new Date().toISOString());

  res.status(201).json({ id, message: 'Demande envoyée, en attente de validation admin' });
});

// GET /api/users/department-requests (admin)
router.get('/department-requests', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { status } = req.query;
  let query = 'SELECT * FROM department_change_requests';
  const params = [];
  if (status) { query += ' WHERE status = ?'; params.push(status); }
  query += ' ORDER BY created_at DESC';
  res.json(db.prepare(query).all(...params));
});

// PUT /api/users/department-requests/:id (admin approuve ou rejette)
router.put('/department-requests/:id', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { status, admin_note } = req.body;
  if (!['approved', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'Statut invalide (approved | rejected)' });
  }

  const request = db.prepare('SELECT * FROM department_change_requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ error: 'Demande introuvable' });
  if (request.status !== 'pending') return res.status(409).json({ error: 'Demande déjà traitée' });

  const now = new Date().toISOString();
  db.prepare(`
    UPDATE department_change_requests
    SET status = ?, admin_id = ?, admin_note = ?, resolved_at = ?
    WHERE id = ?
  `).run(status, req.user.id, admin_note || null, now, req.params.id);

  if (status === 'approved') {
    try {
      await kcAdminFetch(`/users/${request.user_id}`, {
        method: 'PUT',
        body:   JSON.stringify({ attributes: { department: [request.requested_department] } }),
      });
    } catch (err) {
      console.error('[USERS] Erreur mise à jour département Keycloak:', err.message);
    }
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

// ── Demandes de changement de rôle (SQLite — role_change_requests) ─────────────

// POST /api/users/role-request
router.post('/role-request', verifyToken, (req, res) => {
  const db = getDb();
  const { requested_role } = req.body;

  if (!requested_role) return res.status(400).json({ error: 'Rôle demandé requis' });
  if (!REQUESTABLE_ROLES.includes(requested_role)) {
    return res.status(400).json({ error: `Rôle invalide. Valeurs possibles : ${REQUESTABLE_ROLES.join(', ')}` });
  }
  if (req.user.roles.includes(requested_role)) {
    return res.status(400).json({ error: 'Vous avez déjà ce rôle' });
  }

  const existing = db.prepare(
    "SELECT id FROM role_change_requests WHERE user_id = ? AND requested_role = ? AND status = 'pending'"
  ).get(req.user.id, requested_role);
  if (existing) return res.status(409).json({ error: 'Une demande pour ce rôle est déjà en attente' });

  const id = crypto.randomUUID();
  db.prepare(`
    INSERT INTO role_change_requests (id, user_id, user_name, current_roles, requested_role, status, created_at)
    VALUES (?, ?, ?, ?, ?, 'pending', ?)
  `).run(id, req.user.id, req.user.name, JSON.stringify(req.user.roles), requested_role, new Date().toISOString());

  res.status(201).json({ id, message: 'Demande de rôle envoyée, en attente de validation admin' });
});

// GET /api/users/role-requests (admin)
router.get('/role-requests', verifyToken, requireAdmin, (req, res) => {
  const db = getDb();
  const { status } = req.query;
  let query = 'SELECT * FROM role_change_requests';
  const params = [];
  if (status) { query += ' WHERE status = ?'; params.push(status); }
  query += ' ORDER BY created_at DESC';
  res.json(db.prepare(query).all(...params));
});

// PUT /api/users/role-requests/:id (admin approuve ou rejette)
router.put('/role-requests/:id', verifyToken, requireAdmin, async (req, res) => {
  const db = getDb();
  const { status, admin_note } = req.body;

  if (!['approved', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'Statut invalide (approved | rejected)' });
  }

  const request = db.prepare('SELECT * FROM role_change_requests WHERE id = ?').get(req.params.id);
  if (!request) return res.status(404).json({ error: 'Demande introuvable' });
  if (request.status !== 'pending') return res.status(409).json({ error: 'Demande déjà traitée' });

  const now = new Date().toISOString();
  db.prepare(`
    UPDATE role_change_requests
    SET status = ?, admin_id = ?, admin_note = ?, resolved_at = ?
    WHERE id = ?
  `).run(status, req.user.id, admin_note || null, now, req.params.id);

  if (status === 'approved') {
    try {
      await assignRolesToUser(request.user_id, [request.requested_role]);
    } catch (err) {
      console.error('[USERS] Erreur assignation rôle Keycloak:', err.message);
    }
  }

  sendLog({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   rolesCsv(req.user.roles),
    action:      status === 'approved' ? 'approve_role_request' : 'reject_role_request',
    target_type: 'user',
    target_id:   request.user_id,
    target_name: request.user_name,
    details:     { requested_role: request.requested_role, admin_note },
    ...reqMeta(req),
  });

  res.json({
    message: status === 'approved'
      ? 'Demande approuvée, rôle assigné dans Keycloak'
      : 'Demande rejetée',
  });
});

// ── POST /api/users/:id/send-verify-email ────────────────────────────────────
router.post('/:id/send-verify-email', verifyToken, requireAdmin, async (req, res) => {
  try {
    const r = await kcAdminFetch(`/users/${req.params.id}/send-verify-email`, { method: 'PUT' });
    if (r.status === 404) return res.status(404).json({ error: 'Utilisateur introuvable' });
    if (!r.ok) return res.status(502).json({ error: 'Erreur Keycloak lors de l\'envoi' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── GET /api/users/me/notifications ───────────────────────────────────────────
// Retourne les préférences de notification email de l'utilisateur connecté.
// Crée une entrée par défaut (tout activé, non configuré) si elle n'existe pas.
router.get('/me/notifications', verifyToken, (req, res) => {
  const db     = getDb();
  const userId = req.user.id;

  let prefs = db.prepare(
    'SELECT * FROM user_notification_preferences WHERE user_id = ?'
  ).get(userId);

  // Initialise des préférences par défaut si l'utilisateur n'en a pas encore
  if (!prefs) {
    db.prepare(`
      INSERT INTO user_notification_preferences
        (user_id, notify_new_issue, notify_issue_assigned, notify_issue_resolved,
         notify_issue_status_update, notify_pm_due, preferences_set)
      VALUES (?, 1, 1, 1, 1, 1, 0)
    `).run(userId);
    prefs = db.prepare(
      'SELECT * FROM user_notification_preferences WHERE user_id = ?'
    ).get(userId);
  }

  res.json({
    notify_new_issue:           !!prefs.notify_new_issue,
    notify_issue_assigned:      !!prefs.notify_issue_assigned,
    notify_issue_resolved:      !!prefs.notify_issue_resolved,
    notify_issue_status_update: !!prefs.notify_issue_status_update,
    notify_pm_due:              !!prefs.notify_pm_due,
    preferences_set:            !!prefs.preferences_set,
    updated_at:                 prefs.updated_at,
  });
});

// ── PUT /api/users/me/notifications ───────────────────────────────────────────
// Met à jour les préférences et marque preferences_set = 1.
router.put('/me/notifications', verifyToken, (req, res) => {
  const db     = getDb();
  const userId = req.user.id;

  const toInt = (val, fallback = 1) =>
    (val === undefined || val === null) ? fallback : (val ? 1 : 0);

  const {
    notify_new_issue,
    notify_issue_assigned,
    notify_issue_resolved,
    notify_issue_status_update,
    notify_pm_due,
  } = req.body;

  db.prepare(`
    INSERT INTO user_notification_preferences
      (user_id, notify_new_issue, notify_issue_assigned, notify_issue_resolved,
       notify_issue_status_update, notify_pm_due, preferences_set, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, 1, datetime('now','localtime'))
    ON CONFLICT(user_id) DO UPDATE SET
      notify_new_issue           = excluded.notify_new_issue,
      notify_issue_assigned      = excluded.notify_issue_assigned,
      notify_issue_resolved      = excluded.notify_issue_resolved,
      notify_issue_status_update = excluded.notify_issue_status_update,
      notify_pm_due              = excluded.notify_pm_due,
      preferences_set            = 1,
      updated_at                 = excluded.updated_at
  `).run(
    userId,
    toInt(notify_new_issue),
    toInt(notify_issue_assigned),
    toInt(notify_issue_resolved),
    toInt(notify_issue_status_update),
    toInt(notify_pm_due),
  );

  res.json({ message: 'Préférences de notification mises à jour' });
});

// ── GET /api/users/:id ────────────────────────────────────────────────────────
// Placé en dernier pour ne pas masquer les routes statiques (/department-requests, etc.)
router.get('/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const resp = await kcAdminFetch(`/users/${req.params.id}`);
    if (resp.status === 404) return res.status(404).json({ error: 'Utilisateur introuvable' });
    if (!resp.ok) return res.status(502).json({ error: 'Erreur Keycloak' });
    const u = await resp.json();
    const roles = await getUserRoleNames(u.id);
    res.json(mapKcUser(u, roles));
  } catch (err) {
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

module.exports = router;
