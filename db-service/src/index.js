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
const debugRoutes          = require('./routes/debug');
const { getDb } = require('./database');

const app = express();

// Initialize DB on startup
getDb();

app.set('trust proxy', 1); // Pour récupérer la vraie IP derrière Nginx
app.use(helmet());

app.use(cors({
  origin: function (origin, callback) {
    const allowed = [
      'https://app.lucaslopvet.fr',
      'https://dev.app.lucaslopvet.fr',
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
app.use('/',                   debugRoutes);

const server = app.listen(PORT, () => {
  console.log(`DB service running on port ${PORT}`);
});

module.exports = { app, server };
