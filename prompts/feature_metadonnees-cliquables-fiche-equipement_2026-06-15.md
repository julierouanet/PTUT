# Prompt Claude Code — Métadonnées cliquables sur la fiche équipement

> **Date** : 2026-06-15
> **Score qualité du prompt** : 92/100 (Excellent)
> À coller dans une **nouvelle session Claude Code** pour implémenter la feature.
> La clôture (tests + `log_feature.py` + doc + `/simplify`) fait partie du prompt.

---

# Tâche : Rendre les métadonnées de la fiche équipement cliquables → fiches de détail liées (avec breadcrumb)

## Contexte projet
Stack : **Flutter** (web prioritaire, APK Android) / **Node.js Express** / **SQLite better-sqlite3** (synchrone, WAL) / **Keycloak** (JWT RS256).
Conventions **CLAUDE.md** à respecter strictement :
- Backend : CommonJS, `db.prepare(...).get/all/run` synchrone, RBAC `verifyToken` + `requireRole`, codes HTTP normalisés (400/401/403/404/500), `logAction` sur **mutation uniquement**.
- Flutter : HTTP via `ApiClient` (jamais `http.X`), sous-écrans via `Navigator.push(MaterialPageRoute(...))` (jamais `ScreenType`), état partagé via Singleton `ChangeNotifier`, couleurs via `AppColors` (pas de `Color(0xFF…)`), **pas de `print`**.
- i18n : toute chaîne UI → clé dans `app_fr.arb` **et** `app_en.arb`, puis `flutter gen-l10n` (oublier l'EN casse `flutter analyze`).
- Jamais de code tronqué ; lire chaque fichier avant de l'éditer.

Fichiers concernés (ancrages réels) :
- `flutter-app/lib/screens/equipment_detail_screen.dart` — pattern de lien cliquable déjà présent : `_replacementLink` (lignes 432-455) ; vue staff `_buildStaffScaffold` (237) vs vue complète `_buildTabbedScaffold` (262).
- `flutter-app/lib/widgets/equipment/equipment_info_tab.dart` — lignes à rendre cliquables : Département/Catégorie/Macro/Sous-catégorie (83-93), Fabricant/Modèle (135-138).
- `flutter-app/lib/widgets/equipment/equipment_detail_helpers.dart` — `DetailInfoRow` (100-157), `DetailSectionTitle` (160).
- `flutter-app/lib/models/equipment.dart` — champs existants `category` (127), `manufacturer` (134), `model` (135), `subcategoryId` (145), `subcategoryName` (147), `macroCategory` (151) ; parsing `fromApiJson` (~281).
- `flutter-app/lib/services/db_api_service.dart` — `getDepartments` (428), `getSubCategoryDetail` (503), `getBrandDetail` (523), `getModelDetail` (559), `getReplacementPlan` (645).
- `flutter-app/lib/screens/subcategory_detail_screen.dart` — ctor `{subcategoryId, subcategoryName, expectedLifespanYears?, isBiomedical=true}`.
- `flutter-app/lib/screens/brand_detail_screen.dart` — ctor `{brandId, brandName, subcategoryId, subcategoryName}`.
- `flutter-app/lib/screens/model_detail_screen.dart` — ctor `{modelId, modelName, brandName, subcategoryId, subcategoryName}`.
- `db-service/src/routes/equipment.js` — `GET /:id` (à enrichir).
- `db-service/src/routes/departments.js` — `GET /:id/stats` (28) à étendre, `GET /:id` (10).
- `db-service/src/routes/categories.js` — `GET /sub/:id` (53) comme modèle de réponse détail.
- `db-service/src/routes/catalog.js` — `GET /brands/:id` (60), `GET /models/:id` (233).

Schémas (contexte/context.md) : `equipment.id` = slug TEXT ; `equipment.model_id` **existe déjà** (backfillé) ; `equipment_models(brand_id, subcategory_id, name)` ; `equipment_brands.name` UNIQUE ; `equipment.category` = nom standard `equipment_categories` (chaîne, **pas d'id sur equipment**) ; `equipment.department` = nom (chaîne).

## Objectif
Sur la fiche détail d'un équipement (vue complète), transformer sous-catégorie, fabricant, modèle, catégorie et département en **liens de drill-down** vers leur fiche, et ajouter un **fil d'Ariane (breadcrumb)** cliquable en tête de chaque fiche de détail. But métier : naviguer la taxonomie et le parc sans repasser par les écrans de gestion (standard GMAO Maximo/Fiix/UpKeep).

## Périmètre
- **Dans le scope :**
  - Liens cliquables **uniquement dans la vue complète** (technicien/superviseur/admin) — `_buildTabbedScaffold`.
  - Cibles : sous-catégorie (écran existant), fabricant (existant), modèle (existant), **catégorie (NOUVEL écran)**, **département (NOUVEL écran dashboard)**.
  - Enrichissement `GET /api/equipment/:id` : `model_id`, `brand_id`, `brand_name`, `subcategory_id`, `subcategory_name`.
  - Endpoint **détail catégorie** (À CRÉER) et **dashboard département** (extension d'un endpoint existant).
  - Widget réutilisable `DetailBreadcrumb` appliqué à **toutes** les fiches de la chaîne (équipement, sous-catégorie, fabricant, modèle, catégorie, département). Segments cliquables.
  - Listes des nouvelles fiches (catégorie, département) → chaque équipement ouvre `EquipmentDetailScreen` (drill-down bidirectionnel).
- **Hors scope :**
  - Aucun lien dans la vue staff (`EquipmentStaffView`) — texte non cliquable.
  - Fiche macro-catégorie.
  - Toute mutation de données (lecture seule → **aucun `logAction`**).

## Spécification détaillée

### Backend — db-service (toutes les routes : `verifyToken`, lecture seule)
1. **`GET /api/equipment/:id`** (`equipment.js`) — ajouter au JSON renvoyé : `model_id`, `brand_id`, `brand_name`, `subcategory_id`, `subcategory_name`, via LEFT JOIN `equipment_models m ON m.id = equipment.model_id`, `equipment_brands b ON b.id = m.brand_id`, `equipment_subcategories s ON s.id = equipment.subcategory_id`. Ne rien casser des champs existants. Valeurs `null` si non rattaché.
2. **Détail catégorie — NOUVELLE route** : `GET /api/equipment-categories/detail?name=<nom>` (ou `GET /api/categories/by-name/:name`). Réponse :
   ```json
   { "name": "Patient Monitor",
     "equipment": [ { "id": "...", "name": "...", "status": "...", "department": "..." } ],
     "brands":    [ { "id": 1, "name": "Philips", "model_count": 3, "equipment_count": 8 } ] }
   ```
   Filtrage sur `equipment.category = ?`. Calquer la **forme** de réponse sur `GET /api/categories/sub/:id` (`categories.js:53`).
3. **Dashboard département** — étendre `GET /api/departments/:id/stats` (`departments.js:28`) **ou** créer `GET /api/departments/:id/detail`. Réponse :
   ```json
   { "id": 5, "name": "Radiologie",
     "kpis": { "total": 42, "operational": 30, "maintenance": 5, "outOfService": 4, "pmOverdue": 3 },
     "equipment": [ ... ],
     "openIssues": [ { "id": "...", "title": "...", "status": "...", "urgency": "..." } ] }
   ```
   `pmOverdue` = même logique que le dashboard (alerte PM `due`). `openIssues` = statuts `{Reported, Acknowledged, Assigned, In Progress, Waiting Materials, Redirected}`.

### Flutter
4. **Modèle `Equipment`** (`equipment.dart`) — ajouter `final int? modelId;`, `final int? brandId;`, `final String? brandName;` (+ dans le constructeur, `fromApiJson` et `copyWith`). Parsing tolérant int/String comme l'existant pour `subcategoryId` (~281).
5. **`DetailInfoRow`** (`equipment_detail_helpers.dart:100`) — ajouter un paramètre optionnel `final VoidCallback? onTap;`. Si non null : envelopper la **valeur** dans un `InkWell`, couleur `AppColors.primary` + `TextDecoration.underline` (copier le style de `_replacementLink`). Si null : comportement actuel inchangé. **Garde-fou** : ne jamais passer `onTap` quand l'id cible est `null`.
6. **`equipment_info_tab.dart`** — `EquipmentInfoTab` doit recevoir un flag `final bool linksEnabled;` (true seulement en vue complète) et des callbacks de navigation (ou un objet `EquipmentLinkHandlers`) fournis par `EquipmentDetailScreen`. Brancher `onTap` sur les lignes Catégorie, Sous-catégorie, Fabricant, Modèle, Département **uniquement si** `linksEnabled && idCible != null`.
7. **Navigation** (depuis `EquipmentDetailScreen`, `MaterialPageRoute`) :
   - Sous-catégorie → `SubcategoryDetailScreen(subcategoryId: eq.subcategoryId!, subcategoryName: eq.subcategoryName!, isBiomedical: eq.macroCategory == 'Biomedical')`.
   - Fabricant → `BrandDetailScreen(brandId: eq.brandId!, brandName: eq.brandName!, subcategoryId: eq.subcategoryId!, subcategoryName: eq.subcategoryName!)`.
   - Modèle → `ModelDetailScreen(modelId: eq.modelId!, modelName: eq.model!, brandName: eq.brandName ?? '', subcategoryId: eq.subcategoryId!, subcategoryName: eq.subcategoryName!)`.
   - Catégorie → `CategoryDetailScreen(categoryName: eq.category)` (À CRÉER).
   - Département → `DepartmentDetailScreen(departmentId: <id résolu>, departmentName: eq.department)` (À CRÉER). L'id département se résout via `getDepartments()` (nom→id) côté client, ou via le nouvel endpoint si tu l'acceptes par nom.
8. **`DbApiService`** — ajouter `Future<Map<String,dynamic>> getCategoryDetail(String name)` et `Future<Map<String,dynamic>> getDepartmentDetail(int id)`. Utiliser `ApiClient` exclusivement.
9. **`CategoryDetailScreen` (À CRÉER)** — calquée sur `SubcategoryDetailScreen` : liste équipements (chaque tuile → `EquipmentDetailScreen`) + liste fabricants/modèles présents. Pas de section durée de vie/remplacement.
10. **`DepartmentDetailScreen` (À CRÉER)** — dashboard : rangée de StatCards (réutiliser le widget `StatCard` existant) pour les 5 KPIs, puis liste équipements + liste incidents ouverts. Responsive (<600 empilé / ≥800 en colonnes), couleurs `AppColors`.
11. **`DetailBreadcrumb` (À CRÉER, `flutter-app/lib/widgets/detail_breadcrumb.dart`)** — widget générique :
    ```dart
    class BreadcrumbSegment { final String label; final VoidCallback? onTap; ... }
    class DetailBreadcrumb extends StatelessWidget { final List<BreadcrumbSegment> segments; ... }
    ```
    Rendu : segments séparés par `›`, segment avec `onTap` en `AppColors.primary` cliquable, dernier segment (page courante) en texte simple non cliquable. Placé en tête du `body` de **chaque** fiche de détail (équipement, sous-catégorie, fabricant, modèle, catégorie, département).
    **Construction des segments** : chaque écran construit son breadcrumb à partir des données qu'il possède déjà ; **si un parent n'est pas connu** (id `null`), ce segment est **omis** (jamais de segment vide ni de crash). Exemple fiche équipement complète : `[Département(onTap), Sous-catégorie(onTap), Équipement(courant, sans onTap)]`.

### i18n
12. Ajouter les clés FR (`app_fr.arb`, template) puis EN (`app_en.arb`) : titres `CategoryDetailScreen`/`DepartmentDetailScreen`, labels KPI département, libellés breadcrumb génériques si besoin. Exécuter `flutter gen-l10n`. Réutiliser les clés existantes (`commonCategory`, `commonDepartment`, `subcategoryLabel`, KPIs dashboard) quand elles existent.

## Contraintes et garde-fous (« ne pas faire »)
- **Lecture seule** : aucune mutation → **pas de `logAction`** dans cette feature.
- **IDs hétérogènes** : `equipment.id` = slug TEXT ; sous-catégorie/fabricant/modèle/département = int ; ne jamais supposer `equipment.id` numérique.
- **Ne jamais** rendre une ligne cliquable si l'id cible est `null` (fabricant/modèle absents sur équipements non catalogués) → garde explicite.
- **Breadcrumb** : un segment sans id parent connu est **omis**, jamais affiché désactivé/vide.
- **Vue staff inchangée** : `linksEnabled = false`, aucun breadcrumb cliquable révélant la gestion.
- HTTP **uniquement** via `ApiClient` ; navigation sous-écrans **uniquement** `MaterialPageRoute`.
- Couleurs **uniquement** `AppColors` ; pas de `print` ; commentaires en français.
- Ne pas casser les champs existants renvoyés par `GET /api/equipment/:id`.

## Étapes attendues (proposer le plan avant de coder)
0. **Avant tout code** : lire les fichiers cités, puis proposer un court plan (ordre, choix endpoint catégorie par-nom vs par-id, résolution id département) et **valider les 2 nouveaux écrans + 2 endpoints** (changement d'architecture → « proposer avant d'agir »).
1. Backend : enrichir `GET /api/equipment/:id` (+ test Jest), créer endpoint catégorie, étendre/créer endpoint département.
2. Flutter : enrichir `Equipment` + parsing.
3. Rendre `DetailInfoRow` cliquable (onTap optionnel) + brancher dans `equipment_info_tab.dart` avec `linksEnabled`.
4. Créer `CategoryDetailScreen`, `DepartmentDetailScreen`, `DetailBreadcrumb` + méthodes `DbApiService`.
5. Appliquer `DetailBreadcrumb` sur les 6 fiches.
6. i18n FR+EN + `flutter gen-l10n`.

## Critères de succès / vérification
- `cd db-service && npm test` passe ; `flutter analyze --no-fatal-infos` passe (depuis `flutter-app/`).
- **Test Jest** ajouté : `GET /api/equipment/:id` renvoie bien `model_id/brand_id/brand_name/subcategory_id/subcategory_name` (avec et sans rattachement → `null`).
- **Scénarios manuels** :
  - Vue complète : clic Sous-catégorie → `SubcategoryDetailScreen` correcte ; clic Fabricant → `BrandDetailScreen` ; clic Modèle → `ModelDetailScreen` ; clic Catégorie → `CategoryDetailScreen` (équipements + fabricants) ; clic Département → `DepartmentDetailScreen` (KPIs + listes).
  - Équipement non catalogué (fabricant/modèle `null`) : lignes **non cliquables**, pas de crash.
  - Vue staff (`hospitalStaff`) : aucune métadonnée cliquable.
  - Breadcrumb présent et cliquable sur les 6 fiches ; segments parents manquants omis.
- `python -X utf8 scripts/log_feature.py --nom "Métadonnées cliquables fiche équipement" --desc "Drill-down depuis la fiche équipement vers sous-catégorie/fabricant/modèle/catégorie/département + breadcrumb cliquable sur toutes les fiches de détail (vue complète)"`
- Ligne visible dans `verification/suivi_verifications.xlsx`.
- **Mettre à jour `contexte/context.md`** : nouveaux endpoints (détail catégorie, dashboard département, champs ajoutés à equipment :id) + nouveaux écrans (`CategoryDetailScreen`, `DepartmentDetailScreen`) avec incrément du compteur d'écrans.

## Étape finale obligatoire
Une fois la feature implémentée et vérifiée, lancer **`/simplify`** sur le code créé/modifié (réutilisation, simplification, efficacité, altitude) avant de clore la tâche.
