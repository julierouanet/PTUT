# Prompt Claude Code — Alertes urgentes cliquables + action rapide « Prendre en charge »

> **Date** : 2026-06-19
> **Score prompt** : 92/100 (Excellent)
> **À coller dans une nouvelle session Claude Code.** La clôture (test + `log_feature.py`) fait partie du prompt.

---

# Tâche : Alertes urgentes cliquables + action rapide « Prendre en charge »

## Contexte projet
GMAO Kabutare — front **Flutter**. Conventions `CLAUDE.md` : navigation sous-écran via `Navigator.push(MaterialPageRoute)` (jamais `pushNamed`/`ScreenType` ici) ; couleurs depuis `AppColors` (pas de `Color(0xFF…)`) ; **aucune chaîne UI en dur** (réutiliser les clés ARB existantes — aucune nouvelle clé requise) ; HTTP via `ApiClient`/services (`DbApiService`), jamais `http` direct ; pas de `print` ; `flutter analyze --no-fatal-infos` est **bloquant**. Lire chaque fichier avant de l'éditer ; ne jamais tronquer un fichier.

Fichiers et points d'ancrage (réels, vérifiés) :
- `flutter-app/lib/widgets/alert_card.dart` — `AlertCard` expose déjà `onTap` (ligne 12) via `InkWell` (ligne 57). Non câblé côté dashboard.
- `flutter-app/lib/screens/dashboard_screen.dart:937-946` — `_buildUrgentAlerts` crée les `AlertCard` **sans `onTap`**.
- `flutter-app/lib/screens/dashboard_screen.dart:847-904` — `_buildPriorityIssues` / `_buildIssueRow` (panneau incidents prioritaires ; `trailing` = `IssueStatusBadge`).
- `flutter-app/lib/widgets/equipment/equipment_critical_banner.dart:22` — `Container` rouge **sans `onTap`/`InkWell`**.
- `flutter-app/lib/screens/equipment_detail_screen.dart:271` (`DefaultTabController length:4`) et `:331` (insertion de `EquipmentCriticalBanner`). Onglets : Infos=0, Maintenance=1, **Incidents=2**, Documents=3 (`:336-361`).
- Cibles de navigation existantes : `EquipmentDetailScreen(equipmentId:)` (utilisé `equipment_detail_screen.dart:455`) ; `IssueDetailScreen(issueId:)` (modèle `department_detail_screen.dart:204`).
- Pattern de prise en charge à répliquer : `_takeOverIssue` (`technician_update_screen.dart:1655-1687`) → `DbApiService.instance.updateIssue(id, {'status':'In Progress','assigned_technician': <nom>, 'taken_at': <ISO8601>})` puis `DataService().reloadIssues()` + `NotificationService().generateFromLoadedData()` + snackbar.
- Éligibilité technicien : `_myAssignableGroups` (`technician_update_screen.dart:101-108`) et filtre `_availableIssues` (`:110-122`).
- Nom technicien : `AuthService().currentUser?.fullName`. Rôles : `AuthService().currentRoles` (`UserRole.technicianBiomedical/It/Infra`).
- i18n déjà présentes : `techTakeCharge` (« Prendre en charge »), `techTakeChargeTitle`, `techTakeChargeContent`, `techTakeChargeMessage`, `techTakeChargeSuccess(equipment)`, `commonConfirm`, `commonCancel`, `commonApiError`.

## Objectif
Permettre le **drill-down** depuis les alertes urgentes (aujourd'hui inertes) et offrir au **technicien** une **action rapide « Prendre en charge »** directement sur les incidents prioritaires du dashboard, sans passer par l'écran technicien.

## Périmètre
- **Dans le scope** :
  1. `AlertCard` « panne critique équipement » (dashboard) → ouvre la fiche équipement.
  2. `AlertCard` « incident critique 24h » (dashboard) → ouvre le détail incident.
  3. `EquipmentCriticalBanner` (fiche) → bascule sur l'onglet Incidents.
  4. Bouton **« Prendre en charge »** sur chaque incident prioritaire **éligible** (technicien uniquement).
- **Hors scope** : autres panneaux (critiques HS, métriques), liste équipements (déjà cliquable), DB, backend, nouvel endpoint, nouvelle clé ARB.

## Distinction de droits (à respecter strictement)
- **Drill-down (1, 2, 3)** : disponible pour **tout rôle** qui voit déjà l'alerte. Aucun gating ajouté.
- **Action rapide (4)** : visible **uniquement** si `_myAssignableGroups.isNotEmpty` (donc technicien) **et** incident éligible (voir garde-fous). Jamais pour staff/admin/superviseur sans rôle technicien.

## Spécification détaillée

**1. `EquipmentCriticalBanner`** — ajouter `final VoidCallback? onTap;` au constructeur (défaut `null`, rétro-compatible). Envelopper le `Container` dans `InkWell(onTap: onTap, …)`. Si `onTap != null`, ajouter en fin de `Row` une icône `Icons.chevron_right` (blanche, size 20). Comportement et rendu inchangés si `onTap == null`.

**2. `equipment_detail_screen.dart:331`** — remplacer `EquipmentCriticalBanner(equipment: eq)` par un wrap `Builder` pour capturer un contexte **descendant** du `DefaultTabController` :
```dart
Builder(
  builder: (ctx) => EquipmentCriticalBanner(
    equipment: eq,
    onTap: () => DefaultTabController.of(ctx).animateTo(2), // onglet Incidents
  ),
),
```
> Ne **pas** utiliser le `context` de `_buildTabbedScaffold` (situé au-dessus du `DefaultTabController`) : `DefaultTabController.of` y échouerait.

**3. `dashboard_screen.dart` `_buildUrgentAlerts`** — câbler les deux `AlertCard` :
- équipement : `onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EquipmentDetailScreen(equipmentId: eq.id)))`
- incident : `onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IssueDetailScreen(issueId: issue.id)))`
Ajouter les `import` manquants (`equipment_detail_screen.dart`, `issue_detail_screen.dart`).

**4. Action rapide sur `_buildIssueRow`** — ajouter une méthode privée `_assignableGroups()` (réplique de `_myAssignableGroups`) et un prédicat `_canTakeOver(Issue i)` :
```
i.status == IssueStatus.acknowledged || i.status == IssueStatus.assigned
&& groups.isNotEmpty
&& (i.assignedGroup == null || groups.contains(i.assignedGroup))
```
Dans `_buildIssueRow`, remplacer `trailing` par un `Row(mainAxisSize: min, …)` contenant l'`IssueStatusBadge` **et**, si `_canTakeOver(issue)`, un bouton compact (`TextButton.icon`/`IconButton`, icône `Icons.handyman_outlined`, label `l10n.techTakeCharge`) qui appelle `_quickTakeOver(issue)`.
Implémenter `_quickTakeOver(Issue issue)` :
1. `showDialog` de confirmation réutilisant `techTakeChargeTitle` / `techTakeChargeContent` (+ `issue.displayName`) / `techTakeChargeMessage`, boutons `commonCancel` / `commonConfirm`.
2. À confirmation : `await DbApiService.instance.updateIssue(issue.id, {'status':'In Progress','assigned_technician': AuthService().currentUser?.fullName ?? '', 'taken_at': DateTime.now().toIso8601String()})`.
3. `await DataService().reloadIssues()` + `NotificationService().generateFromLoadedData()` + `setState`.
4. Succès → snackbar `techTakeChargeSuccess(issue.displayName)` (fond `AppColors.primary`). Échec (`catch`) → snackbar `commonApiError` (fond `AppColors.error`). Toujours vérifier `mounted` avant `ScaffoldMessenger`.

## Contraintes et garde-fous
- Réutiliser `AppColors` ; aucune couleur inline ; aucune nouvelle clé ARB.
- `updateIssue` via `DbApiService.instance` uniquement (pas de `http` direct) — le retry 401 est géré par `ApiClient`.
- **Concurrence** : si deux techniciens prennent le même incident, le backend applique le dernier write ; le `reloadIssues()` post-action reflète l'état réel ; un échec affiche le snackbar d'erreur. Ne pas tenter de verrou optimiste.
- Ne pas modifier la logique d'affichage existante (`_shouldShow`, calcul des listes `criticalEquipment`/`criticalIssues`/`issues`) — seulement ajouter interactivité et bouton.
- L'audit trail de l'assignation est déjà assuré côté backend par `PUT /api/issues/:id` (ne rien ajouter côté Flutter).
- Pas de régression `flutter analyze`.

## Étapes attendues
1. `EquipmentCriticalBanner` : param `onTap` + `InkWell` + chevron conditionnel.
2. `equipment_detail_screen.dart:331` : wrap `Builder` + `animateTo(2)`.
3. `dashboard_screen.dart` : `onTap` des deux `AlertCard` + imports.
4. `dashboard_screen.dart` : `_assignableGroups()`, `_canTakeOver`, `_quickTakeOver`, modification de `_buildIssueRow`.
5. `flutter analyze --no-fatal-infos`.

## Critères de succès / vérification
- `flutter analyze --no-fatal-infos` : **0 erreur**.
- Dashboard : clic `AlertCard` équipement → `EquipmentDetailScreen` du bon `id` ; clic `AlertCard` incident → `IssueDetailScreen` du bon `id`.
- Fiche équipement critique+HS : clic bannière → bascule visible sur l'onglet **Incidents** (pas d'exception `DefaultTabController`).
- Connecté **technicien Biomédical** : bouton « Prendre en charge » visible uniquement sur incidents `acknowledged`/`assigned` de groupe `Biomédical` (ou sans groupe) ; clic → confirmation → incident passe `In Progress` assigné à moi → disparaît des « disponibles » après reload.
- Connecté **admin/superviseur sans rôle technicien** : **aucun** bouton « Prendre en charge ».
- `python -X utf8 scripts/log_feature.py --nom "Alertes urgentes cliquables + prise en charge rapide" --desc "Drill-down des AlertCard dashboard + banniere critique vers onglet Incidents + bouton Prendre en charge technicien sur incidents prioritaires"`.
- Mise à jour doc : non requise (aucun endpoint/table/écran nouveau ; réutilise `PUT /api/issues/:id`).

## Étape finale obligatoire
Une fois implémenté et vérifié, lancer `/simplify` sur le code créé/modifié (notamment factoriser la duplication `updateIssue` de prise en charge entre `technician_update_screen.dart` et `dashboard_screen.dart` si pertinent) avant de clore la tâche.
