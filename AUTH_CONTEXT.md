# Contexte — Système d'authentification PTUT

> **Projet** : Gestion des équipements médicaux — Hôpital de Kabutare  
> **Date** : 2026-05-18  
> Ce document décrit le fonctionnement complet du système d'authentification et d'autorisation, de la couche Flutter jusqu'aux microservices Node.js.

---

## 1. Architecture d'ensemble

```
┌─────────────────────────────────────────────────┐
│  Flutter Web/Mobile App                         │
│  services/auth_service.dart (Singleton)         │
│  services/api_client.dart   (Bearer JWT)        │
└──────────┬──────────────────────────┬───────────┘
           │ HTTPS                    │ HTTPS
           ▼                          ▼
┌──────────────────┐        ┌──────────────────────┐
│  Nginx           │        │  Nginx               │
│  auth.lucaslopvet│        │  DB.lucaslopvet.fr   │
│  → 127.0.0.1:3001│        │  → 127.0.0.1:3002    │
└──────────┬───────┘        └──────────┬───────────┘
           │                           │
           ▼                           ▼
┌──────────────────┐        ┌──────────────────────┐
│  auth-service    │◄───────│  db-service          │
│  Node/Express    │ JWT    │  Node/Express        │
│  port 3001       │ proxy  │  port 3002           │
│  /data/auth.db   │        │  /data/hospital.db   │
└──────────────────┘        └──────────────────────┘
```

**Rôle de chaque couche :**

| Couche | Responsabilité auth |
|--------|---------------------|
| Flutter `ApiClient` | Attache le Bearer JWT, intercepte les 401, déclenche le refresh, redirige sur expiry |
| Nginx | Reverse-proxy transparent — passe les headers `Authorization` sans modification |
| auth-service | Émetteur des tokens, gestion users/rôles/permissions, endpoint `/verify` |
| db-service | Vérifie les tokens **localement** (JWT_SECRET partagé), proxy le JWT vers auth-service si besoin de données utilisateur |

Le `JWT_SECRET` est **partagé** entre auth-service et db-service, permettant à db-service de vérifier les tokens sans appel réseau.

---

## 2. Modèle de données — auth.db (SQLite)

### Table `users`

```sql
id            TEXT PRIMARY KEY          -- 'user-<uuid>'
first_name    TEXT                      -- Migration : séparé de l'ancien champ name
last_name     TEXT
email         TEXT UNIQUE NOT NULL
password_hash TEXT NOT NULL             -- bcrypt $2b$, 12 rounds
department    TEXT NOT NULL
phone         TEXT
is_active     INTEGER DEFAULT 1        -- 0 = compte suspendu
created_at    TEXT
```

### Table `refresh_tokens`

```sql
id         INTEGER PRIMARY KEY AUTOINCREMENT
user_id    TEXT NOT NULL → users.id ON DELETE CASCADE
token      TEXT UNIQUE NOT NULL
expires_at TEXT                         -- ISO datetime, TTL 7 jours
created_at TEXT DEFAULT CURRENT_TIMESTAMP
```

Nettoyage opportuniste à chaque login/refresh : `DELETE FROM refresh_tokens WHERE expires_at < datetime('now')`.

### Tables RBAC

```sql
-- Définition des rôles
roles (
  name         TEXT PRIMARY KEY,        -- 'admin', 'supervisor', …
  display_name TEXT NOT NULL,
  is_builtin   INTEGER DEFAULT 0
)

-- Permissions associées à un rôle
role_permissions (
  role_name  TEXT → roles.name ON DELETE CASCADE,
  permission TEXT,
  PRIMARY KEY (role_name, permission)
)

-- Affectation multi-rôle des utilisateurs
user_roles (
  user_id   TEXT → users.id   ON DELETE CASCADE,
  role_name TEXT → roles.name ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_name)
)
```

### Table `department_change_requests`

```sql
id                    TEXT PRIMARY KEY
user_id               TEXT → users.id
current_department    TEXT NOT NULL
requested_department  TEXT NOT NULL
status                TEXT DEFAULT 'pending'  -- pending | approved | rejected
admin_id              TEXT
admin_note            TEXT
created_at            TEXT
resolved_at           TEXT
```

---

## 3. Structure des tokens JWT

### Access token (durée : 15 min)

Signé avec `JWT_SECRET`. Payload :

```json
{
  "id":         "user-<uuid>",
  "email":      "user@hospital.rw",
  "roles":      ["supervisor", "hospitalStaff"],
  "name":       "Prénom Nom",
  "department": "Cardiology",
  "iat":        1234567890,
  "exp":        1234568790
}
```

### Refresh token (durée : 7 jours)

Signé avec `JWT_REFRESH_SECRET` (secret **différent**). Payload minimal :

```json
{
  "id":  "user-<uuid>",
  "iat": 1234567890,
  "exp": 1235172690
}
```

Le refresh token est **aussi stocké en DB** (`refresh_tokens`) pour permettre la révocation et la rotation stricte.

---

## 4. Flux de connexion (end-to-end)

```
1. Utilisateur saisit email + mot de passe → _submit() [login_screen.dart]
       ↓
2. AuthService.loginWithApi(email, password)
       ↓
3. AuthApiService.login() → POST /api/auth/login
       ↓
4. auth-service :
   a. SELECT user WHERE email = ? → vérifie is_active
   b. bcrypt.compare(password, password_hash)  [12 rounds]
   c. getUserRoles(userId)  → string[]
   d. getUserPermissions(userId)  → string[] (UNION role_permissions)
   e. jwt.sign(payload, JWT_SECRET, { expiresIn: '15m' })
   f. jwt.sign({id}, JWT_REFRESH_SECRET, { expiresIn: '7d' })
   g. INSERT INTO refresh_tokens (user_id, token, expires_at)
   h. sendLog({ action: 'login', … })  → db-service /api/logs/internal
       ↓
5. Réponse : { accessToken, refreshToken, user: { id, name, email, roles, permissions, … } }
       ↓
6. ApiClient.saveTokens(access, refresh)
   → SecureTokenStorage.write('access_token', …)
   → SecureTokenStorage.write('refresh_token', …)
       ↓
7. AuthService._currentUser = User.fromApiJson(data['user'])
   notifyListeners()
       ↓
8. App rebuilds → MainScaffold affiché
9. DataService().loadAll() → charge équipements, incidents, etc.
```

En cas d'échec : `loginWithApi` retourne `false`, `_lastError` contient le message serveur.

---

## 5. Stockage des tokens côté client

**Fichier :** `flutter-app/lib/services/secure_token_storage.dart`

| Plateforme | Mécanisme | Clés |
|------------|-----------|------|
| Web | `SharedPreferences` (localStorage) | `access_token`, `refresh_token` |
| Android | `FlutterSecureStorage` (EncryptedSharedPreferences) | idem |
| iOS | `FlutterSecureStorage` (Keychain) | idem |

### Auto-login au démarrage

`main.dart` tente une restauration de session avant `runApp()` :

```dart
if (await ApiClient.hasStoredTokens()) {
  final restored = await AuthService().restoreSession();
  // restoreSession() → GET /api/auth/me avec l'access token stocké
  if (restored) await DataService().loadAll();
}
```

Si l'access token est expiré, `GET /api/auth/me` retourne 401 → `ApiClient` tente le refresh automatiquement avant de renvoyer la réponse.

---

## 6. Vérification des tokens dans db-service

**Fichier :** `db-service/src/middleware/auth.js`

```js
function verifyToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token manquant' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);  // vérification LOCALE
    next();
  } catch {
    return res.status(401).json({ error: 'Token invalide ou expiré' });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    const userRoles = req.user?.roles ?? [];
    if (!roles.some(r => userRoles.includes(r)))
      return res.status(403).json({ error: 'Rôle insuffisant' });
    next();
  };
}
```

Aucun appel réseau vers auth-service : la vérification est locale grâce au `JWT_SECRET` partagé. `req.user` contient le payload complet du token (id, email, roles, department…).

---

## 7. Rotation des refresh tokens

**Flux sur `POST /api/auth/refresh` :**

```
1. Client envoie { refreshToken }
2. auth-service :
   a. SELECT * FROM refresh_tokens WHERE token = ?
   b. Vérifie expires_at > now()
   c. jwt.verify(token, JWT_REFRESH_SECRET)
   d. SELECT user WHERE id = payload.id AND is_active = 1
   e. DELETE FROM refresh_tokens WHERE token = ?  ← token à usage unique
   f. Signe nouveau access token + nouveau refresh token
   g. INSERT nouveau refresh token en DB
   h. Retourne { accessToken, refreshToken }
```

**Côté client (`ApiClient._tryRefresh`) :**

```dart
final response = await http.post(refreshUrl, body: { 'refreshToken': token });
if (response.statusCode == 200) {
  await saveTokens(newAccess, newRefresh);  // les deux ou rien
  return true;  // → relance la requête originale
}
onSessionExpired?.call();  // refresh rejeté → déconnexion
return false;
```

La rotation est **stricte** : l'ancien refresh token est immédiatement supprimé. Réutiliser un ancien token retourne 401.

---

## 8. Gestion de l'expiry de session

**Callback wired dans `main.dart` :**

```dart
ApiClient.onSessionExpired = () => AuthService().handleSessionExpired();
```

**`handleSessionExpired()` dans `auth_service.dart` :**

```dart
void handleSessionExpired() {
  _sessionExpiredMessage = 'Votre session a expiré. Veuillez vous reconnecter.';
  _currentUser = null;
  notifyListeners();  // → App rebuilds → LoginScreen affiché
}
```

Le message est affiché dans le formulaire de login (`initState` de `login_screen.dart`), puis effacé après lecture.

---

## 9. Modèle RBAC — Rôles et permissions

### Rôles built-in

| Rôle (apiName) | Permissions |
|----------------|-------------|
| `hospitalStaff` | `viewEquipment`, `reportIssue`, `trackIssues` |
| `supervisor` | + `approveRequests`, `assignTasks` |
| `technician_biomedical` | + `updateRepairs`, `registerParts` |
| `technician_it` | + `updateRepairs`, `registerParts` |
| `technician_infra` | + `updateRepairs`, `registerParts` |
| `admin` | Toutes les permissions |
| `technician` | Déprécié — conservé pour compatibilité ascendante |

### Liste exhaustive des permissions

```
viewEquipment     reportIssue       trackIssues
approveRequests   assignTasks       updateRepairs
registerParts     manageEquipment   manageUsers
manageDepartments manageCategories  generateReports
viewInventory     changeDepartment
```

### Vérification côté Flutter

`AuthService.hasPermission(Permission p)` — ordre de priorité :

1. **Admin bypass** : si l'utilisateur a le rôle `admin` → `true` immédiatement
2. **Permissions dynamiques** : cherche dans `DataService().permissionsForRole(role.apiName)` (config admin via API)
3. **Fallback hardcodé** : `user.permissions` (calculé à la réponse de login)

### Filtrage de la sidebar

Chaque `_NavItem` déclare une `requiredPermission`. Au rendu :

```dart
final visible = allItems.where((item) =>
  item.requiredPermission == null ||
  authService.hasPermission(item.requiredPermission!)
).toList();
```

L'ordre des items peut être personnalisé par rôle via la config admin (table `sidebar` dans hospital.db).

### Priorité de rôle pour l'affichage UI

Quand un utilisateur a plusieurs rôles, `AuthService.primaryRole` retourne le plus prioritaire :

```
admin > supervisor > technician_biomedical > technician_it > technician_infra > technician > hospitalStaff
```

---

## 10. Communication inter-services

### auth-service → db-service (logs d'audit)

`auth-service/src/utils/logger.js` envoie un POST non-bloquant :

```
POST http://db-service:3002/api/logs/internal
Header: x-internal-secret: <INTERNAL_SECRET>
Body: { user_id, user_name, user_role, action, target_type, … }
```

db-service valide uniquement `x-internal-secret` — aucun JWT requis pour cette route interne.

### db-service → auth-service (liste de techniciens)

`db-service/src/routes/issues.js` — endpoint `GET /api/issues/:id/assignable-technicians` :

```js
// Proxy du JWT original du client Flutter vers auth-service
const resp = await fetch(`${AUTH_SERVICE_URL}/api/users?role=${role}`, {
  headers: { authorization: req.headers['authorization'] }
});
```

Le JWT du client est transféré tel quel. auth-service vérifie le token et filtre les utilisateurs par rôle.

---

## 11. Endpoints auth-service

| Méthode | Route | Auth requise | Description |
|---------|-------|--------------|-------------|
| `POST` | `/api/auth/login` | Non | Authentification → access + refresh tokens |
| `POST` | `/api/auth/refresh` | Non (refresh token en body) | Rotation des tokens |
| `POST` | `/api/auth/logout` | Non (refresh token en body) | Révocation du refresh token |
| `GET` | `/api/auth/verify` | Bearer JWT | Validation d'un access token |
| `GET` | `/api/auth/me` | Bearer JWT | Profil utilisateur courant avec rôles + permissions |
| `GET` | `/api/users` | Bearer JWT | Liste users (admin) ou filtre par `?role=` (authentifié) |
| `POST` | `/api/users` | Bearer JWT + admin | Créer un utilisateur |
| `PUT` | `/api/users/:id` | Bearer JWT + admin | Modifier un utilisateur |
| `PATCH` | `/api/users/:id/toggle` | Bearer JWT + admin | Suspendre / réactiver |
| `DELETE` | `/api/users/:id` | Bearer JWT + admin | Supprimer (soft delete avec snapshot) |
| `GET` | `/api/roles` | Bearer JWT + admin | Lister les rôles avec permissions |
| `POST` | `/api/roles` | Bearer JWT + admin | Créer un rôle custom |
| `PUT` | `/api/roles/:name/permissions` | Bearer JWT + admin | Modifier les permissions d'un rôle |

---

## 12. Sécurité & rate limiting

### Rate limiting (`auth-service/src/index.js`)

| Endpoint | Fenêtre | Max | Message d'erreur |
|----------|---------|-----|-----------------|
| `POST /api/auth/login` | 15 min | 10 req/IP | "Trop de tentatives de connexion…" |
| `/api/users/*`, `/api/roles/*` (écritures) | 1 min | 60 req/IP | "Trop de requêtes…" |

### Headers de sécurité (Helmet)

- `Strict-Transport-Security` (HSTS)
- `Content-Security-Policy`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`

### CORS

Origines autorisées (hardcodées dans `auth-service/src/index.js`) :

```
https://app.lucaslopvet.fr
https://dev.app.lucaslopvet.fr
http://localhost:3000, 3001, 3002, 5000, 8080, 4200, 9000
```

Tout nouveau front doit être ajouté explicitement dans cette liste.

### Audit trail

Toute mutation sensible appelle `logAction()` / `sendLog()` qui écrit dans `hospital.db` (table `logs`) :

```
login, login_failed, logout
create_user, update_user, delete_user, restore_user
activate_user, suspend_user
change_password, change_email, change_name, change_phone
direct_dept_change, approve_dept_request, reject_dept_request
```

---

## 13. Variables d'environnement critiques

| Variable | Service | Valeur par défaut (ne pas utiliser en prod) |
|----------|---------|---------------------------------------------|
| `JWT_SECRET` | auth + db | `kabutare-hospital-secret-key-change-in-production` |
| `JWT_REFRESH_SECRET` | auth | `kabutare-hospital-refresh-secret-change-in-production` |
| `INTERNAL_SECRET` | auth + db | `kabutare-internal-secret-change-in-production` |
| `DB_PATH` | auth + db | `auth.db` / `hospital.db` |
| `DB_SERVICE_URL` | auth | `http://localhost:3002` |
| `AUTH_SERVICE_URL` | db | `http://localhost:3001` |
| `PORT` | auth + db | `3001` / `3002` |
| `BCRYPT_ROUNDS` | auth | `12` |
| `AUTH_URL` / `DB_URL` | flutter (build) | `https://auth.lucaslopvet.fr` / `https://DB.lucaslopvet.fr` |

auth-service affiche un warning au démarrage si les secrets par défaut sont détectés.

---

## 14. Fichiers clés

| Fichier | Rôle |
|---------|------|
| `auth-service/src/routes/auth.js` | Login, refresh, logout, verify, me |
| `auth-service/src/middleware/auth.js` | `verifyToken`, `requireAdmin` |
| `auth-service/src/database.js` | Schéma + migrations inline |
| `auth-service/src/utils/userRoles.js` | `getUserRoles`, `getUserPermissions`, `setUserRoles` |
| `auth-service/src/utils/logger.js` | `sendLog`, `logAction`, extraction IP/UA |
| `db-service/src/middleware/auth.js` | `verifyToken`, `requireRole` (vérification locale) |
| `db-service/src/routes/logs.js` | Endpoint interne `x-internal-secret` |
| `db-service/src/routes/issues.js` | Proxy JWT vers auth-service |
| `flutter-app/lib/services/api_client.dart` | Bearer JWT, retry 401, `_tryRefresh` |
| `flutter-app/lib/services/auth_service.dart` | État global, `loginWithApi`, `hasPermission` |
| `flutter-app/lib/services/auth_api_service.dart` | Appels HTTP auth (login, logout, getMe) |
| `flutter-app/lib/services/secure_token_storage.dart` | Stockage web/natif des tokens |
| `flutter-app/lib/models/user_role.dart` | Enum `UserRole`, enum `Permission`, mapping API |
| `flutter-app/lib/main.dart` | Wiring `onSessionExpired`, restauration session |
