# Prompt Claude Code — Incidents par département (en cours & résolus) + téléchargement du rapport à la finalisation

> **Date** : 2026-06-18
> **Score prompt** : 99/100 (grille feature-to-prompt, 12 domaines)
> **À coller dans une nouvelle session Claude Code pour implémentation.**

---

# Tâche : Téléchargement du rapport à la finalisation + page détail département listant TOUS les incidents (en cours & résolus)

## Rôle
Tu es un développeur full-stack du projet GMAO de l'Hôpital de District de Kabutare
(Flutter web / Node.js Express / SQLite better-sqlite3 / Keycloak). Tu implémentes une
feature transverse « incidents » destinée aux techniciens, superviseurs et admins, dont
le but métier est : retrouver facilement un problème d'infrastructure (incident sur un
*lieu*, sans tag ni numéro de série) en partant de son département, et récupérer un
rapport d'intervention dès qu'il est figé.

## Contexte projet
Conventions CLAUDE.md à respecter STRICTEMENT :
- Code complet, jamais tronqué. Lire le fichier (`Read`) avant tout `Edit`.
- Commentaires inline en français. Réponses en français.
- Backend : CommonJS, better-sqlite3 **synchrone**, `db.prepare(...).all/get/run`.
  Délimiteurs de section `// ── ... ──`. Pas de migration framework.
- Flutter : HTTP via `ApiClient`/`DbApiService` uniquement (jamais `http.X`). Couleurs
  via `AppColors`. Sous-écran via `Navigator.push(MaterialPageRoute(...))`. Pas de `print`.
- i18n : toute chaîne UI → clé dans `lib/l10n/app_fr.arb` (template) **ET**
  `lib/l10n/app_en.arb`, puis `flutter gen-l10n`. Oublier `app_en.arb` casse `flutter analyze` (bloquant CI).
- Proposer avant d'agir sur tout changement d'architecture (ici : aucun — voir Hors scope).

Fichiers concernés (vérifiés) :
- `db-service/src/routes/departments.js:48` — `GET /:id/detail` (KPIs à :62, requête `openIssues` à :85, réponse à :93).
- `db-service/src/routes/issues.js:691` — `POST /:id/report/finalize` (déjà OK, aucune modif backend rapport).
- `flutter-app/lib/screens/department_detail_screen.dart` — état `_openIssues` (:35), `_load` (:43), KPIs `_buildKpis` (:113), section incidents (:99), `_buildIssuesList` (:143).
- `flutter-app/lib/screens/detail_screen_helpers.dart` — `detailSectionHeader`, `detailEmptyCard` (à réutiliser).
- `flutter-app/lib/widgets/issue/intervention_report_section.dart:158` — `_finalize`, et `_exportPdf` (:214) qui choisit archive (équipement) vs `Printing.layoutPdf` (interactif).
- `flutter-app/lib/services/db_api_service.dart:460` — `getDepartmentDetail(int id)` ; `finalizeInterventionReport` (:251) ; `archiveInterventionPdf` (:268).
- `flutter-app/lib/screens/issue_detail_screen.dart:27` — `IssueDetailScreen({required String issueId, ...})`, ouvert ailleurs via `Navigator.push(MaterialPageRoute(builder: (_) => IssueDetailScreen(issueId: issue.id)))` (cf. `issue_tracking_screen.dart:1052`).
- Widgets réutilisables : `StatCard(title, value, icon, color)`, `StatusBadge(status:, isCompact: true)`.

Schéma utile (`contexte/context.md`) — table `issues` : `id` TEXT, `equipment_id`/`equipment_name`
**nullable** (NULL si l'incident vise un lieu), `location_id` TEXT FK→`locations(id)`, `location_text`
TEXT, `issue_category` TEXT (`Biomedical`/`Infrastructure`/`IT`), `department` TEXT (NOT NULL, c'est
un libellé, déjà la clé de jointure des incidents dans `/detail` et `/stats`), `urgency`, `status`,
`created_at` NOT NULL, `updated_at`. Table `locations` : `id`, `name`, `building`, `department`.

## Objectif
1. Rendre un rapport d'intervention immédiatement téléchargeable au moment de sa finalisation.
2. Faire de la page détail département le point d'entrée pour retrouver **tous** les incidents
   du département (équipement ET infrastructure), **en cours** comme **résolus**, et cliquables.

## Périmètre
- **Dans le scope** :
  - Backend : enrichir UNIQUEMENT `GET /api/departments/:id/detail` (champs incident + nouvelle liste `resolvedIssues` + compteur KPI).
  - Flutter : page détail département (2 sections + KPI + tuiles enrichies cliquables) ; ouverture du dialogue PDF après finalisation du rapport.
  - i18n FR + EN.
- **Hors scope (NE PAS faire)** :
  - Aucune nouvelle table ni colonne DB. Aucun nouveau endpoint. Aucun système de « tags » d'incident.
  - Aucun changement RBAC / permission (le endpoint reste `verifyToken` seul, comme aujourd'hui).
  - Ne pas toucher la logique backend du rapport d'intervention (`issues.js`) : elle est déjà correcte.
  - Ne pas modifier les autres écrans qui consomment `getDepartmentDetail`.

## Spécification détaillée

### 1. Backend — `db-service/src/routes/departments.js` (`GET /:id/detail`)
Ensembles de statuts (exhaustifs, à respecter à la lettre) :
- **Ouverts** : `Reported`, `Acknowledged`, `Assigned`, `In Progress`, `Waiting Materials`, `Redirected`.
- **Résolus** : `Completed`, `Verified`, `Closed`.
  (`Redirected` est OUVERT, jamais résolu.)

Modifier la requête `openIssues` (et créer la requête symétrique `resolvedIssues`) pour
sélectionner, en jointure du lieu :
```sql
SELECT i.id, i.type, i.description, i.status, i.urgency, i.issue_category,
       i.equipment_name,
       COALESCE(l.name, i.location_text) AS location_name,
       i.created_at, i.updated_at
FROM issues i
LEFT JOIN locations l ON l.id = i.location_id
WHERE i.department = ?
  AND i.status IN (<ensemble correspondant>)
ORDER BY <created_at DESC pour ouverts | updated_at DESC pour résolus>
```
Ajouter au bloc `kpis` de la réponse un compteur :
`openIssuesCount` = nombre d'incidents ouverts (source unique = serveur, pas calculé côté client).
La réponse JSON devient :
```json
{
  "id": 1, "name": "Radiologie",
  "kpis": { "total": 0, "operational": 0, "maintenance": 0,
            "outOfService": 0, "pmOverdue": 0, "openIssuesCount": 0 },
  "equipment": [ ... ],
  "openIssues":     [ { "id", "type", "description", "status", "urgency",
                        "issue_category", "equipment_name", "location_name",
                        "created_at", "updated_at" } ],
  "resolvedIssues": [ { ...mêmes champs... } ]
}
```
Lecture seule : aucun `logAction` à ajouter.

### 2. Flutter — `department_detail_screen.dart`
- Ajouter l'état `_resolvedIssues` ; dans `_load`, parser `resolvedIssues` (défaut `[]`).
- **KPI** : ajouter une 6ᵉ `StatCard` « Incidents ouverts » alimentée par
  `_kpis['openIssuesCount']` (via le helper `_kpi('openIssuesCount')`), icône
  `Icons.report_problem_outlined`, couleur `AppColors.warning`. La grille `_buildKpis`
  est déjà responsive (Wrap fluide) — ne pas casser le layout.
- **Deux sections** sous les équipements, via `detailSectionHeader` :
  1. « Incidents en cours » + compteur `(${_openIssues.length})` → liste `_openIssues`, date = `created_at`.
  2. « Incidents résolus » + compteur `(${_resolvedIssues.length})` → liste `_resolvedIssues`, date = `updated_at` (date de clôture).
- **Tuile d'incident** (refondre `_buildIssuesList` en une fonction paramétrée par la liste
  et la clé de date), chaque `ListTile` :
  - `leading` : badge **catégorie** dérivé de `issue_category` (Biomedical / Infrastructure / IT)
    avec icône + couleur distincte (ex. Infrastructure = `AppColors.warning`, Biomedical = `AppColors.primary`, IT = autre teinte `AppColors`). Pas de `Color(0x..)` inline.
  - `title` : `description` (ellipsis 1 ligne).
  - `subtitle` : **cible** = `equipment_name` si non vide, sinon `location_name` si non vide,
    sinon fallback `l10n` générique (ex. « Incident de département ») — JAMAIS de chaîne vide.
    Suivi de l'urgence et de la date formatée (la clé de date dépend de la section).
  - `trailing` : `StatusBadge(status: ..., isCompact: true)`.
  - `onTap` : `Navigator.push(context, MaterialPageRoute(builder: (_) => IssueDetailScreen(issueId: i['id'] as String)))`.
    Importer `issue_detail_screen.dart`.
  - Liste vide → `detailEmptyCard(l10n....)`.

### 3. Flutter — `intervention_report_section.dart` (`_finalize`)
Comportement attendu après finalisation :
- Conserver l'archivage auto du PDF sur l'équipement quand `equipmentId` est présent
  (appel existant `_exportPdf(archive: true)`).
- **PUIS, dans tous les cas**, ouvrir le dialogue interactif de téléchargement/impression
  (`Printing.layoutPdf`) pour proposer le rapport à l'utilisateur. Réutiliser la génération
  existante (`PdfReportService.generateInterventionReport` + nom `rapport_intervention_<issueId>.pdf`).
  Factoriser pour ne pas régénérer le PDF deux fois si possible (générer une fois, archiver
  puis `layoutPdf`). Conserver la gestion d'erreur existante (SnackBar `AppColors.error`).
- Ne pas dupliquer le bouton « Exporter PDF » déjà présent dans `_actions` (:510) — il reste.

### 4. i18n
Ajouter dans `app_fr.arb` ET `app_en.arb` (puis `flutter gen-l10n`) les clés nécessaires :
sections « Incidents en cours » / « Incidents résolus », libellé KPI « Incidents ouverts »,
fallback cible « Incident de département », et au besoin les 3 libellés de catégorie si non
déjà présents. Réutiliser les clés existantes (`dashboardNoIssues`, `departmentOpenIssuesSection`,
`dashboardOperational`, etc.) quand elles conviennent plutôt que d'en créer des doublons.

## Contraintes et garde-fous (Do / Don't)
- DO : requêtes better-sqlite3 synchrones ; statuts repris **exactement** des whitelists ci-dessus.
- DO : `COALESCE(l.name, i.location_text)` pour le nom de lieu ; fallback non-vide côté UI.
- DO : KPI « Incidents ouverts » depuis `kpis.openIssuesCount` (serveur) — source unique.
- DON'T : nouvelle table/colonne/endpoint, `logAction` sur une lecture, `http.X` direct,
  `Color(0x..)` inline, `Navigator.pushNamed` global, classer `Redirected` en résolu.
- DON'T : régénérer le PDF deux fois ni casser le layout responsive des KPIs.

## Raisonnement & plan attendus
Avant de coder, exposer un court plan (5 étapes max) et confirmer qu'aucun changement
d'architecture n'est requis. Puis implémenter dans l'ordre : backend → écran département →
finalize PDF → i18n + `gen-l10n` → vérification.

## Critères de succès / vérification (mesurables)
- `GET /api/departments/:id/detail` renvoie `kpis.openIssuesCount`, `openIssues` et
  `resolvedIssues`, chaque incident portant `issue_category`, `equipment_name`,
  `location_name`, `created_at`, `updated_at`. Un incident d'infrastructure (equipment NULL,
  location renseigné) apparaît avec son `location_name`.
- `cd db-service && npm test` passe (ajouter/adapter un test couvrant `resolvedIssues` +
  `openIssuesCount` si la suite départements existe).
- `cd flutter-app && flutter analyze --no-fatal-infos` → 0 erreur (vérifier `app_en.arb` synchronisé).
- Scénario manuel : ouvrir un département → la rangée KPI montre « Incidents ouverts » ;
  deux sections « En cours » / « Résolus » avec compteurs ; une tuile d'infra montre son
  badge Infrastructure + nom de lieu ; un clic ouvre `IssueDetailScreen`.
- Scénario manuel : finaliser un rapport d'intervention → toast d'archivage (si équipement)
  PUIS dialogue de téléchargement/impression du PDF s'ouvre.
- `python -X utf8 scripts/log_feature.py --nom "Incidents par département + téléchargement rapport finalisé" --desc "Page détail département : KPI incidents ouverts, sections en cours/résolus avec badge catégorie + cible (équipement/lieu) cliquables ; dialogue de téléchargement du PDF à la finalisation du rapport d'intervention"`
- Mettre à jour `contexte/context.md` (section `GET /api/departments/:id/detail`) : ajout
  `resolvedIssues`, `kpis.openIssuesCount` et nouveaux champs incident.

## Étape finale obligatoire
Une fois la feature implémentée et vérifiée, lancer `/simplify` sur le code créé/modifié
(réutilisation, simplification, efficacité, altitude) avant de clore la tâche.
