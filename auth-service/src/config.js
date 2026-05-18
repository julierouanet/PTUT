const config = {
  PORT:                   process.env.PORT                   || 3000,
  DB_PATH:                process.env.DB_PATH                || 'auth.db',
  DB_SERVICE_URL:         process.env.DB_SERVICE_URL         || 'http://localhost:3002',
  INTERNAL_SECRET:        process.env.INTERNAL_SECRET        || 'kabutare-internal-secret-change-in-production',
  // Keycloak
  KC_ISSUER:              process.env.KC_ISSUER              || 'https://keycloak.lucaslopvet.fr/realms/kabutare-hospital',
  KC_REALM:               process.env.KC_REALM               || 'kabutare-hospital',
  KC_ADMIN_URL:           process.env.KC_ADMIN_URL           || 'https://keycloak.lucaslopvet.fr',
  KC_CLIENT_ID:           process.env.KC_CLIENT_ID           || 'auth-service',
  KC_CLIENT_SECRET:       process.env.KC_CLIENT_SECRET       || null,
};

if (!config.KC_CLIENT_SECRET) {
  console.warn('⚠️  [SÉCURITÉ] KC_CLIENT_SECRET non défini — les appels à l\'Admin API Keycloak échoueront.');
}
if (!config.INTERNAL_SECRET || config.INTERNAL_SECRET.includes('change-in-production')) {
  console.warn('⚠️  [SÉCURITÉ] INTERNAL_SECRET utilise une valeur par défaut.');
}

module.exports = config;
