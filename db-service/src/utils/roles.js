// ── Constantes et helpers partagés entre toutes les routes du db-service ─────

const { SYSTEM_ROLES } = require('../middleware/auth');

// Rôles techniciens spécialisés — utilisés dans requireRole() et les filtres métier.
const TECH_ROLES = ['technician_biomedical', 'technician_it', 'technician_infra'];

/**
 * Sérialise les rôles applicatifs du user (hors rôles systèmes Keycloak)
 * pour la colonne `user_role` des logs d'audit.
 * @param {import('express').Request} req
 * @returns {string}
 */
const rolesCsv = (req) =>
  (Array.isArray(req.user?.roles) ? req.user.roles : [])
    .filter((r) => !SYSTEM_ROLES.has(r))
    .join(',');

/**
 * Vérifie si l'utilisateur de la requête possède au moins un des rôles spécifiés.
 * Remplace les `Array.isArray(req.user.roles) && req.user.roles.includes(...)` inline.
 * @param {import('express').Request} req
 * @param {...string} roles
 * @returns {boolean}
 */
const hasRole = (req, ...roles) =>
  Array.isArray(req.user?.roles) && roles.some((r) => req.user.roles.includes(r));

module.exports = { TECH_ROLES, rolesCsv, hasRole };
