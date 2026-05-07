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
                    +----------+------------+
                               |
            +------------------+------------------+
            |                  |                  |
   +--------v------+  +-------v-------+  +-------v--------+
   |  Flutter App   |  | Auth Service  |  |  DB Service    |
   |  (Static Web)  |  | Express.js    |  |  Express.js    |
   |  /var/www/     |  | Port 3001     |  |  Port 3002     |
   +----------------+  +-------+-------+  +-------+--------+
                               |                  |
                          +----v-----+      +-----v--------+
                          | auth.db  |      | hospital.db  |
                          | (SQLite) |      | (SQLite)     |
                          +----------+      +--------------+
```

## Domaines et ports

| Environnement | Frontend                 | Auth Service                  | DB Service                 |
|---------------|--------------------------|-------------------------------|----------------------------|
| **Production**| app.lucaslopvet.fr       | auth.lucaslopvet.fr (:3001)   | DB.lucaslopvet.fr (:3002)  |
| **Dev**       | dev.app.lucaslopvet.fr   | dev.auth.lucaslopvet.fr (:3003)| dev.DB.lucaslopvet.fr (:3004)|

---

# 1. Auth Service

**Stack** : Node.js 20 (Alpine) / Express 4.21.0 / SQLite (better-sqlite3 11.7.0)
**Port interne** : 3001 | **Port dev externe** : 3003

## 1.1 Schemas de base de donnees

### Table `users`

| Colonne       | Type    | Contraintes                                                              |
|---------------|---------|--------------------------------------------------------------------------|
| id            | TEXT    | PRIMARY KEY, format `user-{uuid}`                                        |
| name          | TEXT    | NOT NULL, compose de first_name + last_name                              |
| first_name    | TEXT    | Ajoute via migration                                                     |
| last_name     | TEXT    | Ajoute via migration                                                     |
| email         | TEXT    | UNIQUE NOT NULL                                                          |
| password_hash | TEXT    | NOT NULL, bcrypt 12 rounds                                               |
| department    | TEXT    | NOT NULL                                                                 |
| role          | TEXT    | NOT NULL, CHECK IN ('hospitalStaff','supervisor','technician','admin')    |
| phone         | TEXT    | Nullable                                                                 |
| is_active     | INTEGER | DEFAULT 1 (1=actif, 0=inactif)                                          |
| created_at    | TEXT    | NOT NULL, ISO timestamp                                                  |

**Index** : `idx_users_email` sur (email)

### Table `refresh_tokens`

| Colonne    | Type    | Contraintes                                            |
|------------|---------|--------------------------------------------------------|
| id         | INTEGER | PRIMARY KEY AUTOINCREMENT                              |
| user_id    | TEXT    | NOT NULL, FK -> users(id) ON DELETE CASCADE            |
| token      | TEXT    | UNIQUE NOT NULL                                        |
| expires_at | TEXT    | NOT NULL, ISO timestamp                                |
| created_at | TEXT    | DEFAULT CURRENT_TIMESTAMP                              |

**Index** : `idx_refresh_tokens_token` (token), `idx_refresh_tokens_user` (user_id)

### Table `department_change_requests`

| Colonne              | Type | Contraintes                                  |
|----------------------|------|----------------------------------------------|
| id                   | TEXT | PRIMARY KEY, UUID                            |
| user_id              | TEXT | NOT NULL, FK -> users(id) ON DELETE CASCADE  |
| user_name            | TEXT | NOT NULL                                     |
| current_department   | TEXT | NOT NULL                                     |
| requested_department | TEXT | NOT NULL                                     |
| status               | TEXT | NOT NULL DEFAULT 'pending' (pending/approved/rejected) |
| admin_id             | TEXT | Nullable                                     |
| admin_note           | TEXT | Nullable, max 200 chars                      |
| created_at           | TEXT | DEFAULT CURRENT_TIMESTAMP                    |
| resolved_at          | TEXT | Nullable                                     |

**Index** : `idx_dept_req_user` (user_id), `idx_dept_req_status` (status)

### Table `roles`

| Colonne      | Type    | Contraintes                                          |
|--------------|---------|------------------------------------------------------|
| name         | TEXT    | PRIMARY KEY, regex `^[a-zA-Z][a-zA-Z0-9_]*$`        |
| display_name | TEXT    | NOT NULL                                             |
| description  | TEXT    | Nullable                                             |
| is_builtin   | INTEGER | DEFAULT 0 (1=builtin, 0=custom)                     |
| created_at   | TEXT    | DEFAULT CURRENT_TIMESTAMP                            |

### Table `role_permissions`

| Colonne     | Type | Contraintes                                    |
|-------------|------|------------------------------------------------|
| role_name   | TEXT | NOT NULL, FK -> roles(name) ON DELETE CASCADE  |
| permission  | TEXT | NOT NULL                                       |

**Cle primaire** : (role_name, permission)

**Configuration DB** : WAL mode, foreign_keys = ON

## 1.2 Roles et permissions

### Roles built-in

| Role           | Display Name           | Permissions                                                                         |
|----------------|------------------------|-------------------------------------------------------------------------------------|
| hospitalStaff  | Personnel hospitalier  | viewEquipment, reportIssue, trackIssues                                             |
| supervisor     | Superviseur            | viewEquipment, reportIssue, trackIssues, approveRequests, assignTasks               |
| technician     | Technicien             | viewEquipment, reportIssue, trackIssues, updateRepairs, registerParts               |
| admin          | Administrateur ICT     | TOUTES les permissions (14 permissions, non modifiables)                            |

### Liste des permissions

`viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`, `updateRepairs`, `registerParts`, `manageEquipment`, `manageUsers`, `manageDepartments`, `manageCategories`, `generateReports`, `viewInventory`, `changeDepartment`

## 1.3 Utilisateurs seed (8 comptes)

| ID      | Nom                    | Email                     | Role           | Departement      | MDP          |
|---------|------------------------|---------------------------|----------------|------------------|--------------|
| usr-001 | Admin Systeme          | admin@kabutare.rw         | admin          | Administration   | Admin1234!   |
| usr-002 | Dr. Habimana Jean      | j.habimana@kabutare.rw    | supervisor     | Chirurgie        | Password1!   |
| usr-003 | Mme. Uwimana Claire    | c.uwimana@kabutare.rw     | supervisor     | Maternite        | Password1!   |
| usr-004 | Tech. Balde Moussa     | m.balde@kabutare.rw       | technician     | Administration   | Password1!   |
| usr-005 | Tech. Cisse Amadou     | a.cisse@kabutare.rw       | technician     | Administration   | Password1!   |
| usr-006 | Dr. Traore Ibrahim     | i.traore@kabutare.rw      | hospitalStaff  | Bloc operatoire  | Password1!   |
| usr-007 | Inf. Keita Fatou       | f.keita@kabutare.rw       | hospitalStaff  | Urgences         | Password1!   |
| usr-008 | Lab. Diallo Oumar      | o.diallo@kabutare.rw      | hospitalStaff  | Laboratoire      | Password1!   |

## 1.4 Endpoints API

### Authentification (`/api/auth`)

#### POST /api/auth/login
- **Rate limit** : 10 tentatives / 15 min par IP
- **Body** : `{ "email": "string", "password": "string" }`
- **Reponse 200** :
```json
{
  "accessToken": "JWT (15min)",
  "refreshToken": "JWT (7 jours)",
  "user": {
    "id": "string", "name": "string", "first_name": "string", "last_name": "string",
    "email": "string", "role": "string", "department": "string",
    "phone": "string|null", "permissions": ["string"]
  }
}
```
- **Erreurs** : 400 (champs manquants), 401 (identifiants invalides)
- **Comportement** : verifie is_active=1, bcrypt compare, cree les tokens, nettoie les tokens expires, log audit

#### POST /api/auth/refresh
- **Body** : `{ "refreshToken": "string" }`
- **Reponse 200** : `{ "accessToken": "nouveau JWT", "refreshToken": "nouveau JWT" }`
- **Comportement** : rotation de token (supprime ancien, cree nouveau pair), verifie user actif
- **Erreurs** : 400 (token manquant), 403 (token invalide/expire/utilisateur introuvable)

#### POST /api/auth/logout
- **Body** : `{ "refreshToken": "string (optionnel)" }`
- **Reponse 200** : `{ "message": "Deconnexion reussie" }`

#### GET /api/auth/verify
- **Header** : `Authorization: Bearer {token}`
- **Reponse 200** : `{ "valid": true, "user": { id, email, role, name, department } }`

#### GET /api/auth/me
- **Header** : `Authorization: Bearer {token}`
- **Reponse 200** : Objet utilisateur complet avec permissions

### Gestion des utilisateurs (`/api/users`) - Rate limit : 60 req/min

#### GET /api/users (Admin)
- **Reponse** : Array d'utilisateurs (tous les champs sauf password_hash)

#### POST /api/users (Admin)
- **Body** : `{ "first_name", "last_name", "email", "password", "department", "role", "phone?" }`
- **Validation** : role doit etre dans [hospitalStaff, supervisor, technician, admin]
- **Reponse 201** : `{ "message": "Utilisateur cree", "id": "user-{uuid}" }`
- **Erreurs** : 400 (champs manquants/role invalide), 409 (email duplique)

#### PUT /api/users/:id (Admin)
- **Body** : Tous les champs optionnels (COALESCE pour mise a jour partielle)
- **Log** : Enregistre les changements avant/apres pour chaque champ modifie

#### PATCH /api/users/:id/toggle (Admin)
- Toggle is_active entre 0 et 1
- **Reponse** : `{ "message": "Compte active/desactive", "is_active": 0|1 }`

#### DELETE /api/users/:id (Admin)
- **Query** : `?reason=...` (max 200 chars, optionnel)
- Snapshot du user pour audit, interdit l'auto-suppression

#### POST /api/users/restore (Admin)
- **Body** : `{ "snapshot": { "id", "email", "name", "department?", "role?", "phone?" } }`
- Genere mot de passe temporaire (8 hex chars)

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
- Roles tries par is_builtin DESC, name ASC

#### POST /api/roles (Admin)
- **Body** : `{ "name": "regex [a-zA-Z][a-zA-Z0-9_]*", "display_name", "description?", "permissions?": [] }`
- Permissions validees contre la whitelist

#### PUT /api/roles/:name/permissions (Admin)
- Admin role non modifiable, transaction DELETE+INSERT

#### DELETE /api/roles/:name (Admin)
- Impossible de supprimer les roles builtin

## 1.5 Middleware et securite

- **verifyToken** : Extraction Bearer token, verification JWT_SECRET, set req.user
- **requireAdmin** : Verifie req.user.role === 'admin'
- **helmet()** : Headers de securite (XSS, CSP, etc.)
- **CORS** : Origins autorisees = `https://app.lucaslopvet.fr`, `https://dev.app.lucaslopvet.fr`, `http://localhost:(3000|3001|3002|5000|8080|4200|9000)`
- **Trust proxy** : `app.set('trust proxy', 1)` pour Nginx
- **Audit logging** : Envoi asynchrone vers db-service `/api/logs/internal` avec header `x-internal-secret`

## 1.6 Configuration (src/config.js)

| Variable             | Defaut                                                    |
|----------------------|-----------------------------------------------------------|
| PORT                 | 3000                                                      |
| JWT_SECRET           | kabutare-hospital-secret-key-change-in-production         |
| JWT_REFRESH_SECRET   | kabutare-hospital-refresh-secret-change-in-production     |
| ACCESS_TOKEN_EXPIRY  | 15m                                                       |
| REFRESH_TOKEN_EXPIRY | 7d (604800000 ms)                                         |
| DB_PATH              | auth.db                                                   |
| BCRYPT_ROUNDS        | 12                                                        |
| DB_SERVICE_URL       | http://localhost:3002                                     |
| INTERNAL_SECRET      | kabutare-internal-secret-change-in-production             |

## 1.7 Dependances (package.json)

| Package            | Version  | Role                    |
|--------------------|----------|-------------------------|
| express            | ^4.21.0  | Framework web           |
| bcrypt             | ^5.1.1   | Hashage mots de passe   |
| better-sqlite3     | ^11.7.0  | Driver SQLite           |
| jsonwebtoken       | ^9.0.2   | Gestion JWT             |
| helmet             | ^8.0.0   | Headers securite        |
| express-rate-limit | ^7.1.5   | Rate limiting           |
| cors               | ^2.8.5   | CORS middleware         |
| jest               | ^29.7.0  | Tests (dev)             |
| supertest          | ^7.0.0   | Tests HTTP (dev)        |

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
| status             | TEXT    | NOT NULL DEFAULT 'Disponible'                                |
| supplier           | TEXT    | Nullable                                                     |
| location           | TEXT    | Nullable                                                     |
| created_at         | TEXT    | DEFAULT CURRENT_TIMESTAMP                                    |
| updated_at         | TEXT    | DEFAULT CURRENT_TIMESTAMP                                    |
| next_revision_date | TEXT    | Nullable, ajoute via migration                               |
| manufacturer       | TEXT    | Nullable, ajoute via migration (inventaire physique 2025-2026) |
| model              | TEXT    | Nullable, ajoute via migration                               |
| manuf_year         | INTEGER | Nullable, ajoute via migration (annee fabrication)           |
| install_date       | TEXT    | Nullable, ajoute via migration (ISO YYYY-MM-DD)              |
| department_id      | INTEGER | Nullable, FK -> departments(id), ajoute via migration        |
| category_id        | INTEGER | Nullable, FK -> equipment_categories(id), ajoute via migration |

**Index** : `idx_equipment_dept` (department), `idx_equipment_status` (status)

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

### Table `issues`

| Colonne              | Type | Contraintes                        |
|----------------------|------|------------------------------------|
| id                   | TEXT | PRIMARY KEY                        |
| equipment_id         | TEXT | NOT NULL                           |
| equipment_name       | TEXT | NOT NULL                           |
| department           | TEXT | NOT NULL                           |
| type                 | TEXT | NOT NULL                           |
| description          | TEXT | NOT NULL                           |
| reporter             | TEXT | NOT NULL                           |
| reporter_id          | TEXT | Nullable (migration)               |
| reporter_email       | TEXT | Nullable (migration)               |
| urgency              | TEXT | DEFAULT 'Moyen' (migration)        |
| status               | TEXT | NOT NULL DEFAULT 'Ouvert'          |
| assigned_technician  | TEXT | Nullable                           |
| diagnosis            | TEXT | Nullable                           |
| actions              | TEXT | Nullable                           |
| parts_replaced       | TEXT | Nullable                           |
| created_at           | TEXT | NOT NULL                           |
| updated_at           | TEXT | DEFAULT CURRENT_TIMESTAMP          |

**Index** : `idx_issues_status` (status), `idx_issues_equipment` (equipment_id)

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
| Equipment Status | `Disponible`, `En service`, `En maintenance`, `Hors service`, `Inactif`, `À éliminer`, `Transféré` |
| Equipment Dept   | `IT`, `Radiologie`, `Reanimation`, `Sterilisation`, `Laboratoire`, `Urgences`, `Maintenance`, `Infrastructure` |
| Equipment Cat    | `Imagerie`, `Laboratoire`, `Chirurgie`, `Monitoring`, `Therapeutique`, `Informatique`, `Mobilier`, `Autre` |
| Issue Status     | `Ouvert`, `En cours`, `Resolu`, `Annule`                                      |
| Issue Urgency    | `Faible`, `Moyen`, `Urgent`                                                   |
| Issue Type       | `Panne`, `Maintenance`, `Inspection`, `Autre`                                 |
| Inventory Cat    | `Consommable medical`, `Hygiene`, `Bureautique`                               |
| Inventory Status | `Normal`, `Faible`, `Rupture` (calcule : stock=0 -> Rupture, <min -> Faible)  |

## 2.3 Donnees seed et import inventaire physique

### Source primaire — Inventaire physique 2025-2026 (XLSX hopital)

Script `db-service/scripts/import_inventory.js` — peuple la base depuis le fichier XLSX reel fourni par le service biomedical de l'hopital (`PHYISICAL INVENTORY OF MEDICAL EQUIPMENTS 2025-2026 -.xlsx`).

| Volume        | Resultat apres import |
|---------------|------------------------|
| equipment     | ~340 (342 lignes parsees - 2 collisions de SerialNumber) |
| equipment_tags| ~338 |
| departments   | ~56 (issus de Standard_Departments, en anglais) |
| equipment_categories | ~626 (~611 standard + ~15 ajoutes a la volee depuis l'inventaire) |

Statuts mappes depuis l'anglais vers le francais : `operational`->`En service`, `UNDER M`/`UNDERM`->`En maintenance`, `IDDLE`->`Inactif`, `DISPOSED`->`Hors service`, `to be disposal`->`À éliminer`, `KIBIRIZI DH`->`Transféré`. Logique dans `scripts/lib/inventory_normalizer.js` (testee via Jest, 31 tests).

CLI :
```bash
node scripts/import_inventory.js --xlsx <chemin.xlsx> [--dry-run] [--insert-only]
```

Audit : chaque insertion / mise a jour est tracee dans `logs` avec `user_role='system'`, `user_name='import_inventory'`, action `create_equipment_import` ou `update_equipment_import`.

### Donnees seed legacy (`db-service/seed.js`) - 45 equipements de demo

Les equipements de seed (id `eq-001`...`eq-045`) cohabitent avec les equipements importes du XLSX (id derive du SerialNumber). Exemples :

| ID     | Nom                            | Departement    | Categorie           | Statut          |
|--------|--------------------------------|----------------|---------------------|-----------------|
| eq-001 | Serveur Dell PowerEdge R750    | Administration | Equipement ICT      | En usage        |
| eq-003 | Tensiometre electronique Omron | OPD            | Equipement biomedical| Disponible     |
| eq-024 | Scanner IRM Siemens 1.5T       | Chirurgie      | Equipement biomedical| En usage       |
| eq-041 | Autoclave Steris 400           | Bloc operatoire| Sterilisation        | En maintenance |

### Incidents (6 items)
| ID      | Equipement                | Statut   | Urgence | Reporter           |
|---------|---------------------------|----------|---------|---------------------|
| ISS-001 | Respirateur anesthesie    | En cours | -       | Dr. Traore          |
| ISS-003 | Serveur Dell              | Ouvert   | -       | IT Admin. Konate    |
| ISS-004 | Scanner IRM               | Resolu   | -       | Radiologue Camara   |

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
| GET     | /api/equipment                  | Auth              | Liste (filtres: department, status, category). Retourne maintenanceHistory + futureMaintenance |
| GET     | /api/equipment/:id              | Auth              | Details avec historique maintenance               |
| POST    | /api/equipment                  | Admin/Supervisor  | Creer (required: id, name, department, category)  |
| PUT     | /api/equipment/:id              | Admin/Sup/Tech    | Modifier (COALESCE, partial update)               |
| DELETE  | /api/equipment/:id              | Admin             | Supprimer (snapshot audit, ?reason=)              |
| POST    | /api/equipment/:id/maintenance  | Admin/Sup/Tech    | Ajouter enregistrement maintenance                |
| POST    | /api/equipment/restore          | Admin             | Restaurer equipement supprime                     |

### Incidents (`/api/issues`)

| Methode | Route             | Auth           | Description                                              |
|---------|-------------------|----------------|----------------------------------------------------------|
| GET     | /api/issues       | Auth           | Liste (filtres: status, department, equipment_id), tri DESC created_at |
| GET     | /api/issues/:id   | Auth           | Details incident                                         |
| POST    | /api/issues       | Auth           | Signaler (required: id, equipment_id, equipment_name, department, type, description, reporter) |
| PUT     | /api/issues/:id   | Admin/Sup/Tech | Modifier (status, assigned_technician, diagnosis, actions, parts_replaced, urgency) |
| DELETE  | /api/issues/:id   | Admin          | Supprimer                                                |

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
│   └── departments.dart         # Department, EquipmentCategory enums
├── providers/
│   └── locale_provider.dart     # FR/EN avec SharedPreferences
├── widgets/                     # Composants UI reutilisables
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

| Endpoint          | URL                                               |
|-------------------|---------------------------------------------------|
| Auth base         | https://auth.lucaslopvet.fr (configurable via --dart-define AUTH_URL) |
| DB base           | https://DB.lucaslopvet.fr (configurable via --dart-define DB_URL)    |
| Login             | /api/auth/login                                   |
| Logout            | /api/auth/logout                                  |
| Refresh           | /api/auth/refresh                                 |
| Me                | /api/auth/me                                      |
| Users             | /api/users                                        |
| Dept Requests     | /api/users/department-requests                    |
| Roles             | /api/roles                                        |
| Equipment         | /api/equipment                                    |
| Issues            | /api/issues                                       |
| Inventory         | /api/inventory                                    |
| Logs              | /api/logs                                         |
| Sidebar           | /api/sidebar/config                               |

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
id, name, department, category, serialNumber, supplier, location: String
status: EquipmentStatus (disponible, enUsage, enMaintenance, horsService)
nextRevisionDate: String?
maintenanceHistory, futureMaintenance: List<MaintenanceRecord>
MaintenanceRecord: { date, intervention, technician: String }
```

### Issue
```
id, equipmentId, equipmentName, department, type, description, reporter, createdAt: String
reporterId, reporterEmail, assignedTechnician, diagnosis, actions, partsReplaced: String?
status: IssueStatus (open, approved, inProgress, resolved)
urgency: IssueUrgency (faible, moyen, urgent)
```

### InventoryItem
```
id, name, unit, lastRestocked: String
category: InventoryCategory (consommableMedical, hygiene, bureautique)
currentStock, minStock: int
status: StockStatus (normal, low, outOfStock)
```

## 3.4 Ecrans (13)

| #  | Ecran                    | Permissions requises    | Description                                                       |
|----|--------------------------|-------------------------|-------------------------------------------------------------------|
| 0  | LoginScreen              | -                       | Email/password, boutons dev quick-login                           |
| 1  | DashboardScreen          | -                       | Stats equipements par statut, 4 incidents recents, alertes critiques |
| 2  | EquipmentListScreen      | viewEquipment           | Table recherchable, filtres dept/status/categorie, CRUD, details  |
| 3  | IssueTrackingScreen      | trackIssues             | 2 onglets (tous les incidents / a valider), filtres statut        |
| 4  | IssueFormScreen          | reportIssue             | Formulaire : equipement picker, type, urgence, description, photos (max 5) |
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

## 3.6 Flux principaux

### Login
1. User saisit email/password
2. `AuthService.loginWithApi()` -> `AuthApiService.login()` -> POST /api/auth/login
3. Tokens sauvegardes dans SecureTokenStorage
4. `DataService.loadAll()` charge toutes les donnees
5. Navigation vers HomeHub

### Auto-refresh JWT
1. Requete API retourne 401
2. `ApiClient._tryRefresh()` -> POST /api/auth/refresh avec refreshToken
3. Nouveau pair de tokens sauvegarde (rotation)
4. Requete originale rejouee
5. Si refresh echoue -> `AuthService.handleSessionExpired()` -> retour login

### CRUD Equipement
- Create: `DbApiService.createEquipment()` -> POST /api/equipment -> `DataService.reloadEquipment()`
- Update: `DbApiService.updateEquipment()` -> PUT /api/equipment/{id}
- Delete: `DbApiService.deleteEquipment()` -> DELETE /api/equipment/{id}?reason=

## 3.7 Dependances (pubspec.yaml)

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

| Service         | Container            | Port       | Volume            | Health check           |
|-----------------|----------------------|------------|-------------------|------------------------|
| auth-service    | auth-service-prod    | 3001:3001  | auth_data_prod:/data | wget /health 30s/10s/3r |
| db-service      | db-service-prod      | 3002:3002  | db_data_prod:/data   | wget /health 30s/10s/3r |

**db-service depends_on auth-service (condition: service_healthy)**

### Docker Compose Dev (docker-compose.dev.yml)

| Service           | Container            | Port       | Volume           |
|-------------------|----------------------|------------|------------------|
| auth-service-dev  | auth-service-dev     | 3003:3001  | auth_data_dev:/data |
| db-service-dev    | db-service-dev       | 3004:3002  | db_data_dev:/data   |

**Variables d'environnement dev** (avec defauts) :
- JWT_SECRET_DEV: kabutare-dev-secret
- JWT_REFRESH_SECRET_DEV: kabutare-dev-refresh-secret
- INTERNAL_SECRET_DEV: kabutare-internal-dev-secret

## 4.2 Nginx (6 fichiers de config)

Tous : HTTPS obligatoire (Let's Encrypt), redirect HTTP->HTTPS, proxy headers (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto)

| Fichier       | Domaine                     | Upstream / Root                    | Cache        |
|---------------|-----------------------------|------------------------------------|--------------|
| app.conf      | app.lucaslopvet.fr          | /var/www/flutter-app (SPA)         | 1 an, immutable |
| auth.conf     | auth.lucaslopvet.fr         | proxy http://127.0.0.1:3001       | -            |
| db.conf       | DB.lucaslopvet.fr           | proxy http://127.0.0.1:3002       | -            |
| dev-app.conf  | dev.app.lucaslopvet.fr      | /var/www/flutter-app-dev (SPA)     | 1 heure      |
| dev-auth.conf | dev.auth.lucaslopvet.fr     | proxy http://127.0.0.1:3003       | -            |
| dev-db.conf   | dev.DB.lucaslopvet.fr       | proxy http://127.0.0.1:3004       | -            |

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

| Variable           | Description                                |
|--------------------|--------------------------------------------|
| JWT_SECRET         | Cle de signature access tokens             |
| JWT_REFRESH_SECRET | Cle de signature refresh tokens            |
| INTERNAL_SECRET    | Secret communication inter-services        |

### Dev (defauts dans docker-compose.dev.yml)

| Variable                | Defaut                              |
|-------------------------|-------------------------------------|
| JWT_SECRET_DEV          | kabutare-dev-secret                 |
| JWT_REFRESH_SECRET_DEV  | kabutare-dev-refresh-secret         |
| INTERNAL_SECRET_DEV     | kabutare-internal-dev-secret        |

### Communication inter-services (dans Docker)

| Service      | Variable          | Valeur                          |
|--------------|-------------------|---------------------------------|
| auth-service | DB_SERVICE_URL    | http://db-service:3002          |
| db-service   | AUTH_SERVICE_URL  | http://auth-service:3001        |

---

# 5. Departements hospitaliers

Administration, OPD (Consultations externes), Medecine Interne, Pediatrie, Urgences, Laboratoire, Stomatologie, Kinesitherapie, Neonatologie, Maternite, Chirurgie, Bloc Operatoire, Ophtalmologie, TB-MR, GBV (Violence basee sur le genre), Sante Mentale, ARV (Traitement VIH/SIDA), Pharmacie, Radiologie, ICT
