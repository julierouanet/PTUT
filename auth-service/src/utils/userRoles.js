// ── Helpers centralisés pour le système multi-rôles ──────────────────────────
// Lecture / écriture des rôles d'un utilisateur dans la table de jonction
// `user_roles`, et calcul de l'union des permissions associées.

/**
 * Retourne la liste (triée alphabétiquement) des rôles d'un utilisateur.
 * @param {import('better-sqlite3').Database} db
 * @param {string} userId
 * @returns {string[]}
 */
function getUserRoles(db, userId) {
  return db
    .prepare('SELECT role_name FROM user_roles WHERE user_id = ? ORDER BY role_name')
    .all(userId)
    .map((r) => r.role_name);
}

/**
 * Retourne l'union (DISTINCT) des permissions des rôles d'un utilisateur.
 * @param {import('better-sqlite3').Database} db
 * @param {string} userId
 * @returns {string[]}
 */
function getUserPermissions(db, userId) {
  return db
    .prepare(`
      SELECT DISTINCT rp.permission
        FROM user_roles ur
        JOIN role_permissions rp ON rp.role_name = ur.role_name
       WHERE ur.user_id = ?
       ORDER BY rp.permission
    `)
    .all(userId)
    .map((r) => r.permission);
}

/**
 * Remplace les rôles d'un utilisateur par la liste fournie (transaction
 * DELETE + INSERT). Lève une erreur si un rôle n'existe pas dans la table
 * `roles` (la FK la détecterait, mais on échoue tôt avec un message clair).
 * @param {import('better-sqlite3').Database} db
 * @param {string} userId
 * @param {string[]} roles
 */
function setUserRoles(db, userId, roles) {
  const unique = Array.from(new Set(roles));
  if (unique.length === 0) {
    throw new Error('Au moins un rôle est requis');
  }

  const placeholders = unique.map(() => '?').join(',');
  const existing = db
    .prepare(`SELECT name FROM roles WHERE name IN (${placeholders})`)
    .all(...unique)
    .map((r) => r.name);
  const missing = unique.filter((r) => !existing.includes(r));
  if (missing.length > 0) {
    throw new Error(`Rôle(s) inconnu(s) : ${missing.join(', ')}`);
  }

  const tx = db.transaction(() => {
    db.prepare('DELETE FROM user_roles WHERE user_id = ?').run(userId);
    const ins = db.prepare('INSERT INTO user_roles (user_id, role_name) VALUES (?, ?)');
    for (const r of unique) {
      ins.run(userId, r);
    }
  });
  tx();
}

module.exports = { getUserRoles, getUserPermissions, setUserRoles };
