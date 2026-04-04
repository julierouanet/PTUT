module.exports = {
  PORT: process.env.PORT || 3000,
  JWT_SECRET: process.env.JWT_SECRET || 'kabutare-hospital-secret-key-change-in-production',
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'kabutare-hospital-refresh-secret-change-in-production',
  ACCESS_TOKEN_EXPIRY: '15m',
  REFRESH_TOKEN_EXPIRY: '7d',
  REFRESH_TOKEN_EXPIRY_MS: 7 * 24 * 60 * 60 * 1000, // 7 days in ms
  DB_PATH: process.env.DB_PATH || 'auth.db',
  BCRYPT_ROUNDS: 10,
  DB_SERVICE_URL: process.env.DB_SERVICE_URL || 'http://localhost:3002',
  INTERNAL_SECRET: process.env.INTERNAL_SECRET || 'kabutare-internal-secret-change-in-production',
};
