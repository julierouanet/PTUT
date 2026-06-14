<!--
Feature  : Plan de remplacement formel des biomédicaux
Date     : 2026-06-14
Score    : 100/100 (grille KPI feature-to-prompt — Excellent)
Usage    : coller l'intégralité du bloc ci-dessous dans une NOUVELLE session Claude Code.
-->

# Tâche : Plan de remplacement formel des biomédicaux (GMAO Kabutare)

## Contexte projet
GMAO Kabutare — Flutter (web/APK) + Node.js Express + SQLite (better-sqlite3, SYNCHRONE, WAL) + Keycloak.
Lire CLAUDE.md, contexte.md et contexte/context.md AVANT de coder. Respecter strictement les conventions.
Cette feature couvre le gap #1 du rapport d'accréditation RHAS (standard RA3 S5 ★, niveau L1→L3) :
audit/rapport_accreditation_RHAS_2026-06-12.md.

Données DÉJÀ présentes sur la table `equipment` (ne rien recréer) :
- manuf_year          → db-service/src/database.js:160
- install_date        → db-service/src/database.js:161
- warranty_end_date   → db-service/src/database.js:541
- criticality (A/B/C) → db-service/src/database.js:542
- status (enum: Operational, Maintenance, Out of service, To be disposal, Disposed)
Hiérarchie catégories EXISTANTE : equipment_macro_categories (Biomedical/Infrastructure/IT)
→ equipment_subcategories. La feature ne concerne QUE la macro-catégorie Biomedical.

Fichiers de référence à imiter :
- Routes + pattern (verifyToken + requireRole + logAction) : db-service/src/routes/equipment.js
  (ex. GET / :40, POST /:id/maintenance :372, GET maintenance-label :545).
- Export PDF de référence : flutter-app/lib/services/pdf_report_service.dart (6 sections GMAO).
- Écran rapports (permission generateReports) : flutter-app/lib/screens/reports_screen.dart.
- Liste équipement : flutter-app/lib/screens/equipment_list_screen.dart.
- Détail équipement : flutter-app/lib/screens/equipment_detail_screen.dart.
- Gestion catégories existante (à imiter pour les sous-catégories) :
  flutter-app/lib/widgets/settings/ (CategoriesTab) + settings_screen.dart (TabBar).

## Objectif
Consolider les données existantes en un plan de remplacement priorisé et budgétisable des
équipements biomédicaux, exportable PDF pour le comité d'accréditation, et signaler
visuellement les équipements concernés.

## Périmètre
- Dans le scope :
  1. Colonne `expected_lifespan_years` sur equipment_subcategories (durée de vie de référence).
  2. Calcul serveur du statut de remplacement + horizon par équipement biomédical.
  3. Écran de gestion des sous-catégories (CRUD léger + saisie de la durée de vie).
  4. Page de détail sous-catégorie (À CRÉER) avec la liste des notifications liées.
  5. Indicateurs « triangle » sur liste équipement et liste sous-catégories
     (survol = tooltip résumé, clic = page de détail).
  6. Section « Notifications » sur la page détail équipement.
  7. Rapport PDF « Plan de remplacement » : encart KPI de flotte + tableau détaillé.
- Hors scope : durée de vie pour Infrastructure/IT ; saisie de coûts/devis ; workflow
  d'approbation budgétaire ; amorçage (seed) de durées (laisser vide, l'admin saisit).

## RBAC (tranché — ne pas réinterpréter)
- Lecture du plan de remplacement et export PDF : requireRole('admin','supervisor')
  (équivalent permission applicative generateReports).
- Écriture de la durée de vie d'une sous-catégorie : requireRole('admin')
  (équivalent permission applicative manageCategories).

## Spécification détaillée

### 1. DB — db-service/src/database.js
Ajouter, en migration IDEMPOTENTE (try/catch comme les ALTER existants vers la ligne 539-542) :
    try { db.exec("ALTER TABLE equipment_subcategories ADD COLUMN expected_lifespan_years INTEGER"); } catch (_) {}
Aucun seed. NULL = durée non définie.

### 2. Règles de calcul (côté serveur, source de vérité unique)
- age = (annéeCourante − manuf_year) ; fallback (annéeCourante − année(install_date)) si manuf_year NULL.
- lifespan = expected_lifespan_years de la sous-catégorie de l'équipement.
- statut de remplacement :
    • "donnee_manquante" si lifespan IS NULL → section à part, NON notée (pas d'horizon).
    • "a_remplacer"      si age >= lifespan  OU status == 'To be disposal'.
    • "bientot"          si 0.8*lifespan <= age < lifespan.
    • "ok"               sinon.
- horizon budgétaire (seulement si lifespan défini) :
    reste = lifespan − age
    • "cette_annee" si reste <= 0 OU status == 'To be disposal'
    • "1_2_ans"     si 0 < reste <= 2
    • "plus_tard"   si reste > 2
- IMPORTANT : warranty_end_date n'intervient PAS ; le statut 'Out of service' ne déclenche PAS
  "a_remplacer". Seuls age>=lifespan et 'To be disposal' déclenchent.
- tri du plan : criticality A > B > C, puis dépassement (age − lifespan) décroissant.

### 3. Backend — db-service/src/routes/
- GET /api/equipment/replacement-plan  (verifyToken + requireRole('admin','supervisor')) →
  renvoie { summary, items }. Exemple de réponse :
    {
      "summary": {
        "biomedical_count": 142,
        "avg_age_years": 6.4,
        "end_of_life_count": 23,
        "end_of_life_pct": 16.2,
        "by_horizon": { "cette_annee": 23, "1_2_ans": 18, "plus_tard": 90, "donnee_manquante": 11 },
        "by_criticality": { "A": 40, "B": 62, "C": 40 }
      },
      "items": [
        { "id": "ge-vivid-s60-001", "name": "Echographe Vivid S60", "subcategory": "Echographe",
          "criticality": "A", "age": 11, "lifespan": 10, "overshoot": 1,
          "status_replacement": "a_remplacer", "horizon": "cette_annee" }
      ]
    }
- PUT /api/equipment/subcategories/:id/lifespan  (verifyToken + requireRole('admin')) →
  body { expected_lifespan_years: number|null }. Valider entier >= 0 ou null (400 sinon).
- logAction({ action: 'update_subcategory_lifespan', target_type: 'subcategory',
  target_id, target_name, details, ...extractReqMeta(req) }) sur la mutation PUT.
- Si l'endpoint de liste des sous-catégories n'existe pas encore, l'ajouter (GET).

### 4. Flutter
- Écran « Gestion des sous-catégories » : PROPOSER d'abord l'emplacement (nouvel onglet de
  SettingsScreen en imitant CategoriesTab, OU écran dédié) et ATTENDRE validation AVANT de coder.
  Liste des sous-catégories biomédicales avec champ éditable expected_lifespan_years + triangle si NULL.
- Page « Détail sous-catégorie » (À CRÉER, via MaterialPageRoute) : infos de la sous-catégorie +
  liste des notifications liées (équipements à remplacer / bientôt de cette sous-catégorie).
  État vide : si la sous-catégorie n'a aucune notification, afficher un message « Aucune alerte »
  (chaîne i18n) plutôt qu'une liste vide.
- Section « Notifications » sur equipment_detail_screen.dart : affiche les alertes de l'équipement
  (à remplacer / bientôt / donnée manquante) ; si aucune, message « Aucune alerte ».
- Indicateur triangle réutilisable (widget dédié, ex. ReplacementBadge) :
    • orange = a_remplacer, jaune = bientot, gris = donnee_manquante (aucun badge si "ok").
    • Rendu : petite icône triangle (Icons.warning) de la couleur correspondante, dans un Tooltip.
    • Tooltip (survol/appui long) = résumé court, ex. « À remplacer — 11 ans / réf. 10 ans (Crit. A) ».
    • Clic = navigation vers la page de détail concernée (équipement ou sous-catégorie).
  Posé dans equipment_list_screen.dart (par ligne d'équipement) et dans la liste des sous-catégories.
- Rapport PDF « Plan de remplacement » dans pdf_report_service.dart, déclenché depuis
  reports_screen.dart (bouton conditionné à generateReports, comme l'export existant) :
    1) Encart KPI flotte : âge moyen, % en fin de vie, comptes par horizon, par criticité.
    2) Tableau détaillé trié (criticité puis dépassement) : nom, sous-cat, criticité, âge,
       durée réf., dépassement, statut, horizon.
- HTTP via ApiClient uniquement. Couleurs via AppColors (définir les teintes triangle dans
  app_theme.dart, pas de Color(0xFF) inline).

### 5. i18n
Toute chaîne UI → clé dans app_fr.arb PUIS app_en.arb, puis flutter gen-l10n. Ne pas oublier EN
(casse flutter analyze).

## Contraintes et garde-fous (NE PAS faire)
- NE PAS rendre une migration non idempotente (toujours try/catch ; pas de DROP COLUMN).
- NE PAS utiliser http.get/post direct → ApiClient.{get,post,put} uniquement.
- NE PAS hardcoder de couleur (Color(0xFF…)) → AppColors.
- NE PAS exposer une route sans verifyToken + requireRole adéquat (voir section RBAC).
- NE PAS omettre logAction sur la mutation PUT.
- NE PAS supposer equipment.id numérique (TEXT slug) ni user_id entier (UUID Keycloak).
- NE PAS faire intervenir warranty_end_date ni 'Out of service' dans le déclenchement.
- NE PAS seed de durées de vie.
- NE PAS utiliser pushNamed pour les sous-écrans (MaterialPageRoute).

## Démarche attendue
1. Commencer par PROPOSER un court plan (DB → backend → Flutter → PDF → i18n) ET l'emplacement
   de l'écran sous-catégories (onglet Settings vs écran dédié), puis ATTENDRE ma validation
   AVANT d'écrire du code (changement d'architecture = proposer avant d'agir).
2. Implémenter dans cet ordre, couche par couche, code COMPLET (jamais tronqué).
3. Écrire les tests Jest backend (DB :memory:, mock rate-limiter) pour le calcul statut/horizon.

## Critères d'acceptation observables
- Un équipement biomédical de 11 ans dans une sous-catégorie à expected_lifespan_years = 10
  → status_replacement = "a_remplacer", horizon = "cette_annee", badge triangle ORANGE en liste.
- Un équipement de 9 ans dans une sous-catégorie à 10 ans
  → status_replacement = "bientot", horizon = "1_2_ans", badge triangle JAUNE.
- Un équipement dont la sous-catégorie a expected_lifespan_years = NULL
  → status_replacement = "donnee_manquante", badge GRIS, exclu des comptes by_horizon (sauf donnee_manquante),
    et sa sous-catégorie porte un triangle dans l'écran de gestion.

## Critères de succès / vérification (clôture)
- npm test passe dans db-service/ (dont tests du calcul statut/horizon).
- flutter analyze --no-fatal-infos sans erreur.
- python -X utf8 scripts/log_feature.py --nom "Plan de remplacement biomédical" --desc "Durée de vie de référence par sous-catégorie + calcul statut/horizon + écran gestion sous-catégories + badges triangle + rapport PDF plan de remplacement (RA3 S5)"
- Mise à jour de contexte.md (schéma : colonne expected_lifespan_years) et de
  contexte/context.md (nouveaux endpoints + nouvel écran + compteur d'écrans).
