const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const multer = require('multer');
const { PORT } = require('./config');
const equipmentRoutes      = require('./routes/equipment');
const issuesRoutes         = require('./routes/issues');
const inventoryRoutes      = require('./routes/inventory');
const logsRoutes           = require('./routes/logs');
const locationsRoutes      = require('./routes/locations');
const sidebarRoutes        = require('./routes/sidebar');
const pushRoutes           = require('./routes/push_notifications');
const analyticsRoutes      = require('./routes/analytics');
const featuresRoutes       = require('./routes/features');
const { router: backupsRoutes, initBackupCron } = require('./routes/backups');
const categoriesRoutes     = require('./routes/categories');
const departmentsRoutes    = require('./routes/departments');
const pmProtocolsRoutes    = require('./routes/pm_protocols');
const documentsRoutes      = require('./routes/documents');
const catalogRoutes        = require('./routes/catalog');
const debugRoutes          = require('./routes/debug');
const { getDb } = require('./database');
const { startPmReminderJob } = require('./jobs/pm_reminder_job');

const app = express();

// Initialize DB on startup
getDb();
// Activer le cron de sauvegarde automatique si configuré
initBackupCron();
// Démarrer le job quotidien de rappel PM (J-7 et J=0)
startPmReminderJob();

app.set('trust proxy', 1); // Pour récupérer la vraie IP derrière Nginx
app.use(helmet());

app.use(cors({
  origin: function (origin, callback) {
    const allowed = [
      'https://app.lucaslopvet.fr',
      'https://dev.app.lucaslopvet.fr',
      // CORS_ORIGIN peut contenir plusieurs origines séparées par des virgules
      // ex: "https://41.186.x.x,https://192.168.1.100" (internet + WiFi hôpital)
      ...(process.env.CORS_ORIGIN
        ? process.env.CORS_ORIGIN.split(',').map(s => s.trim()).filter(Boolean)
        : []),
    ];
    if (!origin || allowed.includes(origin) || /^http:\/\/localhost(:\d+)?$/.test(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
}));

app.use(express.json());

app.use('/api/locations',      locationsRoutes);
app.use('/api/equipment',      equipmentRoutes);
app.use('/api/issues',         issuesRoutes);
app.use('/api/inventory',      inventoryRoutes);
app.use('/api/logs',           logsRoutes);
app.use('/api/sidebar/config', sidebarRoutes);
app.use('/api/notifications',  pushRoutes);
app.use('/api/analytics',      analyticsRoutes);
app.use('/api/features',       featuresRoutes);
app.use('/api/admin/backups',  backupsRoutes);
app.use('/api/categories',     categoriesRoutes);
app.use('/api/departments',    departmentsRoutes);
app.use('/api/pm-protocols',   pmProtocolsRoutes);
app.use('/api/equipment',      documentsRoutes);
app.use('/api',                catalogRoutes);
app.use('/api/debug',          debugRoutes);
app.use('/',                   debugRoutes);

// ── Gestion centralisée des erreurs Multer (taille/type/nombre de fichiers) ──
// Sans ce middleware, une erreur Multer (ex. fichier > limite) provoquait une
// page HTML 500 par défaut côté client au lieu d'un message JSON exploitable.
const MULTER_ERROR_MESSAGES = {
  LIMIT_FILE_SIZE: 'Fichier trop volumineux',
  LIMIT_FILE_COUNT: 'Trop de fichiers envoyés',
};
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    const message = err.code === 'LIMIT_UNEXPECTED_FILE'
      ? (err.message || 'Type de fichier non supporté')
      : (MULTER_ERROR_MESSAGES[err.code] || err.message);
    return res.status(400).json({ error: message });
  }
  next(err);
});

// ── Gestion centralisée des erreurs non interceptées (catch-all) ─────────────
// Sans ce middleware, Express renvoie son comportement par défaut (page HTML,
// stack trace en dev) au lieu d'une réponse JSON exploitable. On ne renvoie
// jamais le message brut ou la stack au client — uniquement dans les logs.
app.use((err, req, res, next) => {
  console.error('[DB] Erreur non interceptée :', err.stack || err.message);
  res.status(500).json({ error: 'Erreur serveur interne' });
});

const server = app.listen(PORT, () => {
  console.log(`DB service running on port ${PORT}`);
});

module.exports = { app, server };
