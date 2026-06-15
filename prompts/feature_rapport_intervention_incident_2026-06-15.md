# Prompt — Rapport d'intervention éditable par incident résolu

> **Projet** : GMAO Hôpital de Kabutare — Module 1
> **Date** : 2026-06-15
> **Score qualité du prompt** : 99/100 (Excellent)
> **Usage** : coller tel quel dans une nouvelle session Claude Code pour implémenter la feature.

---

# Tâche : Rapport d'intervention éditable par incident résolu

## Contexte projet
GMAO Hôpital de District de Kabutare — stack **Flutter** (web prioritaire + APK) + **Node.js
Express** + **SQLite better-sqlite3** (synchrone, WAL, `foreign_keys = ON`) + **Keycloak**
(JWT RS256). Toutes les conventions sont dans `CLAUDE.md` — les respecter strictement.

Rappels critiques applicables à cette feature :
- `equipment.id` = slug TEXT (`a-z0-9_-`, max 100) — jamais un entier.
- `user_id` = UUID Keycloak TEXT — jamais un entier.
- Migrations DB **inline et idempotentes** dans `db-service/src/database.js` via
  `PRAGMA table_info` / `CREATE TABLE IF NOT EXISTS` — exécutées au démarrage.
- Accès DB **synchrones** : `db.prepare(...).run/get/all` — pas d'`async` autour.
- Toute mutation backend → `logAction(...)` (audit trail obligatoire).
- RBAC = `verifyToken` + `requireRole(...)`. Codes HTTP : 400/401/403/404/409/500 (voir CLAUDE.md).
- Flutter : HTTP **uniquement** via `ApiClient.{get,post,put,patch,delete}` (jamais `http.X`),
  état partagé via Singleton `ChangeNotifier` consommé par `ListenableBuilder`, couleurs via
  `AppColors` (pas de `Color(0xFF…)` inline), URLs via `--dart-define` (jamais hardcodées).
- i18n **obligatoire FR+EN** : clé dans `lib/l10n/app_fr.arb` (template) PUIS `app_en.arb`,
  puis `flutter gen-l10n`. Oublier `app_en.arb` casse `flutter analyze` (bloquant CI).

Fichiers réels concernés (à lire avant d'écrire) :
- `db-service/src/database.js:49` — table `issues` (schéma) et emplacement des migrations.
- `db-service/src/database.js:756` — table `equipment_documents` (modèle à imiter).
- `db-service/src/routes/issues.js:79` — `GET /api/issues/:id` enrichi (equipment, audit_log, maintenance_records).
- `db-service/src/routes/issues.js:253` — `PUT /api/issues/:id` (statuts, diagnosis/actions/parts_replaced) : y ajouter les routes du rapport.
- `db-service/src/routes/documents.js:40` — `POST /api/equipment/:id/documents` (multipart, document_type) : route d'upload à RÉUTILISER pour l'archivage.
- `db-service/src/index.js:60` — mount `/api/issues` ; `:71` — mount documents sur `/api/equipment`.
- `db-service/src/utils/roles.js` — `TECH_ROLES`, `rolesCsv`.
- `flutter-app/lib/screens/issue_detail_screen.dart:26` — écran cible (vue technicien/privilégié) ; getter `_isPrivileged` à `:57`.
- `flutter-app/lib/screens/issue_staff_detail_screen.dart` — vue staff (consultation rapport finalisé).
- `flutter-app/lib/services/pdf_report_service.dart:27` — `PdfReportService.generate` (FEAT-036, PDF 100% client, `pdf`+`printing`) à étendre.
- `flutter-app/lib/services/db_api_service.dart` — y ajouter les appels API.
- `flutter-app/lib/screens/reports_screen.dart:99` (`_computeMttr`) et `:711` — branchement KPI MTTR/coût.

## Objectif
Permettre, pour chaque incident, de construire **tout au long de l'intervention** un rapport
structuré qui résume ce qui a été réalisé sur l'équipement (diagnostic, actions, pièces, temps,
cause racine, recommandations), puis de l'**exporter en PDF** et de l'**archiver automatiquement
dans l'historique de l'équipement** à la clôture. But métier : tracer la maintenance, alimenter
les KPIs GMAO (MTTR réel, coût de maintenance) et constituer la mémoire technique de chaque équipement.

## Périmètre
- Dans le scope :
  - Table 1:1 `issues` ↔ `issue_intervention_reports`.
  - Rapport éditable **dès la prise en charge** (incident `In Progress`) par le technicien
    assigné + supervisor/admin ; **figé** (lecture seule) à la clôture (`Closed`/`Verified`) ;
    **réouverture admin uniquement**.
  - Champs rapport : `summary`, `root_cause`, `recommendations`, `duration_hours`,
    `returned_to_service_at`, `estimated_cost`, `final_equipment_status`, auteur + validateur,
    `report_status` (`draft`/`finalized`).
  - Pré-remplissage depuis l'incident (`diagnosis`, `actions`, `parts_replaced`) **sans dupliquer
    ces colonnes** : le rapport les lit en live depuis `issues`.
  - Export PDF client + archivage auto dans `equipment_documents` (`document_type='intervention'`).
  - Branchement KPI : `duration_hours` → MTTR de réparation réel ; `estimated_cost` → coût de maintenance.
  - i18n FR+EN complète.
- Hors scope :
  - Modèles/templates de rapport configurables par l'admin.
  - Signature électronique cryptographique (un nom + horodatage suffit).
  - Incidents liés à un **lieu** (`location_id`) sans équipement : le rapport est éditable et
    exportable, mais **PAS archivé** dans `equipment_documents` (aucun équipement cible).

## Spécification détaillée

### 1) DB — `db-service/src/database.js` (migration idempotente)
Ajouter, près des autres `CREATE TABLE IF NOT EXISTS` :

```sql
CREATE TABLE IF NOT EXISTS issue_intervention_reports (
  id                      INTEGER PRIMARY KEY AUTOINCREMENT,
  issue_id                TEXT    NOT NULL UNIQUE REFERENCES issues(id) ON DELETE CASCADE,
  summary                 TEXT,
  root_cause              TEXT,
  recommendations         TEXT,
  duration_hours          REAL,
  returned_to_service_at  TEXT,
  estimated_cost          REAL,
  final_equipment_status  TEXT,        -- whitelist = enum equipment.status
  author_id               TEXT,
  author_name             TEXT,
  validated_by_id         TEXT,
  validated_by_name       TEXT,
  validated_at            TEXT,
  report_status           TEXT NOT NULL DEFAULT 'draft',  -- 'draft' | 'finalized'
  created_at              TEXT DEFAULT (datetime('now','localtime')),
  updated_at              TEXT DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_intervention_reports_issue
  ON issue_intervention_reports(issue_id);
```

Ne JAMAIS DROP/recréer la table `issues`. Vérifier l'inclusion du dossier dans le Dockerfile
n'est pas nécessaire (fichier existant).

### 2) Backend — `db-service/src/routes/issues.js`
Constantes en tête du fichier :
- `const REPORT_STATUSES = ['draft', 'finalized'];`
- Réutiliser/relire la whitelist des statuts équipement (`equipment.status`) :
  `Operational`, `Maintenance`, `Out of service`, `To be disposal`, `Disposed` pour valider
  `final_equipment_status`.

Routes (toutes : 404 si incident introuvable ; validation explicite → 400) :

1. `GET /api/issues/:id/report` (`verifyToken`)
   - Retourne le rapport s'il existe, sinon un brouillon vide
     `{ issue_id, report_status: 'draft' }`.
   - Joindre les champs de pré-remplissage **live** depuis l'issue : `diagnosis`, `actions`,
     `parts_replaced`, `equipment_id`, `equipment_name`.

2. `PUT /api/issues/:id/report` (`verifyToken, requireRole('admin','supervisor', ...TECH_ROLES)`)
   - UPSERT : `INSERT INTO issue_intervention_reports (...) VALUES (...)
     ON CONFLICT(issue_id) DO UPDATE SET ... , updated_at = datetime('now','localtime')`.
   - Refuser **409** si `report_status='finalized'` SAUF si l'appelant est `admin`.
   - Renseigner `author_id`/`author_name` (depuis `req.user`) au premier enregistrement.
   - Valider `final_equipment_status` contre la whitelist (400 sinon).
   - `logAction({ action: 'update_intervention_report', target_type: 'issue', target_id: :id, ... })`.

3. `POST /api/issues/:id/report/finalize` (`verifyToken, requireRole('admin','supervisor', ...TECH_ROLES)`)
   - Exiger que `issues.status ∈ {Completed, Verified, Closed}` (sinon **409**).
   - `report_status='finalized'`, renseigner `validated_by_id/name` + `validated_at`.
   - `logAction({ action: 'finalize_intervention_report', ... })`.

4. `PATCH /api/issues/:id/report/reopen` (`verifyToken, requireRole('admin')`)
   - `report_status='draft'`. `logAction({ action: 'reopen_intervention_report', ... })`.

Exemple de payload `PUT` attendu :
```json
{
  "summary": "Remplacement de la sonde défectueuse et recalibration.",
  "root_cause": "Usure normale de la sonde (durée de vie dépassée).",
  "recommendations": "Prévoir une sonde de rechange en stock.",
  "duration_hours": 2.5,
  "returned_to_service_at": "2026-06-15",
  "estimated_cost": 45000,
  "final_equipment_status": "Operational"
}
```

### 3) Flutter
- `models/issue_intervention_report.dart` : modèle **immuable** (`const`, `final`) avec
  `factory IssueInterventionReport.fromApiJson(...)` et `copyWith(...)` — pattern CLAUDE.md.
  Gérer `report_status` et `final_equipment_status` de façon enum-safe (défaut sûr).
- `services/db_api_service.dart` : `getInterventionReport`, `saveInterventionReport`,
  `finalizeInterventionReport`, `reopenInterventionReport` — via `ApiClient` uniquement.
- `screens/issue_detail_screen.dart` : section « Rapport d'intervention » :
  - Formulaire éditable (tous les champs) visible si incident pris en charge ET
    (technicien assigné OU `_isPrivileged`, getter `:57`).
  - Lecture seule si `report_status='finalized'` ; si admin → bouton « Rouvrir ».
  - Bouton « Finaliser » (actif si incident résolu), bouton « Exporter PDF ».
  - Champs pré-remplis (lecture) : diagnostic/actions/pièces tirés de l'incident.
- `screens/issue_staff_detail_screen.dart` : affichage **lecture seule** du rapport finalisé.
- `services/pdf_report_service.dart` : nouvelle méthode
  `static Future<Uint8List> generateInterventionReport({...})` au même style visuel que
  `generate()` (palette `_primary`/`_success`…, en-tête hôpital). Sections : identité incident +
  équipement, diagnostic/actions/pièces, champs rapport (résumé, cause racine, recommandations,
  durée, coût, état final), bloc signatures (auteur + validateur + dates).
- Archivage automatique à la finalisation : générer le PDF puis l'uploader via
  `POST /api/equipment/:equipmentId/documents` (multipart, `document_type='intervention'`,
  `original_name = "rapport_intervention_<issueId>.pdf"`). **Ne pas archiver** si l'incident
  n'a pas d'`equipment_id`.

### 4) KPIs GMAO — `screens/reports_screen.dart`
- `_computeMttr` (`:99`) : lorsqu'un rapport finalisé existe avec `duration_hours`, utiliser
  cette valeur comme **temps de réparation réel** ; conserver le fallback `created_at → taken_at`
  pour les incidents sans rapport. Documenter le changement en commentaire FR.
- Ajouter un KPI **coût de maintenance** (somme des `estimated_cost` des rapports de la période)
  affiché dans le tableau de bord rapports et exporté dans le CSV/PDF (`:711`).

### 5) i18n
Ajouter toutes les nouvelles chaînes UI dans `lib/l10n/app_fr.arb` (template) PUIS
`lib/l10n/app_en.arb`, puis exécuter `flutter gen-l10n`.

## Contraintes et garde-fous (« ne pas faire »)
- NE PAS dupliquer `diagnosis`/`actions`/`parts_replaced` dans le rapport — les lire depuis `issues`.
- NE PAS DROP ni recréer la table `issues` ; migration purement additive et idempotente.
- NE PAS autoriser l'édition d'un rapport `finalized` sauf rôle `admin`.
- NE PAS archiver de PDF pour un incident sans `equipment_id`.
- NE PAS faire d'appel `http.X` direct côté Flutter ni de couleur/URL en dur.
- NE PAS oublier `app_en.arb` (sinon `flutter analyze` casse en CI).
- Audit `logAction` sur CHAQUE mutation (update/finalize/reopen). Pas de secret en dur.

## Étapes attendues
1. **Proposer** d'abord le schéma de la table + la liste des endpoints + l'emplacement UI,
   et attendre validation (changement d'architecture — règle CLAUDE.md).
2. Migration DB idempotente.
3. Routes backend + validation + audit + **tests Jest** (`db-service`, DB `:memory:`,
   mock `express-rate-limit`).
4. Modèle Dart + méthodes `DbApiService`.
5. UI éditable + RBAC + gel/réouverture dans `issue_detail_screen` (+ lecture staff).
6. `PdfReportService.generateInterventionReport` + bouton export.
7. Archivage auto dans `equipment_documents` à la finalisation.
8. Branchement KPI MTTR + coût dans `reports_screen.dart`.
9. i18n FR+EN + `flutter gen-l10n`.

## Critères de succès / vérification
- `cd db-service && npm test` → les nouveaux tests (GET/PUT/finalize/reopen, RBAC, 409 sur
  rapport finalisé, validation `final_equipment_status`) passent.
- `cd flutter-app && flutter analyze --no-fatal-infos` passe.
- Vérification manuelle : rapport éditable en cours d'intervention, figé à la clôture,
  PDF généré et visible dans la fiche équipement (`equipment_documents` type `intervention`).
- `python -X utf8 scripts/log_feature.py --nom "Rapport d'intervention par incident" --desc "Rapport structuré éditable 1:1 par incident (résumé, cause racine, recommandations, durée, coût, état final, signatures), figé à la clôture, export PDF + archivage auto dans l'historique équipement, branché MTTR/coût"`
- Mise à jour `contexte.md` (nouvelle table `issue_intervention_reports`) + `contexte/context.md`
  (endpoints `/api/issues/:id/report*` + écran incident).

## Étape finale obligatoire
Une fois la feature implémentée et vérifiée, lancer `/simplify` sur le code créé/modifié
pour nettoyer (réutilisation, simplification, efficacité, altitude) avant de clore la tâche.
