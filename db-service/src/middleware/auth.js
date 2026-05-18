const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const { JWT_SECRET, KC_ISSUER } = require('../config');

// ── Rôles système Keycloak à ignorer dans le RBAC applicatif ──────────────────
const SYSTEM_ROLES = new Set([
  'offline_access',
  'uma_authorization',
  'default-roles-kabutare-hospital',
]);

// ── Client JWKS avec cache 10 min ─────────────────────────────────────────────
const client = jwksClient({
  jwksUri:        `${KC_ISSUER}/protocol/openid-connect/certs`,
  cache:          true,
  cacheMaxEntries: 5,
  cacheMaxAge:    10 * 60 * 1000,
  rateLimit:      true,
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    callback(null, key.getPublicKey());
  });
}

// ── Vérification token : RS256 Keycloak + shim HS256 legacy ───────────────────
// Le shim permet une transition sans coupure. À supprimer en Phase 5 (après 7 jours).
function verifyToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token manquant' });

  jwt.verify(token, getKey, { algorithms: ['RS256'], issuer: KC_ISSUER }, (err, decoded) => {
    if (!err) {
      req.user = {
        id:         decoded.sub,
        email:      decoded.email        ?? '',
        name:       decoded.name         ?? `${decoded.given_name ?? ''} ${decoded.family_name ?? ''}`.trim(),
        roles:      (decoded.realm_access?.roles ?? []).filter((r) => !SYSTEM_ROLES.has(r)),
        department: decoded.department   ?? '',
      };
      return next();
    }

    // Shim Phase 5 : fallback token HS256 (ancien format) — à supprimer après migration complète
    if (!JWT_SECRET) return res.status(401).json({ error: 'Token invalide ou expiré' });
    try {
      req.user = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
      return next();
    } catch {
      return res.status(401).json({ error: 'Token invalide ou expiré' });
    }
  });
}

function requireRole(...allowed) {
  return (req, res, next) => {
    const userRoles = Array.isArray(req.user?.roles) ? req.user.roles : [];
    if (!userRoles.some((r) => allowed.includes(r))) {
      return res.status(403).json({ error: `Rôle requis: ${allowed.join(' ou ')}` });
    }
    next();
  };
}

module.exports = { verifyToken, requireRole, SYSTEM_ROLES };
