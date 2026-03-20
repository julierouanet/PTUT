const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { PORT } = require('./config');
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const debugRoutes = require('./routes/debug');
const { getDb } = require('./database');

const app = express();

// Initialize DB on startup
getDb();

app.use(helmet());

// Rate limiter : max 10 tentatives de login par IP par fenêtre de 15 min
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Trop de tentatives de connexion. Réessayez dans 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/login', loginLimiter);

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

app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/', debugRoutes);

const server = app.listen(PORT, () => {
  console.log(`Auth service running on port ${PORT}`);
});

module.exports = { app, server };
