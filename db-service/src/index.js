const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { PORT } = require('./config');
const equipmentRoutes = require('./routes/equipment');
const issuesRoutes    = require('./routes/issues');
const inventoryRoutes = require('./routes/inventory');
const debugRoutes     = require('./routes/debug');
const { getDb } = require('./database');

const app = express();

// Initialize DB on startup
getDb();

app.use(helmet({ contentSecurityPolicy: false }));

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

app.use('/api/equipment', equipmentRoutes);
app.use('/api/issues',    issuesRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/',              debugRoutes);

const server = app.listen(PORT, () => {
  console.log(`DB service running on port ${PORT}`);
});

module.exports = { app, server };
