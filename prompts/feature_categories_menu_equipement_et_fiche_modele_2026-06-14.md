# Prompt — Catégories sous le menu Équipements + Catalogue Fabricant→Modèle (fiche technique)

> **Projet** : GMAO Hôpital de Kabutare (Flutter / Node.js Express / SQLite better-sqlite3 / Keycloak)
> **Date** : 2026-06-14
> **Score KPI du prompt** : 92/100 (Excellent)
> **À coller dans une nouvelle session Claude Code.** La clôture (tests + `log_feature.py` + doc) fait partie de la tâche.

---

# Tâche : Déplacer la gestion des catégories sous le menu Équipements, et ajouter un catalogue Fabricant → Modèle avec fiche technique éditable

Tu vas implémenter **deux features liées**. Lis ce prompt en entier, puis **propose un plan d'exécution ordonné AVANT d'écrire du code** (c'est un changement d'architecture majeur : nouvelles tables, nouveaux endpoints, nouveaux écrans). Attends ma validation du plan avant d'implémenter. Respecte strictement `CLAUDE.md` (code complet jamais tronqué, `Read` avant `Edit`, commentaires en français, vérification `flutter analyze` / `npm test`).

## Contexte projet

Stack et conventions (voir `CLAUDE.md` et `contexte/context.md`) :
- **Backend db-service** : CommonJS, `better-sqlite3` **synchrone**, migrations **inline idempotentes** dans `db-service/src/database.js` via `PRAGMA table_info` + `ALTER TABLE` dans des `try { } catch (_) {}`. Une route = un fichier dans `db-service/src/routes/`. Toute mutation appelle `logAction({...})`. RBAC par `verifyToken` + `requireRole(...)`.
- **Flutter** : état partagé via Singleton `ChangeNotifier` + `ListenableBuilder` ; HTTP **uniquement** via `ApiClient.{get,post,put,delete}` ; URLs dans `services/api_config.dart` ; couleurs via `AppColors` ; navigation sous-écrans via `Navigator.push(MaterialPageRoute(...))` ; i18n obligatoire FR (`app_fr.arb`) **et** EN (`app_en.arb`) puis `flutter gen-l10n`.
- **Pièges critiques** : `equipment.id` est un slug TEXT (jamais entier) ; `user_id` = UUID Keycloak (TEXT) ; ne jamais supprimer une colonne (migrer) ; toute nouvelle entrée sidebar a un `requiredPermission` ; nouveau dossier db-service → `COPY` dans le Dockerfile.

Fichiers réels concernés (vérifiés) :
- `flutter-app/lib/main.dart:260-275` — `_allNavItems` (NavItems, `ScreenType.equipment`, `ScreenType.settings`).
- `flutter-app/lib/screens/settings_screen.dart:22` — `SettingsScreen` à 4 onglets (`TabController(length: 4)`).
- `flutter-app/lib/widgets/settings/categories_tab.dart` — `CategoriesTab` (réutilisable tel quel) ; clic sous-catégorie limité au biomédical en `:202`.
- `flutter-app/lib/screens/equipment_list_screen.dart` — écran liste équipements (rendu par `ScreenType.equipment`).
- `flutter-app/lib/screens/subcategory_detail_screen.dart` — page détail sous-catégorie (durée de vie + alertes remplacement), à enrichir.
- `flutter-app/lib/services/db_api_service.dart:368-420` — méthodes catégories (`getMacroCategories`, `getSubCategories`, `createSubCategory`, …) : **modèle à imiter** pour les nouvelles méthodes.
- `db-service/src/routes/categories.js` — CRUD sous-catégories (**modèle à imiter** : validation, 404/409, `logAction('create_subcategory'/...)`).
- `db-service/src/routes/equipment.js` — liste équipements + filtres (`department`, `status`, `category`, `macro_category`). À étendre avec filtres `subcategory_id`, `brand_id`, `model_id`.
- `db-service/src/routes/documents.js:11-70` — mécanisme `equipment_documents` (`documentUpload`, `VALID_DOC_TYPES`) : **modèle à imiter** pour les documents de modèle.
- `db-service/src/routes/pm_protocols.js` — protocoles PM par `subcategory_id`.
- `db-service/src/database.js` — table `equipment` (`:18`), `equipment_subcategories` (`:467`, FK `subcategory_id` `:539`), `pm_protocols` (`:577`), `equipment_documents` (`:756`), colonnes `manufacturer`/`model` (`:158`).

## Objectif

1. Rendre la gestion des catégories accessible **dans le menu Équipements** (et non plus dans Paramètres).
2. Introduire un **catalogue structuré Fabricant → Modèle** rattaché aux sous-catégories, avec une **fiche technique de modèle** (documents + protocoles PM) éditable, alimentée automatiquement depuis les données existantes.

Pourquoi : aligner l'app sur les GMAO du marché (Maximo/Infor EAM/CARL Source) où la fiche technique partagée appartient au couple *fabricant + modèle*, et regrouper la configuration métier-équipement au même endroit.

## Périmètre

**Dans le scope :**
- **Feature A** : déplacer **uniquement l'onglet Catégories** vers la page Équipements via une `TabBar` (« Liste » | « Catégories »). L'onglet Catégories n'apparaît que si `manageCategories`. `SettingsScreen` repasse à 3 onglets.
- **Feature B** : tables `equipment_brands`, `equipment_models`, colonne `equipment.model_id`, table `model_documents`, table de liaison `model_pm_protocols` ; auto-seed + backfill par migration ; endpoints CRUD brands/models + docs + liens PM ; filtres equipment ; enrichissement de la page détail sous-catégorie (liste équipements + liste fabricants) **pour toutes les macro-catégories** ; nouvel écran `BrandDetailScreen` (modèles du fabricant) ; nouvel écran `ModelDetailScreen` (fiche : équipements + documents + protocoles PM).

**Hors scope :**
- Modification du **formulaire équipement** (`equipment_form_screen.dart`) : on ne touche PAS à la saisie ; le lien `model_id` est géré uniquement par la migration auto-seed.
- Specs techniques structurées (clé/valeur) et durée de vie au niveau modèle.
- Refonte de `import_inventory.js`.
- Déplacement des onglets Départements / Rôles / Journal.

## Spécification détaillée

### 1. DB — `db-service/src/database.js` (migrations idempotentes, après le bloc sous-catégories)

Créer dans l'ordre, chaque `ALTER` dans un `try { } catch (_) {}`, chaque table en `CREATE TABLE IF NOT EXISTS` :

```sql
-- Fabricants (marques)
CREATE TABLE IF NOT EXISTS equipment_brands (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL COLLATE NOCASE UNIQUE,
  created_at  TEXT DEFAULT (datetime('now','localtime')),
  updated_at  TEXT
);

-- Modèles (couple fabricant + référence, rattaché à une sous-catégorie)
CREATE TABLE IF NOT EXISTS equipment_models (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  brand_id        INTEGER NOT NULL REFERENCES equipment_brands(id) ON DELETE CASCADE,
  subcategory_id  INTEGER REFERENCES equipment_subcategories(id),
  name            TEXT NOT NULL,
  created_at      TEXT DEFAULT (datetime('now','localtime')),
  updated_at      TEXT,
  UNIQUE(brand_id, subcategory_id, name COLLATE NOCASE)
);
CREATE INDEX IF NOT EXISTS idx_models_brand ON equipment_models(brand_id);
CREATE INDEX IF NOT EXISTS idx_models_subcat ON equipment_models(subcategory_id);

-- Documents de modèle (mêmes 3 types que equipment_documents : technical/intervention/certification)
CREATE TABLE IF NOT EXISTS model_documents (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  model_id      INTEGER NOT NULL REFERENCES equipment_models(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  original_name TEXT NOT NULL,
  stored_name   TEXT NOT NULL,
  mime_type     TEXT,
  file_size_kb  INTEGER,
  uploaded_by   TEXT,
  uploader_name TEXT,
  uploaded_at   TEXT,
  deleted_at    TEXT
);
CREATE INDEX IF NOT EXISTS idx_model_documents_model ON model_documents(model_id);

-- Liaison N-N modèle ↔ protocoles PM (en plus de ceux de la sous-catégorie)
CREATE TABLE IF NOT EXISTS model_pm_protocols (
  model_id    INTEGER NOT NULL REFERENCES equipment_models(id) ON DELETE CASCADE,
  protocol_id INTEGER NOT NULL REFERENCES pm_protocols(id) ON DELETE CASCADE,
  PRIMARY KEY (model_id, protocol_id)
);
```

```js
// Colonne de rattachement sur equipment (idempotent)
try { db.exec('ALTER TABLE equipment ADD COLUMN model_id INTEGER REFERENCES equipment_models(id)'); } catch (_) {}
```

**Auto-seed + backfill (idempotent)** — garder un garde-fou comme `_pm_seeded` si besoin, sinon s'appuyer sur `INSERT OR IGNORE` + `WHERE model_id IS NULL` :
1. `INSERT OR IGNORE INTO equipment_brands(name)` ← `SELECT DISTINCT manufacturer FROM equipment WHERE manufacturer IS NOT NULL AND TRIM(manufacturer) <> ''`.
2. `INSERT OR IGNORE INTO equipment_models(brand_id, subcategory_id, name)` ← `SELECT DISTINCT b.id, e.subcategory_id, e.model FROM equipment e JOIN equipment_brands b ON b.name = e.manufacturer WHERE e.model IS NOT NULL AND TRIM(e.model) <> ''`.
3. Backfill `UPDATE equipment SET model_id = (SELECT m.id FROM equipment_models m JOIN equipment_brands b ON b.id = m.brand_id WHERE b.name = equipment.manufacturer AND m.name = equipment.model AND (m.subcategory_id IS equipment.subcategory_id)) WHERE model_id IS NULL AND manufacturer IS NOT NULL AND model IS NOT NULL`.

> ⚠️ Ne casse pas les déploiements existants : colonnes ajoutées **nullable**, jamais de DROP. Migration rejouable sans effet de bord.

### 2. Backend — nouveau fichier `db-service/src/routes/catalog.js` (monté sous `/api`)

Imiter `categories.js` (validation explicite, 400/404/409, `logAction`, `extractReqMeta`). RBAC : lecture `verifyToken` ; mutations `verifyToken, requireRole('admin')` (cohérent avec `categories.js`). Toutes les mutations → `logAction` (`create_brand`, `update_brand`, `delete_brand`, `create_model`, `update_model`, `delete_model`, `link_model_protocol`, `unlink_model_protocol`).

Endpoints :
| Méthode | Route | Accès | Détail |
|---|---|---|---|
| GET | `/api/brands` | Auth | Filtre `?subcategory_id=` (fabricants présents dans la sous-cat). Retourne `model_count`, `equipment_count`. |
| GET | `/api/brands/:id` | Auth | Détail fabricant + ses modèles (filtrables `?subcategory_id=`) avec `equipment_count`. |
| POST | `/api/brands` | Admin | `{name}` ; 409 si doublon (COLLATE NOCASE). |
| PUT | `/api/brands/:id` | Admin | Renommage ; 409 doublon. |
| DELETE | `/api/brands/:id` | Admin | **409 `BRAND_HAS_MODELS`** si modèles/équipements rattachés. |
| GET | `/api/models` | Auth | Filtres `?subcategory_id=` `?brand_id=` ; `equipment_count` par modèle. |
| GET | `/api/models/:id` | Auth | Modèle + fabricant + sous-cat + liste équipements + documents (`deleted_at IS NULL`) + protocoles PM liés. |
| POST | `/api/models` | Admin | `{brand_id, subcategory_id, name}` ; 409 doublon (UNIQUE). |
| PUT | `/api/models/:id` | Admin | Renommage / rebrancher brand/subcat. |
| DELETE | `/api/models/:id` | Admin | **409 `MODEL_HAS_EQUIPMENT`** si équipements rattachés. |
| GET/POST/DELETE | `/api/models/:id/documents[/:docId]` | Auth (lecture) / Admin (mut.) | Imiter `documents.js` avec `documentUpload.single('file')`, `VALID_DOC_TYPES`, stockage `UPLOAD_DIR`, soft-delete `deleted_at`. Table `model_documents`. |
| POST/DELETE | `/api/models/:id/protocols/:protocolId` | Admin | Lier / délier un `pm_protocols` via `model_pm_protocols` (`INSERT OR IGNORE` / `DELETE`). |

Étendre `db-service/src/routes/equipment.js` (liste) avec les filtres `subcategory_id`, `brand_id` (via `model.brand_id`), `model_id` (whitelist + paramètres préparés, comme `macro_category`).

Étendre `db-service/src/routes/categories.js` → `GET /api/categories/sub/:id` : ajouter au payload `brands` (fabricants présents dans la sous-cat avec `model_count`/`equipment_count`) **et** `equipment` (liste des équipements de la sous-cat : `id, name, status, manufacturer, model, model_id`). Alternative acceptable : 2 sous-routes dédiées `/api/categories/sub/:id/brands` et `?` ; choisis et documente.

Monter la route dans `db-service/src/index.js` (liste blanche CORS déjà gérée globalement ; pas de nouveau front).

### 3. Flutter

**A. ApiConfig** (`services/api_config.dart`) : ajouter `brandsUrl`, `brandItemUrl(id)`, `modelsUrl`, `modelItemUrl(id)`, `modelDocumentsUrl(id)`, `modelDocumentItemUrl(id, docId)`, `modelProtocolUrl(id, protocolId)` + variantes filtrées (query). Imiter le style `categoriesSub*`.

**B. DbApiService** (`services/db_api_service.dart`, après `:420`) : méthodes `getBrands({int? subcategoryId})`, `getBrandDetail(id, {int? subcategoryId})`, `createBrand/updateBrand/deleteBrand`, `getModels({int? subcategoryId, int? brandId})`, `getModelDetail(id)`, `createModel/updateModel/deleteModel`, `getSubCategoryDetail(id)` (si pas déjà), upload/list/delete document modèle, link/unlink protocole. Imiter exactement le pattern `getSubCategories` / `createSubCategory` (avec `_checkStatus` et `ApiException`).

**C. Feature A — TabBar dans Équipements** :
- Créer `flutter-app/lib/screens/equipment_hub_screen.dart` : `StatefulWidget` avec `TabController`. Onglet 1 = `EquipmentListScreen` (inchangé). Onglet 2 = `CategoriesTab` **seulement si** `AuthService().hasPermission(Permission.manageCategories)` (sinon `TabController(length: 1)` et pas de TabBar). Style TabBar « pilule » identique à `settings_screen.dart:82-128`.
- Dans `main.dart`, faire pointer le rendu de `ScreenType.equipment` vers `EquipmentHubScreen` (et non plus directement `EquipmentListScreen`). Ne pas modifier le `NavItem` ni `requiredPermission`.
- `settings_screen.dart` : retirer l'onglet Catégories → `TabController(length: 3)`, retirer le `Tab` et l'entrée `CategoriesTab` du `TabBarView` (ordre restant : Départements, Rôles, Journal). Supprimer l'import devenu inutile s'il l'est.

**D. Feature B — page détail enrichie** :
- `categories_tab.dart:202` : rendre le `onTap` actif pour **toutes** les sous-catégories (plus seulement `isBiomedical`). Continuer de passer `expectedLifespanYears`.
- `subcategory_detail_screen.dart` : garder la section durée de vie/alertes **uniquement si biomédical** ; ajouter deux sections affichées pour toutes :
  - **Équipements** : liste (nom + `StatusBadge`) des équipements de la sous-cat (depuis `getSubCategoryDetail`).
  - **Fabricants** : liste des fabricants avec compteurs ; chaque tuile → `Navigator.push` vers `BrandDetailScreen(brandId, brandName, subcategoryId, subcategoryName)`.
- `flutter-app/lib/screens/brand_detail_screen.dart` (nouveau) : en-tête fabricant + liste de ses **modèles** (dans le contexte de la sous-cat) avec `equipment_count` ; chaque modèle → `ModelDetailScreen`. Si `manageCategories` : actions renommer fabricant / ajouter-renommer-supprimer modèle (suppression désactivée si `equipment_count > 0`, comme `categories_tab.dart:262-268`), dialogues calqués sur `_showAddDialog`/`_showEditDialog`/`_confirmDeleteSub`.
- `flutter-app/lib/screens/model_detail_screen.dart` (nouveau) : **fiche modèle** = en-tête (fabricant · sous-cat) + section **Équipements** du modèle + section **Documents** (liste par type, upload/suppression si `manageCategories`, réutiliser le pattern de l'écran documents équipement existant s'il y en a un) + section **Protocoles PM** liés (lier depuis la liste des `pm_protocols` de la sous-cat, délier).

### 4. i18n
Ajouter toutes les chaînes dans `app_fr.arb` **puis** `app_en.arb`, puis `flutter gen-l10n`. Clés suggérées (préfixe cohérent) : `equipmentTabList`, `equipmentTabCategories`, `brandDetailTitle`, `brandModelsSection`, `modelDetailTitle`, `modelEquipmentSection`, `modelDocumentsSection`, `modelProtocolsSection`, `subcategoryEquipmentSection`, `subcategoryBrandsSection`, `catalogAddBrand`, `catalogAddModel`, `catalogDeleteBlockedTooltip`, etc. **Aucune chaîne UI en dur.**

## Contraintes et garde-fous

- **Proposer le plan avant de coder** (architecture majeure). Pour tout choix de schéma non couvert ici, proposer avant d'agir.
- Migrations **idempotentes**, colonnes **nullable**, **aucun DROP** de colonne existante.
- `equipment.id` = slug TEXT ; `user_id`/`uploaded_by` = UUID Keycloak TEXT.
- **RBAC** : lecture `verifyToken` ; mutations `requireRole('admin')`. Côté Flutter, gating UI via `Permission.manageCategories`.
- **`logAction` obligatoire** sur **chaque** mutation (brands, models, documents, liens PM) avec `target_type`/`target_id`/`target_name`/`details` + `extractReqMeta(req)`.
- Suppressions **bloquées (409)** si rattachements (modèles/équipements) — mêmes codes d'erreur structurés que `SUBCATEGORY_HAS_EQUIPMENT`.
- HTTP Flutter **uniquement** via `ApiClient` ; URLs via `ApiConfig` ; pas de `Color(0xFF…)` ni `print`.
- i18n FR **et** EN sinon `flutter analyze` casse.
- Si tu crées un dossier dans db-service, l'ajouter au `Dockerfile` (`COPY`). Vérifier la liste blanche CORS (aucun nouveau front ici).
- **Ne pas** modifier `equipment_form_screen.dart` ni `import_inventory.js`.

## Étapes attendues

1. **Plan** ordonné (DB → backend → Flutter → i18n → tests → doc) soumis pour validation.
2. Migrations + auto-seed dans `database.js`.
3. Route `catalog.js` + extensions `equipment.js` / `categories.js` + montage `index.js`.
4. Tests Jest db-service (brands/models CRUD, 409 rattachement, filtres, documents, liens PM).
5. ApiConfig + DbApiService (méthodes + URLs).
6. Feature A : `equipment_hub_screen.dart`, branchement `main.dart`, allègement `settings_screen.dart`.
7. Feature B : enrichissement `subcategory_detail_screen.dart`, `categories_tab.dart` (onTap), `brand_detail_screen.dart`, `model_detail_screen.dart`.
8. i18n FR+EN + `flutter gen-l10n`.
9. Vérification + clôture.

## Critères de succès / vérification

- `cd db-service && npm test` passe (avec les nouveaux tests).
- `cd flutter-app && flutter analyze --no-fatal-infos` passe (0 erreur).
- Migration rejouable : redémarrer db-service deux fois ne duplique ni n'échoue (auto-seed idempotent).
- Parcours manuel : Équipements → onglet Catégories → sous-catégorie → section Fabricants → `BrandDetailScreen` → modèle → `ModelDetailScreen` (documents + protocoles PM). Onglet Catégories absent pour un rôle sans `manageCategories`.
- `python -X utf8 scripts/log_feature.py --nom "Catalogue Fabricant/Modèle + Catégories sous Équipements" --desc "Onglet Catégories déplacé dans le menu Équipements ; nouvelles tables equipment_brands/equipment_models/model_documents/model_pm_protocols auto-seedées, endpoints CRUD, écrans détail fabricant et modèle (fiche = documents + protocoles PM)."`
- Vérifier la ligne dans `verification/suivi_verifications.xlsx`.
- **Mise à jour doc** (feature majeure) : `contexte.md` (Schémas de Données : nouvelles tables) + `contexte/context.md` (nouveaux endpoints `/api/brands`, `/api/models`, filtres equipment, nouveaux écrans dans « Écrans », incrément du compteur).
