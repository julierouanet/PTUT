# Prompt Claude Code — Refonte de la page technicien
- **Date** : 2026-06-20
- **Score final** : 100/100 (grille KPI 12 domaines)
- **À coller dans une nouvelle session Claude Code pour implémentation.**

---

# Tâche : Refonte de la page technicien — onglets réordonnés, planning en page séparée, validation déléguée au détail d'incident

## Rôle
Tu es un développeur Flutter senior intervenant sur la GMAO de l'Hôpital de Kabutare. Tu
appliques strictement `CLAUDE.md`. Avant tout changement non trivial tu expliques le « pourquoi »,
et tu proposes avant d'agir sur tout changement de navigation. Cible métier : permettre aux
admins/superviseurs de trier (valider) les incidents signalés depuis une fiche complète, et
alléger l'espace technicien.

## Contexte projet
- Stack : Flutter (Material). État partagé via **singletons `extends ChangeNotifier`**
  (`AuthService()`, `DataService()`) consommés tels quels — **pas** de Provider/Riverpod/Bloc.
- HTTP : **toujours** `ApiClient` (ici indirectement via `DbApiService.instance`) — jamais `http.X`.
- Navigation : principale via `MainScaffold` / `ScreenType` ; **sous-écrans via
  `Navigator.push(MaterialPageRoute(...))`** (cf. `lib/models/nav_item.dart`, `lib/main.dart:372`).
- Couleurs : `AppColors` (`theme/app_theme.dart`) — jamais de `Color(0xFF…)` inline.
- i18n : clés dans `lib/l10n/app_fr.arb` (template) **ET** `lib/l10n/app_en.arb`, puis `flutter gen-l10n`.
- Breakpoints : `AppBreakpoints.tablet` (600) / `AppBreakpoints.desktop` (800).

Fichiers concernés (réels, vérifiés) :
- `flutter-app/lib/screens/technician_update_screen.dart`
  - `initState` (`technician_update_screen.dart:196-209`) : `_canValidate`, `tabCount`, `startTab`.
  - `build` → `TabBar` + `TabBarView` (`technician_update_screen.dart:302-374`).
  - `_takeOverIssue` avec `_tabController.animateTo(1)` (`technician_update_screen.dart:1665`).
  - Onglet agenda : `_buildAgendaTab` (`technician_update_screen.dart:1333`), modèle `_AgendaEvent`
    (`technician_update_screen.dart:23`), helpers `_allAgendaEvents` (`:1260`), `_eventsForDay` (`:1306`),
    `_buildEventTile` (`:1543`), `_legendItem` (`:1594`), `_monthName` (`:1315`), `_parseDate` (`:1251`),
    état `_focusedDay`/`_selectedDay` (`:94-95`).
  - Onglet validation : `_buildValidationTab` (`:2289`), `_buildValidationIssueItem` (`:2371`) avec
    les boutons mobile (`:2419-2440`) et desktop (`:2496-2511`), `_showValidationIssueDetail` (`:2517`),
    `_showValidateDialog` (`:2529`), `_validateIssue` (`:2659`), `_validationUrgencyColor` (`:2694`),
    `_validationGroupMeta` (`:2703`).
- `flutter-app/lib/screens/issue_detail_screen.dart`
  - `_isPrivileged` (`issue_detail_screen.dart:58`), `_buildSupervisorActions` (`:390`),
    `_showReassignDialog` (`:419`), `_load` (`:95`), `build`/sections (`:289`), barre basse (`:903`).
- `flutter-app/lib/l10n/app_fr.arb` + `flutter-app/lib/l10n/app_en.arb`.
- **À CRÉER** : `flutter-app/lib/screens/technician_schedule_screen.dart`.

## Objectif
1. Réordonner les onglets de la page technicien : **« À valider » en premier** (pour
   admin/superviseur). 2. **Sortir le planning des onglets** vers une page séparée atteinte par
   un bouton. 3. **Simplifier l'onglet « À valider »** : un seul bouton « Examiner » par incident,
   qui ouvre le détail d'incident où l'utilisateur valide et (si besoin) réassigne par groupe.

## Périmètre
- **Dans le scope** : Flutter + i18n FR/EN. Réutilisation stricte des appels existants
  `DbApiService.instance.updateIssue(...)` (validation) et `DbApiService.instance.reassignIssue(...)`
  (réassignation par groupe, déjà câblée dans le détail via `_showReassignDialog`).
- **Hors scope** : aucune migration DB, aucun nouvel endpoint, **pas** d'assignation individuelle
  à un technicien nommé (la réassignation reste **par groupe** : Biomédical / IT / Infrastructure).
  Ne pas toucher au backend ni aux modèles de données.

## Spécification détaillée

### 1. Réordonnancement des onglets (`technician_update_screen.dart`)
L'agenda quitte le `TabBar`. Nouvel ordre :
- Si `_canValidate` (admin/superviseur) → **3 onglets** : `[0] À valider`, `[1] Disponibles`,
  `[2] Mes interventions`.
- Sinon (technicien simple) → **2 onglets** : `[0] Disponibles`, `[1] Mes interventions`.

À faire :
- `initState` : `tabCount = _canValidate ? 3 : 2`. Définir un getter/const local pour l'index
  de « Mes interventions » : `final myInterventionsIndex = _canValidate ? 2 : 1;`.
  `startTab = widget.issueId != null ? myInterventionsIndex : 0` (deep-link incident → on atterrit
  sur l'intervention ; sinon onglet par défaut = « À valider » si valideur, « Disponibles » sinon).
- `build` : reconstruire `tabs:` et `children:` du `TabBarView` dans le **même ordre** que ci-dessus.
  L'onglet « À valider » (`Icons.pending_actions_outlined`, `l10n.issueValidationTab`, badge
  `_openIssuesForValidation.length`) n'apparaît que si `_canValidate`. Retirer l'onglet
  `techScheduleTab` (`Icons.calendar_today_outlined`) et l'appel `_buildAgendaTab(...)`.
- `_takeOverIssue` (`:1665`) : remplacer `_tabController.animateTo(1)` par
  `_tabController.animateTo(_canValidate ? 2 : 1)` (index dynamique de « Mes interventions »).
- Ne **pas** laisser de référence morte à `_buildAgendaTab` (déplacé, cf. §2).

### 2. Planning en page séparée (NOUVEAU `technician_schedule_screen.dart`)
- Créer `class TechnicianScheduleScreen extends StatefulWidget` avec un `Scaffold` (AppBar
  `title: l10n.techScheduleTitle`) dont le corps est l'actuel contenu de `_buildAgendaTab`.
- **Déplacer** (couper depuis `technician_update_screen.dart`) le modèle `_AgendaEvent` et les
  membres/méthodes agenda : `_focusedDay`, `_selectedDay`, `_allAgendaEvents`, `_eventsForDay`,
  `_buildAgendaTab` (à renommer en `build`/`_buildBody`), `_buildEventTile`, `_legendItem`,
  `_monthName`, `_parseDate`. Garder l'usage de `AuthService().currentUser?.fullName` et
  `DataService()` (singletons accessibles partout). Conserver l'import `table_calendar`.
- **Vérifier** qu'aucun de ces symboles n'est encore référencé dans `technician_update_screen.dart`
  après déplacement (sinon supprimer la référence). Le `_AgendaEvent` n'est utilisé que par l'agenda.
- Accès : ajouter un **bouton icône calendrier** (`Icons.calendar_today_outlined`,
  `tooltip: l10n.techScheduleTab`) **à droite du `TabBar`** dans le `build` de
  `technician_update_screen.dart`. Pour cela, envelopper le `TabBar` dans un `Row` :
  `Row(children: [Expanded(child: TabBar(...)), IconButton(...)])` à l'intérieur du `Material`
  existant. Le bouton fait :
  `Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicianScheduleScreen()));`
  → ainsi le planning reste accessible **dans les 2 configurations d'onglets** (valideur ou non).

### 3. Onglet « À valider » : bouton unique « Examiner » (`_buildValidationIssueItem`)
- Dans **les deux branches** (mobile `:2419-2440` et desktop `:2496-2511`), **supprimer** le bouton
  « Détails » (`info_outline`, `issueValidationDetails`) **et** le bouton « Valider »
  (`check_circle`, `issueValidationValidate`). Les remplacer par **un seul** bouton « Examiner » :
  `ElevatedButton.icon(icon: Icon(Icons.visibility_outlined, size: 16), label: Text(l10n.issueValidationReview), onPressed: () => _showValidationIssueDetail(issue), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white))`.
  (Mobile : bouton pleine largeur ; desktop : à droite de la ligne.)
- `_showValidationIssueDetail` (`:2517`) : rendre l'ouverture **`await`** et **rafraîchir** au retour :
  ```dart
  Future<void> _showValidationIssueDetail(Issue issue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueDetailScreen(
          issueId: issue.id,
          onNavigate: (_, {equipmentId, issueId}) {},
        ),
      ),
    );
    await DataService().reloadIssues();
    if (mounted) setState(() {});
  }
  ```
- Comme la validation migre vers le détail (§4), **supprimer** de `technician_update_screen.dart`
  les méthodes désormais inutilisées : `_showValidateDialog` (`:2529`), `_validateIssue` (`:2659`),
  `_validationUrgencyColor` (`:2694`) et le champ `_isValidating` (`:80`) **uniquement s'ils ne
  sont plus référencés** après refonte. `_validationGroupMeta` / `_buildValidationGroupChip` restent
  s'ils servent encore l'affichage des chips de groupe dans l'onglet. Vérifie chaque suppression
  par recherche d'usage avant de retirer.

### 4. Bouton « Valider » dans le détail d'incident (`issue_detail_screen.dart`)
- Importer `IssueStatus` (`../models/issue.dart` est déjà importé) et au besoin `UrgencyBadge`
  (déjà importé).
- Dans `_buildSupervisorActions` (`:390`), ajouter — **en première position** et **conditionnel** —
  un bouton « Valider » visible uniquement si `detail.issue.status == IssueStatus.reported`
  (le reste du Wrap, Réassigner + Commenter, est déjà gardé par `_isPrivileged` via `_buildBody:289`) :
  ```dart
  if (detail.issue.status == IssueStatus.reported)
    ElevatedButton.icon(
      onPressed: _submitting ? null : () => _showValidateDialog(l10n, detail),
      icon: const Icon(Icons.check_circle_outline, size: 16),
      label: Text(l10n.issueValidationValidate),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
    ),
  ```
- Ajouter dans `_IssueDetailScreenState` un dialog `_showValidateDialog(l10n, detail)` qui reprend
  la logique de l'ancien `_showValidateDialog`/`_validateIssue` du technicien :
  - Dropdown **groupe** (`['Biomédical','IT','Infrastructure']`, défaut `detail.issue.assignedGroup`).
  - Sélecteur **urgence** (chips `IssueUrgency.values`, défaut `detail.issue.urgency`).
  - **Indicateur de délai** depuis le signalement, en tête du dialog : « Signalé il y a N jour(s) »
    via une nouvelle clé i18n pluralisée `issueValidationReportedAgo` (calcul front :
    `DateTime.now().difference(DateTime.parse(detail.issue.createdAt)).inDays`, borne à 0 si parsing
    échoue — réutiliser un `try/catch` comme `IssueDetailScreen._fmtDate`).
  - Action « Valider » → `await DbApiService.instance.updateIssue(detail.issue.id, {'status': 'Acknowledged', 'urgency': selectedUrgency.displayName, if (selectedGroup != null && selectedGroup != detail.issue.assignedGroup) 'assigned_group': selectedGroup})`,
    puis `setState(() { _loading = true; _error = null; }); await _load();` (recharge la fiche) et
    SnackBar succès `issueValidationSuccess` / erreur `issueValidationError`. Gérer `_submitting`.
  - Réutiliser les clés i18n existantes : `issueValidationConfirmTitle`, `issueValidationGroupLabel`,
    `issueValidationUrgencyLabel`, `issueValidationConfirmMessage`, `issueValidationValidate`,
    `issueValidationSuccess`, `issueValidationError`, `issueValidationRedirectLabel`, `commonCancel`.

### 5. i18n (app_fr.arb + app_en.arb, puis `flutter gen-l10n`)
Ajouter dans **les deux** fichiers (avec placeholders pour le pluriel) :
- `issueValidationReview` → FR « Examiner » / EN « Review ».
- `issueValidationReportedAgo` → message pluralisé, ex. FR
  `"{days, plural, =0{Signalé aujourd'hui} one{Signalé il y a {days} jour} other{Signalé il y a {days} jours}}"`,
  EN `"{days, plural, =0{Reported today} one{Reported {days} day ago} other{Reported {days} days ago}}"`,
  avec `placeholders: { "days": { "type": "int" } }`.
Ne pas dupliquer de clé existante. Si une clé manque dans l'autre ARB, `flutter analyze` casse.

## Contraintes et garde-fous (Do / Don't)
- **Do** : index d'onglets calculés dynamiquement (jamais en dur). Bouton planning visible pour
  valideur **et** technicien simple. `await` + `reloadIssues` + `setState` au retour du détail.
  Bouton « Valider » du détail conditionné à `status == reported`. i18n FR **et** EN.
- **Don't** : pas de `Navigator.pushNamed` global ; pas de `http.X` direct ; pas de `print` (utiliser
  `debugPrint` si indispensable) ; pas de `Color(0xFF…)` inline ; pas de nouvel endpoint ni de
  changement DB ; ne pas laisser de méthode/champ mort (`_buildAgendaTab`, `_isValidating`, etc.) ;
  ne pas réintroduire l'assignation par technicien nommé.
- RBAC : la validation reste réservée admin/superviseur (`_canValidate` côté onglet, `_isPrivileged`
  + `status == reported` côté détail). L'audit trail est assuré par le backend sur `updateIssue` —
  ne rien ajouter côté Flutter.

## Étapes attendues
1. **Proposer un court plan** (ordre des modifications, méthodes déplacées) avant d'écrire le code.
2. Créer `technician_schedule_screen.dart` (déplacer l'agenda) et brancher le bouton calendrier.
3. Réordonner les onglets + corriger `startTab` et l'`animateTo` de `_takeOverIssue`.
4. Refondre `_buildValidationIssueItem` (bouton « Examiner ») + `_showValidationIssueDetail` (await+refresh).
5. Ajouter le bouton + dialog « Valider » (avec délai depuis signalement) dans `issue_detail_screen.dart`.
6. Nettoyer le code mort dans `technician_update_screen.dart` (vérifier chaque usage avant suppression).
7. i18n FR+EN + `flutter gen-l10n`.

## Critères de succès / vérification (mesurables)
- `flutter analyze --no-fatal-infos` : **0 erreur, 0 warning** introduit.
- Scénarios manuels validés :
  - Admin/superviseur : onglets dans l'ordre `[À valider, Disponibles, Mes interventions]`,
    « À valider » sélectionné par défaut.
  - Technicien simple : onglets `[Disponibles, Mes interventions]`, **aucun** onglet validation,
    bouton calendrier toujours présent.
  - Clic « Examiner » → ouvre le détail ; bouton « Valider » présent (statut `reported`) ; après
    validation et retour, l'incident **disparaît** de la liste « À valider ».
  - Deep-link technicien avec `issueId` → atterrit sur « Mes interventions » (index correct).
  - Prise en charge d'un incident disponible → bascule sur « Mes interventions » (bon index).
  - Bouton calendrier → ouvre `TechnicianScheduleScreen` ; retour arrière OK.
- `python -X utf8 scripts/log_feature.py --nom "Refonte page technicien" --desc "Onglet À valider en premier, planning en page séparée, validation+réassignation déléguées au détail d'incident (bouton Examiner), délai de signalement affiché"`
- Mise à jour `contexte/context.md` : nouvel écran `TechnicianScheduleScreen` (section « Écrans »,
  mettre à jour le compteur et le tableau) car nouvel écran Flutter.

## Étape finale obligatoire
Une fois la feature implémentée et vérifiée, lancer `/simplify` sur le code créé/modifié
(réutilisation, simplification, efficacité, altitude) avant de clore la tâche.
