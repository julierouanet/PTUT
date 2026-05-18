module.exports = {
  PORT:             process.env.PORT             || 3002,
  DB_PATH:          process.env.DB_PATH          || 'hospital.db',
  // Conservé pour le shim de transition Phase 5 (supprimer après migration complète)
  JWT_SECRET:       process.env.JWT_SECRET       || null,
  AUTH_SERVICE_URL: process.env.AUTH_SERVICE_URL || 'http://localhost:3001',
  INTERNAL_SECRET:  process.env.INTERNAL_SECRET  || 'kabutare-internal-secret-change-in-production',
  // Keycloak
  KC_ISSUER: process.env.KC_ISSUER || 'https://keycloak.lucaslopvet.fr/realms/kabutare-hospital',
};
