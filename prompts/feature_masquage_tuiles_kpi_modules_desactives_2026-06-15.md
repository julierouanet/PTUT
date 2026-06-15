# Prompt — Masquer les tuiles KPI des modules désactivés

> **Date** : 2026-06-15
> **Score qualité prompt** : 100/100 (grille KPI feature-to-prompt, 8 domaines)
> **À coller dans une NOUVELLE session Claude Code pour implémentation.**
> La clôture (flutter analyze + log_feature.py) fait partie du prompt.

---

# Tâche : Propager la désactivation d'un module à ses tuiles KPI (cohérence UI aval)

## Contexte projet
GMAO Kabutare — front Flutter (Singleton `ChangeNotifier` + `ListenableBuilder`,
pas de Provider/Riverpod/Bloc — cf. CLAUDE.md « Règles absolues Flutter »).
Modules désactivables via feature flags : `FeatureService().isModuleEnabled(flagId, role)`
(flutter-app/lib/services/feature_service.dart:96-104). Seuls `equipment` et `inventory`
sont désactivables ; `settings` est toujours actif (auth-service/seed.js:27-28).

Vocabulaire GMAO : ce correctif relève de la « cohérence UI aval » — désactiver un module
doit propager le masquage à TOUS ses éléments visuels. Les cartes modules et les `onTap`
sont déjà gérés ; il reste les COMPTEURS des tuiles KPI.

Fichier concerné (UNIQUE) :
- flutter-app/lib/screens/home_hub_screen.dart
  - `_buildManagerView` (~682-774) : vue Superviseur/Admin (seul endroit avec tuiles KPI)
  - `_buildKpiRow` (~824-875) : construit les 3 tuiles
  - `ListenableBuilder` parent (~155) écoute déjà `DataService` + `FeatureService`
    → rafraîchissement en direct quand un flag change. NE PAS y toucher.
  Les numéros de ligne sont indicatifs : repère les méthodes par leur nom, pas par la ligne.

Pattern de référence DÉJÀ présent dans le fichier (à imiter, lignes ~833-838) :
  final auth     = AuthService();
  final features = FeatureService();
  final role     = auth.primaryRole?.apiName;
  final canGoInventory = auth.hasPermission(Permission.viewInventory) &&
      features.isModuleEnabled('inventory', role);
  final canGoEquipment = features.isModuleEnabled('equipment', role);

## Objectif
Quand un module est désactivé, ses tuiles KPI doivent être RETIRÉES de la rangée du
tableau de bord d'accueil (et non affichées avec un compteur). Aujourd'hui « Alertes
stock » reste visible avec « 0 » et les tuiles `equipment` ne sont pas conditionnées au flag.

## Périmètre
- Dans le scope : les 3 tuiles KPI de `_buildKpiRow` (vue manager uniquement).
- Hors scope : badge cloche, sidebar, bottom nav, cartes modules (déjà gérées),
  permissions par rôle (inchangées), backend, DB, i18n.
- NE PAS sur-ingénier : pas de multi-site, pas de dépendances entre modules, pas de
  nouvelle table/endpoint. Correctif purement front, un seul fichier.

## Spécification détaillée
Répartition tuile → module et condition d'affichage :
| Tuile | Module | Condition |
|---|---|---|
| Incidents critiques/urgents | equipment | isModuleEnabled('equipment', role) |
| Hors service | equipment | isModuleEnabled('equipment', role) |
| Alertes stock | inventory | hasPermission(viewInventory) && isModuleEnabled('inventory', role) |

Comportement attendu :
1. Construire la liste des tuiles conditionnellement (n'ajouter une tuile que si sa
   condition est vraie), en réutilisant `auth`, `features`, `role` (cf. pattern ci-dessus).
2. Rangée recomposée dynamiquement : `Expanded` sur le nombre RÉEL de tuiles restantes,
   espacement `SizedBox(width: isWide ? 16 : 8)` uniquement ENTRE tuiles.
3. Rangée vide (0 tuile) → `return const SizedBox.shrink();`.
4. Responsive : s'il ne reste QU'UNE tuile ET `!isWide` (petit écran), ne pas l'étirer
   plein écran — l'envelopper dans `Align(alignment: Alignment.centerLeft)` avec une
   largeur bornée (`ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220))`).
   Sur écran large OU si ≥2 tuiles, garder le comportement `Expanded` actuel.
5. Conserver la mise à 0 de `stockAlertCount` dans `_buildManagerView` (~696) et les
   `onTap` conditionnels (`canGoEquipment` / `canGoInventory`).

Esquisse de structure attendue (à adapter, NE PAS recopier tel quel) :
  final tiles = <_KpiTile>[
    if (canGoEquipment) _KpiTile(/* incidents critiques */),
    if (canGoInventory) _KpiTile(/* alertes stock */),
    if (canGoEquipment) _KpiTile(/* hors service */),
  ];
  if (tiles.isEmpty) return const SizedBox.shrink();
  if (!isWide && tiles.length == 1) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: tiles.first,
      ),
    );
  }
  return Row(children: [ /* Expanded + SizedBox entre tuiles */ ]);

## Contraintes et garde-fous (CLAUDE.md)
- Lire le fichier ENTIER avant d'éditer. Code complet, jamais tronqué.
- Commentaires inline en français.
- Pas de nouvelle chaîne i18n (on masque des widgets existants).
- Couleurs via `AppColors` — jamais de `Color(0xFF…)`. Pas de `print`.
- Ne pas modifier le `ListenableBuilder` parent ni la signature publique de `_KpiTile`.
- Ne rien changer côté backend / DB / autres écrans.

## Plan avant d'agir
Avant toute édition, AFFICHE un court plan : la nouvelle structure de `_buildKpiRow`
(ordre des tuiles, conditions, gestion rangée vide + tuile unique). Si quoi que ce soit
touche au-delà de `_buildKpiRow`, propose-le AVANT de coder (règle CLAUDE.md
« Proposer avant d'agir »). Puis applique la modification.

## Étapes attendues
1. Lire home_hub_screen.dart en entier.
2. Proposer le plan (ci-dessus).
3. Refactorer `_buildKpiRow` : liste conditionnelle + layout dynamique (vide → shrink ;
   tuile unique mobile → alignée gauche, bornée 220px).
4. (Optionnel mais recommandé) Ajouter un widget test sous flutter-app/test/ vérifiant
   qu'avec `equipment` désactivé les libellés des tuiles concernées ne sont pas rendus.
5. flutter analyze --no-fatal-infos (depuis flutter-app/).

## Critères de succès / vérification
- flutter analyze --no-fatal-infos passe sans nouvelle erreur/warning.
- Désactiver `equipment` → « Incidents critiques » et « Hors service » disparaissent.
- Désactiver `inventory` → « Alertes stock » disparaît.
- Désactiver les deux → rangée KPI entièrement masquée (aucun cadre vide).
- Une seule tuile restante en mobile → tuile alignée à gauche, non étirée plein écran.
- Réactiver un module → tuiles réapparaissent sans rechargement (live ListenableBuilder).
- python -X utf8 scripts/log_feature.py --nom "Masquage tuiles KPI modules désactivés"
  --desc "Les tuiles KPI du hub (incidents/hors-service/stock) sont retirées quand leur
  module est désactivé via feature flags ; rangée recomposée, masquée si vide, tuile
  unique alignée à gauche en mobile."
- Pas de mise à jour contexte.md (correctif UI, aucune interface publique modifiée).
