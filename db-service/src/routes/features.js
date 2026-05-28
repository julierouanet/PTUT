const express = require('express');
const { getDb } = require('../database');
const { verifyToken, requireRole } = require('../middleware/auth');
const { logAction, extractReqMeta } = require('../utils/logger');

const router = express.Router();

// ── GET /api/features ──────────────────────────────────────────────────────────
// Retourne la liste des features avec leurs overrides par rôle.
// Réservé aux admins.
router.get('/', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const features = db.prepare('SELECT * FROM features ORDER BY id ASC').all();
  const overridesStmt = db.prepare(
    'SELECT role_name, is_active FROM feature_role_overrides WHERE feature_id = ?'
  );

  const result = features.map((f) => {
    const overrides = overridesStmt.all(f.id);
    const roleOverrides = {};
    for (const o of overrides) {
      roleOverrides[o.role_name] = o.is_active === 1;
    }
    return {
      id:               f.id,
      name:             f.name,
      description:      f.description,
      is_global_active: f.is_global_active === 1,
      role_overrides:   roleOverrides,
    };
  });

  res.json(result);
});

// ── PUT /api/features/:id ──────────────────────────────────────────────────────
// Met à jour le statut global et le tableau des overrides par rôle.
// Réservé aux admins.
router.put('/:id', verifyToken, requireRole('admin'), (req, res) => {
  const db = getDb();
  const { id } = req.params;
  const { is_global_active, role_overrides } = req.body;

  if (typeof is_global_active !== 'boolean') {
    return res.status(400).json({ error: 'is_global_active (boolean) requis' });
  }

  const existing = db.prepare('SELECT * FROM features WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Feature introuvable' });

  db.transaction(() => {
    db.prepare('UPDATE features SET is_global_active = ? WHERE id = ?')
      .run(is_global_active ? 1 : 0, id);

    if (role_overrides && typeof role_overrides === 'object') {
      db.prepare('DELETE FROM feature_role_overrides WHERE feature_id = ?').run(id);
      const insertOverride = db.prepare(
        'INSERT INTO feature_role_overrides (feature_id, role_name, is_active) VALUES (?, ?, ?)'
      );
      for (const [roleName, isActive] of Object.entries(role_overrides)) {
        insertOverride.run(id, roleName, isActive ? 1 : 0);
      }
    }
  })();

  logAction({
    user_id:     req.user.id,
    user_name:   req.user.name,
    user_role:   req.user.roles[0],
    action:      'update_feature_flag',
    target_type: 'feature',
    target_id:   id,
    target_name: existing.name,
    details:     { is_global_active, role_overrides: role_overrides || {} },
    ...extractReqMeta(req),
  });

  res.json({ message: 'Feature mise a jour' });
});

module.exports = router;
