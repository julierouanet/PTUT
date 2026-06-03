const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { PORT } = require('./config');
const authRoutes         = require('./routes/auth');
const usersRoutes        = require('./routes/users');
const debugRoutes        = require('./routes/debug');
const { getDb }          = require('./database');
const rolesRoutes        = require('./routes/roles');
const internalRoutes     = require('./routes/internal');
const featureFlagsRoutes = require('./routes/featureFlags');

const app = express();

// Initialize DB on startup
getDb();

app.set('trust proxy', 1); // Pour récupérer la vraie IP derrière Nginx
app.use(helmet());

// CORS doit être AVANT les rate limiters pour que les réponses 429 aient les headers CORS
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
    if (!origin || allowed.includes(origin) || /^http:\/\/localhost:(3000|3001|3002|5000|8080|4200|9000)$/.test(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
}));

// Rate limiter : max 10 tentatives de login par IP par fenêtre de 15 min
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Trop de tentatives de connexion. Réessayez dans 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/login', loginLimiter);

// Rate limiter pour l'inscription : max 5 créations de compte par IP par heure
const registrationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { error: 'Trop de tentatives d\'inscription. Réessayez dans une heure.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/register', registrationLimiter);

// Rate limiter pour le mot de passe oublié : max 5 demandes par IP par 15 min
const forgotPasswordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { error: 'Trop de demandes. Réessayez dans 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/forgot-password', forgotPasswordLimiter);

// Rate limiter pour les endpoints d'écriture/administration
const writeLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 60,
  message: { error: 'Trop de requêtes. Réessayez dans une minute.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/users', writeLimiter);
app.use('/api/roles', writeLimiter);

app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/roles', rolesRoutes);
app.use('/api/feature-flags', featureFlagsRoutes);
app.use('/internal', internalRoutes);
app.use('/', debugRoutes);

const server = app.listen(PORT, () => {
  console.log(`Auth service running on port ${PORT}`);
});

module.exports = { app, server };
