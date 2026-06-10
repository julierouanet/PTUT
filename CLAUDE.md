# CLAUDE.md — Instructions de Développement

> Ce fichier définit les conventions, commandes et règles de codage du projet.
> **Contexte métier, architecture, schémas DB et stack** → voir `contexte.md`.

---

## 🤖 Comportement Attendu

### Règles absolues

- **Jamais de code tronqué** : tout bloc de code généré est complet. Si le fichier est long, l'écrire en entier — jamais de `// ... reste du code inchangé` ni de `// TODO: compléter`.
- **Lire avant d'écrire** : toujours utiliser `Read` sur le fichier cible avant `Edit` ou `Write`.
- **Vérifier après modification** : s'assurer que `npm test` ou `flutter analyze` passe encore.
- **Commentaires en français** : tout commentaire inline est en français.
- **Réponses en français** : communication avec le développeur en français.
- **Expliquer le "pourquoi"** : pour tout changement non trivial, expliquer la raison avant le code.
- **Proposer avant d'agir** sur tout changement d'architecture (nouvelles tables, nouveaux services, changement de flux auth).

---

## 📊 Processus Obligatoire de Livrables & Vérification Humaine

> ⚡ **PRIORITÉ HAUTE — Ce processus se déclenche automatiquement à chaque feature terminée, sans exception.**

### Règle

Dès qu'une tâche est considérée comme **terminée** — nouveau endpoint, nouvel écran, nouveau widget, nouveau script, nouvelle règle métier — le processus de validation ci-dessous **doit se déclencher avant de clore la tâche**.

### Cible du fichier

| Paramètre | Valeur |
|---|---|
| **Chemin** | `verification/suivi_verifications.xlsx` (racine du projet) |
| **Création auto** | Si le dossier ou le fichier n'existe pas, le script les crée |

### Structure du tableau Excel

| Colonne | Rempli par | Valeur par défaut |
|---|---|---|
| `ID Feature` | Script (auto) | `FEAT-001`, `FEAT-002`, … |
| `Nom de la Feature` | Claude | Fourni à l'appel du script |
| `Description concise` | Claude | Fourni à l'appel du script |
| `Date d'ajout` | Script (auto) | Date du jour (`YYYY-MM-DD`) |
| `Statut Vérification` | Script (auto) | `En attente de revue` |
| `Vérifié par (Humain)` | Humain | *(vide)* |
| `Date de Validation` | Humain | *(vide)* |
| `Notes / Commentaires` | Claude / Humain | Optionnel |

### Méthode d'enregistrement — `scripts/log_feature.py`

Le script officiel utilise **openpyxl**. Il ajoute une ligne sans jamais écraser les données existantes.

```bash
# Dépendance (une seule fois)
pip install openpyxl

# Usage depuis la racine du projet
python -X utf8 scripts/log_feature.py \
  --nom  "Nom court de la feature" \
  --desc "Description concise en 1-2 phrases" \
  --notes "Remarques optionnelles"          # facultatif

# Exemple concret
python -X utf8 scripts/log_feature.py \
  --nom  "Sélecteur catégorie incident" \
  --desc "Widget responsive (dialog ≥800px / bottom-sheet <800px) de pré-qualification avant IssueFormScreen" \
  --notes "Testé Chrome + Android. Filtre équipements par catégorie."

# Mettre à jour le statut après validation humaine
python -X utf8 scripts/log_feature.py \
  --update FEAT-003 --statut "Validé" --par "Prénom Nom"
```

> 💡 **`-X utf8`** : flag obligatoire sur Windows pour l'encodage correct des accents. Linux/Mac : flag ignoré sans effet.

**Sortie attendue :**
```
✅ Feature enregistrée : FEAT-003 — "Sélecteur catégorie incident"
   Fichier : .../verification/suivi_verifications.xlsx
```

### ✅ Checklist de clôture de tâche

Avant de considérer une feature comme livrée, cocher mentalement :

- [ ] Code complet — aucun bloc tronqué
- [ ] `npm test` **ou** `flutter analyze --no-fatal-infos` passe
- [ ] `python -X utf8 scripts/log_feature.py --nom "..." --desc "..."` exécuté
- [ ] La ligne est visible dans `verification/suivi_verifications.xlsx`
- [ ] Mise à jour de `contexte.md` effectuée si la feature est majeure (voir règle ci-dessous)

### 📝 Mise à jour de `contexte.md` — Règle de documentation continue

Toute **feature majeure** doit entraîner une mise à jour de `contexte.md` (et/ou `contexte/context.md`) **avant** de clore la tâche.

**Constitue une feature majeure :**

| Changement | Fichier à mettre à jour |
|---|---|
| Nouvelle table ou colonne DB | `contexte.md` → section "Schémas de Données" + `contexte/context.md` → schéma complet |
| Nouveau rôle Keycloak ou nouvelle permission | `contexte.md` → section "IAM & Sécurité" |
| Nouveau endpoint API (`GET`/`POST`/`PUT`/`DELETE`) | `contexte/context.md` → section endpoints du service concerné |
| Nouvel écran Flutter | `contexte/context.md` → section "Écrans (13)" (mettre à jour le compteur et le tableau) |
| Nouveau service ou nouveau module | `contexte.md` → sections "Architecture" et "Structure du Projet" |
| Changement de déploiement ou de variable d'env | `contexte.md` → sections "Déploiement" et "Variables d'Environnement" |

**Ne nécessite pas de mise à jour documentaire :**
- Corrections de bugs sans impact sur les interfaces publiques
- Refactoring interne sans ajout de colonne ou d'endpoint
- Modifications de style, couleurs, textes i18n

> ⚠️ En cas de doute, documenter. Une documentation à jour est prioritaire sur le temps gagné à ne pas l'écrire.

---

## ⚙️ Commandes Essentielles

### Backend (depuis `auth-service/` ou `db-service/`)

```bash
npm install                                    # installer les dépendances
npm start                                      # lancer le service
npm test                                       # jest --forceExit --detectOpenHandles
npm run seed                                   # données démo SQLite
```

### Import inventaire physique (depuis `db-service/`)

```bash
npm run import:inventory -- --dry-run                        # valider sans écrire
npm run import:inventory -- --xlsx <chemin.xlsx>             # UPSERT (défaut)
npm run import:inventory -- --xlsx <chemin.xlsx> --insert-only  # ne pas écraser l'existant
```

### Flutter (depuis `flutter-app/`)

```bash
flutter pub get
flutter gen-l10n                               # régénérer l10n après modif ARB
flutter analyze --no-fatal-infos              # lint — BLOQUANT en CI
flutter test

# Run local (dev)
flutter run -d chrome \
  --dart-define=AUTH_URL=http://localhost:3001 \
  --dart-define=DB_URL=http://localhost:3002 \
  --dart-define=KC_TOKEN_URL=http://localhost:8080/realms/kabutare-hospital/protocol/openid-connect/token

# Build web (prod hôpital)
flutter build web --release \
  --dart-define=AUTH_URL=https://kabutare.duckdns.org/auth \
  --dart-define=DB_URL=https://kabutare.duckdns.org/db \
  --dart-define=KC_TOKEN_URL=https://kabutare.duckdns.org/realms/kabutare-hospital/protocol/openid-connect/token

# Build APK Android
flutter build apk --release \
  --dart-define=AUTH_URL=https://kabutare.duckdns.org/auth \
  --dart-define=DB_URL=https://kabutare.duckdns.org/db \
  --dart-define=KC_TOKEN_URL=https://kabutare.duckdns.org/realms/kabutare-hospital/protocol/openid-connect/token
```

### Docker

```bash
# Prod
docker compose -p gestion-equipement-medical-prod -f docker-compose.yml up -d --build

# Dev
docker compose -p gestion-equipement-medical_dev -f docker-compose.dev.yml up -d --build

# Seed
docker exec auth-service-prod node seed.js
docker exec db-service-prod   node seed.js

# Import inventaire en prod
docker cp <fichier.xlsx> db-service-prod:/tmp/inventory.xlsx
docker exec db-service-prod node scripts/import_inventory.js --xlsx /tmp/inventory.xlsx
```

---

## 📝 Conventions — Backend Node.js

### Structure et style

- **CommonJS** (`require` / `module.exports`) — pas d'ESM
- **camelCase** en JS, **snake_case** en SQL et noms de colonnes DB
- Un `router` par fichier de route, exporté en bas du fichier
- Délimiter les sections : `// ── POST /api/xxx ──────────────────────────`
- **Pas de framework de migration** : ALTER TABLE inline dans `database.js` via `PRAGMA table_info`, idempotent au démarrage
- **better-sqlite3 synchrone** : `db.prepare(...).run/get/all` — pas d'`async` autour des accès DB
- `WAL` activé + `foreign_keys = ON` dans chaque `database.js`

### Pattern d'une route type

```js
// ── PUT /api/equipment/:id ──────────────────────────
router.put('/:id', verifyToken, requireRole('admin', 'supervisor', 'technician'), (req, res) => {
  const { id } = req.params;
  const { name, status } = req.body;

  // 1. Validation explicite
  if (!id) return res.status(400).json({ error: 'id requis' });
  if (status && !VALID_STATUSES_EQ.includes(status)) {
    return res.status(400).json({ error: 'statut invalide' });
  }

  // 2. Vérifier existence
  const existing = db.prepare('SELECT * FROM equipment WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'Équipement introuvable' });

  // 3. Opération DB (synchrone)
  db.prepare('UPDATE equipment SET name = COALESCE(?, name), status = COALESCE(?, status), updated_at = datetime(\'now\',\'localtime\') WHERE id = ?')
    .run(name || null, status || null, id);

  // 4. Audit trail
  logAction({
    user_id: req.user.id, user_name: req.user.name, user_role: req.user.roles[0],
    action: 'update_equipment',
    target_type: 'equipment', target_id: id, target_name: existing.name,
    details: JSON.stringify({ status }),
    ...extractReqMeta(req)
  });

  res.json({ message: 'Équipement mis à jour' });
});
```

### Codes HTTP

| Code | Situation |
|---|---|
| `400` | Input invalide ou manquant |
| `401` | Token absent ou invalide |
| `403` | Rôle insuffisant |
| `404` | Ressource introuvable |
| `409` | Conflit d'unicité (doublon) |
| `500` | Erreur serveur inattendue |

### Audit trail — obligatoire sur toute mutation

```js
logAction({
  user_id,           // req.user.id (UUID Keycloak)
  user_name,         // req.user.name
  user_role,         // req.user.roles[0]
  action,            // 'create_equipment' | 'update_issue' | 'delete_user' | ...
  target_type,       // 'equipment' | 'issue' | 'user' | ...
  target_id,
  target_name,
  details,           // JSON.stringify des champs modifiés
  ...extractReqMeta(req)
});
```

### Tests Jest

```js
// DB en mémoire — toujours en tête des tests
process.env.DB_PATH = ':memory:';

// Mock rate-limiter — évite les blocages en test
jest.mock('express-rate-limit', () => () => (req, res, next) => next());
```

---

## 🎨 Conventions — Flutter/Dart

### Patterns obligatoires

**Singleton service** :
```dart
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  // ...
}
```

**Modèle immuable** :
```dart
class Equipment {
  final String id;
  final String name;
  final EquipmentStatus status;

  const Equipment({required this.id, required this.name, required this.status});

  factory Equipment.fromApiJson(Map<String, dynamic> json) => Equipment(
    id: json['id'] as String,
    name: json['name'] as String,
    status: EquipmentStatus.fromString(json['status'] as String),
  );

  Equipment copyWith({String? id, String? name, EquipmentStatus? status}) => Equipment(
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
  );
}
```

**Enum riche** (manipulée côté API) :
```dart
enum EquipmentStatus {
  operational, maintenance, outOfService, toBeDisposal, disposed;

  String get displayName => switch (this) {
    EquipmentStatus.operational  => 'Operational',
    EquipmentStatus.maintenance  => 'Maintenance',
    // ...
  };

  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentStatus.operational => l10n.statusOperational,
    // ...
  };

  static EquipmentStatus fromString(String value) => switch (value.toLowerCase()) {
    'operational' => EquipmentStatus.operational,
    _             => EquipmentStatus.operational, // défaut sécurisé
  };
}
```

### Règles absolues Flutter

- **État partagé** = Singleton `extends ChangeNotifier` consommé via `ListenableBuilder(listenable: …)` — pas de Provider/Riverpod/Bloc
- **HTTP** : toujours `ApiClient.{get,post,put,patch,delete}` — jamais `http.X` direct (sinon pas de retry sur 401)
- **Navigation principale** : via `MainScaffold._navigateTo(int)` (enum `ScreenType`) — pas de `Navigator.pushNamed` global
- **Sous-écrans** (formulaires, modaux) : `Navigator.push(MaterialPageRoute(builder: …))`
- **URLs API** : injectées via `--dart-define` dans `services/api_config.dart` — jamais hardcodées
- **Tokens** : `SecureTokenStorage` — FlutterSecureStorage (natif) ou SharedPreferences (web)
- **Couleurs** : `AppColors` depuis `theme/app_theme.dart` — pas de `Color(0xFF…)` inline
- **Pas de `print`** : utiliser `debugPrint` si vraiment nécessaire (préférer rien)

### i18n — Procédure obligatoire

Toute nouvelle chaîne de caractères affichée dans l'UI :
1. Ajouter la clé dans `lib/l10n/app_fr.arb` (fichier template)
2. Ajouter la traduction dans `lib/l10n/app_en.arb`
3. Exécuter `flutter gen-l10n`
4. Utiliser dans le widget : `AppLocalizations.of(context)!.<clé>`

> ⚠️ Oublier `app_en.arb` casse `flutter analyze` — bloquant en CI.

### Signalement d'incident — Flux pré-qualification

Tout déclenchement "Signaler un incident" (sidebar, bottom nav, drawer, dashboard) passe **obligatoirement** par `showIssueCategorySelector(context)` (`lib/widgets/issue_category_selector.dart`) :
- `>= 800px` → `showDialog` (dialog centré)
- `< 800px` → `showModalBottomSheet` (coins arrondis)

| Tuile | Filtre équipements |
|---|---|
| Équipements Biomédicaux | Imagerie, Laboratoire, Chirurgie, Monitoring, Thérapeutique |
| Infrastructure & Électricité | Mobilier, Autre |
| Informatique (IT) | Informatique |
| Autre / Je ne sais pas | `null` (tous les équipements) |

**Exception** : depuis `EquipmentListScreen`, navigation directe avec équipement pré-sélectionné — pas de sélecteur.

---

## 🔒 Règles de Sécurité

- **Aucun secret en dur** : `process.env.*` (Node) ou `--dart-define` (Flutter)
- **Jamais de bcrypt côté Node** : gestion des mots de passe 100% déléguée à Keycloak
- **Jamais de `JWT_SECRET` partagé** : validation JWT via JWKS RS256 uniquement
- **Logs** : préfixe `[AUTH]`, `[DB]`, etc. en français — jamais de token ou mot de passe dans les logs
- **CORS** : liste blanche explicite dans `auth-service/src/index.js` **et** `db-service/src/index.js` — tout nouveau front doit y être ajouté manuellement
- **Ne jamais committer** : `*.db`, `*.sqlite`, `.env`, `node_modules/`, `flutter-app/build/`, `.dart_tool/`

---

## ⚠️ Pièges Critiques

| Piège | Conséquence | Solution |
|---|---|---|
| `docker compose down -v` | Détruit `auth_data`, `db_data`, `keycloak_data` | Toujours `down` sans `-v` |
| Nouveau dossier dans db-service non déclaré | Non embarqué dans l'image Docker | Ajouter `COPY <dossier>/ ./<dossier>/` dans le `Dockerfile` |
| Nouvelle entrée sidebar sans `requiredPermission` | Accessible à tous les rôles | Déclarer `requiredPermission` dans la config sidebar |
| `equipment.id` supposé numérique | Incompatible avec les IDs slug du XLSX | Toujours TEXT `a-z0-9_-`, max 100 chars |
| `user_id` supposé entier | Les IDs Keycloak sont des UUID | Toujours traiter les `user_id` comme TEXT |
| Réutiliser un refresh token consommé | Keycloak invalide la session | La rotation est stricte — `ApiClient._tryRefresh` gère ça |
| Supprimer une colonne dans `database.js` | Casse les déploiements existants | Migrer : RENAME table → CREATE new → INSERT SELECT → DROP old |
| Build Flutter sans `--dart-define` | Pointe vers les URLs par défaut (prod) | Toujours passer les 3 `--dart-define` |
| Email non reçu (vérification/reset) | Mauvais diagnostic → code Node | Vérifier les Events Keycloak (console admin → Events) — pas le code Node |
| Ajouter une permission sans seed | Permission absente en prod | Mettre à jour `seed.js` auth-service ET penser à relancer `node seed.js` |

---

## 📈 Audit KPI

| Élément | Valeur |
|---|---|
| **Dernier audit** | 2026-06-10 |
| **Score** | **83,5/100 — Bon** (grille KPI à 8 domaines) |
| **Rapport** | `audit/rapport_audit_2026-06-10.md` |
| **Skill** | `.claude/skills/audit-gmao-kpi/SKILL.md` |

**Relancer l'audit** : invoquer le skill `/audit-gmao-kpi` (ou demander « audite l'application avec la grille KPI »). Le skill embarque la grille complète, les requêtes SQL de mesure (lecture seule) et la structure du rapport. Outils d'appui : `audit/tools/diff_arb.js` (sync ARB), `audit/tools/kpi_queries.js` (KPIs métier sur `hospital.db`).

Points faibles relevés (voir top 10 du rapport) : ~~`POST /api/auth/access-request` public sans rate-limit créant des comptes actifs~~ (✅ corrigé 2026-06-10 : rate-limit 3/h + VERIFY_EMAIL + sendLog), mutations `roles.js` sans audit trail, documentation `contexte/context.md` en retard sur le code, chaînes UI en dur dans les écrans admin.
