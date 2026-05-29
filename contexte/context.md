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
- **auth-service** : proxy Admin API Keycloak (`/api/users`, `/api/roles`), `GET /api/auth/me`, gestion `department_change_requests` et `role_permissions` SQLite
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
| supervisor            | viewEquipment, reportIssue, trackIssues, approveRequests, assignTasks               |
| technician            | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts               |
| technician_biomedical | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts               |
| technician_it         | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts               |
| technician_infra      | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts               |
| admin                 | TOUTES les permissions (14)                                                         |

**SYSTEM_ROLES** filtrés des tokens : `offline_access`, `uma_authorization`, `default-roles-kabutare-hospital`

### Liste des permissions

`viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`, `updateRepairs`, `registerParts`, `manageEquipment`, `manageUsers`, `manageDepartments`, `manageCategories`, `generateReports`, `viewInventory`, `changeDepartment`

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

### Gestion des roles (`/api/roles`) - Rate limit : 60 req/min

#### GET /api/roles (Admin)
- Rôles Keycloak (filtrés SYSTEM_ROLES) + permissions depuis `role_permissions` SQLite

#### POST /api/roles (Admin)
- Crée dans Keycloak + insère dans `role_permissions` SQLite

#### PUT /api/roles/:name/permissions (Admin)
- Uniquement `role_permissions` SQLite (Keycloak ne connaît pas les permissions applicatives)

#### DELETE /api/roles/:name (Admin)
- DELETE Keycloak + DELETE `role_permissions` SQLite

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

| Colonne      | Type    | Contraintes                                     |
|--------------|---------|--------------------------------------------------|
| id           | INTEGER | PRIMARY KEY AUTOINCREMENT                        |
| equipment_id | TEXT    | NOT NULL, FK -> equipment(id) ON DELETE CASCADE  |
| date         | TEXT    | NOT NULL                                         |
| intervention | TEXT    | NOT NULL                                         |
| technician   | TEXT    | NOT NULL                                         |
| is_future    | INTEGER | DEFAULT 0                                        |

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
| updated_at           | TEXT | DEFAULT `datetime('now','localtime')`              |

**Contrainte applicative** (POST `/api/issues`) : `equipment_id` + `equipment_name` **OU** `location_id` doit etre fourni.
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

## 2.2 Enums de validation

| Contexte         | Valeurs                                                                       |
|------------------|-------------------------------------------------------------------------------|
| Equipment Status | `Operational`, `Maintenance`, `Out of service`, `To be disposal`, `Disposed` (5 valeurs, en anglais) |
| Equipment Dept   | `IT`, `Radiologie`, `Réanimation`, `Stérilisation`, `Laboratoire`, `Urgences`, `Maintenance`, `Infrastructure` |
| Equipment Cat    | `Imagerie`, `Laboratoire`, `Chirurgie`, `Monitoring`, `Thérapeutique`, `Informatique`, `Mobilier`, `Autre` |
| Issue Status     | `Reported`, `Acknowledged`, `Assigned`, `In Progress`, `Waiting Materials`, `Completed`, `Verified`, `Closed`, `Redirected` (9 valeurs, en anglais) |
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
| GET     | /api/equipment                  | Auth              | Liste (filtres: department, status, category, **macro_category**, **macro_category_id**). Retourne maintenanceHistory + futureMaintenance + **macro_category** + **subcategory_name** |
| GET     | /api/equipment/:id              | Auth              | Details avec historique maintenance + **pmProtocols** (protocoles PM de la sous-catégorie) |
| POST    | /api/equipment                  | Admin/Supervisor  | Creer (required: id, name, department, category) + optionnel: **subcategory_id**, **warranty_end_date**, **criticality** |
| PUT     | /api/equipment/:id              | Admin/Sup/Tech    | Modifier (COALESCE, partial update) + nouveaux champs GMAO |
| DELETE  | /api/equipment/:id              | Admin             | Supprimer (snapshot audit, ?reason=)              |
| POST    | /api/equipment/:id/maintenance  | Admin/Sup/Tech    | Ajouter enregistrement maintenance                |
| POST    | /api/equipment/restore          | Admin             | Restaurer equipement supprime                     |

### Catégories & Sous-catégories (`/api/categories`) **[NOUVEAU]**

| Methode | Route                    | Auth  | Description                                                  |
|---------|--------------------------|-------|--------------------------------------------------------------|
| GET     | /api/categories/macro    | Auth  | Liste des 3 macro-catégories (Biomedical, Infrastructure, IT) |
| GET     | /api/categories/sub      | Auth  | Liste sous-catégories (filtre: ?macro_category_id=). Inclut equipment_count |
| GET     | /api/categories/sub/:id  | Auth  | Détail sous-catégorie + ses protocols PM + equipment_count   |

### Protocoles de Maintenance Préventive (`/api/pm-protocols`) **[NOUVEAU]**

| Methode | Route              | Auth  | Description                                                               |
|---------|--------------------|-------|---------------------------------------------------------------------------|
| GET     | /api/pm-protocols  | Auth  | Liste (filtres: ?subcategory_id=, ?macro_category_id=). Checklist désérialisée en tableau |
| GET     | /api/pm-protocols/:id | Auth | Détail avec checklist |
| POST    | /api/pm-protocols  | Admin | Créer (required: subcategory_id, name, frequency_months ; optionnel: estimated_duration_hours, checklist[]) |
| PUT     | /api/pm-protocols/:id | Admin | Modifier (COALESCE partiel) |
| DELETE  | /api/pm-protocols/:id | Admin | Supprimer |

### Incidents (`/api/issues`)

| Methode | Route                       | Auth           | Description                                              |
|---------|-----------------------------|----------------|----------------------------------------------------------|
| GET     | /api/issues                 | Auth           | Liste (filtres: status, department, equipment_id), tri DESC created_at |
| GET     | /api/issues/:id             | Auth           | Details incident enrichis : `{ ...issue, equipment, audit_log: [{id,timestamp,user_name,user_role,action,details}], maintenance_records: [{id,equipment_id,date,intervention,technician,is_future}] }` |
| POST    | /api/issues                 | Auth           | Signaler. Required: `id`, `department`, `type`, `description`, `reporter`, et **(`equipment_id`+`equipment_name`) OU `location_id`**. Auto-derive `issue_category` & `assigned_group` (Biomedical si equipement, Infrastructure si lieu). Status initial = `Reported`. |
| PUT     | /api/issues/:id             | Admin/Sup/Tech | Modifier (status, assigned_technician, diagnosis, actions, parts_replaced, urgency) |
| PATCH   | /api/issues/:id/reassign    | Admin/Sup/Tech | Reassigner vers un autre groupe. Body: `{ new_group, reason }`. `new_group` dans `Biomédical/Infrastructure/IT`, `reason` >= 10 char. Effets : `assigned_group` change, `assigned_technician` -> NULL, status -> `Reported`, ligne tracee appendée dans `actions`. |
| DELETE  | /api/issues/:id             | Admin          | Supprimer                                                |

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

### Autres

| Methode | Route   | Auth   | Description                              |
|---------|---------|--------|------------------------------------------|
| GET     | /       | Public | Dashboard HTML debug (stats + tableaux)  |
| GET     | /health | Public | `{ "status": "ok", "service": "db-service" }` |

## 2.5 Middleware

- **verifyToken** : Meme logique que auth-service (JWT_SECRET partage)
- **requireRole(...roles)** : Verifie req.user.role dans la liste fournie

## 2.6 Configuration (src/config.js)

| Variable         | Defaut                                                |
|------------------|-------------------------------------------------------|
| PORT             | 3002                                                  |
| DB_PATH          | hospital.db                                           |
| JWT_SECRET       | kabutare-hospital-secret-key-change-in-production     |
| AUTH_SERVICE_URL | http://localhost:3001                                 |
| INTERNAL_SECRET  | kabutare-internal-secret-change-in-production         |

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
├── screens/               # 13 ecrans (8965 lignes)
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── equipment_list_screen.dart
│   ├── issue_tracking_screen.dart
│   ├── issue_form_screen.dart
│   ├── technician_update_screen.dart
│   ├── inventory_screen.dart
│   ├── reports_screen.dart
│   ├── user_management_screen.dart
│   ├── settings_screen.dart
│   ├── logs_screen.dart
│   ├── account_settings_screen.dart
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
│   └── departments.dart         # Department, EquipmentCategory enums
├── providers/
│   └── locale_provider.dart     # FR/EN avec SharedPreferences
├── widgets/                     # Composants UI reutilisables
│   ├── issue_category_selector.dart  # Selecteur de categorie avant IssueFormScreen
├── theme/                       # AppTheme, couleurs
├── l10n/                        # Traductions FR/EN
├── utils/                       # Utilitaires (file picker)
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
| deptRequestsUrl      | /api/users/department-requests                               |                        |
| rolesUrl             | /api/roles                                                   |                        |
| equipmentUrl         | /api/equipment                                               |                        |
| issuesUrl            | /api/issues                                                  |                        |
| inventoryUrl         | /api/inventory                                               |                        |
| logsUrl              | /api/logs                                                    |                        |
| sidebarUrl           | /api/sidebar/config                                          |                        |

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

## 3.4 Ecrans (14)

| #  | Ecran                    | Permissions requises    | Description                                                       |
|----|--------------------------|-------------------------|-------------------------------------------------------------------|
| 0  | LoginScreen              | -                       | Email/password, boutons dev quick-login                           |
| 1  | DashboardScreen          | -                       | Stats equipements par statut, 4 incidents recents, alertes critiques |
| 2  | EquipmentListScreen      | viewEquipment           | Table recherchable, filtres dept/status/categorie, CRUD, details  |
| 3  | IssueTrackingScreen      | trackIssues             | 2 onglets (tous les incidents / a valider), filtres statut. Clics naviguent vers IssueDetailScreen |
| 3b | IssueDetailScreen        | trackIssues             | Sous-ecran GMAO : 5 sections (contexte, panne, intervention, ressources, timeline). Charge GET /api/issues/:id enrichi |
| 4  | IssueFormScreen          | reportIssue             | Formulaire : equipement picker (filtre par categoryFilter), type, urgence, description, photos (max 5). Parametre `categoryFilter: List<String>?` restreint les equipements selectionables. |
| 5  | TechnicianUpdateScreen   | updateRepairs           | Diagnostic, actions, pieces remplacees                            |
| 6  | InventoryScreen          | viewInventory           | Table stock, filtres categorie/statut, CRUD                      |
| 7  | ReportsScreen            | generateReports         | Statistiques maintenance, equipements                             |
| 8  | UserManagementScreen     | manageUsers             | CRUD users, demandes dept (approve/reject), filtres role          |
| 9  | SettingsScreen           | manageDepartments       | Departements, categories, permissions par role, sidebar order     |
| 10 | LogsScreen               | manageUsers             | Logs d'audit filtres (action, user, type, dates, limit)          |
| 11 | AccountSettingsScreen    | -                       | Profil personnel, changement mot de passe                        |
| 12 | HomeHubScreen            | -                       | Hub de selection modules (Equipment, Settings, Inventory)         |

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
- Update: `DbApiService.updateEquipment()` -> PUT /api/equipment/{id}
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
