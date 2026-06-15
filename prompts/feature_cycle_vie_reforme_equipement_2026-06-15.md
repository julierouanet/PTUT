# Prompt Claude Code — Cycle de vie & Réforme des équipements (soft delete / décommissionnement)

> **Date** : 2026-06-15
> **Score qualité du prompt** : 92/100 (Excellent)
> **À coller dans une nouvelle session Claude Code à la racine du projet PTUT.**

---

# Tâche : Cycle de vie des équipements — réforme (soft delete) vs suppression (hard delete)

## Contexte projet

Stack : Flutter (web + APK) / Node.js Express / SQLite **better-sqlite3** (synchrone, WAL, `foreign_keys=ON`) / Keycloak (JWT RS256 JWKS). Conventions dans `CLAUDE.md` (CommonJS, camelCase JS / snake_case SQL, migrations idempotentes inline via `PRAGMA table_info`, `logAction` obligatoire sur toute mutation, RBAC `verifyToken`+`requireRole`, i18n FR+EN, `ApiClient` only, pas de secret en dur, couleurs `AppColors`).

Fichiers concernés (réels, vérifiés) :
- DB : `db-service/src/database.js:18` (table `equipment`), `db-service/src/database.js:548` (exemple de migration `ALTER TABLE` idempotente à imiter), `db-service/src/database.js:33` (`maintenance_records` a `ON DELETE CASCADE`), `db-service/src/database.js:49` (`issues.equipment_id` est TEXT **sans FK** → à vérifier manuellement).
- Backend : `db-service/src/routes/equipment.js:11` (`VALID_STATUSES_EQ`), `db-service/src/routes/equipment.js:40` (GET liste + filtres), `db-service/src/routes/equipment.js:294` (PUT update), `db-service/src/routes/equipment.js:383` (DELETE hard delete actuel), `db-service/src/routes/equipment.js:88` (GET replacement-plan — pattern d'endpoint à imiter).
- Flutter : `flutter-app/lib/models/equipment.dart:1` (enum `EquipmentStatus`) et `:123` (modèle `Equipment`), `flutter-app/lib/services/db_api_service.dart:68` (`deleteEquipment`), `flutter-app/lib/screens/equipment_list_screen.dart`, `flutter-app/lib/screens/equipment_form_screen.dart`, `flutter-app/lib/l10n/app_fr.arb` + `app_en.arb`.

## Objectif

Aligner le cycle de vie des équipements sur les standards GMAO (Maximo `DECOMMISSIONED`, garde-fou de suppression Fiix) : distinguer la **suppression définitive** (réservée aux erreurs de saisie, équipement « vierge ») de la **réforme / décommissionnement** (fin de vie réelle : cassé, obsolète, remplacé, perdu). Un équipement réformé n'est jamais effacé — il passe `Disposed`, sort des listes actives mais conserve tout son historique (incidents, maintenances) pour l'audit d'accréditation, et peut pointer son remplaçant.

## Périmètre

**Dans le scope :**
- Soft delete = réforme via statut `Disposed` enrichi de métadonnées.
- Workflow d'approbation : proposition (technicien/superviseur → `To be disposal`) puis validation (admin → `Disposed`).
- Garde-fou sur le hard delete (409 si historique, override admin `?force=true`).
- Lien bidirectionnel « remplacé par / remplace » (simple, **sans** transfert automatique d'historique).
- Filtre des équipements réformés hors des listes actives par défaut.

**Hors scope :**
- Transfert/réaffectation automatique des incidents vers le remplaçant (option « swap avancé » écartée).
- Module 2 (déchets biomédicaux) : la whitelist `disposal_method` doit rester extensible (`recycled` futur) mais ne pas l'implémenter maintenant.
- Aucune modification du calcul `replacement-plan` existant.

## Spécification détaillée

### 1. DB — `db-service/src/database.js`

Ajouter 7 colonnes à `equipment`, **en migrations idempotentes** sur le modèle de `database.js:548` (`try { db.exec("ALTER TABLE equipment ADD COLUMN ...") } catch (_) {}`), pas dans le `CREATE TABLE` initial (les déploiements existants ne le rejouent pas) :

| Colonne | Type | Rôle |
|---|---|---|
| `decommissioned_at` | TEXT | Date/heure ISO de la réforme (NULL si actif) |
| `decommission_reason` | TEXT | Motif (whitelist, voir backend) |
| `disposal_method` | TEXT | Méthode d'élimination (whitelist) |
| `decommissioned_by_id` | TEXT | UUID Keycloak de l'agent |
| `decommissioned_by_name` | TEXT | Nom de l'agent |
| `decommission_notes` | TEXT | Texte libre optionnel |
| `replaced_by_id` | TEXT | FK → `equipment(id)`, NULL si non remplacé |

> Ne pas créer de contrainte FK SQL sur `replaced_by_id` via ALTER (impossible en SQLite) ; valider l'existence côté Node avant écriture.

### 2. Backend — `db-service/src/routes/equipment.js`

**Whitelists** (en tête, à côté de `VALID_STATUSES_EQ`) :
```js
const DECOMMISSION_REASONS = ['irreparable', 'obsolete', 'replaced', 'lost', 'donated_out'];
const DISPOSAL_METHODS     = ['destroyed', 'sold', 'donated', 'returned', 'cannibalized'];
```

**a) `POST /:id/propose-disposal`** — `verifyToken`, `requireRole('admin','supervisor', ...TECH_ROLES)` :
- Body : `{ decommission_reason }` (doit ∈ `DECOMMISSION_REASONS`).
- Effet : `status='To be disposal'`, stocke `decommission_reason` (pré-rempli, modifiable à la validation). Refuse `400` si déjà `Disposed`.
- `logAction` action `propose_disposal_equipment`.

**b) `POST /:id/decommission`** — `verifyToken`, `requireRole('admin')` (validation finale) :
- Body : `{ decommission_reason, disposal_method, decommission_notes?, replaced_by_id? }`.
- Validations : `decommission_reason ∈ DECOMMISSION_REASONS` (400 sinon) ; `disposal_method ∈ DISPOSAL_METHODS` (400 sinon) ; si `replaced_by_id` fourni → l'équipement cible doit exister (404 sinon) et ≠ `:id` (400 sinon). Si `decommission_reason === 'replaced'`, `replaced_by_id` est **requis** (400 sinon).
- Effet (soft delete) : `status='Disposed'`, `decommissioned_at=datetime('now','localtime')`, remplit `decommissioned_by_id/name` depuis `req.user`, `decommission_reason/method/notes`, `replaced_by_id`.
- `logAction` action `decommission_equipment` avec `details` = snapshot des champs de réforme.

**c) `DELETE /:id`** (modifier l'existant `equipment.js:383`) — garde Fiix :
- Compter l'historique lié : `issues` (WHERE `equipment_id=?`), `maintenance_records`, `equipment_tags`, `equipment_documents WHERE deleted_at IS NULL`.
- Si **au moins un** existe **et** `req.query.force !== 'true'` → `409 { error: "Équipement avec historique : réformer au lieu de supprimer", hasHistory: true }`.
- Si `force === 'true'` (admin uniquement, déjà `requireRole('admin')`) → autoriser la purge : supprimer d'abord les `issues`/`equipment_tags`/`equipment_documents` liés (les `maintenance_records` partent en CASCADE), puis l'équipement. Conserver le `logAction` snapshot existant en ajoutant `forced: true` dans `details`.
- Sinon (équipement vierge) → comportement actuel inchangé.

**d) GET liste `equipment.js:40`** : exclure `status='Disposed'` par défaut ; n'inclure que si `req.query.include_disposed === 'true'`. Ajouter au SELECT les nouvelles colonnes + un JOIN/sous-requête pour le nom du remplaçant (`replaced_by_name`) et l'éventuel équipement « remplace » (inverse).

### 3. Flutter

**`models/equipment.dart`** :
- Ajouter au modèle : `decommissionedAt`, `decommissionReason`, `disposalMethod`, `decommissionedByName`, `decommissionNotes`, `replacedById`, `replacedByName` (tous `String?`), parsés dans `fromApiJson` et propagés dans `copyWith`.
- Ne pas toucher l'enum `EquipmentStatus` (les 5 valeurs existent déjà).

**`services/db_api_service.dart`** (à côté de `deleteEquipment:68`) :
- `Future<void> proposeDisposal(String id, String reason)` → `ApiClient.post('/api/equipment/$id/propose-disposal', ...)`.
- `Future<void> decommissionEquipment(String id, {required String reason, required String method, String? notes, String? replacedById})`.
- `deleteEquipment` : ajouter param `bool force` → `?force=true` (en plus du `reason` existant). Gérer le 409 `hasHistory` pour déclencher l'UI de réforme.

**UI** (écran détail/liste équipement) :
- Bouton « Réformer / Mettre au rebut » → dialog (responsive `<800` bottom-sheet / `≥800` dialog, cf. `issue_category_selector`) : dropdown motif, dropdown méthode, sélecteur d'équipement remplaçant (visible si motif=`replaced`), champ notes.
- Sur la fiche : badge « Réformé » + bloc « Remplacé par → [neuf] » (et sur le neuf « Remplace → [ancien] »), cliquables.
- Le bouton « Supprimer » : si l'API renvoie 409 `hasHistory`, afficher un dialog expliquant qu'il faut réformer ; le hard delete forcé (`force:true`) n'est proposé qu'au rôle `admin` avec confirmation explicite « ceci détruit aussi tout l'historique ».
- Liste : ne pas afficher les réformés sauf filtre explicite « Afficher les équipements réformés ».

### 4. i18n

Toute chaîne nouvelle dans `app_fr.arb` (template) **et** `app_en.arb`, puis `flutter gen-l10n`. Couvrir : libellés des 5 motifs, des 5 méthodes, titres dialog, badge « Réformé », « Remplacé par » / « Remplace », message 409, confirmation purge.

## Contraintes et garde-fous

- **Migrations idempotentes** : `ALTER TABLE ... ADD COLUMN` dans un `try/catch`, jamais dans le `CREATE TABLE` initial (piège `CLAUDE.md` : supprimer/modifier une colonne casse les déploiements).
- **`equipment.id` = slug TEXT** ; **`user_id` = UUID Keycloak TEXT** — jamais d'entier.
- **`logAction` obligatoire** sur `propose_disposal_equipment`, `decommission_equipment`, et `delete_equipment` (déjà présent).
- **RBAC strict** : proposition = tech/superviseur/admin ; réforme + hard delete = `admin` only.
- **Whitelists serveur** : rejeter toute valeur hors liste en `400` (comme `criticality`).
- **`ApiClient` only** côté Flutter (jamais `http.X`), **`AppColors`** (pas de `Color(0xFF…)`).
- **Ne pas** : transférer l'historique vers le remplaçant, modifier `replacement-plan`, ajouter `recycled`, créer une vraie FK SQL via ALTER.
- **Proposer avant d'agir** : le changement de schéma `equipment` + le nouveau workflow de statuts sont structurants → exposer le plan avant de coder.

## Étapes attendues

1. **Plan d'abord** : présenter la liste des fichiers touchés et l'ordre d'exécution, valider l'approche schéma + endpoints avant tout code.
2. DB : ajouter les 7 colonnes (migrations idempotentes).
3. Backend : whitelists + `propose-disposal` + `decommission` + garde-fou `DELETE` + filtre liste.
4. `npm test` (db-service) — ajouter des tests : réforme valide, motif/méthode invalides, `replaced` sans `replaced_by_id`, DELETE bloqué par historique (409), DELETE `force=true`, liste excluant `Disposed`.
5. Flutter : modèle → service → UI dialog + liens + filtre. `flutter analyze --no-fatal-infos`.
6. i18n FR+EN + `flutter gen-l10n`.

## Critères de succès / vérification

- `npm test` (db-service) **et** `flutter analyze --no-fatal-infos` passent.
- Un équipement réformé sort des listes mais reste accessible et garde son historique ; le lien remplaçant s'affiche dans les deux sens.
- Un équipement avec incident/maintenance ne peut **pas** être hard-deleted sans `force=true`.
- `python -X utf8 scripts/log_feature.py --nom "Réforme & cycle de vie équipements" --desc "Soft delete (décommissionnement statut Disposed enrichi : motif, méthode, remplaçant) + garde-fou hard delete (409 si historique, force admin) ; workflow proposition→validation"`
- Mise à jour doc (feature majeure : nouvelles colonnes + endpoints) : `contexte.md` (section Schémas + enums) et `contexte/context.md` (schéma `equipment` complet + endpoints `propose-disposal` / `decommission` + DELETE modifié).

## Étape finale obligatoire

Une fois la feature implémentée et vérifiée, lancer `/simplify` sur le code créé/modifié pour nettoyer (réutilisation, simplification, efficacité, altitude) avant de clore la tâche.
