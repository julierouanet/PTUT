# Rapport de refactoring — Clean Code Global — 2026-06-06

## Résumé des modifications

### Backend Node.js

| Fichier créé/modifié | Nature du changement |
|---|---|
| `db-service/src/utils/roles.js` (**nouveau**) | Source unique pour `TECH_ROLES` et `rolesCsv` |
| `db-service/src/routes/equipment.js` | Import depuis `utils/roles`, suppression `enrichEquipment` (dead code) |
| `db-service/src/routes/issues.js` | Import depuis `utils/roles`, suppression déclarations locales |
| `db-service/src/routes/inventory.js` | Import depuis `utils/roles` |
| `db-service/src/routes/push_notifications.js` | Import depuis `utils/roles` |
| `db-service/src/routes/pm_protocols.js` | Import depuis `utils/roles` |

### Flutter/Dart

| Fichier créé/modifié | Nature du changement |
|---|---|
| `lib/theme/app_theme.dart` | Ajout `AppBreakpoints` (desktop=800, tablet=600) |
| `lib/models/nav_item.dart` (**nouveau**) | `ScreenType` enum + `NavItem` class (extraits de main.dart) |
| `lib/widgets/tab_label.dart` (**nouveau**) | Widget responsive icône+texte (remplace 4×90 lignes dupliquées) |
| `lib/widgets/layout/app_sidebar.dart` (**nouveau**) | Sidebar desktop StatefulWidget (extraite de `_MainScaffoldState`) |
| `lib/widgets/layout/app_top_bar.dart` (**nouveau**) | Top bar StatelessWidget (extraite de `_MainScaffoldState`) |
| `lib/widgets/layout/app_bottom_nav.dart` (**nouveau**) | Bottom nav StatelessWidget (extraite de `_MainScaffoldState`) |
| `lib/main.dart` | Refactorisé : utilise les 3 widgets layout, `NavItem`, `ScreenType` depuis `models/` |
| `lib/screens/technician_update_screen.dart` | `_AvailableIssueCard` extrait + 4 helpers top-level |
| 15 fichiers screens/widgets | Remplacement `800`→`AppBreakpoints.desktop`, `600`→`AppBreakpoints.tablet` |

## Métriques avant/après

| Métrique | Avant | Après |
|---|---|---|
| `TECH_ROLES` dupliqué | 5 fichiers | 1 source (`utils/roles.js`) |
| `rolesCsv` dupliqué | 5 fichiers | 1 source (`utils/roles.js`) |
| Dead code `enrichEquipment` | 1 (11 lignes) | 0 |
| Magic breakpoints `800`/`600` éparpillés | 18 occurrences, 15 fichiers | 1 constante `AppBreakpoints` |
| `main.dart` lignes | 991 | 436 |
| `_isSidebarCollapsed` dans `_MainScaffoldState` | oui (état) | non (géré par `AppSidebar`) |
| Pattern TabLabel dupliqué | 4×90 lignes | 1 widget `TabLabel` |
| `_buildAvailableIssueItem` dans state class | 173 lignes | Widget `_AvailableIssueCard` |
| Tests backend | 113/113 ✅ | 113/113 ✅ |
| `flutter analyze` | 0 error, 0 warning | 0 error, 0 warning |

## Décisions techniques

### Pourquoi `utils/roles.js` et non intégration dans `middleware/auth.js` ?
`TECH_ROLES` est une constante métier (rôles des techniciens), distincte des rôles systèmes Keycloak gérés par `auth.js`. Les séparer respecte la responsabilité unique de chaque module.

### Pourquoi `enrichEquipment` supprimée plutôt que corrigée ?
La fonction préparait 3 statements SQLite en dehors de la boucle (pour perf), exactement comme le `GET /` qui ne l'utilise pas. La réutiliser aurait au contraire dégradé les performances en recréant les statements à chaque appel unitaire.

### Pourquoi `AppSidebar` gère son propre état collapsed ?
Extraire `_isSidebarCollapsed` de `_MainScaffoldState` respecte le principe « un composant = un état qu'il possède ». La sidebar est le seul composant à avoir besoin de cet état.

### Pourquoi `_AvailableIssueCard` plutôt qu'extraction dans un fichier séparé ?
Le widget reste privé (`_`) car il n'a aucune raison d'être réutilisé en dehors de `TechnicianUpdateScreen`. L'extraction dans le même fichier (en fin de fichier) améliore la lisibilité sans créer une dépendance inter-fichier injustifiée.

### Pourquoi `ScreenType` déplacé dans `models/nav_item.dart` ?
`ScreenType` est un modèle de domaine (énumération des écrans), pas une préoccupation du fichier `main.dart`. Le déplacer dans `models/` rend les imports des widgets layout possibles sans dépendance circulaire.
