# CLAUDE.md — Guide de contexte projet

> **Projet** : Système de gestion des équipements médicaux — Hôpital de Kabutare (PTUT ISIS).
> **Stack globale** : 2 microservices Node.js/Express + SQLite, application Flutter (web prioritaire, mobile possible), Nginx reverse-proxy, Docker Compose (prod + dev), CI/CD Jenkins.

---

## Architecture & Patterns

### Vue d'ensemble — Microservices (3 tiers)

```
                 ┌──────────────────────────────────────────────┐
                 │  Flutter Web App (lib/) — port serveur HTTPS │
                 │  Auth via JWT, stockage tokens sécurisé      │
                 └────────┬─────────────────────────┬───────────┘
                          │                         │
                  ┌───────▼────────┐       ┌────────▼─────────┐
                  │  auth-service  │       │   db-service     │
                  │  Node + Express│◄──────┤  Node + Express  │
                  │  port 3001     │ verify│  port 3002       │
                  │  better-sqlite3│       │  better-sqlite3  │
                  └────────────────┘       └──────────────────┘
                  /data/auth.db            /data/hospital.db
```

- Communication inter-services authentifiée par `INTERNAL_SECRET` + JWT partagé (`JWT_SECRET`).
- Reverse-proxy Nginx (`nginx/conf.d/*.conf`) gère HTTPS sur 6 sous-domaines (`app/auth/DB.lucaslopvet.fr` + variantes `dev.*`).
- Auth-service expose les utilisateurs/rôles/permissions ; db-service consulte auth-service via `AUTH_SERVICE_URL` pour vérifier les tokens.

### Modules majeurs

| Dossier            | Rôle                                                                     |
| ------------------ | ------------------------------------------------------------------------ |
| `auth-service/`    | JWT login/refresh/logout, users, roles, permissions, rate-limiting.       |
| `db-service/`      | CRUD `equipment`, `equipment_tags`, `departments`, `equipment_categories`, `inventory`, `issues`, `logs`, `sidebar`. Script d'import XLSX dans `scripts/`. |
| `flutter-app/lib/` | Application cliente (web + mobile). Voir sous-dossiers ci-dessous.        |
| `nginx/conf.d/`    | Vhosts HTTPS + headers CORS.                                              |
| `docker-compose*.yml` | Orchestration prod / dev (volumes nommés `auth_data*`, `db_data*`).    |
| `Jenkinsfile`      | Pipeline CI/CD : analyse + tests Flutter, build web, deploy via Docker.   |

### Backend — pattern routes/middleware/utils

Chaque service Node suit la même structure :

```
src/
├── index.js          # bootstrap Express : helmet, CORS, rate-limit, mount routes
├── config.js         # constantes + lecture process.env (avec valeurs par défaut)
├── database.js       # better-sqlite3 + initTables() + migrations idempotentes
├── middleware/
│   └── auth.js       # verifyToken, requireRole(...roles), requireAdmin
├── routes/           # un fichier par ressource (auth, users, equipment, ...)
└── utils/
    └── logger.js     # sendLog / logAction / extractIp / extractReqMeta
```

Conventions :
- **better-sqlite3 en mode synchrone** (`db.prepare(...).run/get/all`). Pas d'`async` autour des accès DB. WAL activé + `foreign_keys = ON`.
- Migrations inline dans `database.js` (`PRAGMA table_info` + `ALTER TABLE` conditionnel) — pas de framework de migration.
- Toute action métier sensible appelle `logAction(...)` ou `sendLog(...)` (audit trail).
- Validation manuelle des inputs côté route (whitelists `VALID_*`, regex, longueurs max). Pas de Joi/Zod.

### Frontend — Flutter sans package d'état

```
flutter-app/lib/
├── main.dart         # MaterialApp, routing impératif (enum ScreenType + setState)
├── data/             # mock_data.dart (fallback démo / tests)
├── l10n/             # ARB FR/EN (template = app_fr.arb), génération via flutter gen-l10n
├── models/           # POJOs Dart, tous avec fromApiJson()
├── providers/        # locale_provider.dart (singleton ChangeNotifier)
├── screens/          # 1 écran = 1 fichier (login_screen.dart, dashboard_screen.dart, …)
├── services/         # ApiClient, AuthService, DataService, NotificationService — tous Singleton + ChangeNotifier
├── theme/            # AppTheme.lightTheme + AppColors
├── utils/            # file_picker (stub web/native via conditional import)
└── widgets/          # composants UI réutilisables (StatCard, StatusBadge, NotificationBell, …)
```

Patterns clés :
- **Pas de Provider/Riverpod/Bloc**. État partagé = `Singleton extends ChangeNotifier`, consommation via `ListenableBuilder(listenable: …)`.
- **`ApiClient`** centralise tous les appels HTTP : ajoute le Bearer JWT, intercepte 401, déclenche `_tryRefresh()` (rotation stricte access+refresh), rappelle `onSessionExpired` si échec.
- **URLs API injectées à la compilation** via `--dart-define=AUTH_URL=…` / `DB_URL=…` (voir `services/api_config.dart`). Défaut = prod.
- **Stockage tokens** : `SecureTokenStorage` choisit `FlutterSecureStorage` (natif) ou `SharedPreferences` (web).
- **Permissions UI** : enum `Permission` ; chaque entrée de sidebar déclare une `requiredPermission` filtrée par `AuthService.hasPermission(...)`.
- **i18n obligatoire** : tout texte affiché passe par `AppLocalizations.of(context)!.xxx`. Ne **jamais** hardcoder du FR/EN dans un widget.

---

## Build & Test Commands

> Toutes les commandes ci-dessous sont à exécuter **depuis la racine du dépôt**, sauf indication contraire.

### Stack complète (Docker — recommandé)

```bash
# Production (sous-domaines lucaslopvet.fr) — nécessite /etc/kabutare/.env sur le VPS
docker-compose -p gestion-equipement-medical-prod -f docker-compose.yml up -d --build

# Développement (sous-domaines dev.*)
docker-compose -p gestion-equipement-medical_dev -f docker-compose.dev.yml up -d --build

# Seed d'un service (utilisateurs + données démo)
docker exec auth-service-prod node seed.js
docker exec db-service-prod  node seed.js
```

### auth-service / db-service (Node 20)

```bash
cd auth-service        # ou: cd db-service
npm install            # installe les dépendances (bcrypt nécessite python3 + make + g++)
npm start              # node src/index.js  (port 3001 / 3002)
npm test               # jest --forceExit --detectOpenHandles  (DB en :memory:)
npm run seed           # node seed.js — peuple la base SQLite avec les données de démo
```

### Import de l'inventaire physique 2025-2026 (db-service)

Script dédié `scripts/import_inventory.js` qui peuple `equipment`, `equipment_tags`, `departments` et `equipment_categories` à partir du XLSX réel de l'hôpital (feuilles `Equipment Migration Template`, `Standard_Departments`, `Standard_Equipment_Names`).

```bash
cd db-service
npm run import:inventory -- --dry-run                       # parse + valide sans écrire
npm run import:inventory -- --xlsx <chemin.xlsx>            # UPSERT par défaut (préserve created_at)
npm run import:inventory -- --xlsx <chemin.xlsx> --insert-only  # n'écrase pas les existants
```

Sur le VPS (en prod / dev) le XLSX doit être copié dans le conteneur :

```bash
docker cp <fichier.xlsx> db-service-<env>:/tmp/inventory.xlsx
docker exec db-service-<env> node scripts/import_inventory.js --xlsx /tmp/inventory.xlsx
```

Idempotent : un re-run sur le même XLSX exécute uniquement des UPDATE (`updated_at` rafraîchi, `created_at` préservé, aucun doublon dans `equipment_tags`).

> **Pas de linter/formatter Node configuré.** Suivre le style existant (voir section Conventions).

### flutter-app (Dart SDK ^3.10.7)

```bash
cd flutter-app
flutter pub get                          # installe les dépendances
flutter gen-l10n                         # régénère lib/l10n/app_localizations*.dart (auto sur build)
flutter analyze --no-fatal-infos         # lint (flutter_lints) — bloquant en CI
flutter test                             # tests unitaires + widgets

# Run local (par défaut pointe vers la prod — surcharger pour cibler local)
flutter run -d chrome \
  --dart-define=AUTH_URL=http://localhost:3001 \
  --dart-define=DB_URL=http://localhost:3002

# Build web pour déploiement
flutter build web --release \
  --dart-define=AUTH_URL=https://auth.lucaslopvet.fr \
  --dart-define=DB_URL=https://DB.lucaslopvet.fr
```

### CI/CD (Jenkins)

Le pipeline (`Jenkinsfile`) déclenche automatiquement sur push :
1. `flutter pub get` → `flutter analyze` → `flutter test` (dans `ghcr.io/cirruslabs/flutter:3.41.4`).
2. `flutter build web` avec les `--dart-define` correspondant à la branche.
3. Copie vers `/var/www/flutter-app[-dev]`.
4. `docker-compose up -d --build` du compose correspondant + `node seed.js` opportuniste.
5. Healthcheck `curl /health` sur les deux services.

| Branche | Cible                     | Compose utilisé             |
| ------- | ------------------------- | --------------------------- |
| `main`  | PROD (lucaslopvet.fr)     | `docker-compose.yml`        |
| `dev`   | DEV (dev.*.lucaslopvet.fr)| `docker-compose.dev.yml`    |

---

## Code Style & Conventions

### Backend Node (auth-service / db-service)

- **CommonJS** (`require` / `module.exports`) — pas d'ESM.
- **camelCase** en JS, **snake_case** en SQL/DB (`first_name`, `is_active`, `created_at`).
- Routes Express : un `router` par fichier, exporté en bas. Sectionner les blocs par commentaires `// ── POST /api/xxx ─────────────`.
- **Validation explicite** au début de chaque handler (`if (!field) return res.status(400).json({ error: '…' })`). Whitelists de valeurs (`VALID_STATUSES_EQ`, `VALID_DEPARTMENTS`, …) en haut du fichier.
- **Codes HTTP cohérents** : 400 (input), 401 (auth manquante), 403 (rôle insuffisant), 404 (introuvable), 409 (conflit unique), 500 (erreur serveur).
- **Sécurité** : toujours `requireRole('admin', …)` sur les écritures sensibles. Sanitiser tout `req.query.reason` ou texte libre (cf. `routes/equipment.js` DELETE).
- **Audit** : sur toute mutation (`create_*`, `update_*`, `delete_*`, `login`, `logout`, …), appeler `logAction({ user_id, user_name, user_role, action, target_type, target_id, target_name, details, ...extractReqMeta(req) })`.
- **Pas de console.log de mot de passe / token**. Logs avec préfixe `[AUTH]`, `[DB]`, … en français.
- Tests Jest : DB en mémoire (`process.env.DB_PATH = ':memory:'`), mock du rate-limiter (`jest.mock('express-rate-limit', …)`).

### Frontend Flutter (Dart)

- Lints : `flutter_lints` (cf. `analysis_options.yaml`). `flutter analyze --no-fatal-infos` doit passer.
- **Singletons** pour les services :
  ```dart
  class AuthService extends ChangeNotifier {
    static final AuthService _instance = AuthService._internal();
    factory AuthService() => _instance;
    AuthService._internal();
    …
  }
  ```
- **Modèles immuables** : champs `final`, constructeur `const`, factory `fromApiJson(Map<String, dynamic>)`, méthode `copyWith(...)`.
- **Énumérations riches** : ajouter `displayName`, `localizedName(l10n)`, `fromString(value)` quand l'enum est manipulé côté API.
- **Pas de print** : utiliser `debugPrint` si vraiment nécessaire (préférer rien).
- **Texte UI** : exclusivement via `AppLocalizations.of(context)!.<clé>`. Toute nouvelle clé → `lib/l10n/app_fr.arb` (template) + `app_en.arb`, puis `flutter gen-l10n`.
- **Couleurs** : importer `AppColors` depuis `theme/app_theme.dart` (pas de `Color(0xFF…)` en dur dans les widgets, sauf cas vraiment local).
- **Navigation** : pas de `Navigator.pushNamed` global. Le routing principal vit dans `MainScaffold._navigateTo(int)` via l'enum `ScreenType`. Les sous-écrans (modaux, settings) utilisent `Navigator.push(MaterialPageRoute(builder: …))`.
- **HTTP** : **toujours** passer par `ApiClient.{get,post,put,patch,delete}` — jamais d'appel `http.X` direct (sinon pas de retry sur 401).

### Style général

- **Commentaires en français** (le projet est francophone). Sections délimitées par `// ── Titre ──────────────────────`.
- **Aucun secret en dur** : tout passe par `process.env.*` (Node) ou `--dart-define` (Flutter). Le `.env.example` documente les variables attendues ; `/etc/kabutare/.env` sur le VPS.
- Ne pas committer : `*.db`, `*.sqlite`, `.env`, `node_modules/`, `flutter-app/build/`, `.dart_tool/` (déjà couverts par `.gitignore` et `.claudeignore`).

---

## Variables d'environnement clés

| Variable               | Service          | Rôle                                         |
| ---------------------- | ---------------- | -------------------------------------------- |
| `JWT_SECRET`           | auth + db        | Signature des access tokens (15 min).        |
| `JWT_REFRESH_SECRET`   | auth             | Signature des refresh tokens (7 jours).      |
| `INTERNAL_SECRET`      | auth + db        | Authentification service-à-service.          |
| `DB_PATH`              | auth + db        | Chemin du fichier SQLite (`/data/*.db`).     |
| `DB_SERVICE_URL`       | auth             | URL interne du db-service.                   |
| `AUTH_SERVICE_URL`     | db               | URL interne de l'auth-service.               |
| `PORT`                 | auth + db        | 3001 / 3002.                                 |
| `AUTH_URL` / `DB_URL`  | flutter (build)  | Injectées via `--dart-define`.               |

---

## Pièges à éviter

- **`docker-compose down -v`** détruirait `auth_data` / `db_data` (utilisateurs + équipements). Toujours préférer `down` sans `-v`.
- **Migrations DB** : ne supprimer aucune colonne dans `database.js` sans script de migration explicite — c'est lu à chaque démarrage.
- **Dockerfile db-service** : tout nouveau dossier (ex. `scripts/`) doit être ajouté via `COPY` dans le Dockerfile, sinon il n'est pas embarqué dans l'image (le `.dockerignore` ne suffit pas).
- **`equipment.id`** : la clé primaire est désormais dérivée du `TagNumber` slugifié pour les équipements importés (`a-z0-9_-`, max 100). Les lignes du XLSX sans `TagNumber` exploitable sont **ignorées** par `scripts/import_inventory.js`. Préserver la convention si on insère manuellement.
- **CORS** : la liste blanche d'origines est codée dans `auth-service/src/index.js`. Ajouter explicitement tout nouveau front autorisé.
- **Rotation refresh token** : un refresh consomme l'ancien et en émet un nouveau ; ne jamais réutiliser le précédent côté client (déjà géré par `ApiClient._tryRefresh`).
- **Permissions** : ajouter une nouvelle entrée dans la sidebar Flutter sans déclarer la `requiredPermission` correspondante l'expose à tous les rôles.
- **i18n** : oublier d'ajouter une clé dans `app_en.arb` casse le build (`flutter analyze` échoue).
