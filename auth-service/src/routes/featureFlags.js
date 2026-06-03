// ── Routes Feature Flags ───────────────────────────────────────────────────────
// Permet à l'admin d'activer ou désactiver les modules de l'application.
// La table `feature_flags` est dans auth.db (un flag = un module).
// La table `feature_flag_overrides` stocke les exceptions par rôle Keycloak.
//
// Logique d'évaluation (côté Flutter) :
//   global.enabled = 0 → module désactivé pour tous (kill switch)
//   override présent pour le rôle → override.enabled (true/false)
//   sinon → global.enabled

'use strict';

const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireAdmin } = require('../middleware/auth');
const { sendLog, reqMeta } = require('../utils/logger');

const router = express.Router();

// Noms de rôles Keycloak autorisés comme clés d'override
const VALID_ROLES = [
  'hospitalStaff',
  'supervisor',
  'technician',
  'technician_biomedical',
  'technician_it',
  'technician_infra',
  'admin',
];

// ── GET /api/feature-flags ─────────────────────────────────────────────────────
// Retourne tous les flags avec leur état global et leurs overrides par rôle.
// Accessible à tout utilisateur authentifié (le Flutter en a besoin pour la navigation).
router.get('/', verifyToken, (req, res) => {
  try {
    const db    = getDb();
    const flags = db.prepare('SELECT id, name, description, enabled FROM feature_flags ORDER BY id').all();

    const result = flags.map((flag) => {
      const overrides = db
        .prepare('SELECT role, enabled FROM feature_flag_overrides WHERE flag_id = ?')
        .all(flag.id);

      // Convertir en objet { role: bool }
      const roleOverrides = {};
      for (const ov of overrides) {
        roleOverrides[ov.role] = ov.enabled === 1;
      }

      return {
        id:               flag.id,
        name:             flag.name,
        description:      flag.description ?? null,
        is_global_active: flag.enabled === 1,
        role_overrides:   roleOverrides,
      };
    });

    res.json(result);
  } catch (err) {
    console.error('[FEATURES] Erreur GET /feature-flags:', err.message);
    res.status(500).json({ error: 'Erreur interne du serveur' });
  }
});

// ── PUT /api/feature-flags/:id ─────────────────────────────────────────────────
// Met à jour l'état global et les overrides par rôle d'un flag.
// Réservé aux administrateurs.
router.put('/:id', verifyToken, requireAdmin, (req, res) => {
  const { id } = req.params;
  const { is_global_active, role_overrides } = req.body;

  // 1. Validation de l'entrée
  if (typeof is_global_active !== 'boolean') {
    return res.status(400).json({ error: 'is_global_active (boolean) est requis' });
  }
  if (role_overrides !== undefined && (typeof role_overrides !== 'object' || Array.isArray(role_overrides))) {
    return res.status(400).json({ error: 'role_overrides doit être un objet { role: bool }' });
  }

  // Valider les clés de role_overrides
  const overrides = role_overrides ?? {};
  for (const [role, val] of Object.entries(overrides)) {
    if (!VALID_ROLES.includes(role)) {
      return res.status(400).json({ error: `Rôle inconnu : "${role}"` });
    }
    if (typeof val !== 'boolean') {
      return res.status(400).json({ error: `La valeur de l'override pour "${role}" doit être un booléen` });
    }
  }

  // 2. Vérifier que le flag existe
  const db   = getDb();
  const flag = db.prepare('SELECT id, name FROM feature_flags WHERE id = ?').get(id);
  if (!flag) {
    return res.status(404).json({ error: `Flag "${id}" introuvable` });
  }

  // Settings ne peut jamais être désactivé (contrôle de sécurité côté serveur)
  if (id === 'settings' && !is_global_active) {
    return res.status(400).json({ error: 'Le module Settings ne peut pas être désactivé' });
  }

  // 3. Transaction : mise à jour flag + remplacement complet des overrides
  db.transaction(() => {
    db.prepare(`
      UPDATE feature_flags
      SET enabled    = ?,
          updated_at = datetime('now','localtime'),
          updated_by = ?
      WHERE id = ?
    `).run(is_global_active ? 1 : 0, req.user.id, id);

    // Remplacer tous les overrides existants
    db.prepare('DELETE FROM feature_flag_overrides WHERE flag_id = ?').run(id);

    const insertOverride = db.prepare(
      'INSERT INTO feature_flag_overrides (flag_id, role, enabled) VALUES (?, ?, ?)'
    );
    for (const [role, val] of Object.entries(overrides)) {
      insertOverride.run(id, role, val ? 1 : 0);
    }
  })();

  // 4. Audit trail
  sendLog({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0] ?? 'admin',
    action:      'update_feature_flag',
    target_type: 'feature_flag',
    target_id:   id,
    target_name: flag.name,
    details:     JSON.stringify({ is_global_active, role_overrides: overrides }),
    ...reqMeta(req),
  });

  // 5. Retourner le flag mis à jour
  const updatedOverrides = db
    .prepare('SELECT role, enabled FROM feature_flag_overrides WHERE flag_id = ?')
    .all(id);

  const responseOverrides = {};
  for (const ov of updatedOverrides) {
    responseOverrides[ov.role] = ov.enabled === 1;
  }

  res.json({
    id,
    name:             flag.name,
    is_global_active,
    role_overrides:   responseOverrides,
    message:          'Feature flag mis à jour',
  });
});

module.exports = router;
