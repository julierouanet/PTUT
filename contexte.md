# 🏥 Contexte Projet — Gestion des Équipements Médicaux

> **Hôpital de District de Kabutare, Rwanda**
> **Commanditaire** : Dr. NZABONIMANA Ephraim · nzephmd@gmail.com · +250 788823228
> **Projet** : PTUT ISIS — Module 1 (Gestion des Équipements et Maintenance)

---

## 🎯 Vue d'ensemble

### Objectif métier

Permettre au personnel hospitalier de **suivre, surveiller et signaler les problèmes** liés aux équipements médicaux (ICT, biomédicaux, infrastructure) dans tous les départements. Remplace un suivi papier/manuel fragmenté.

### Périmètre PTUT

| Module | Description | Statut |
|---|---|---|
| **1 — Équipements & Maintenance** | Suivi équipements, incidents, inventaire, audit | ✅ **Ce projet** |
| 2 — Santé Environnementale | Tri déchets, hygiène des mains | Futur |
| 3 — Accréditation | Conformité, réunions, formations | Futur |
| 4 — Santé Communautaire | Accouchements, agents CHW | Futur |
| 5 — Surveillance Maladies | Épidémies, décès communautaires | Futur |
| 6 — Ressources Humaines | Congés, missions, présence | Futur |
| 7 — Logistique | Stocks, actifs, mouvements | Futur |

### Utilisateurs et rôles

| Rôle Keycloak | Profil | Permissions clés |
|---|---|---|
| `hospitalStaff` | Docteurs, infirmiers, techniciens labo | Voir équipements, signaler incidents, suivre ses demandes |
| `supervisor` | Chefs de département | + Approuver demandes, assigner tâches |
| `technician` / `technician_biomedical` / `technician_it` / `technician_infra` | Techniciens spécialisés | + Mettre à jour réparations, enregistrer pièces |
| `admin` | ICT Admin | Toutes les 14 permissions |

**14 permissions applicatives (SQLite)** :
`viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`, `updateRepairs`, `registerParts`, `manageEquipment`, `manageUsers`, `manageDepartments`, `manageCategories`, `generateReports`, `viewInventory`, `changeDepartment`

---

## 🏗️ Architecture Globale

### Schéma 3 tiers + IAM

```
                 ┌──────────────────────────────────────────────┐
                 │  Flutter Web App / APK Android               │
                 │  Auth via Keycloak Direct Grant (JWT RS256)  │
                 └────┬──────────────┬──────────────┬───────────┘
                      │ KC_TOKEN_URL │              │ DB_URL
              ┌───────▼────────┐     │     ┌────────▼─────────┐
              │   Keycloak     │     │     │   db-service     │
              │   port 8080    │     │     │  Node + Express  │
              │   PostgreSQL   ├─────┘     │  port 3002       │
              │   SMTP→Brevo   │  JWKS     │  better-sqlite3  │
              └───────┬────────┘           └──────────────────┘
                      │ Admin API                /data/hospital.db
              ┌───────▼────────┐
              │  auth-service  │       ┌──────────────────────┐
              │  Node + Express│       │        Brevo         │
              │  port 3001     │──────►│  API transactionnelle│
              │  better-sqlite3│       │  (incidents, depts)  │
              └────────────────┘       └──────────────────────┘
              /data/auth.db
              (role_permissions,
               department_change_requests)
```

### Responsabilités des services

| Service | Rôle | Ce qu'il NE fait PAS |
|---|---|---|
| **Keycloak** | Émission/validation JWT RS256, stockage users/mots de passe/rôles, JWKS, SMTP Brevo | Ne gère pas les permissions applicatives |
| **auth-service** | Proxy Admin API Keycloak (CRUD users/rôles), `GET /api/auth/me`, permissions SQLite, demandes de département | N'émet aucun token, ne hache aucun mot de passe |
| **db-service** | CRUD équipements/incidents/inventaire/logs, validation JWT via JWKS | N'appelle pas auth-service pour valider les tokens |
| **Flutter App** | Interface web + mobile, routing RBAC, refresh automatique JWT | Pas d'appel HTTP direct hors `ApiClient` |

### Communication inter-services

- **Auth utilisateur** : JWT RS256 JWKS — aucun `JWT_SECRET` partagé
- **Service-à-service** : header `x-internal-secret` (= `INTERNAL_SECRET`)
- **Admin Keycloak** : service account OAuth2 (`KC_CLIENT_ID` / `KC_CLIENT_SECRET`)

---

## 🛠️ Stack Technique

| Couche | Technologie | Version |
|---|---|---|
| **Frontend** | Flutter (web prioritaire, APK Android possible) | SDK ^3.10.7 |
| **Backend** | Node.js + Express | Node 20 / Express 4.21.0 |
| **Base de données métier** | SQLite via better-sqlite3 (mode synchrone, WAL) | 11.7.0 |
| **IAM** | Keycloak (realm `kabutare-hospital`) | 26+ |
| **Auth DB** | PostgreSQL (backend Keycloak uniquement) | 16 |
| **Reverse proxy** | Nginx (HTTPS, Let's Encrypt via DuckDNS DNS-01) | Stable |
| **Containerisation** | Docker Compose (prod + dev) | v2 |
| **CI/CD** | Jenkins (`ghcr.io/cirruslabs/flutter:3.41.4`) | — |
| **Emailing** | Brevo (SMTP Keycloak + API REST services Node) | — |
| **Tests** | Jest (Node) + flutter_test (Dart) | — |

---

## 📦 Structure du Projet

```
PTUT/
├── CLAUDE.md                     # Instructions pour Claude (conventions, commandes)
├── contexte.md                   # Ce fichier (contexte métier & architecture)
├── auth-service/
│   ├── src/
│   │   ├── index.js              # Bootstrap : helmet, CORS, rate-limit, routes
│   │   ├── config.js             # process.env + valeurs par défaut
│   │   ├── database.js           # SQLite init + migrations idempotentes
│   │   ├── middleware/auth.js    # verifyToken (JWKS RS256), requireRole, requireAdmin
│   │   ├── routes/               # auth.js, users.js, roles.js
│   │   └── utils/logger.js       # sendLog, logAction, extractIp, extractReqMeta
│   ├── scripts/
│   │   ├── keycloak-init.js      # Bootstrap realm (one-shot)
│   │   └── migrate-users.js      # Migration auth.db → Keycloak (one-shot)
│   └── seed.js
├── db-service/
│   ├── src/
│   │   ├── routes/               # equipment, issues, inventory, logs, sidebar, locations
│   │   └── ...
│   └── scripts/
│       ├── import_inventory.js   # Import XLSX inventaire physique 2025-2026
│       └── lib/inventory_normalizer.js
├── flutter-app/
│   └── lib/
│       ├── main.dart             # MaterialApp, routing (enum ScreenType)
│       ├── screens/              # 13 écrans (1 fichier par écran)
│       ├── services/             # ApiClient, AuthService, DataService, DbApiService,
│       │                         # AuthApiService, ConfigService, NotificationService
│       ├── models/               # Equipment, Issue, User, Location, InventoryItem,
│       │                         # UserRole/Permission, AppNotification
│       ├── widgets/              # issue_category_selector, StatCard, StatusBadge, ...
│       ├── providers/            # locale_provider.dart (FR/EN)
│       ├── theme/                # AppTheme.lightTheme, AppColors
│       └── l10n/                 # app_fr.arb (template), app_en.arb
├── nginx/conf.d/                 # Vhosts HTTPS (prod multi-sous-domaines + kabutare.conf LAN)
├── docker-compose.yml            # Stack prod
├── docker-compose.dev.yml        # Stack dev
├── Jenkinsfile                   # Pipeline CI/CD
└── contexte/
    ├── context.md                # Schémas DB complets + tous les endpoints API
    ├── plan.md                   # Protocole déploiement LAN hôpital (DuckDNS + NAT)
    └── resume_need_software_kabutare.md  # Cahier des charges original
```

---

## 🗄️ Schémas de Données

### auth-service (`auth.db`)

| Table | Clé primaire | Rôle |
|---|---|---|
| `role_permissions` | `(role_name, permission)` | Permissions applicatives par rôle Keycloak — sans FK (rôles dans Keycloak) |
| `department_change_requests` | UUID TEXT | Demandes de changement de département (`pending` / `approved` / `rejected`) |

> Les tables `users`, `user_roles`, `refresh_tokens`, `roles` ont été **supprimées** — tout est dans Keycloak.

### db-service (`hospital.db`)

| Table | PK | Description |
|---|---|---|
| `equipment` | TEXT slug (`a-z0-9_-`, max 100) | Équipements médicaux |
| `equipment_tags` | AUTOINCREMENT | Numéros de tags physiques par équipement (1 équipement → N tags) |
| `departments` | AUTOINCREMENT | Référentiel départements (~56 entrées en anglais) |
| `equipment_categories` | AUTOINCREMENT | Référentiel catégories (~626 entrées) |
| `maintenance_records` | AUTOINCREMENT | Historique des interventions de maintenance |
| `preventive_maintenance_plans` | AUTOINCREMENT | Plans de maintenance préventive (fréquence en mois) |
| `locations` | TEXT | Lieux infrastructure (bâtiment + département) — pour incidents sans équipement |
| `issues` | TEXT | Incidents — vise un **équipement** (`equipment_id`) **OU** un **lieu** (`location_id`) |
| `inventory` | TEXT | Pièces détachées et consommables médicaux |
| `logs` | AUTOINCREMENT | Audit trail de toutes les mutations |
| `sidebar_config` | `(role, screen_type)` | Ordre et visibilité de la sidebar par rôle |

### Points critiques

- **`equipment.id`** : slug dérivé du `TagNumber` XLSX — jamais un entier
- **`issues`** : `equipment_id` + `equipment_name` **OU** `location_id` — jamais les deux nuls
- **`issue_category` / `assigned_group`** : dérivés automatiquement (`Biomedical` si équipement, `Infrastructure` si lieu)
- **`user_id`** : UUID Keycloak (ex. `f47ac10b-58cc-4372-a567-0e02b2c3d479`) — jamais un entier
- **Migrations** : inline dans `database.js` via `PRAGMA table_info` + `ALTER TABLE`, idempotentes au démarrage

### Enums principaux (whitelists serveur)

| Contexte | Valeurs |
|---|---|
| `equipment.status` | `Operational`, `Maintenance`, `Out of service`, `To be disposal`, `Disposed` |
| `issues.status` | `Reported`, `Acknowledged`, `Assigned`, `In Progress`, `Waiting Materials`, `Completed`, `Verified`, `Closed`, `Redirected` |
| `issues.urgency` | `Faible`, `Moyen`, `Urgent`, `Critique` |
| `issues.issue_category` | `Biomedical`, `Infrastructure`, `IT` |
| `inventory.status` | `Normal`, `Faible`, `Rupture` (calculé : `stock=0` → Rupture, `<min` → Faible) |

---

## 🔐 IAM & Sécurité

### Flux d'authentification (Keycloak Direct Grant)

```
Flutter App
  → POST /realms/kabutare-hospital/protocol/openid-connect/token
      (grant_type=password, form-urlencoded, client_id=flutter-app)
  ← access_token JWT RS256 (15 min) + refresh_token (rotation stricte)
  → GET /api/auth/me   [auth-service, Bearer token]
  ← profil user (claims JWT) + permissions applicatives (SQLite role_permissions)
  → DataService.loadAll()   [toutes les données métier]
```

### Auto-refresh (ApiClient)

```
Requête API → 401
  → POST kcTokenUrl (grant_type=refresh_token)
  → Nouveaux tokens sauvegardés (rotation)
  → Requête originale rejouée
  → Échec refresh → handleSessionExpired() → retour login
```

### Emails : deux chemins distincts

| Type | Responsable | Configurer ici |
|---|---|---|
| Vérification email, reset mot de passe | **Keycloak** (SMTP Brevo) | Console Keycloak → Realm Settings → Email |
| Notifications incidents, changements département | **Services Node** (API REST Brevo) | Variable `BREVO_API_KEY` |

---

## 🌐 Déploiement & Infrastructure

### Mode cible — Serveur local hôpital avec NAT

Le système tourne sur un **serveur physique à l'hôpital**. L'accès combine LAN interne et accès depuis l'extérieur via NAT :

```
Internet / Réseau LAN hôpital
         ↓ HTTPS :443
  Routeur hôpital (NAT port-forward :443 → IP serveur)
         ↓
  Nginx (kabutare.duckdns.org — cert Let's Encrypt DNS-01)
  ├── /auth/          → auth-service :3001
  ├── /db/            → db-service :3002
  ├── /download/app.apk → APK Android
  └── /               → Flutter Web SPA
```

- **DuckDNS** (`kabutare.duckdns.org`) : hostname public → résolution DNS locale par le routeur (ou dnsmasq) vers l'IP interne
- **Let's Encrypt DNS-01** : cert valide sans exposer le port 80 sur Internet
- **APK Android** : servi par Nginx sous `/download/app.apk`, installable depuis le navigateur Android

> Voir `contexte/plan.md` pour le protocole de déploiement complet pas-à-pas.

### Environments Docker

| Env | Compose | Ports auth/db | Flutter |
|---|---|---|---|
| **Prod** | `docker-compose.yml` | 3001 / 3002 | `/var/www/flutter-app` |
| **Dev** | `docker-compose.dev.yml` | 3003 / 3004 | `/var/www/flutter-app-dev` |

**Projet Docker** : `gestion-equipement-medical-prod` / `gestion-equipement-medical_dev`

> ⚠️ `docker-compose down -v` détruit les volumes de données. Toujours `down` sans `-v`.

### Keycloak

- **Prod** : PostgreSQL (`keycloak_postgres_data`), port 8080
- **Dev** : H2 `start-dev`, port 8081
- `nginx/conf.d/keycloak.conf` : déploiement **manuel** sur le serveur (non géré par Jenkins)

### Pipeline CI/CD (Jenkins)

| Étape | Action |
|---|---|
| 1–4 | `flutter pub get` → `flutter analyze` → `flutter test` → build web |
| 5–6 | Copie vers `/var/www/flutter-app[-dev]` |
| 7–8 | `docker-compose up -d --build` + `node seed.js` |
| 9 | Healthcheck HTTPS `/health` sur les deux services |

| Branche | Cible | `AUTH_URL` / `DB_URL` |
|---|---|---|
| `main` | prod | `https://kabutare.duckdns.org/auth` / `/db` |
| `dev` | dev | `https://dev.kabutare.duckdns.org/auth` / `/db` |

---

## 📋 Variables d'Environnement

### Services Node (depuis `/etc/kabutare/.env`)

| Variable | Service | Rôle |
|---|---|---|
| `INTERNAL_SECRET` | auth + db | Authentification service-à-service |
| `DB_PATH` | auth + db | Chemin SQLite (`/data/auth.db` / `/data/hospital.db`) |
| `KC_ISSUER` | auth + db | URL realm (`https://kabutare.duckdns.org/realms/kabutare-hospital`) |
| `KC_ADMIN_URL` | auth | URL Admin API Keycloak |
| `KC_CLIENT_ID` | auth | `auth-service` (service account) |
| `KC_CLIENT_SECRET` | auth | Secret client Keycloak |
| `DB_SERVICE_URL` | auth | `http://db-service:3002` (réseau Docker) |
| `AUTH_SERVICE_URL` | db | `http://auth-service:3001` (réseau Docker) |
| `BREVO_API_KEY` | auth + db | API Brevo pour emails transactionnels applicatifs |
| `PORT` | auth / db | 3001 / 3002 |

### Keycloak (Docker Compose)

| Variable | Description |
|---|---|
| `KC_DB_PASSWORD` | Mot de passe PostgreSQL |
| `KC_ADMIN_USER` / `KC_ADMIN_PASSWORD` | Console admin Keycloak |
| `KC_EMAIL_SMTP_PASSWORD` | Mot de passe SMTP Brevo (pour emails système) |

### Flutter (`--dart-define` à la compilation)

```bash
--dart-define=AUTH_URL=https://kabutare.duckdns.org/auth
--dart-define=DB_URL=https://kabutare.duckdns.org/db
--dart-define=KC_TOKEN_URL=https://kabutare.duckdns.org/realms/kabutare-hospital/protocol/openid-connect/token
```

---

## 🏥 Départements Hospitaliers (20)

Administration, OPD, Médecine Interne, Pédiatrie, Urgences, Laboratoire, Stomatologie, Kinésithérapie, Néonatologie, Maternité, Chirurgie, Bloc Opératoire, Ophtalmologie, TB-MR, GBV, Santé Mentale, ARV, Pharmacie, Radiologie, ICT

---

## 📚 Documentation Complémentaire

| Fichier | Contenu |
|---|---|
| `CLAUDE.md` | Instructions de développement (conventions, commandes, règles de code) |
| `contexte/context.md` | Schémas DB complets, tous les endpoints API, détails d'implémentation |
| `contexte/plan.md` | Protocole de déploiement LAN hôpital pas-à-pas (DuckDNS, NAT, Nginx, TLS) |
