# Contexte du projet - Gestion d'Equipement Medical (Hopital de Kabutare)

## Description generale

Application web et mobile de gestion d'equipements medicaux pour l'Hopital de District de Kabutare (Rwanda). Le systeme permet le suivi des equipements, la gestion des incidents, l'inventaire des pieces detachees, et l'administration des utilisateurs avec un controle d'acces base sur les roles (RBAC).

**Commanditaire** : Dr. NZABONIMANA Ephraim (nzephmd@gmail.com / +250 788823228)

## Architecture globale

Architecture microservices composee de 3 services principaux, orchestres par Docker Compose, deployes via Jenkins, avec Nginx en reverse proxy HTTPS.

```
                    +-----------------------+
                    |        Nginx          |
                    | (Reverse Proxy HTTPS) |
                    | Let's Encrypt SSL     |
                    +----+----------+-------+
                         |          |
          +--------------+          +------------------+
          |                                            |
   +------v--------+  +-------v-------+  +------------v---+  +-------v--------+
   |  Flutter App   |  | Auth Service  |  |   Keycloak     |  |  DB Service    |
   |  (Static Web)  |  | Express.js    |  |   Port 8080    |  |  Express.js    |
   |  /var/www/     |  | Port 3001     |  |   (IAM/JWT)    |  |  Port 3002     |
   +----------------+  +-------+-------+  +-------+--------+  +-------+--------+
                               |                  |                   |
                          +----v-----+      +------v------+     +-----v--------+
                          | auth.db  |      | PostgreSQL  |     | hospital.db  |
                          | (SQLite) |      | (Keycloak)  |     | (SQLite)     |
                          +----------+      +-------------+     +--------------+
```

**Responsabilités après migration Keycloak :**
- **Keycloak** : émission/validation JWT (RS256 asymétrique), stockage users/mots de passe/rôles, endpoint token (Direct Grant), JWKS
- **auth-service** : proxy Admin API Keycloak (`/api/users`, `/api/roles`), `GET /api/auth/me`, gestion `department_change_requests`, `role_permissions`, `access_requests` SQLite
- **db-service** : validation JWT via JWKS Keycloak (jwks-rsa), CRUD équipements/incidents/inventaire

## Domaines et ports

| Environnement | Frontend                 | Auth Service                   | DB Service                  | Keycloak                        |
|---------------|--------------------------|--------------------------------|-----------------------------|----------------------------------|
| **Production**| app.lucaslopvet.fr       | auth.lucaslopvet.fr (:3001)    | DB.lucaslopvet.fr (:3002)   | keycloak.lucaslopvet.fr (:8080)  |
| **Dev**       | dev.app.lucaslopvet.fr   | dev.auth.lucaslopvet.fr (:3003)| dev.DB.lucaslopvet.fr (:3004)| keycloak.lucaslopvet.fr (:8081) |

---

# 1. Auth Service

**Stack** : Node.js 20 (Alpine) / Express 4.21.0 / SQLite (better-sqlite3 11.7.0)
**Port interne** : 3001 | **Port dev externe** : 3003

## 1.1 Schemas de base de donnees

> **Post-migration Keycloak** : auth.db ne contient plus que deux tables actives. Les tables `users`, `user_roles`, `refresh_tokens`, `roles` ont été supprimées — Keycloak gère désormais tout cela. Les tables legacy peuvent encore exister sur des déploiements existants (jamais recréées au démarrage, ignorées).

### Table `role_permissions`

| Colonne     | Type | Contraintes                           |
|-------------|------|---------------------------------------|
| role_name   | TEXT | NOT NULL (nom de rôle Keycloak realm) |
| permission  | TEXT | NOT NULL                              |

**Cle primaire** : (role_name, permission)
**Pas de FK** : les rôles vivent dans Keycloak, pas dans SQLite.
**Migration automatique** : si l'ancienne table avec FK -> roles existe, elle est recréée sans FK au démarrage (`role_permissions_v2` pattern, marqueur `_rp_migrated`).

### Table `feature_flags` **[NOUVEAU]**

| Colonne     | Type    | Contraintes                                        |
|-------------|---------|-----------------------------------------------------|
| id          | TEXT    | PRIMARY KEY (ex: `equipment`, `inventory`)          |
| name        | TEXT    | NOT NULL (nom affiché)                             |
| description | TEXT    | Nullable                                           |
| enabled     | INTEGER | NOT NULL DEFAULT 1 (0 = désactivé globalement)     |
| updated_at  | TEXT    | DEFAULT datetime now                               |
| updated_by  | TEXT    | Nullable (UUID Keycloak de l'admin)                |

**Modules désactivables** : `equipment`, `inventory`. Le module `settings` n'a pas de ligne — il est verrouillé côté API (PUT refuse explicitement).
**Seed automatique** : `initTables()` insère les deux flags avec `enabled=1` via `INSERT OR IGNORE`.

### Table `feature_flag_overrides` **[NOUVEAU]**

| Colonne  | Type    | Contraintes                                          |
|----------|---------|-------------------------------------------------------|
| flag_id  | TEXT    | NOT NULL, FK → feature_flags(id) ON DELETE CASCADE    |
| role     | TEXT    | NOT NULL (nom de rôle Keycloak, ex: `hospitalStaff`) |
| enabled  | INTEGER | NOT NULL (0 ou 1 — override pour ce rôle)            |

**Cle primaire** : (flag_id, role)
**Logique d'évaluation** : global.enabled=0 → désactivé pour tous ; override présent → override.enabled ; sinon → global.enabled.

### Table `department_change_requests`

| Colonne              | Type | Contraintes                              |
|----------------------|------|------------------------------------------|
| id                   | TEXT | PRIMARY KEY, UUID                        |
| user_id              | TEXT | NOT NULL (UUID Keycloak — pas de FK)     |
| user_name            | TEXT | NOT NULL                                 |
| current_department   | TEXT | NOT NULL                                 |
| requested_department | TEXT | NOT NULL                                 |
| status               | TEXT | NOT NULL DEFAULT 'pending' (pending/approved/rejected) |
| admin_id             | TEXT | Nullable (UUID Keycloak)                 |
| admin_note           | TEXT | Nullable, max 200 chars                  |
| created_at           | TEXT | DEFAULT CURRENT_TIMESTAMP                |
| resolved_at          | TEXT | Nullable                                 |

**Index** : `idx_dept_req_user` (user_id), `idx_dept_req_status` (status)
**Migration automatique** : si FK -> users existe, table recrée sans FK au démarrage.

**Configuration DB** : WAL mode, foreign_keys = ON

## 1.2 Roles et permissions

### Rôles de realm Keycloak (7 rôles)

| Rôle                  | Permissions applicatives (SQLite role_permissions)                                  |
|-----------------------|-------------------------------------------------------------------------------------|
| hospitalStaff         | viewEquipment, reportIssue, trackIssues                                             |
| supervisor            | viewEquipment, reportIssue, trackIssues, approveRequests, assignTasks, viewInterventionDocuments |
| technician            | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts, approveRequests, viewInterventionDocuments |
| technician_biomedical | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts, approveRequests, viewInterventionDocuments |
| technician_it         | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts, approveRequests, viewInterventionDocuments |
| technician_infra      | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts, approveRequests, viewInterventionDocuments |
| admin                 | TOUTES les permissions (17)                                                         |

**SYSTEM_ROLES** filtrés des tokens : `offline_access`, `uma_authorization`, `default-roles-kabutare-hospital`

### Liste des permissions

`viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`, `updateRepairs`, `registerParts`, `manageEquipment`, `manageUsers`, `manageDepartments`, `manageCategories`, `generateReports`, `viewInventory`, `changeDepartment`, `manageFeatures`, `manageBackups`, `viewInterventionDocuments`

## 1.3 Utilisateurs — migration Keycloak

Les utilisateurs sont désormais dans **Keycloak** (realm `kabutare-hospital`). Script de migration one-shot : `scripts/migrate-users.js`.

- Chaque utilisateur migré reçoit un mot de passe temporaire + `requiredActions: ['UPDATE_PASSWORD']`
- Le mapping `ancien_id → keycloak_uuid` est exporté en CSV (`--output mapping.csv`)
- Idempotent : vérifie si l'email existe avant de créer

Les 8 comptes seed auth-service (admin@kabutare.rw, etc.) peuvent être migrés ou recréés directement dans la console Keycloak (`https://keycloak.lucaslopvet.fr/admin` → realm kabutare-hospital).

## 1.4 Endpoints API

> **Login / Refresh / Logout** : ces opérations se font **directement sur Keycloak** (pas via auth-service).
> - Login : `POST https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token` (Direct Grant, form-urlencoded, `grant_type=password`)
> - Refresh : même endpoint, `grant_type=refresh_token`
> - Logout : suppression locale des tokens (tokens Keycloak expirent en 15 min)

### Authentification (`/api/auth`)

#### POST /api/auth/access-request *(public, rate-limit 3/h/IP)*
- **Body** : `{ "first_name", "last_name", "email", "password", "department?", "phone?" }`
- Crée un compte Keycloak (rôle `hospitalStaff`, mot de passe permanent) avec **email non vérifié** : `requiredActions: ['VERIFY_EMAIL']` + envoi immédiat de l'email de vérification — l'utilisateur doit valider son email avant de pouvoir se connecter (`routes/auth.js`).
- `phone` optionnel : posé en attribut Keycloak (`attributes.phone`), aucune validation de format côté serveur (déléguée au formulaire Flutter) — uniquement une limite de 20 caractères max anti-abus.
- Traçabilité : ligne insérée dans `access_requests` (colonne `phone` incluse, statut `auto_created`) + audit trail central `sendLog` (action `access_request_account_created`, `details.phone`).
- **Erreurs** : 400 si champs manquants / email invalide / mot de passe < 8 chars / téléphone > 20 chars ; 409 si email déjà existant ; 502 si erreur Keycloak.
- ✅ Correctif #1 de l'audit 2026-06-10 appliqué : rate-limiter dédié (`index.js`), VERIFY_EMAIL, sendLog.

#### POST /api/auth/forgot-password *(public, rate-limit 5/15min)*
- **Body** : `{ "email" }` — répond toujours 200 (anti-énumération), puis déclenche en asynchrone un email `UPDATE_PASSWORD` via l'Admin API Keycloak si l'email existe.

#### POST /api/auth/register *(public)*
- Création de compte auto-déclaratif via Admin API Keycloak (hospitalStaff + VERIFY_EMAIL).
- **Note** : le lien "S'inscrire" a été remplacé côté Flutter par "Demander un accès" (voir ci-dessus). Cet endpoint reste opérationnel pour usage admin direct.

#### GET /api/auth/me
- **Header** : `Authorization: Bearer {token Keycloak RS256}`
- **Reponse 200** :
```json
{
  "id": "uuid-keycloak (sub)",
  "name": "string", "first_name": "string", "last_name": "string",
  "email": "string", "department": "string", "phone": "string|null",
  "roles": ["string"],
  "permissions": ["string"]
}
```
- **Comportement** : lit les claims du JWT (sub, name, given_name, family_name, email, department) + interroge `role_permissions` SQLite pour les permissions

#### POST /api/auth/debug-mode/verify *(admin uniquement, rate-limit 10/15min/IP)*
- **Body** : `{ "password" }`
- Compare le mot de passe soumis à la variable d'env `DEBUG_MODE_PASSWORD` (saisie interactivement lors de l'exécution de `setup_ubuntu.sh`, partagée prod/dev via `/etc/kabutare/.env`).
- Déverrouille côté Flutter l'affichage de l'item sidebar « Debug & Test » pour la durée de la session (état en mémoire `AuthService.debugModeEnabled`, reset au logout) — protection contre un clic accidentel sur des actions destructrices (clear issues, reseed DB).
- **Réponse 200** : `{ "valid": true }` ; **401** : `{ "valid": false, "error": "..." }` (mot de passe incorrect OU `DEBUG_MODE_PASSWORD` non configuré côté serveur — jamais de 500) ; **400** si `password` absent ; **403** si non-admin.
- Aucune trace du mot de passe dans les logs (`sendLog` avec `details: {}` volontairement vide).

### Gestion des utilisateurs (`/api/users`) - Rate limit : 60 req/min

> Toutes les opérations proxient vers **Keycloak Admin API**. Les IDs sont des UUID Keycloak.

#### GET /api/users (Admin)
- Proxy `GET /admin/realms/kabutare-hospital/users` + enrichissement des rôles en parallèle
- Supporte `?role=X` → `GET /admin/realms/kabutare-hospital/roles/{role}/users`

#### POST /api/users (Admin)
- **Body** : `{ "first_name", "last_name", "email", "password", "department", "roles": ["string"], "phone?" }`
- Crée dans Keycloak + reset-password + assignation des rôles (transaction)
- **Reponse 201** : `{ "message": "Utilisateur cree", "id": "uuid-keycloak" }`

#### PUT /api/users/:id (Admin)
- Met à jour Keycloak user + reset-password si `password` fourni + diff des rôles (add/remove)

#### PATCH /api/users/:id/toggle (Admin)
- GET état enabled actuel → PUT `{ enabled: !current }`
- **Reponse** : `{ "message": "...", "is_active": 0|1 }`

#### DELETE /api/users/:id (Admin)
- Snapshot GET → DELETE Keycloak → audit log

#### POST /api/users/restore (Admin)
- Recrée dans Keycloak avec mot de passe temporaire + `UPDATE_PASSWORD` required action

#### PUT /api/users/me/department (Auth + permission changeDepartment)
- Changement direct de departement sans approbation

#### POST /api/users/department-request (Auth)
- Demande de changement (1 seule demande pending a la fois)

#### GET /api/users/department-requests (Admin)
- **Query** : `?status=pending|approved|rejected`

#### PUT /api/users/department-requests/:id (Admin)
- **Body** : `{ "status": "approved|rejected", "admin_note?" }`
- Si approved : met a jour le departement du user

#### GET /api/users/me/notifications (Auth — supervisor/technician/admin)
- Retourne les préférences de notification email de l'utilisateur connecté
- Crée une entrée par défaut si absente (`preferences_set = false`)
- **Réponse** : `{ notify_new_issue, min_urgency_new_issue, notify_critical_acknowledged, notify_critical_diagnosed, notify_critical_resolved, notify_pm_due, preferences_set, updated_at }`
- `min_urgency_new_issue` (`Faible`/`Moyen`/`Urgent`/`Critique`, défaut `Critique`) : seuil d'urgence minimal déclenchant l'email "nouvel incident" — filtré côté `send-email`/`send-to-roles`, indépendamment des push (non filtrées)

#### PUT /api/users/me/notifications (Auth — supervisor/technician/admin)
- Met à jour les préférences + marque `preferences_set = 1`
- **Body** : `{ notify_new_issue?, min_urgency_new_issue?, notify_critical_acknowledged?, notify_critical_diagnosed?, notify_critical_resolved?, notify_pm_due? }` (tous optionnels)
- `min_urgency_new_issue` validé contre `['Faible','Moyen','Urgent','Critique']` → `400` si invalide

#### POST /internal/notifications/send-email (x-internal-secret)
- Appelé par db-service — envoie un email à un utilisateur si ses préférences le permettent
- **Body** : `{ type, to_email, to_name, user_id, payload }`
- Types : `critical_new_issue` (seuil `min_urgency_new_issue` comparé à `payload.urgency`), `critical_acknowledged`, `critical_diagnosed`, `critical_resolved`, `pm_due`
- Répond immédiatement `{ sent: bool, reason? }` (`reason` : `preference_disabled` ou `below_urgency_threshold`)

#### POST /internal/notifications/send-to-roles (x-internal-secret)
- Notifie tous les utilisateurs des rôles spécifiés ayant la préférence activée
- **Body** : `{ type, roles: string[], payload }`
- Requête Keycloak Admin API pour récupérer les emails, asynchrone (réponse immédiate)

#### Demandes de rôle (`role_change_requests`)

| Methode | Route | Auth | Description |
|---|---|---|---|
| POST | /api/users/role-request | Auth | Demande d'un rôle supplémentaire (whitelist REQUESTABLE_ROLES, 409 si pending existante) |
| GET | /api/users/role-requests | Admin | Liste (filtre `?status=`) |
| PUT | /api/users/role-requests/:id | Admin | `{ status: approved\|rejected, admin_note? }` — si approved, assigne le rôle dans Keycloak |

#### Divers utilisateurs

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/users/:id | Admin | Détail d'un utilisateur Keycloak (placé en dernier dans le router) |
| POST | /api/users/:id/send-verify-email | Admin | Déclenche l'email de vérification Keycloak |

> ⚠️ `GET /api/users?role=X` est accessible à **tout utilisateur authentifié** (seul le listing complet sans `?role` exige admin) — constat d'audit 2026-06-10 (correctif #3).

### Feature Flags (`/api/feature-flags`) **[NOUVEAU]**

#### GET /api/feature-flags (Auth — tout rôle authentifié)
- Retourne la liste de tous les modules avec leur état global et les overrides par rôle
- **Réponse 200** : `[{ id, name, description, is_global_active: bool, role_overrides: { role: bool } }]`
- Chargé au démarrage par `DataService.loadAll()` via `FeatureService.loadFeatures()`

#### PUT /api/feature-flags/:id (Admin — `manageFeatures`)
- Met à jour l'état global et remplace tous les overrides par rôle
- **Body** : `{ is_global_active: bool, role_overrides: { role: bool } }`
- **Erreurs** : 400 si `is_global_active` manquant ou non booléen ; 400 si rôle inconnu dans les overrides ; 400 si tentative de désactiver `settings` ; 404 si flag inconnu ; 403 si non-admin
- **Audit trail** via `sendLog` (action `update_feature_flag`)

### Paramètres Application (`/api/app-settings`) **[NOUVEAU]**

Table `app_settings` (auth.db) : 6 clés — 3 publiques (contact login) + 3 Brevo (clé API secrète masquée, expéditeur email/nom).
Config Brevo : priorité valeur DB non vide → fallback variable d'environnement. Refactor `email_service.js` : `_getBrevoConfig()` lit la DB à chaque envoi.

#### GET /api/app-settings/public (Public — aucune auth)
- Retourne `{ login_contact_title, login_contact_email, login_contact_phone }`
- Jamais de clé `is_secret=1`. Utilisé par `login_screen.dart` pour le bandeau contact d'urgence.

#### GET /api/app-settings (Admin)
- Retourne toutes les clés. `brevo_api_key` masquée : `{ key, is_secret:true, configured:bool, hint:string|null }`

#### PUT /api/app-settings (Admin)
- **Body** : `{ settings: { key: value, ... } }`
- Règle secret : `''` = inchangé ; `'__CLEAR__'` = vider ; autre = écrire
- Rejet 400 si clé hors `ALL_KEYS`. Audit `sendLog` (clés modifiées sans valeur secrète).

#### POST /api/app-settings/test-email (Admin)
- **Body** : `{ to_email: string }`
- Envoie un email de test via la config Brevo active (DB ou env)

### Gestion des roles (`/api/roles`) - Rate limit : 60 req/min

#### GET /api/roles (Admin)
- Rôles Keycloak (filtrés SYSTEM_ROLES) + permissions depuis `role_permissions` SQLite

#### POST /api/roles (Admin)
- Crée dans Keycloak + insère dans `role_permissions` SQLite

#### PUT /api/roles/:name/permissions (Admin)
- Uniquement `role_permissions` SQLite (Keycloak ne connaît pas les permissions applicatives)
- 403 si `name === 'admin'` (rôle protégé)

#### GET /api/roles/:name/permissions (Admin)
- Permissions SQLite d'un rôle spécifique

#### GET /api/roles/:name/hierarchy (Admin)
- Parent/enfants depuis la table `role_hierarchy`

#### GET /api/roles/:name/users (Admin)
- Utilisateurs Keycloak ayant ce rôle, paginé (`?page=&limit=`, max 50)

#### DELETE /api/roles/:name (Admin)
- DELETE Keycloak + DELETE `role_permissions` SQLite — 400 si rôle intégré (7 builtin)

> ⚠️ Constat d'audit 2026-06-10 : POST/PUT/DELETE de `/api/roles` n'écrivent **aucun audit trail** (`sendLog` absent — correctif #2 du rapport).

## 1.5 Middleware et securite

- **verifyToken** : JWKS (jwks-rsa) → RS256 Keycloak en priorité, fallback HS256 shim (transition). Normalise `req.user = { id: sub, email, name, roles: realm_access.roles filtré, department, given_name, family_name, phone }`
- **requireRole(...roles)** : vérifie `Array.isArray(req.user.roles) && roles.some(...)`
- **requireAdmin** : vérifie `req.user.roles.includes('admin')`
- **SYSTEM_ROLES** filtré : `offline_access`, `uma_authorization`, `default-roles-kabutare-hospital`
- **helmet()** : Headers de securite (XSS, CSP, etc.)
- **CORS** : Origins autorisees = `https://app.lucaslopvet.fr`, `https://dev.app.lucaslopvet.fr`, `http://localhost:(3000|3001|3002|5000|8080|4200|9000)`
- **Trust proxy** : `app.set('trust proxy', 1)` pour Nginx
- **Audit logging** : Envoi asynchrone vers db-service `/api/logs/internal` avec header `x-internal-secret`

## 1.6 Configuration (src/config.js)

| Variable           | Defaut          | Description                                              |
|--------------------|-----------------|----------------------------------------------------------|
| PORT               | 3000            |                                                          |
| DB_PATH            | auth.db         |                                                          |
| DB_SERVICE_URL     | localhost:3002  |                                                          |
| INTERNAL_SECRET    | (none)          | Secret communication inter-services                      |
| JWT_SECRET         | null            | Shim transition HS256 — à supprimer en Phase 5           |
| KC_ISSUER          | (requis)        | `https://keycloak.lucaslopvet.fr/realms/kabutare-hospital` |
| KC_REALM           | kabutare-hospital |                                                        |
| KC_ADMIN_URL       | (requis)        | URL interne Keycloak pour Admin API                      |
| KC_CLIENT_ID       | auth-service    | Client Keycloak (service account)                        |
| KC_CLIENT_SECRET   | (requis)        | Secret du client confidential auth-service               |

## 1.7 Dependances (package.json)

| Package            | Version  | Role                                             |
|--------------------|----------|--------------------------------------------------|
| express            | ^4.21.0  | Framework web                                    |
| better-sqlite3     | ^11.7.0  | Driver SQLite                                    |
| jsonwebtoken       | ^9.0.2   | Validation JWT (shim HS256 + decode claims)      |
| jwks-rsa           | ^3.1.0   | Récupération clés publiques Keycloak (JWKS)      |
| bcrypt             | ^5.1.1   | Legacy — à supprimer en Phase 5                  |
| helmet             | ^8.0.0   | Headers securite                                 |
| express-rate-limit | ^7.5.1   | Rate limiting                                    |
| cors               | ^2.8.5   | CORS middleware                                  |
| jest               | ^29.7.0  | Tests (dev)                                      |
| supertest          | ^7.0.0   | Tests HTTP (dev)                                 |

### Scripts npm

| Script          | Commande                         | Role                                      |
|-----------------|----------------------------------|-------------------------------------------|
| start           | `node src/index.js`              |                                           |
| seed            | `node seed.js`                   | Données démo (legacy — ne crée plus users)|
| kc:init         | `node scripts/keycloak-init.js`  | Bootstrap realm Keycloak (one-shot)       |
| migrate:users   | `node scripts/migrate-users.js`  | Migration users auth.db → Keycloak        |

---

# 2. DB Service

**Stack** : Node.js 20 (Alpine) / Express 4.21.0 / SQLite (better-sqlite3 11.7.0)
**Port interne** : 3002 | **Port dev externe** : 3004

## 2.1 Schemas de base de donnees

### Table `equipment`

| Colonne            | Type    | Contraintes                                                  |
|--------------------|---------|--------------------------------------------------------------|
| id                 | TEXT    | PRIMARY KEY (regex `^[a-zA-Z0-9_-]+$`, max 100)              |
| name               | TEXT    | NOT NULL                                                     |
| department         | TEXT    | NOT NULL (denormalisation, sync avec departments.name)       |
| category           | TEXT    | NOT NULL (denormalisation, sync avec equipment_categories.name) |
| serial_number      | TEXT    | Nullable                                                     |
| status             | TEXT    | NOT NULL DEFAULT 'Operational'                               |
| location           | TEXT    | Nullable                                                     |
| created_at         | TEXT    | DEFAULT `datetime('now','localtime')`                        |
| updated_at         | TEXT    | DEFAULT `datetime('now','localtime')`                        |
| next_revision_date | TEXT    | Nullable, ajoute via migration                               |
| manufacturer       | TEXT    | Nullable, ajoute via migration (absorbe l'ancien `supplier`) |
| model              | TEXT    | Nullable, ajoute via migration                               |
| manuf_year         | INTEGER | Nullable, ajoute via migration (annee fabrication)           |
| install_date       | TEXT    | Nullable, ajoute via migration (ISO YYYY-MM-DD)              |
| department_id      | INTEGER | Nullable, FK -> departments(id), ajoute via migration        |
| category_id        | INTEGER | Nullable, FK -> equipment_categories(id), ajoute via migration |
| last_preventive_maintenance | TEXT | Nullable, ajoute via migration (ISO YYYY-MM-DD)        |
| next_preventive_maintenance | TEXT | Nullable, ajoute via migration (denormalise depuis `preventive_maintenance_plans`) |
| building           | TEXT    | Nullable, ajoute via migration (batiment / aile, ex : "Bloc A") |

> **Migration `supplier` -> `manufacturer`** : la colonne `supplier` a ete supprimee (`ALTER TABLE equipment DROP COLUMN supplier`). Les valeurs ont ete copiees dans `manufacturer` quand celui-ci etait NULL. Le XLSX d'inventaire physique ne distingue pas les deux concepts.

**Index** : `idx_equipment_dept` (department), `idx_equipment_status` (status)

### Table `locations` (nouvelle — infrastructure)

| Colonne    | Type | Contraintes  |
|------------|------|--------------|
| id         | TEXT | PRIMARY KEY  |
| name       | TEXT | NOT NULL     |
| building   | TEXT | NOT NULL     |
| department | TEXT | NOT NULL     |

**Index** : `idx_locations_dept` (department)
**Usage** : une issue peut viser un lieu (`issues.location_id`) plutot qu'un equipement — cas typique : panne electrique, probleme infrastructure.

### Table `departments`

| Colonne | Type    | Contraintes               |
|---------|---------|---------------------------|
| id      | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name    | TEXT    | NOT NULL UNIQUE           |

Peuplee par `scripts/import_inventory.js` depuis la feuille `Standard_Departments` du XLSX (~56 entrees, noms en anglais).

### Table `equipment_categories`

| Colonne | Type    | Contraintes               |
|---------|---------|---------------------------|
| id      | INTEGER | PRIMARY KEY AUTOINCREMENT |
| name    | TEXT    | NOT NULL UNIQUE           |

Peuplee par `scripts/import_inventory.js` depuis la feuille `Standard_Equipment_Names` du XLSX (~611 entrees + ajouts a la volee si une categorie utilisee dans l'inventaire est absente du standard).

### Table `equipment_tags`

| Colonne      | Type    | Contraintes                                          |
|--------------|---------|------------------------------------------------------|
| id           | INTEGER | PRIMARY KEY AUTOINCREMENT                            |
| equipment_id | TEXT    | NOT NULL, FK -> equipment(id) ON DELETE CASCADE      |
| tag_number   | TEXT    | NOT NULL                                             |

**Contrainte unique** : (equipment_id, tag_number) — un meme tag peut exister sur plusieurs equipements (collisions documentees dans le XLSX).
**Index** : `idx_equipment_tags_tag` (tag_number)
**Cle naturelle** : un equipement = un SerialNumber (cle primaire `equipment.id`), avec potentiellement plusieurs `tag_number` rattaches.

### Table `maintenance_records`

| Colonne             | Type    | Contraintes                                           |
|---------------------|---------|-------------------------------------------------------|
| id                  | INTEGER | PRIMARY KEY AUTOINCREMENT                             |
| equipment_id        | TEXT    | NOT NULL, FK -> equipment(id) ON DELETE CASCADE       |
| date                | TEXT    | NOT NULL                                              |
| intervention        | TEXT    | NOT NULL                                              |
| technician          | TEXT    | NOT NULL                                              |
| is_future           | INTEGER | DEFAULT 0                                             |
| technician_id       | TEXT    | UUID Keycloak du technicien (FEAT-044, migration)     |
| checklist_snapshot  | TEXT    | JSON sérialisé [{step,label,done}] (FEAT-044)         |
| duration_minutes    | INTEGER | Durée réelle de l'intervention (FEAT-044)             |
| parts_used          | TEXT    | JSON sérialisé [{inventory_id,name,qty}] (FEAT-044)   |
| maintenance_type    | TEXT    | 'preventive' ou 'corrective' (FEAT-044, default corrective) |

### Table `preventive_maintenance_plans` (nouvelle)

Plans de maintenance preventive (1 equipement -> N plans : trimestriel, annuel, calibration, etc.). Le champ `equipment.next_preventive_maintenance` peut etre calcule/denormalise depuis le plan le plus proche.

| Colonne              | Type    | Contraintes                                          |
|----------------------|---------|------------------------------------------------------|
| id                   | INTEGER | PRIMARY KEY AUTOINCREMENT                            |
| equipment_id         | TEXT    | NOT NULL, FK -> equipment(id) ON DELETE CASCADE      |
| frequency_months     | INTEGER | NOT NULL                                             |
| last_completed_date  | TEXT    | Nullable                                             |
| description          | TEXT    | Nullable                                             |
| created_at           | TEXT    | DEFAULT `datetime('now','localtime')`                |
| updated_at           | TEXT    | DEFAULT `datetime('now','localtime')`                |

**Index** : `idx_pm_plans_equipment` (equipment_id)

### Table `issues` (refondue — equipement OU lieu)

| Colonne              | Type | Contraintes                                        |
|----------------------|------|----------------------------------------------------|
| id                   | TEXT | PRIMARY KEY                                        |
| equipment_id         | TEXT | **Nullable** (NULL si l'incident vise un lieu)     |
| equipment_name       | TEXT | **Nullable** (NULL si l'incident vise un lieu)     |
| location_id          | TEXT | Nullable, FK -> locations(id)                      |
| issue_category       | TEXT | NOT NULL DEFAULT 'Biomedical' (Biomedical/Infrastructure/IT) |
| assigned_group       | TEXT | Nullable (Biomedical/Infrastructure/IT)            |
| department           | TEXT | NOT NULL                                           |
| type                 | TEXT | NOT NULL                                           |
| description          | TEXT | NOT NULL                                           |
| reporter             | TEXT | NOT NULL                                           |
| reporter_id          | TEXT | Nullable (migration)                               |
| reporter_email       | TEXT | Nullable (migration)                               |
| urgency              | TEXT | DEFAULT 'Moyen' (migration)                        |
| status               | TEXT | NOT NULL DEFAULT 'Reported'                        |
| assigned_technician  | TEXT | Nullable                                           |
| diagnosis            | TEXT | Nullable                                           |
| actions              | TEXT | Nullable                                           |
| parts_replaced       | TEXT | Nullable                                           |
| created_at           | TEXT | NOT NULL                                           |
| resolved_at          | TEXT | Nullable — posé à la 1ʳᵉ transition vers `Completed` (KPI MTTR, onglet Terminés) |
| updated_at           | TEXT | DEFAULT `datetime('now','localtime')`              |

**Contrainte applicative** (POST `/api/issues`) : `equipment_id` + `equipment_name` **OU** `location_id` doit etre fourni.
**`resolved_at`** : renseigné une seule fois par `PUT /api/issues/:id` quand `status` passe à `Completed` (idempotent via `COALESCE` — jamais réécrit). Les incidents terminés avant la migration restent `NULL`. Migration `ALTER TABLE` placée **après** le rebuild ci-dessus.
**Derivation auto** : `issue_category` / `assigned_group` = `Biomedical` si equipement, `Infrastructure` si lieu.
**Index** : `idx_issues_status` (status), `idx_issues_equipment` (equipment_id), `idx_issues_location` (location_id), `idx_issues_group` (assigned_group)
**Migration** : rebuild complet de la table (RENAME -> CREATE -> INSERT SELECT -> DROP), idempotent (s'execute si `location_id` est absent du PRAGMA).

### Table `inventory`

| Colonne        | Type    | Contraintes                    |
|----------------|---------|--------------------------------|
| id             | TEXT    | PRIMARY KEY                    |
| name           | TEXT    | NOT NULL                       |
| category       | TEXT    | NOT NULL                       |
| current_stock  | INTEGER | NOT NULL DEFAULT 0             |
| min_stock      | INTEGER | NOT NULL DEFAULT 0             |
| unit           | TEXT    | NOT NULL                       |
| status         | TEXT    | NOT NULL DEFAULT 'Normal'      |
| last_restocked | TEXT    | Nullable                       |
| updated_at     | TEXT    | DEFAULT CURRENT_TIMESTAMP      |

### Table `logs`

| Colonne     | Type    | Contraintes                    |
|-------------|---------|--------------------------------|
| id          | INTEGER | PRIMARY KEY AUTOINCREMENT      |
| timestamp   | TEXT    | DEFAULT CURRENT_TIMESTAMP      |
| user_id     | TEXT    | Nullable                       |
| user_name   | TEXT    | NOT NULL                       |
| user_role   | TEXT    | NOT NULL                       |
| action      | TEXT    | NOT NULL                       |
| target_type | TEXT    | Nullable                       |
| target_id   | TEXT    | Nullable                       |
| target_name | TEXT    | Nullable                       |
| details     | TEXT    | Nullable                       |
| ip_address  | TEXT    | Nullable (migration)           |
| user_agent  | TEXT    | Nullable (migration)           |

**Index** : `idx_logs_timestamp`, `idx_logs_user`, `idx_logs_action`

### Table `sidebar_config`

| Colonne     | Type    | Contraintes                        |
|-------------|---------|-------------------------------------|
| role        | TEXT    | NOT NULL, PK composite             |
| screen_type | TEXT    | NOT NULL, PK composite             |
| sort_order  | INTEGER | NOT NULL DEFAULT 0                 |

### Autres tables db-service (ajoutées au fil des features — audit 2026-06-10)

| Table | Création (`src/database.js`) | Rôle |
|---|---|---|
| `push_subscriptions` | :381 | Souscriptions Web Push par utilisateur |
| `features` + `feature_role_overrides` | :395, :402 | Feature flags **locaux db-service** (distincts de `feature_flags` auth-service) |
| `backup_settings` + `backup_history` | :422, :429 | Configuration et historique des sauvegardes SQLite |
| `equipment_macro_categories` / `equipment_subcategories` | :454, :467 | Taxonomie GMAO (3 macro-catégories) |
| `pm_protocols` + `_pm_seeded` | :571, :589 | Protocoles PM par type d'équipement + marqueur de seed |
| `equipment_documents` | :750 | Documents équipement (soft delete `deleted_at`). **[MODIFIÉ 2026-06-23]** colonne `issue_id TEXT` ajoutée (nullable), `equipment_id` rendu nullable (reconstruction de table idempotente) — un document peut désormais être rattaché à un incident sans équipement. Limitation connue : les documents archivés avant cette migration ont `issue_id IS NULL` (pas de backfill, aucune correspondance fiable) — restent visibles dans l'onglet Documents de l'équipement mais absents du badge/KPI/section "documents d'intervention" côté incident. |
| `issue_photos` | :770 | Photos d'incidents (max 5) |
| `notifications` | :793 | Notifications in-app |

Colonnes `issues` non listées plus haut : `location_text`, `location_tag` (`database.js:148-149`), `taken_at` (`database.js:152`).

Côté **auth-service**, la table `role_hierarchy` (parent/enfant de rôles, cf. `routes/roles.js:138`) existe également.

## 2.2 Enums de validation

| Contexte         | Valeurs                                                                       |
|------------------|-------------------------------------------------------------------------------|
| Equipment Status | `Operational`, `Maintenance`, `Out of service`, `To be disposal`, `Disposed` (5 valeurs, en anglais) |
| Equipment Dept   | `IT`, `Radiologie`, `Réanimation`, `Stérilisation`, `Laboratoire`, `Urgences`, `Maintenance`, `Infrastructure` |
| Equipment Cat    | `Imagerie`, `Laboratoire`, `Chirurgie`, `Monitoring`, `Thérapeutique`, `Informatique`, `Mobilier`, `Autre` |
| Issue Status     | `Reported`, `Acknowledged`, `Assigned`, `In Progress`, `Waiting Materials`, `Completed`, `Verified`, `Closed`, `Redirected`, `Rejected` (10 valeurs, en anglais) |
| Issue Urgency    | `Faible`, `Moyen`, `Urgent`, `Critique`                                       |
| Issue Type       | `Panne`, `Maintenance`, `Inspection`, `Autre`                                 |
| Issue Group      | `Biomédical`, `Infrastructure`, `IT` (nouveau — `assigned_group` & `issue_category`) |
| Inventory Cat    | `Consommable médical`, `Hygiène`, `Bureautique`                               |
| Inventory Status | `Normal`, `Faible`, `Rupture` (calcule : stock=0 -> Rupture, <min -> Faible)  |

### Migrations de statuts (FR -> EN) — appliquees automatiquement au demarrage

**equipment.status** (idempotent, UPDATE conditionnel) :
- `Disponible`, `En service`, `En usage` -> `Operational`
- `En maintenance` -> `Maintenance`
- `Hors service`, `Inactif`, `Transféré` -> `Out of service`
- `À éliminer` -> `To be disposal`

**issues.status** (idempotent) :
- `Ouvert` -> `Reported`
- `Approuvé` -> `Acknowledged`
- `En cours` -> `In Progress`
- `Résolu` -> `Completed`
- `Annulé` -> `Closed`

## 2.3 Donnees seed et import inventaire physique

### Source primaire — Inventaire physique 2025-2026 (XLSX hopital)

Script `db-service/scripts/import_inventory.js` — peuple la base depuis le fichier XLSX reel fourni par le service biomedical de l'hopital (`PHYISICAL INVENTORY OF MEDICAL EQUIPMENTS 2025-2026 -.xlsx`).

| Volume        | Resultat apres import |
|---------------|------------------------|
| equipment     | ~340 (342 lignes parsees - 2 collisions de SerialNumber) |
| equipment_tags| ~338 |
| departments   | ~56 (issus de Standard_Departments, en anglais) |
| equipment_categories | ~626 (~611 standard + ~15 ajoutes a la volee depuis l'inventaire) |

Statuts normalises vers la whitelist anglaise (`VALID_STATUSES_EQ`) : `operational`/variantes->`Operational`, `UNDER M`/`UNDERM`->`Maintenance`, `IDDLE`->`Out of service`, `DISPOSED`->`Disposed`, `to be disposal`->`To be disposal`, `KIBIRIZI DH`->`Out of service`. Defaut si vide ou inconnu = `Operational`. Logique dans `scripts/lib/inventory_normalizer.js` (testee via Jest).

CLI :
```bash
node scripts/import_inventory.js --xlsx <chemin.xlsx> [--dry-run] [--insert-only]
```

Audit : chaque insertion / mise a jour est tracee dans `logs` avec `user_role='system'`, `user_name='import_inventory'`, action `create_equipment_import` ou `update_equipment_import`.

### Donnees seed legacy (`db-service/seed.js`) - 45 equipements de demo

Les equipements de seed (id `eq-001`...`eq-045`) cohabitent avec les equipements importes du XLSX (id derive du SerialNumber). Exemples :

| ID     | Nom                            | Departement    | Categorie           | Statut          |
|--------|--------------------------------|----------------|---------------------|-----------------|
| eq-001 | Serveur Dell PowerEdge R750    | Administration | Equipement ICT      | Operational     |
| eq-003 | Tensiometre electronique Omron | OPD            | Equipement biomedical| Operational    |
| eq-024 | Scanner IRM Siemens 1.5T       | Chirurgie      | Equipement biomedical| Operational    |
| eq-041 | Autoclave Steris 400           | Bloc operatoire| Sterilisation        | Maintenance    |

> Les statuts FR historiques eventuellement encore presents dans la base sont automatiquement migres vers leur equivalent EN au demarrage du service (cf. 2.2 — Migrations de statuts).

### Incidents (6 items)
| ID      | Equipement                | Statut       | Urgence | Reporter           |
|---------|---------------------------|--------------|---------|---------------------|
| ISS-001 | Respirateur anesthesie    | In Progress  | -       | Dr. Traore          |
| ISS-003 | Serveur Dell              | Reported     | -       | IT Admin. Konate    |
| ISS-004 | Scanner IRM               | Completed    | -       | Radiologue Camara   |

### Inventaire (7 items)
| ID      | Nom                        | Stock actuel | Stock min | Statut  |
|---------|----------------------------|--------------|-----------|---------|
| inv-001 | Gants steriles (boite 100) | 45           | 20        | Normal  |
| inv-002 | Masques chirurgicaux       | 12           | 15        | Faible  |
| inv-003 | Seringues 10ml             | 0            | 50        | Rupture |

## 2.4 Endpoints API

### Equipements (`/api/equipment`)

| Methode | Route                           | Auth              | Description                                      |
|---------|---------------------------------|-------------------|--------------------------------------------------|
| GET     | /api/equipment                  | Auth              | Liste (filtres: department, status, category, **macro_category**, **macro_category_id**). **Exclut `status='Disposed'` par défaut** (sauf `?include_disposed=true` ou `?status=Disposed`). Retourne maintenanceHistory + futureMaintenance + **macro_category** + **subcategory_name** + **replaced_by_name**/**replaces_id**/**replaces_name** (liens de remplacement). **[NOUVEAU 2026-06-24]** Pagination serveur optionnelle et rétro-compatible : sans `?page=`, réponse legacy inchangée (tableau brut). Avec `?page=&limit=` (défaut 20, max 100, 400 si <1) → enveloppe `{items, total, page, limit, total_pages}`. Ajoute aussi `?search=` (LIKE OR sur name/department/category/manufacturer/model) et `?sort_by=name\|status\|department\|install_date` + `?sort_dir=asc\|desc` (400 si hors whitelist). **[NOUVEAU 2026-06-25]** `?light=true` (legacy et paginé) : omet les 3 requêtes N+1 (`maintenanceHistory`/`futureMaintenance`/`tags` renvoyés vides) — toutes les colonnes scalaires restent présentes. Utilisé par `DataService._loadEquipment()` au login (optimisation bas-débit) ; la fiche détail recharge l'objet complet via `GET /api/equipment/:id` |
| GET     | /api/equipment/:id              | Auth              | Details avec historique maintenance + **pmProtocols** + **pmPlan** (fréquence + dernière date). **[NOUVEAU]** Expose `model_id`, `brand_id`, `brand_name`, `subcategory_id`, `subcategory_name`, `subcategory_description` (LEFT JOIN catalogue, `null` si non rattaché/non saisi) pour le drill-down et la description de la fiche |
| POST    | /api/equipment                  | Admin/Supervisor  | Creer (required: id, name, department, category) + optionnel: **subcategory_id**, **warranty_end_date**, **criticality** |
| PUT     | /api/equipment/:id              | Admin/Sup/Tech    | Modifier (COALESCE, partial update) + nouveaux champs GMAO |
| DELETE  | /api/equipment/:id              | Admin             | Supprimer (snapshot audit, ?reason=). **[GARDE-FOU]** Si historique (issues/maintenance/tags/documents) → `409 {hasHistory:true}` sauf `?force=true` (purge l'équipement + son historique, `details.forced=true`) |
| POST    | /api/equipment/:id/propose-disposal | Admin/Sup/Tech | **[NOUVEAU]** Étape 1 réforme : `status='To be disposal'` + `decommission_reason` (whitelist). 400 si déjà `Disposed`. Audit `propose_disposal_equipment` |
| POST    | /api/equipment/:id/decommission | Admin             | **[NOUVEAU]** Étape 2 réforme (soft delete) : `status='Disposed'` + métadonnées. Body `{decommission_reason, disposal_method, decommission_notes?, replaced_by_id?}`. Whitelists `DECOMMISSION_REASONS`/`DISPOSAL_METHODS` (400 sinon) ; `replaced_by_id` doit exister (404) et ≠ self (400) ; requis si motif=`replaced`. Audit `decommission_equipment` |
| POST    | /api/equipment/:id/maintenance  | Admin/Sup/Tech    | **v3** : body `{checklist_snapshot, notes, duration_minutes, parts_used, maintenance_type}`. Si `maintenance_type=preventive` : calcule next_pm, UPSERT plan, dé-stocke pièces, met à jour `last/next_preventive_maintenance`. Réponse: `{maintenance_record_id, next_preventive_maintenance, parts_updated}`. Legacy (corrective) : `{date, intervention, technician, is_future}` |
| PUT     | /api/equipment/:id/pm-plan      | Admin/Sup/Tech    | UPSERT fréquence PM. Body: `{frequency_months: int}`. Crée ou met à jour `preventive_maintenance_plans` |
| GET     | /api/equipment/:id/maintenance-label/:record_id | Admin/Sup/Tech | Génère un PDF A6 paysage (pdfkit). `Content-Type: application/pdf`. Inclut équipement, technicien, dates maint. |
| GET     | /api/equipment/replacement-plan | Admin/Sup         | **[NOUVEAU]** Plan de remplacement biomédical (RA3 S5). Calcul serveur âge/statut/horizon. Retourne `{summary:{biomedical_count, avg_age_years, end_of_life_count, end_of_life_pct, by_horizon, by_criticality}, items:[{id, name, subcategory, criticality, age, lifespan, overshoot, status_replacement, horizon}]}`. Statut: `a_remplacer`/`bientot`/`ok`/`donnee_manquante` ; tri criticité A>B>C puis dépassement |
| POST    | /api/equipment/restore          | Admin             | Restaurer equipement supprime                     |
| GET     | /api/equipment/:id/documents    | Auth (non-staff)  | Liste des documents actifs. Filtre optionnel: `?type=technical\|intervention\|certification`. Retourne `[{id, document_type, original_name, mime_type, file_size_kb, uploader_name, uploaded_at, issue_id, issue_status, issue_created_at}]` — `issue_*` nuls pour les documents sans incident associé (LEFT JOIN issues) |
| POST    | /api/equipment/:id/documents    | Admin/Sup/Tech    | **[NOUVEAU]** Upload multipart (`file` + `type`). Stockage physique `/data/uploads/documents/` avec nom UUID. Retourne `{id, stored_name, original_name, document_type, mime_type, file_size_kb}` |
| GET     | /api/equipment/:id/documents/:doc_id/download | Auth (non-staff) | **[NOUVEAU]** Téléchargement inline (`Content-Disposition: inline`). 404 si soft-deleted |
| DELETE  | /api/equipment/:id/documents/:doc_id | Admin/Sup    | **[NOUVEAU]** Soft delete (`deleted_at`). Fichier physique conservé |

### Catégories & Sous-catégories (`/api/categories`) **[NOUVEAU]**

| Methode | Route                    | Auth  | Description                                                  |
|---------|--------------------------|-------|--------------------------------------------------------------|
| GET     | /api/categories/macro    | Auth  | Liste des 3 macro-catégories (Biomedical, Infrastructure, IT) |
| GET     | /api/categories/sub      | Auth  | Liste sous-catégories (filtre: ?macro_category_id=). Inclut equipment_count |
| GET     | /api/categories/sub/:id  | Auth  | Détail sous-catégorie (inclut `description`) + `protocols` (PM) + `equipment_count` + **[NOUVEAU]** `equipment` (liste) + `brands` (fabricants présents, avec model_count/equipment_count) |
| GET     | /api/categories/detail   | Auth  | **[NOUVEAU]** Détail d'une catégorie standard par nom (`?name=`). Retourne `{name, equipment:[{id,name,status,department}], brands:[{id,name,model_count,equipment_count}]}`. Lecture seule (drill-down fiche équipement) |
| PUT     | /api/categories/sub/:id  | Admin | Renomme la sous-catégorie. Body `{name, macro_category_id?, description?}`. **[NOUVEAU]** `description` (TEXT, optionnel ; chaîne vide/null = effacement) affichée sur la fiche équipement. `logAction('update_subcategory')` (audit `old_description`/`description`) |
| PUT     | /api/categories/sub/:id/lifespan | Admin | **[NOUVEAU]** Durée de vie de référence (RA3 S5). Body `{expected_lifespan_years: int>=0\|null}`. `logAction('update_subcategory_lifespan')` |

### Protocoles de Maintenance Préventive (`/api/pm-protocols`) **[NOUVEAU]**

| Methode | Route              | Auth  | Description                                                               |
|---------|--------------------|-------|---------------------------------------------------------------------------|
| GET     | /api/pm-protocols  | Auth  | Liste (filtres: ?subcategory_id=, ?macro_category_id=). Checklist désérialisée en tableau |
| GET     | /api/pm-protocols/:id | Auth | Détail avec checklist |
| POST    | /api/pm-protocols  | Admin | Créer (required: subcategory_id, name, frequency_months ; optionnel: estimated_duration_hours, checklist[]) |
| PUT     | /api/pm-protocols/:id | Admin | Modifier (COALESCE partiel) |
| DELETE  | /api/pm-protocols/:id | Admin | Supprimer |

### Catalogue Fabricant → Modèle (`/api/brands`, `/api/models`) **[NOUVEAU]**

Fiche technique partagée au niveau du couple (fabricant + modèle). Lecture `verifyToken`, mutations `requireRole('admin')`. `logAction` sur chaque mutation.

| Methode | Route                                   | Auth  | Description                                                                 |
|---------|-----------------------------------------|-------|-----------------------------------------------------------------------------|
| GET     | /api/brands                             | Auth  | Liste fabricants + `model_count`/`equipment_count`. Filtre `?subcategory_id=` (présents dans la sous-cat) |
| GET     | /api/brands/:id                         | Auth  | Détail fabricant + ses modèles (filtrables `?subcategory_id=`)             |
| POST    | /api/brands                             | Admin | `{name}` ; 409 doublon (COLLATE NOCASE)                                      |
| PUT     | /api/brands/:id                         | Admin | Renommage ; 409 doublon                                                      |
| DELETE  | /api/brands/:id                         | Admin | **409 `BRAND_HAS_MODELS`** si modèles OU équipements rattachés               |
| GET     | /api/models                             | Auth  | Liste modèles + `equipment_count`. Filtres `?subcategory_id=` `?brand_id=`   |
| GET     | /api/models/:id                         | Auth  | Fiche : modèle + fabricant + sous-cat + `equipment` + `documents` + `protocols` |
| POST    | /api/models                             | Admin | `{brand_id, subcategory_id, name}` ; 409 doublon (UNIQUE)                    |
| PUT     | /api/models/:id                         | Admin | Renommage / rebranchement brand+subcat                                       |
| DELETE  | /api/models/:id                         | Admin | **409 `MODEL_HAS_EQUIPMENT`** si équipements rattachés                       |
| GET     | /api/models/:id/documents               | Auth  | Liste documents (filtre `?type=`)                                            |
| POST    | /api/models/:id/documents               | Admin | Upload multipart (champ `file`, `type` ∈ technical/intervention/certification) |
| GET     | /api/models/:id/documents/:docId/download | Auth | Téléchargement / aperçu                                                      |
| DELETE  | /api/models/:id/documents/:docId        | Admin | Soft-delete (`deleted_at`)                                                   |
| POST    | /api/models/:id/protocols/:protocolId   | Admin | Lier un `pm_protocols` (INSERT OR IGNORE, idempotent)                        |
| DELETE  | /api/models/:id/protocols/:protocolId   | Admin | Délier un protocole                                                          |

> Filtres ajoutés à `GET /api/equipment` : `?subcategory_id=`, `?brand_id=` (via modèle), `?model_id=`.

### Incidents (`/api/issues`)

| Methode | Route                       | Auth           | Description                                              |
|---------|-----------------------------|----------------|----------------------------------------------------------|
| GET     | /api/issues                 | Auth           | Liste (filtres: status, department, equipment_id), tri DESC created_at. LEFT JOIN du rapport finalisé : ajoute `report_duration_hours` et `report_estimated_cost` (KPIs MTTR réel + coût). **[MODIFIÉ 2026-06-23]** ajoute aussi `documents_count` (sous-requête `equipment_documents` par `issue_id`), exposé côté Flutter via `Issue.documentsCount` (badge liste + KPI taux de clôture documentée). **[NOUVEAU 2026-06-24]** Pagination serveur optionnelle et rétro-compatible : sans `?page=`, réponse legacy inchangée (tableau brut). Avec `?page=&limit=` (défaut 20, max 100) → enveloppe `{items, total, page, limit, total_pages}`. Filtres additionnels : `?search=` (LIKE OR sur type/description/reporter/department/equipment_name), `?status_ne=` (exclusion statut), `?urgency=`, `?assigned_group=`, `?assigned_group_in=` (CSV, inclut aussi `assigned_group IS NULL` — réplique la logique de pool technicien), `?assigned_technician=`, `?reporter_id=`, `?created_after=`/`?created_before=` (filtre période ISO), `?sort_by=created_at\|urgency` + `?sort_dir=asc\|desc` (défaut `desc`). Toute valeur d'enum hors whitelist → 400 |
| GET     | /api/issues/:id             | Auth           | Details incident enrichis : `{ ...issue, equipment, audit_log: [{id,timestamp,user_name,user_role,action,details}], maintenance_records: [{id,equipment_id,date,intervention,technician,is_future}] }` |
| POST    | /api/issues                 | Auth           | Signaler. Required: `id`, `department`, `type`, `description`, `reporter`, et **(`equipment_id`+`equipment_name`) OU `location_id`**. Auto-derive `issue_category` & `assigned_group` (Biomedical si equipement, Infrastructure si lieu). Status initial = `Reported`. |
| PUT     | /api/issues/:id             | Admin/Sup/Tech | Modifier (status, assigned_technician, diagnosis, actions, parts_replaced, urgency, taken_at). La 1ʳᵉ transition `status → Completed` pose `resolved_at` (ISO, idempotent via `COALESCE`) et l'inscrit dans l'audit `details`. Champ optionnel `parts_consumed: [{item_id, quantity}]` déclenche un déstockage transactionnel dans `inventory` (rollback si stock insuffisant → 409). |
| PATCH   | /api/issues/:id/reassign    | Admin/Sup/Tech | Reassigner vers un autre groupe. Body: `{ new_group, reason }`. `new_group` dans `Biomédical/Infrastructure/IT`, `reason` >= 10 char. Effets : `assigned_group` change, `assigned_technician` -> NULL, status -> `Reported`, ligne tracée appendée dans `actions`. |
| PATCH   | /api/issues/:id/escalate    | Admin/Sup/Tech | Escalade/suspension. Body: `{ escalation_status, escalation_comment }`. `escalation_status` ∈ `Waiting Materials\|Redirected`, `escalation_comment` >= 10 char. Met à jour le statut et appende le commentaire dans `actions`. |
| PATCH   | /api/issues/:id/reject      | Admin/Sup      | Rejet rapide d'un incident en file de validation. Body: `{ reason_code, comment? }`. `reason_code` ∈ `duplicate\|not_reproducible\|out_of_scope\|false_alarm\|other` ; `comment` obligatoire (≥5 char) si `other`, max 500. **409** si statut ≠ `Reported`. Effets : status → `Rejected`, ligne tracée appendée dans `actions` (incident conservé). Audit `reject_issue`. |
| PATCH   | /api/issues/:id/detach      | Admin/Sup/Tech | Détachement d'un incident pris en charge → retour au pool. Body: `{ reason }` (≥10 char). **409** si statut ≠ `In Progress` ; **403** si technicien non-assigné (admin exempté). Effets : status → `Acknowledged`, `assigned_technician`/`taken_at` → NULL, ligne tracée appendée dans `actions`. Audit `detach_issue`. |
| PATCH   | /api/issues/:id/link-equipment | Admin/Sup/Tech | **[NOUVEAU]** Liaison tardive d'un incident créé sans équipement (`equipment_id IS NULL`) à un équipement du catalogue. Body: `{ equipment_id }`. **400** si manquant ; **409** si déjà lié ou incident clôturé (`Completed`/`Rejected`) ou équipement `Disposed` ; **403** si technicien non-assigné/incident non `In Progress` (admin/supervisor exemptés) ; **404** si incident ou équipement introuvable. Effets : `equipment_id`/`equipment_name` posés, `equipment_linked_at` (ISO, posé une seule fois), ligne tracée appendée dans `actions`. Audit `link_issue_equipment`. |
| PATCH   | /api/issues/:id/close-as-disposed | Admin/Sup/Tech | Clôture intervention — équipement irréparable. Body: `{ reason (≥10 char), disposal_method ∈ destroyed\|sold\|donated\|returned\|cannibalized }`. **400** si incident sans `equipment_id` ou body invalide ; **404** si incident/équipement introuvable ; **409** si équipement déjà `Disposed`. Effets : session active fermée silencieusement, issue → `Completed`, equipment → `Disposed` (`decommission_reason = 'irreparable'`, `disposal_method`, `decommission_notes`, `decommissioned_by_*`). Deux logAction : `issue_closed_equipment_disposed` + `decommission_equipment`. |
| DELETE  | /api/issues/:id             | Admin          | Supprimer                                                |
| POST    | /api/issues/:id/photos      | Auth           | **[NOUVEAU]** Upload multipart (champ `photos`, max 5 fichiers JPEG/PNG, 5 Mo chacun). Vérifie que total ≤ 5. Retourne `{photos: [{id, original_name, file_size_kb}]}` |
| GET     | /api/issues/:id/photos      | Auth           | **[NOUVEAU]** Liste les photos de l'incident. Retourne `[{id, original_name, mime_type, file_size_kb, uploaded_at}]` |
| GET     | /api/issues/:id/photos/:photo_id/download | Auth | **[NOUVEAU]** Téléchargement inline d'une photo. `Content-Disposition: inline` |
| GET     | /api/issues/:id/report      | Auth           | **[NOUVEAU]** Rapport d'intervention (brouillon vide `{issue_id, report_status:'draft'}` si absent). Joint les champs live de l'incident : `diagnosis`, `actions`, `parts_replaced`, `equipment_id`, `equipment_name`, `issue_status` |
| PUT     | /api/issues/:id/report      | Admin/Sup/Tech | **[NOUVEAU]** UPSERT du rapport (`ON CONFLICT(issue_id)`). **409** si `report_status='finalized'` sauf `admin`. Valide `final_equipment_status` (whitelist statuts équipement → 400). Renseigne `author_id/name` au 1er enregistrement |
| POST    | /api/issues/:id/report/finalize | Admin/Sup/Tech | **[NOUVEAU]** Fige le rapport (`finalized`). Exige `issues.status ∈ {Completed, Verified, Closed}` sinon **409**. Renseigne `validated_by_id/name` + `validated_at` |
| PATCH   | /api/issues/:id/report/reopen | Admin        | **[NOUVEAU]** Rouvre un rapport figé (`report_status='draft'`) |
| GET     | /api/issues/:id/sessions    | Auth           | **[NOUVEAU]** Liste toutes les boucles d'intervention (triées `loop_number ASC`). **404** si incident inexistant |
| PUT     | /api/issues/:id/sessions/active | Admin/Sup/Tech | **[NOUVEAU]** Upsert transactionnel de la session active. **400** si incident n'est pas `In Progress`. Crée (loop_number auto) ou met à jour la session ouverte. Champs : `diagnosis`, `diagnosis_addendum`, `action_taken`, `outcome`. Audit trail `update_intervention_session` |
| POST    | /api/issues/:id/sessions/active/close | Admin/Sup/Tech | **[NOUVEAU]** Ferme la session active. **400** si pas de session active, ou `resolved=false` sans `next_actions`. Calcule `duration_hours` via `julianday`. Audit trail `close_intervention_session` |
| GET     | /api/issues/:id/documents   | Auth           | **[NOUVEAU 2026-06-23]** Liste les documents PDF d'intervention de l'incident (`equipment_documents` filtré par `issue_id`). Retourne `[{id, document_type, original_name, mime_type, file_size_kb, uploader_name, uploaded_at}]` |
| POST    | /api/issues/:id/documents   | Admin/Sup/Tech | **[NOUVEAU 2026-06-23]** Upload multipart multi-fichiers (champ `files`, max 5, PDF/JPEG/PNG 10 Mo chacun). Body `type` (défaut `completion`, whitelist incluant `intervention`). Rattache aussi à `equipment_id` si l'incident en a un. Audit trail `upload_intervention_document` |
| GET     | /api/issues/:id/documents/:doc_id/download | Auth | **[NOUVEAU 2026-06-23]** Téléchargement inline d'un document d'intervention. `Content-Disposition: inline`. Audit trail `download_intervention_document` |

### Documents d'intervention cross-équipement (`/api/documents/interventions`) **[NOUVEAU 2026-07-01]**

Onglet « Documents » de la page technicien : liste/filtre/export des documents `equipment_documents`
avec `document_type='intervention'`, toutes équipements confondus (pas de scope par `equipment_id`).
Auth : `verifyToken` + `requireRole('admin','supervisor','technician','technician_biomedical','technician_it','technician_infra')`
sur les 4 routes (pas de middleware de permission fine côté db-service — la permission applicative
`viewInterventionDocuments` est vérifiée côté Flutter uniquement, cf. `contexte.md` § IAM & Sécurité).

| Methode | Route                                  | Auth  | Description |
|---------|-----------------------------------------|-------|--------------|
| GET     | /api/documents/interventions            | Rôles ci-dessus | Liste paginée (`?page=&limit=`, défaut 20, max 100). Filtres : `?uploaded_by=` (égalité stricte UUID, jamais LIKE sur le nom), `?from=&to=` (`YYYY-MM-DD`, filtre sur `date(uploaded_at)`), `?search=` (LIKE sur `original_name` uniquement). `400` si date mal formatée ou `from > to`. Enveloppe `{items, total, page, limit, total_pages}`, `items` vide (pas d'erreur) si aucun résultat |
| GET     | /api/documents/interventions/technicians | Rôles ci-dessus | Paires `{uploaded_by, uploader_name}` distinctes ayant au moins un document `intervention` non supprimé — alimente le filtre technicien (jamais de résolution par nom) |
| GET     | /api/documents/interventions/zip        | Rôles ci-dessus | Mêmes filtres `uploaded_by`/`from`/`to` (pas de pagination, pas de plafond de volume). `404` si sélection vide. `archiver('zip')` en streaming direct sur la réponse (`Content-Type: application/zip`), noms de fichiers dédupliqués (`_2`, `_3`…). Audit `export_intervention_documents_zip` (`{uploaded_by, from, to, doc_count}`) |
| GET     | /api/documents/interventions/print-pdf  | Rôles ci-dessus | Mêmes filtres, ne garde que `mime_type='application/pdf'` (images exclues du merge, pas de conversion). `404` si aucun PDF ne matche. Fusion via `pdf-lib` (`PDFDocument.copyPages`), `Content-Type: application/pdf`. Audit `export_intervention_documents_pdf` |

> Dépendances ajoutées à `db-service/package.json` : `archiver` (ZIP streaming), `pdf-lib` (fusion PDF).
> Aucune nouvelle table/colonne — lecture filtrée de `equipment_documents` existante.

### Lieux (`/api/locations`)

| Methode | Route            | Auth  | Description                                       |
|---------|------------------|-------|---------------------------------------------------|
| GET     | /api/locations   | Auth  | Liste tous les lieux, triee par `building, name`. |

### Inventaire (`/api/inventory`)

| Methode | Route               | Auth            | Description                                          |
|---------|---------------------|-----------------|------------------------------------------------------|
| GET     | /api/inventory      | Auth            | Liste (filtres: status, category), tri ASC name      |
| GET     | /api/inventory/:id  | Auth            | Details article                                      |
| POST    | /api/inventory      | Admin/Supervisor| Creer (required: id, name, category, current_stock, min_stock, unit). Status calcule auto |
| PUT     | /api/inventory/:id  | Admin/Sup/Tech  | Modifier. Si restock detecte -> last_restocked maj   |
| DELETE  | /api/inventory/:id  | Admin           | Supprimer                                            |

### Logs (`/api/logs`)

| Methode | Route              | Auth            | Description                                          |
|---------|--------------------|-----------------|------------------------------------------------------|
| GET     | /api/logs          | Admin           | Consulter (filtres: action, user_id, target_type, from, to, limit max 1000 defaut 500) |
| POST    | /api/logs/internal | Header interne  | Enregistrement depuis auth-service (header: x-internal-secret) |

### Sidebar Config (`/api/sidebar`)

| Methode | Route                | Auth  | Description                                        |
|---------|----------------------|-------|----------------------------------------------------|
| GET     | /api/sidebar/config  | Auth  | Config pour le role (query: ?role=, defaut req.user.role) |
| PUT     | /api/sidebar/config  | Admin | Modifier l'ordre des ecrans pour un role (transaction) |
| GET     | /api/sidebar/config/all | Auth | **[NOUVEAU 2026-06-25]** Config de TOUS les rôles en un seul appel : `{admin: [...], supervisor: [...], technician_biomedical: [...], technician_it: [...], technician_infra: [...], hospitalStaff: [...]}`. Remplace les 6 requêtes `?role=` émises au login (`DataService._loadSidebarConfig()`) — optimisation bas-débit, route statique déclarée avant `GET /` |

### Départements (`/api/departments`)

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/departments | Auth | Liste des départements |
| GET | /api/departments/:id/stats | Auth | Statistiques d'un département |
| GET | /api/departments/:id/detail | Auth | Dashboard département (lecture seule). Retourne `{id, name, kpis:{total,operational,maintenance,outOfService,pmOverdue,openIssuesCount}, equipment:[{id,name,status,category}], openIssues:[...], resolvedIssues:[...]}`. Chaque incident = `{id,type,description,status,urgency,issue_category,equipment_name,location_name,created_at,updated_at}` avec `location_name = COALESCE(locations.name, location_text)`. `openIssues` = statuts non terminaux (tri `created_at` DESC) ; `resolvedIssues` = `Completed/Verified/Closed` (tri `updated_at` DESC). KPIs/équipements via `department_id` ; incidents via `department=name` |
| GET | /api/departments/:id/check-dependencies | Admin | Vérifie les dépendances avant suppression |
| POST | /api/departments | Admin | Créer |
| PUT | /api/departments/:id | Admin | Modifier |
| DELETE | /api/departments/:id | Admin | Supprimer |

### Analytics (`/api/analytics`)

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/analytics | Admin | Données agrégées pour AnalyticsScreen |

### Features db-service (`/api/features`)

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/features | Admin | Liste des features (tables `features` + `feature_role_overrides` locales db-service) |
| PUT | /api/features/:id | Admin | Mise à jour état global + overrides |

### Sauvegardes (`/api/admin/backups`)

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/admin/backups | Admin | Historique (`backup_history`) + réglages (`backup_settings`) |
| POST | /api/admin/backups/trigger | Admin | Sauvegarde immédiate (`db.backup()`) |
| POST | /api/admin/backups/settings | Admin | Réglages du cron de sauvegarde |
| GET | /api/admin/backups/download/:id | Admin | Téléchargement d'une sauvegarde |

### Notifications push & in-app (`/api/notifications`)

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/notifications/vapid-key | Public | Clé publique VAPID (Web Push) |
| POST | /api/notifications/subscribe | Auth | Enregistre une souscription push (`push_subscriptions`) |
| POST | /api/notifications/unsubscribe | Auth | Supprime la souscription |
| GET | /api/notifications | Auth | Notifications in-app de l'utilisateur (table `notifications`) |
| PATCH | /api/notifications/read-all | Auth | Tout marquer lu |
| PATCH | /api/notifications/:id/read | Auth | Marquer une notification lue |

### Compléments équipements & incidents

| Methode | Route | Auth | Description |
|---|---|---|---|
| GET | /api/equipment/by-tag/:tagNumber | Auth | Recherche par numéro de tag physique |
| GET | /api/issues/:id/assignable-technicians | Admin/Sup/Tech | Techniciens assignables (interroge auth-service) |

### Debug & Test (`/api/debug`)

| Methode | Route                      | Auth   | Description                                                       |
|---------|----------------------------|--------|-------------------------------------------------------------------|
| GET     | /                          | Public | Dashboard HTML debug (stats + tableaux)                           |
| GET     | /health                    | Public | `{ "status": "ok", "service": "db-service" }`                    |
| POST    | /api/debug/clear-issues    | Admin  | Supprime tous les incidents (`DELETE FROM issues`). Retourne `{ deleted: N }`. Audit trail action `debug_clear_all_issues`. |
| POST    | /api/debug/notify-now      | Admin  | Envoie une notification email de test immédiate à l'admin appelant (type `critical_new_issue`). Retourne `{ success, message, sent, reason }`. Audit `debug_notify_now`. |
| POST    | /api/debug/notify-schedule | Admin  | Active/désactive les notifications email auto de test. Body: `{ interval: "minute" \| "hour" \| "stop" }`. Retourne `{ success, status, interval? }`. Audit `debug_notify_start` / `debug_notify_stop`. Scheduling in-memory (reset au redémarrage). |

## 2.5 Middleware

- **verifyToken** : validation **JWKS RS256 Keycloak uniquement** (`jwks-rsa`, cache 10 min, `KC_JWKS_URI` surchargeable) — aucun `JWT_SECRET`, aucun fallback HS256 (`src/middleware/auth.js:35`). Normalise `req.user = { id: sub, email, name, roles (filtrés SYSTEM_ROLES), department }`
- **requireRole(...roles)** : vérifie `req.user.roles.some(...)` → 403 sinon
- **upload** (`src/middleware/upload.js`) : multer, noms de fichiers UUID, `documentUpload` (JPEG/PNG/PDF, 10 Mo) et `photoUpload` (JPEG/PNG, 5 Mo, max 5 fichiers)

## 2.6 Configuration (src/config.js)

| Variable         | Defaut                                                |
|------------------|-------------------------------------------------------|
| PORT             | 3002                                                  |
| DB_PATH          | hospital.db                                           |
| KC_ISSUER        | (requis) URL du realm Keycloak                        |
| KC_JWKS_URI      | (optionnel) surcharge l'URL JWKS                      |
| AUTH_SERVICE_URL | http://localhost:3001                                 |
| INTERNAL_SECRET  | kabutare-internal-secret-change-in-production ⚠️ fallback en dur — correctif #4 audit |
| UPLOAD_DIR       | Répertoire de stockage des uploads (`/data/uploads/documents`) |

> `JWT_SECRET` n'existe plus dans db-service — la validation est 100 % JWKS RS256 (audit 2026-06-10).

## 2.7 Dependances (package.json)

| Package        | Version  | Role                                      |
|----------------|----------|-------------------------------------------|
| express        | ^4.21.0  | Framework web                             |
| better-sqlite3 | ^11.7.0  | Driver SQLite                             |
| jsonwebtoken   | ^9.0.2   | Verification JWT                          |
| helmet         | ^8.0.0   | Headers securite                          |
| cors           | ^2.8.5   | CORS middleware                           |
| axios          | ^1.7.0   | Client HTTP                               |
| xlsx           | ^0.18.5  | Lecture du XLSX d'inventaire (SheetJS)    |
| jest           | ^29.7.0  | Tests (dev) — `__tests__/inventory_normalizer.test.js` |
| supertest      | ^7.0.0   | Tests HTTP (dev)                          |

### Scripts npm exposes

| Script                  | Commande                                | Role                                            |
|-------------------------|-----------------------------------------|-------------------------------------------------|
| start                   | `node src/index.js`                     | Lance le service                                |
| seed                    | `node seed.js`                          | Peuple la base avec les donnees de demo legacy  |
| import:inventory        | `node scripts/import_inventory.js`      | Importe l'inventaire physique 2025-2026 (XLSX)  |
| test                    | `jest --forceExit --detectOpenHandles`  | Tests unitaires (DB en `:memory:`)              |

---

# 3. Flutter App

**Stack** : Flutter SDK ^3.10.7 / Dart
**State management** : Singleton + ChangeNotifier (pas de Provider/Bloc/Riverpod)
**19 517 lignes de code Dart dans 48 fichiers**

## 3.1 Architecture des fichiers

```
lib/
├── main.dart              # Point d'entree, navigation, module hub
├── screens/               # 25 ecrans
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── equipment_list_screen.dart
│   ├── issue_tracking_screen.dart
│   ├── issue_form_screen.dart
│   ├── issue_staff_detail_screen.dart  # Vue lecture seule incidents pour hospitalStaff (timeline, pas de champs techniques)
│   ├── technician_update_screen.dart
│   ├── technician_schedule_screen.dart  # Planning technicien (calendrier), extrait de l'onglet Agenda
│   ├── inventory_screen.dart
│   ├── reports_screen.dart
│   ├── user_management_screen.dart
│   ├── settings_screen.dart
│   ├── logs_screen.dart
│   ├── account_settings_screen.dart
│   ├── subcategory_detail_screen.dart  # Détail sous-catégorie : durée de vie/alertes (biomédical) + équipements + fabricants (toutes macro-cat)
│   ├── equipment_hub_screen.dart       # [NOUVEAU] Conteneur Équipements : onglets « Liste » | « Catégories » (Catégories si permission manageCategories)
│   ├── brand_detail_screen.dart        # [NOUVEAU] Détail fabricant : modèles (CRUD admin) dans le contexte de la sous-catégorie
│   ├── model_detail_screen.dart        # [NOUVEAU] Fiche modèle : équipements + documents (upload/delete) + protocoles PM (lier/délier)
│   ├── category_detail_screen.dart     # [NOUVEAU] Fiche catégorie standard : équipements (→ détail) + fabricants présents (lecture seule, drill-down)
│   ├── department_detail_screen.dart   # [NOUVEAU] Dashboard département : KPIs parc + équipements (→ détail) + incidents ouverts (lecture seule)
│   └── home_hub_screen.dart
├── services/
│   ├── auth_service.dart        # Singleton, login/logout/session
│   ├── auth_api_service.dart    # Appels API auth-service
│   ├── data_service.dart        # Singleton, chargement/cache donnees
│   ├── db_api_service.dart      # Appels API db-service
│   ├── api_client.dart          # Client HTTP, tokens, refresh auto
│   ├── config_service.dart      # Departements/categories dynamiques
│   └── notification_service.dart# Notifications in-app
├── models/
│   ├── user.dart                # User model
│   ├── user_role.dart           # UserRole enum, Permission enum
│   ├── equipment.dart           # Equipment, MaintenanceRecord, EquipmentStatus enum
│   ├── issue.dart               # Issue, IssueStatus, IssueUrgency enums
│   ├── inventory_item.dart      # InventoryItem, InventoryCategory, StockStatus enums
│   ├── notification.dart        # AppNotification model
│   ├── location.dart            # Location model (lieux infrastructure)
│   ├── departments.dart         # Department, EquipmentCategory enums
│   ├── equipment_document.dart  # [NOUVEAU] EquipmentDocument (documents équipement)
│   └── issue_photo.dart         # [NOUVEAU] IssuePhoto (photos incidents)
├── providers/
│   └── locale_provider.dart     # FR/EN avec SharedPreferences
├── widgets/                     # Composants UI reutilisables
│   ├── issue_category_selector.dart  # Selecteur de categorie avant IssueFormScreen
│   ├── equipment/
│   │   └── equipment_documents_tab.dart  # [NOUVEAU] Onglet Documents (2 sections + upload/download/delete)
│   └── issue/
│       └── intervention_documents_section.dart  # [NOUVEAU 2026-06-23] Liste des PDF d'intervention de l'incident — remplace InterventionReportSection (formulaire manuel retiré de issue_detail_screen, fichier/modèle conservés pour les routes /report*)
├── theme/                       # AppTheme, couleurs
├── l10n/                        # Traductions FR/EN
├── utils/                       # Utilitaires (file picker)
│   └── image_compressor.dart    # [NOUVEAU] Compression images (web=bypass, natif=placeholder)
└── data/                        # Donnees mock pour dev offline
```

## 3.2 Services principaux

### AuthService (Singleton)

| Methode                | Description                                              |
|------------------------|----------------------------------------------------------|
| loginWithApi(email, pw)| Login API, sauvegarde tokens, retourne bool              |
| restoreSession()       | Auto-login via getMe() si tokens stockes                 |
| refreshCurrentUser()   | Recharge profil depuis API                               |
| logoutApi()            | Logout API + clear tokens                                |
| updateProfile({...})   | Mise a jour profil (rollback on error)                   |
| changePassword(pw)     | Changement mot de passe                                  |
| handleSessionExpired() | Appele quand refresh JWT echoue                          |
| hasPermission(p)       | Verifie permission utilisateur courant                   |

**Getters pratiques** : `canViewEquipment`, `canManageEquipment`, `canReportIssue`, `canTrackIssues`, `canApproveRequests`, `canAssignTasks`, `canUpdateRepairs`, `canManageUsers`, `canGenerateReports`, `canViewInventory`

### DataService (Singleton)

| Donnees                      | Source API                                    |
|------------------------------|-----------------------------------------------|
| `equipment: List<Equipment>` | DbApiService.getEquipment()                   |
| `issues: List<Issue>`        | DbApiService.getIssues()                      |
| `inventory: List<InventoryItem>` | DbApiService.getInventory()               |
| `users: List<User>`          | AuthApiService.getUsers()                     |
| `deptRequests: List<Map>`    | AuthApiService.getDepartmentRequests()        |
| `sidebarOrder: Map<String, List<String>>` | DbApiService.getSidebarConfig() |
| `_rolePermissionsMap: Map`   | AuthApiService.getRoles()                     |

Methode `loadAll()` charge tout, fallback sur donnees mock si API indisponible.

### ApiClient (methodes statiques)

- **Token storage** : `SecureTokenStorage` (FlutterSecureStorage natif, SharedPreferences web)
- **Cles** : `access_token`, `refresh_token`
- **Methodes HTTP** : `get()`, `post()`, `put()`, `patch()`, `delete()` avec auth header auto
- **postPublic()** : Pour login/refresh (pas d'auth header)
- **Auto-refresh** : Sur 401 -> appel refresh endpoint -> rotation tokens -> retry requete
- **Callback** : `ApiClient.onSessionExpired` appele si refresh echoue
- **Headers** : `Content-Type: application/json`, `Authorization: Bearer <token>`

### ApiConfig

| Constante / Endpoint | URL / Valeur par defaut                                      | --dart-define          |
|----------------------|--------------------------------------------------------------|------------------------|
| authBaseUrl          | https://auth.lucaslopvet.fr                                  | AUTH_URL               |
| dbBaseUrl            | https://DB.lucaslopvet.fr                                    | DB_URL                 |
| kcTokenUrl           | https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token | KC_TOKEN_URL |
| kcClientId           | flutter-app                                                  | KC_CLIENT_ID           |
| meUrl                | /api/auth/me                                                 |                        |
| usersUrl             | /api/users                                                   |                        |
| deptRequestsUrl         | /api/users/department-requests                            |                        |
| rolesUrl                | /api/roles                                                |                        |
| notificationPrefsUrl    | /api/users/me/notifications                               |                        |
| equipmentUrl         | /api/equipment                                               |                        |
| issuesUrl            | /api/issues                                                  |                        |
| inventoryUrl         | /api/inventory                                               |                        |
| logsUrl              | /api/logs                                                    |                        |
| sidebarUrl           | /api/sidebar/config                                          |                        |
| sidebarAllUrl        | /api/sidebar/config/all                                      |                        |

> `loginUrl`, `logoutUrl`, `refreshUrl`, `verifyUrl` supprimés — ces opérations passent directement par `kcTokenUrl` (Keycloak).

## 3.3 Modeles de donnees

### User
```
id, name, firstName, lastName, email, department, createdAt: String
role: UserRole (enum)
permissions: List<Permission>
isActive: bool
phone: String?
fullName => '$firstName $lastName'
fromApiJson() : parse id, name, first_name, last_name, email, department, role, permissions, is_active, phone, created_at
```

### Equipment
```
id, name, department, category, serialNumber, location: String
manufacturer, model, installDate: String?  (manufacturer absorbe l'ancien supplier)
manufYear: int?
status: EquipmentStatus (operational, maintenance, outOfService, toBeDisposal, disposed)
nextRevisionDate, lastPreventiveMaintenance, nextPreventiveMaintenance: String?
maintenanceHistory, futureMaintenance: List<MaintenanceRecord>
MaintenanceRecord: { date, intervention, technician: String }
```

### Issue
```
id, department, type, description, reporter, createdAt: String
equipmentId, equipmentName, locationId, assignedGroup: String?  (equipement OU lieu)
issueCategory: String  (Biomedical/Infrastructure/IT, defaut Biomedical)
reporterId, reporterEmail, assignedTechnician, diagnosis, actions, partsReplaced: String?
status: IssueStatus (reported, acknowledged, assigned, inProgress, waitingMaterials, completed, verified, closed, redirected)
urgency: IssueUrgency (faible, moyen, urgent, critique)
```

### Location (nouveau)
```
id, name, building, department: String
```

### InventoryItem
```
id, name, unit, lastRestocked: String
category: InventoryCategory (consommableMedical, hygiene, bureautique)
currentStock, minStock: int
status: StockStatus (normal, low, outOfStock)
```

## 3.4 Ecrans (27 fichiers dans `lib/screens/` — audit 2026-06-10, +2 le 2026-06-15 : category_detail, department_detail, +1 le 2026-06-20 : technician_schedule — 2026-06-22 : FeatureManagementScreen n'a plus d'entrée sidebar autonome, intégré dans SettingsScreen onglet 4 — +1 le 2026-06-23 : technician_intervention_update, extrait de TechnicianUpdateScreen)

| #  | Ecran                    | Permissions requises    | Description                                                       |
|----|--------------------------|-------------------------|-------------------------------------------------------------------|
| 0  | LoginScreen              | -                       | Email/password, boutons dev quick-login                           |
| 1  | DashboardScreen          | -                       | Stats equipements par statut, 4 incidents recents, alertes critiques |
| 2  | EquipmentListScreen      | viewEquipment           | SliverList virtualisé, tri sur 4 colonnes, filtres PM (retard/imminente), RBAC colonnes (staffMedical vs technicien), export CSV liste filtrée, bouton "Planifier PM" quick-action, délègue créa/édition à EquipmentFormScreen |
| 2b | EquipmentFormScreen      | manageEquipment         | Nouvel écran dédié créa/édition : Stepper 3 étapes (Infos essentielles / Infos techniques / GMAO & Maintenance). Remplace le dialog mono-bloc. |
| 3  | IssueTrackingScreen      | trackIssues             | Liste unique tous les incidents, filtres statut/urgence/période/groupe, recherche, vue Kanban (desktop), split view, export CSV. Onglet "À valider" déplacé vers TechnicianUpdateScreen. |
| 3b | IssueDetailScreen        | trackIssues             | Sous-ecran GMAO : sections contexte (localisation `location_text`/`location_tag` + indicateur téléphone absent), panne, **incidents récents liés** (section `related_issues` max 3 depuis `GET /api/issues/:id`), intervention, **rapport d'intervention** (editable si pris en charge + technicien assigne/privilegie ; fige a la cloture ; reouverture admin ; export PDF + archivage auto), ressources, timeline. Charge GET /api/issues/:id enrichi + GET /api/issues/:id/report. Section rapport = widget reutilisable `widgets/issue/intervention_report_section.dart` (aussi en lecture seule dans IssueStaffDetailScreen). Actions admin/superviseur : **Valider** (si statut `reported` — choix groupe + urgence + délai depuis signalement, statut → Acknowledged), Réassigner (par groupe), Commenter. |
| 4  | IssueFormScreen          | reportIssue             | Formulaire : equipement picker (filtre par categoryFilter), type, urgence, description, photos (max 5). Parametre `categoryFilter: List<String>?` restreint les equipements selectionables. |
| 5  | TechnicianUpdateScreen   | updateRepairs OU approveRequests | Onglets : "À valider" (premier, conditionnel `canApproveRequests`) / Disponibles / Mes interventions (liste cliquable plein-écran, plus de master-detail). Bouton calendrier (à droite du TabBar) → TechnicianScheduleScreen. Le clic sur une carte d'intervention ouvre TechnicianInterventionUpdateScreen. L'onglet "À valider" propose un bouton unique "Examiner" qui ouvre IssueDetailScreen où se font validation + réassignation par groupe. |
| 6  | InventoryScreen          | viewInventory           | Table stock, filtres categorie/statut, CRUD                      |
| 7  | ReportsScreen            | generateReports         | Statistiques maintenance, équipements, KPIs GMAO (MTTR, PM). **Export CSV** + **Export PDF** multi-sections (synthèse, équipements, incidents, PM, MTTR, inventaire critique). **Section Archives** (FEAT-039) : sélecteur Mensuel/Annuel + dropdown (24 derniers mois ou 2 dernières années) → bouton "Télécharger le rapport PDF". Génération 100% côté client via `PdfReportService`. Toute la section Archives est conditionnée par `canGenerateReports`. |
| 8  | UserManagementScreen     | manageUsers             | CRUD users, demandes dept (approve/reject), filtres role          |
| 9  | SettingsScreen           | manageDepartments       | **5 onglets** : Départements, Rôles, Activité, Feature Flags, Paramètres généraux (contact login + config Brevo avec email de test) |
| 10 | LogsScreen               | manageUsers             | Logs d'audit filtres (action, user, type, dates, limit)          |
| 11 | AccountSettingsScreen    | -                       | Profil personnel, changement mot de passe                        |
| 12 | HomeHubScreen            | -                       | Hub de selection modules (Equipment, Settings, Inventory)         |
| 13 | DebugTestScreen          | manageFeatures (admin)  | Module Debug & Test — bouton pour vider la table issues (POST /api/debug/clear-issues) ; section "Tests de Notifications" : 4 boutons (notify-now, auto/minute, auto/heure, stop) + mini-historique des 3 derniers envois |
| 14 | EquipmentDetailScreen    | viewEquipment           | Détail équipement (historique maintenance, PM, documents) |
| 15 | IssueStaffDetailScreen   | trackIssues             | Vue lecture seule incidents pour hospitalStaff (timeline) |
| 16 | UserDetailScreen         | manageUsers             | Fiche utilisateur : profil, demandes dept/rôle, actions admin |
| 17 | RoleDetailScreen         | manageUsers             | Détail rôle : hiérarchie, permissions, ordre sidebar, utilisateurs |
| 18 | AnalyticsScreen          | generateReports         | Tableaux de bord analytiques (GET /api/analytics) |
| 19 | FeatureManagementScreen  | manageFeatures          | Gestion des feature flags par module et par rôle — **n'a plus d'entrée sidebar autonome** ; réutilisé comme onglet 4 de SettingsScreen via `FeaturesTab` |
| 20 | BackupManagementScreen   | manageBackups           | Sauvegardes : déclenchement, historique, téléchargement, cron |
| 21 | TechnicianScheduleScreen | updateRepairs OU approveRequests | Planning du technicien (calendrier `table_calendar` + historique mensuel). Extrait de l'ancien onglet "Agenda" de TechnicianUpdateScreen, désormais autonome (Scaffold) atteint via le bouton calendrier. |
| 22 | TechnicianInterventionUpdateScreen | updateRepairs OU approveRequests | Page dédiée à la mise à jour d'une intervention (diagnostic, actions, chrono, pièces, clôture/escalade/transfert/détachement), extraite du formulaire master-detail/inline de l'onglet "Mes interventions" de TechnicianUpdateScreen. Sélecteur de pièces masqué de façon réactive si le module `inventory` est désactivé (`FeatureService().isModuleEnabled`). `PopScope` + dialog de confirmation si modifications non sauvegardées. **2026-06-23 :** boutons Save + Save-and-Close fusionnés en un seul ElevatedButton `_doSaveAndClose` (màj incident + fermeture session + génération PDF) ; toggle `_planNextAction` conditionnel pour le champ next_actions (optionnel, sans validation minimum). |

## 3.5 Navigation

- **Responsive** : >800px = Sidebar (260px) + content | <800px = Drawer + bottom nav
- **Sidebar order** configurable par role via `DataService().sidebarOrder`
- **Historique** de navigation avec bouton retour
- **Dirty check** sur IssueFormScreen (avertit avant de quitter)
- **Session expire** : retour automatique au login si refresh token echoue
- **Initialisation** : auto-login si tokens stockes -> loadAll() -> HomeHub
- **Pre-qualification incidents** : tout clic sur "Signaler un incident" (sidebar, bottom nav, drawer, dashboard, issue tracking) ouvre d'abord `showIssueCategorySelector()` avant IssueFormScreen. Exception : depuis EquipmentListScreen (equipement pre-selectionne), la navigation reste index-based sans selecteur.

### Sélecteur de catégorie (`lib/widgets/issue_category_selector.dart`)

| Contexte | Comportement |
|---|---|
| Largeur >= 800 px | `showDialog` — Dialog centre, max 500 px |
| Largeur < 800 px | `showModalBottomSheet` — coins arrondis en haut |
| Clic sur une tuile | `Navigator.pop` du sheet/dialog + `Navigator.push` vers IssueFormScreen avec `categoryFilter` |
| Bouton AppBar retour | `Navigator.pop` — retour ecran precedent |

| Tuile | Icone | Filtre DB (`Equipment.category`) |
|---|---|---|
| Equipements Biomedicaux | `CupertinoIcons.heart_circle` | Imagerie, Laboratoire, Chirurgie, Monitoring, Therapeutique |
| Infrastructure & Electricite | `CupertinoIcons.building_2_fill` | Mobilier, Autre |
| Informatique (IT) | `CupertinoIcons.device_desktop` | Informatique |
| Autre / Je ne sais pas | `CupertinoIcons.question_circle` | `null` (tous les equipements) |

## 3.6 Flux principaux

### Signalement d'incident via le sélecteur de catégorie (nouveau)
1. Utilisateur clique "Signaler un incident" (dashboard / issue tracking / sidebar / bottom nav / drawer)
2. `showIssueCategorySelector(context)` affiche l'overlay responsive (dialog ou bottom-sheet)
3. Utilisateur choisit une tuile de categorie
4. Sheet/dialog se ferme via `Navigator.pop`
5. `Navigator.push(MaterialPageRoute)` ouvre `IssueFormScreen` avec `categoryFilter` + `onCancel: () => Navigator.pop(ctx)` dans un `Scaffold` avec `AppBar` retour
6. L'autocomplete equipement est restreint aux categories du filtre (`_filteredEquipmentList`)
7. Si aucun equipement ne correspond, une banniere ambre s'affiche sous le picker
8. Soumission ou annulation => `Navigator.pop` => retour ecran appelant

*Chemin alternatif (EquipmentListScreen)* : clic "Signaler" sur une ligne => `onNavigate(3, equipmentId: eq.id)` => index-based nav, IssueFormScreen avec equipement pre-selectionne, sans selecteur ni filtre.

### Login (Direct Grant Keycloak)
1. User saisit email/password
2. `AuthService.loginWithApi()` → `AuthApiService.login()` → POST `kcTokenUrl` (`grant_type=password`, form-urlencoded)
3. Keycloak retourne `access_token` + `refresh_token` (RS256)
4. Tokens sauvegardés dans SecureTokenStorage
5. `AuthApiService.getMe()` → GET `/api/auth/me` → profil complet avec permissions SQLite
6. `DataService.loadAll()` charge toutes les données
7. Navigation vers HomeHub

### Auto-refresh JWT (Keycloak)
1. Requête API retourne 401
2. `ApiClient._tryRefresh()` → POST `kcTokenUrl` (`grant_type=refresh_token`, form-urlencoded)
3. Nouveau pair de tokens sauvegardé (rotation Keycloak)
4. Requête originale rejouée
5. Si refresh échoue → `AuthService.handleSessionExpired()` → retour login

### CRUD Equipement
- Create: `DbApiService.createEquipment()` -> POST /api/equipment -> `DataService.reloadEquipment()`
  - Champs nouveaux (FEAT-097) : `building`, `model_id`, `tag_number` (insere dans equipment_tags via INSERT OR IGNORE)
- Update: `DbApiService.updateEquipment()` -> PUT /api/equipment/{id}
  - Memes champs nouveaux ; COALESCE sur building/model_id ; tag_number toujours via INSERT OR IGNORE
- Delete: `DbApiService.deleteEquipment()` -> DELETE /api/equipment/{id}?reason=

## 3.7 Clés i18n ajoutées (lib/l10n/)

Fichiers ARB template : `app_fr.arb` + `app_en.arb`. Génération : `flutter gen-l10n`.

| Clé | FR | EN |
|---|---|---|
| `issueCategorySelectorTitle` | Quel type de problème rencontrez-vous ? | What type of problem are you experiencing? |
| `issueCategoryBiomedical` | Équipements Biomédicaux | Biomedical Equipment |
| `issueCategoryBiomedicalDesc` | Scanner, IRM, analyseurs, moniteurs… | Scanner, MRI, analyzers, monitors… |
| `issueCategoryInfrastructure` | Infrastructure & Électricité | Infrastructure & Electrical |
| `issueCategoryInfrastructureDesc` | Lits, tables d'examen, éclairage… | Beds, examination tables, lighting… |
| `issueCategoryIT` | Informatique (IT) | IT (Information Technology) |
| `issueCategoryITDesc` | Ordinateurs, imprimantes, réseau… | Computers, printers, network… |
| `issueCategoryOther` | Autre / Je ne sais pas | Other / I don't know |
| `issueCategoryOtherDesc` | Problème non classé ou incertain… | Unclassified issue or unknown category… |
| `issueFormNoEquipmentInCategory` | Aucun équipement de ce type trouvé dans votre département. | No equipment of this type found in your department. |

## 3.9 Dependances (pubspec.yaml)

| Package                | Version  | Role                              |
|------------------------|----------|-----------------------------------|
| http                   | ^1.2.0   | Client HTTP                       |
| shared_preferences     | ^2.3.0   | Stockage local (web + prefs)      |
| flutter_secure_storage | ^9.2.4   | Stockage securise tokens (natif)  |
| table_calendar         | ^3.1.2   | Widget calendrier                 |
| intl                   | any      | Internationalisation (FR/EN)      |
| cupertino_icons        | ^1.0.8   | Icones iOS                        |
| file_picker            | ^8.0.0   | **[NOUVEAU]** Sélection de fichiers (web + natif) pour upload documents |

---

# 4. Infrastructure

## 4.1 Docker

### Dockerfiles (similaires pour les 2 services)

```dockerfile
FROM node:20-alpine
# Deps systeme : python3, make, g++ (pour better-sqlite3)
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY src/ ./src/
COPY scripts/ ./scripts/    # uniquement db-service (script d'import inventaire)
COPY seed.js ./
RUN mkdir -p /data
ENV DB_PATH=/data/{auth|hospital}.db NODE_ENV=production
EXPOSE {3001|3002}
CMD ["node", "src/index.js"]
```

> **Attention** : tout nouveau dossier doit etre explicitement `COPY` dans le Dockerfile. Le `.dockerignore` ne le copie pas automatiquement.

### Docker Compose Production (docker-compose.yml)

| Service            | Container               | Port       | Volume                      | Health check            |
|--------------------|-------------------------|------------|-----------------------------|-------------------------|
| auth-service       | auth-service-prod       | 3001:3001  | auth_data_prod:/data        | wget /health 30s/10s/3r |
| db-service         | db-service-prod         | 3002:3002  | db_data_prod:/data          | wget /health 30s/10s/3r |
| postgres-keycloak  | postgres-keycloak-prod  | (interne)  | keycloak_postgres_data:/var/lib/postgresql/data | pg_isready 10s/5s/5r |
| keycloak           | keycloak-prod           | 8080:8080  | (état dans PostgreSQL)      | bash /dev/tcp 9000 30s/10s/5r |

**db-service depends_on auth-service (condition: service_healthy)**
**keycloak depends_on postgres-keycloak (condition: service_healthy)**

### Docker Compose Dev (docker-compose.dev.yml)

| Service           | Container      | Port       | Volume              | Notes                          |
|-------------------|----------------|------------|---------------------|--------------------------------|
| auth-service-dev  | auth-service-dev | 3003:3001 | auth_data_dev:/data | extra_hosts: keycloak.lucaslopvet.fr→host-gateway |
| db-service-dev    | db-service-dev | 3004:3002  | db_data_dev:/data   | extra_hosts: keycloak.lucaslopvet.fr→host-gateway |
| keycloak-dev      | keycloak-dev   | 8081:8081  | H2 (start-dev)      | KC_HOSTNAME=keycloak.lucaslopvet.fr, KC_PROXY_HEADERS=xforwarded |

## 4.2 Nginx (6 fichiers de config)

Tous : HTTPS obligatoire (Let's Encrypt), redirect HTTP->HTTPS, proxy headers (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto)

| Fichier          | Domaine                     | Upstream / Root                    | Notes                       |
|------------------|-----------------------------|------------------------------------|------------------------------|
| app.conf         | app.lucaslopvet.fr          | /var/www/flutter-app (SPA)         | Cache 1 an, immutable        |
| auth.conf        | auth.lucaslopvet.fr         | proxy http://127.0.0.1:3001        |                              |
| db.conf          | DB.lucaslopvet.fr           | proxy http://127.0.0.1:3002        |                              |
| dev-app.conf     | dev.app.lucaslopvet.fr      | /var/www/flutter-app-dev (SPA)     | Cache 1 heure                |
| dev-auth.conf    | dev.auth.lucaslopvet.fr     | proxy http://127.0.0.1:3003        |                              |
| dev-db.conf      | dev.DB.lucaslopvet.fr       | proxy http://127.0.0.1:3004        |                              |
| keycloak.conf    | keycloak.lucaslopvet.fr     | proxy http://127.0.0.1:8081 (dev) / 8080 (prod) | proxy_buffer_size 128k (grands headers JWT) |

> `keycloak.conf` n'est **pas** déployé automatiquement par Jenkins — copie manuelle sur le VPS : `sudo cp nginx/conf.d/keycloak.conf /etc/nginx/conf.d/ && sudo systemctl reload nginx`

**SPA routing** : `try_files $uri $uri/ /index.html`
**Gzip** active sur text/plain, text/css, application/javascript, application/json

## 4.3 CI/CD Jenkins

**Image Flutter** : `ghcr.io/cirruslabs/flutter:3.41.4`
**Fichier .env prod** : `/etc/kabutare/.env`

### Pipeline

| Etape | Branche | Action                                                                |
|-------|---------|-----------------------------------------------------------------------|
| 1     | toutes  | Cleanup (rm build/ .pub-cache) + git checkout                         |
| 2     | toutes  | `flutter pub get`                                                     |
| 3     | toutes  | `flutter analyze --no-fatal-infos`                                    |
| 4     | toutes  | `flutter test`                                                        |
| 5     | main    | Build web release (AUTH_URL=https://auth.lucaslopvet.fr, DB_URL=https://DB.lucaslopvet.fr) -> deploy /var/www/flutter-app |
| 6     | dev     | Build web release (AUTH_URL=https://dev.auth.lucaslopvet.fr, DB_URL=https://dev.DB.lucaslopvet.fr) -> deploy /var/www/flutter-app-dev |
| 7     | main    | Docker Compose prod: down + up --build + seed auth-service-prod + seed db-service-prod |
| 8     | dev     | Docker Compose dev: force rm + down + up --build + seed auth-service-dev + seed db-service-dev |
| 9     | main/dev| Healthcheck HTTPS sur /health des services (sleep 5s avant)           |

**Projet Docker Compose** :
- Production : `gestion-equipement-medical-prod`
- Dev : `gestion-equipement-medical_dev`

## 4.4 Variables d'environnement

### Production (depuis /etc/kabutare/.env)

| Variable              | Description                                               |
|-----------------------|-----------------------------------------------------------|
| JWT_SECRET            | Shim transition HS256 — à supprimer après Phase 5         |
| JWT_REFRESH_SECRET    | Shim transition — à supprimer après Phase 5               |
| INTERNAL_SECRET       | Secret communication inter-services                       |
| KC_DB_PASSWORD        | Mot de passe PostgreSQL Keycloak                          |
| KC_ADMIN_USER         | Login admin console Keycloak                              |
| KC_ADMIN_PASSWORD     | Mot de passe admin console Keycloak                       |
| KC_CLIENT_SECRET_AUTH | Secret du client `auth-service` (confidential)            |

### Dev (defauts dans docker-compose.dev.yml)

| Variable                   | Defaut                              |
|----------------------------|-------------------------------------|
| JWT_SECRET_DEV             | kabutare-dev-secret                 |
| INTERNAL_SECRET_DEV        | kabutare-internal-dev-secret        |
| KC_CLIENT_SECRET_AUTH_DEV  | changeme-dev-secret                 |

### Keycloak (dans les services Node)

| Variable         | Valeur prod                                                        |
|------------------|--------------------------------------------------------------------|
| KC_ISSUER        | https://keycloak.lucaslopvet.fr/realms/kabutare-hospital           |
| KC_REALM         | kabutare-hospital                                                  |
| KC_ADMIN_URL     | https://keycloak.lucaslopvet.fr (prod) / http://keycloak-dev:8081 (dev) |
| KC_CLIENT_ID     | auth-service                                                       |
| KC_CLIENT_SECRET | ${KC_CLIENT_SECRET_AUTH}                                           |

### Communication inter-services (dans Docker)

| Service      | Variable          | Valeur                          |
|--------------|-------------------|---------------------------------|
| auth-service | DB_SERVICE_URL    | http://db-service:3002          |
| db-service   | AUTH_SERVICE_URL  | http://auth-service:3001        |

---

# 5. Departements hospitaliers

Administration, OPD (Consultations externes), Medecine Interne, Pediatrie, Urgences, Laboratoire, Stomatologie, Kinesitherapie, Neonatologie, Maternite, Chirurgie, Bloc Operatoire, Ophtalmologie, TB-MR, GBV (Violence basee sur le genre), Sante Mentale, ARV (Traitement VIH/SIDA), Pharmacie, Radiologie, ICT

---

# 6. Tests et couverture RBAC

## 6.1 Fichiers de tests automatisés

| Fichier | Service | Tests | Couverture |
|---|---|---|---|
| `auth-service/src/tests/rbac_permissions.test.js` | auth-service | 73 tests RBAC | GET /api/auth/me (7 rôles × permissions), GET/POST /api/users (admin only), GET /api/roles (admin), GET/PUT /api/users/department-requests (admin), GET/PUT /api/users/me/notifications (tous), POST /api/users/department-request (tous) |
| `db-service/src/tests/rbac_equipment_issues.test.js` | db-service | 100 tests RBAC | GET/POST/DELETE /api/equipment, POST /api/issues, PUT /api/issues/:id (dont pose de `resolved_at` sur Completed), GET/POST/DELETE /api/inventory, GET /api/logs, PATCH /api/issues/:id/escalate, .../reject, .../detach, .../link-equipment |
| `db-service/__tests__/inventory_normalizer.test.js` | db-service | 32 tests unitaires | Normalisation des données XLSX (cleanCell, normalizeStatus, normalizeDate, tagToId) |
| `flutter-app/test/models/user_role_test.dart` | Flutter | Tests unitaires | UserRole enum, Permission enum, getPermissionsForRole() |
| `flutter-app/test/services/auth_service_test.dart` | Flutter | Tests unitaires | AuthService (login, logout, hasPermission, switchUser) |
| `flutter-app/test/rbac/rbac_visibility_test.dart` | Flutter | 24 tests widget RBAC | Hub routing par rôle, visibilité cartes modules (Inventory/Settings), sidebar navigation par rôle, dashboard conditionnel, permissions AuthService, primaryRole |

## 6.2 Scénarios de recette (recette commanditaire)

| Fichier | Contenu |
|---|---|
| `tests/scenarios/scenarios_recette_roles.md` | 25 scénarios Given-When-Then par rôle (7 rôles + cross-rôles), grille de couverture des 14 permissions |
| `tests/fixtures/test_users_roles.md` | 7 comptes Keycloak de test, données de référence, checklist de préparation |

## 6.3 Patterns de tests Jest (backend)

### Mock verifyToken (commun aux deux services)

```js
// Variable de rôle préfixée "mock" pour le hoisting jest.mock
let mockCurrentRoles = ['hospitalStaff'];
function setTestRole(...roles) { mockCurrentRoles = roles; }

jest.mock('../middleware/auth', () => ({
  verifyToken: (req, _res, next) => {
    req.user = { id: 'test-uuid', email: 'test@kabutare.rw', name: 'Test',
                 roles: mockCurrentRoles, department: 'OPD' };
    next();
  },
  requireRole: (...allowed) => (req, res, next) => {
    if (!req.user?.roles?.some(r => allowed.includes(r)))
      return res.status(403).json({ error: `Rôle requis: ${allowed.join(' ou ')}` });
    next();
  },
  requireAdmin: (req, res, next) => {
    if (!req.user?.roles?.includes('admin'))
      return res.status(403).json({ error: 'Access restricted to administrators' });
    next();
  },
  SYSTEM_ROLES: new Set(['offline_access', 'uma_authorization', 'default-roles-kabutare-hospital']),
}));
```

### Commandes d'exécution

```bash
cd auth-service && npm test   # 160 tests (87 existants + 73 RBAC)
cd db-service  && npm test    # 145 tests (32 normalizer + 113 RBAC)
```

## 6.4 Correction sécurité appliquée — GET /api/inventory

**✅ Corrigé** : `requireRole('admin', 'supervisor')` ajouté sur `GET /api/inventory` et `GET /api/inventory/:id` dans `db-service/src/routes/inventory.js`. La permission `viewInventory` est désormais vérifiée à la fois côté API backend et côté Flutter (masquage du menu).

Les tests `rbac_equipment_issues.test.js` ont été mis à jour : le groupe `⚠️ comportement actuel (200 pour tous)` est remplacé par des assertions strictes `✅ 200 pour admin/supervisor` et `🚫 403 pour hospitalStaff/technician*`.
