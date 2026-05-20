module.exports = {
  PORT:             process.env.PORT             || 3002,
  DB_PATH:          process.env.DB_PATH          || 'hospital.db',
  AUTH_SERVICE_URL: process.env.AUTH_SERVICE_URL || 'http://localhost:3001',
  INTERNAL_SECRET:  process.env.INTERNAL_SECRET  || 'kabutare-internal-secret-change-in-production',
  // Keycloak
  KC_ISSUER: process.env.KC_ISSUER || 'https://keycloak.lucaslopvet.fr/realms/kabutare-hospital',
  // Web Push VAPID
  VAPID_PUBLIC_KEY:  process.env.VAPID_PUBLIC_KEY  || '',
  VAPID_PRIVATE_KEY: process.env.VAPID_PRIVATE_KEY || '',
  VAPID_CONTACT:     process.env.VAPID_CONTACT     || 'mailto:admin@lucaslopvet.fr',
};
