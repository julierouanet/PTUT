module.exports = {
  PORT: process.env.PORT || 3002,
  DB_PATH: process.env.DB_PATH || 'hospital.db',
  JWT_SECRET: process.env.JWT_SECRET || 'kabutare-hospital-secret-key-change-in-production',
  AUTH_SERVICE_URL: process.env.AUTH_SERVICE_URL || 'http://localhost:3001',
};
