const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
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
const pmProtocolsRoutes    = require('./routes/pm_protocols');
const debugRoutes          = require('./routes/debug');
const { getDb } = require('./database');

const app = express();

// Initialize DB on startup
getDb();
// Activer le cron de sauvegarde automatique si configuré
initBackupCron();

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
app.use('/api/pm-protocols',   pmProtocolsRoutes);
app.use('/',                   debugRoutes);

const server = app.listen(PORT, () => {
  console.log(`DB service running on port ${PORT}`);
});

module.exports = { app, server };
