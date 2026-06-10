---
name: audit-gmao-kpi
description: >
  Audite l'application GMAO Kabutare et la note sur 100 via la grille KPI à 8 domaines
  (backend, sécurité/RBAC, audit trail, Flutter, i18n, tests, documentation, standards GMAO).
  Utiliser ce skill pour tout audit, re-notation, ou vérification de conformité CLAUDE.md.
  Chaque point perdu exige une preuve fichier:ligne. Lecture seule sur le code applicatif.
---

# Audit GMAO KPI — Kabutare

Audit complet de l'application GMAO de l'Hôpital de District de Kabutare
(Flutter / Node.js Express / SQLite better-sqlite3 / Keycloak), noté sur 100.

## Règles

- Toute preuve = `fichier:ligne` ou sortie de commande collée.
- SQL : SELECT uniquement. Jamais d'UPDATE/INSERT/DELETE sur les .db.
- Un contrôle non mesurable = noté ⚠️ avec la raison, jamais inventé.
- L'audit est **en lecture seule** sur le code applicatif. Seules écritures autorisées :
  le dossier `audit/`, `contexte/context.md`, `contexte.md`, `CLAUDE.md`, et la ligne
  Excel de clôture (`scripts/log_feature.py`).
- Lire d'abord : `CLAUDE.md`, `contexte.md`, `contexte/context.md`,
  `contexte/resume_need_software_kabutare.md`.

## Grille KPI — barème /100

### KPI-1 · Conformité backend (15 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| Pattern de route respecté (validation → existence → DB sync → réponse) | 4 | Grep `router.(post\|put\|patch\|delete)` dans `*/src/routes/*.js`, vérifier chaque handler |
| `better-sqlite3` synchrone — aucun `async` autour des accès DB | 3 | Grep `async` dans les routes puis inspection |
| Migrations idempotentes (`PRAGMA table_info` + `IF NOT EXISTS`) | 4 | Lire `database.js` des deux services, lister tout ALTER non gardé |
| Codes HTTP conformes au tableau CLAUDE.md (400/401/403/404/409/500) | 2 | Échantillonner 10 routes, comparer |
| CommonJS, camelCase JS / snake_case SQL, un router par fichier | 2 | Inspection structurelle |

### KPI-2 · Sécurité & RBAC (15 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| `verifyToken` + `requireRole(...)` sur **chaque** endpoint protégé (RBAC backend, pas seulement masquage UI Flutter) | 6 | Lister toutes les routes, croiser avec la table des permissions de `contexte.md` |
| Aucun secret en dur (grep `BREVO\|SECRET\|PASSWORD` hors `process.env.*`) | 3 | Grep + inspection |
| Validation JWT via JWKS RS256 uniquement — aucun `JWT_SECRET` partagé | 2 | Lire `middleware/auth.js` des deux services |
| CORS en liste blanche explicite dans les deux `index.js` | 2 | Inspection |
| Aucun token / mot de passe loggé ; entrées sidebar avec `requiredPermission` | 2 | Grep logs + config sidebar |

### KPI-3 · Audit trail (10 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| `logAction({...})` présent sur 100 % des mutations POST/PUT/PATCH/DELETE | 7 | Score = 7 × (mutations avec logAction / mutations totales), arrondi |
| Schéma logAction complet (`action`, `target_type`, `target_id`, `target_name`, `details`, `...extractReqMeta(req)`) | 3 | Échantillonner 8 appels |

### KPI-4 · Conformité Flutter (15 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| Zéro `http.get/post/...` direct — uniquement `ApiClient` | 4 | Grep `http\.` dans `flutter-app/lib` hors `api_client.dart` |
| Singletons `ChangeNotifier` + `ListenableBuilder` (pas de Provider/Riverpod/Bloc) | 3 | Lire `pubspec.yaml` + échantillon services |
| Zéro `print(` (debugPrint toléré), zéro `Color(0xFF` inline hors `app_theme.dart` | 3 | Greps ciblés |
| Navigation : `MainScaffold._navigateTo` + `ScreenType` pour le principal, `MaterialPageRoute` pour les sous-écrans | 2 | Grep `pushNamed` (doit être vide) |
| URLs via `--dart-define` (`api_config.dart`), tokens via `SecureTokenStorage` | 3 | Inspection |

### KPI-5 · i18n (5 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| Clés `app_fr.arb` ⟷ `app_en.arb` strictement synchronisées | 3 | Script `audit/tools/diff_arb.js` — chaque clé orpheline = −0,5 |
| Aucune chaîne UI en dur dans les écrans (échantillon de 5 écrans) | 2 | Inspection |

### KPI-6 · Tests & qualité (10 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| `npm test` passe dans `auth-service/` | 3 | Exécution réelle |
| `npm test` passe dans `db-service/` | 3 | Exécution réelle |
| `flutter analyze --no-fatal-infos` sans erreur | 3 | Exécution réelle |
| Tests Jest conformes (DB `:memory:`, mock rate-limiter) | 1 | Inspection des fichiers de test |

> Cas limites : échec dû à l'environnement (port occupé, .env absent) = ⚠️ environnement,
> sans pénalité. Échec dû à un vrai bug = pénalité + entrée dans le top 10 des correctifs.

### KPI-7 · Documentation à jour (10 pts)

| Contrôle | Pts | Méthode de mesure |
|---|---|---|
| Tous les endpoints du code présents dans `contexte/context.md` | 4 | Diff routes réelles ↔ doc |
| Schémas DB documentés = `PRAGMA table_info` réel (colonnes, types) | 4 | Inspection de `database.js` / PRAGMA lecture seule |
| Compteur d'écrans Flutter exact + tableau des écrans à jour | 2 | `ls flutter-app/lib/screens/` ↔ section "Écrans" |

### KPI-8 · Couverture standards GMAO (20 pts)

Référence : Maximo, CARL Source, Dimo Maint, Infor EAM, UpKeep, Fiix — en ne retenant
que ce qui est réaliste pour un hôpital de district.

| Standard GMAO | Pts | Méthode de mesure (SELECT lecture seule / inspection code) |
|---|---|---|
| **MTTR** calculable : moyenne `(updated_at − created_at)` des issues `Completed/Verified/Closed` | 3 | ⚠️ Si pas de colonne `resolved_at`, l'approximation par `updated_at` est une limite à noter |
| **MTBF** : intervalle moyen entre `created_at` des incidents par `equipment_id` (≥ 2 incidents) | 3 | Requête SQL annexe A |
| **Taux de conformité PM** (accréditation JCI) : % des plans où `date(last_completed_date, '+'||frequency_months||' months') >= date('now')` | 4 | Requête SQL annexe A |
| **Taux de disponibilité** : % `equipment.status = 'Operational'` global + par département | 3 | Requête SQL annexe A |
| Historique PM consultable (`maintenance_records` : `checklist_snapshot`, `duration_minutes`, `parts_used`) | 2 | Vérifier remplissage réel des colonnes FEAT-044 |
| Alerte stock (`inventory` : statut `Faible`/`Rupture` calculé) + déstockage auto depuis incident/PM | 2 | Inspection routes inventory |
| Notifications PM (`pm_due` via auth-service) + escalade incidents non résolus | 2 | Inspection `POST /internal/notifications/send-email` + recherche d'un mécanisme d'escalade |
| Export Excel/PDF des rapports par département (exigence 4.6) | 1 | Inspection routes + écrans |

**Score total = Σ KPI-1 … KPI-8, sur 100.**
Verdict : ≥ 85 Excellent · 70–84 Bon · 50–69 Moyen · < 50 Critique.

## Annexe A — Requêtes SQL de mesure (SELECT uniquement)

```sql
-- Taux de disponibilité global et par département
SELECT department,
       ROUND(100.0 * SUM(status = 'Operational') / COUNT(*), 1) AS dispo_pct,
       COUNT(*) AS total
FROM equipment GROUP BY department
UNION ALL
SELECT 'GLOBAL', ROUND(100.0 * SUM(status = 'Operational') / COUNT(*), 1), COUNT(*) FROM equipment;

-- Taux de conformité PM (% de plans à jour)
SELECT ROUND(100.0 * SUM(
         last_completed_date IS NOT NULL AND
         date(last_completed_date, '+' || frequency_months || ' months') >= date('now')
       ) / COUNT(*), 1) AS conformite_pm_pct
FROM preventive_maintenance_plans;

-- MTTR approché (jours) — limite : pas de resolved_at, updated_at utilisé
SELECT ROUND(AVG(julianday(updated_at) - julianday(created_at)), 1) AS mttr_jours
FROM issues WHERE status IN ('Completed', 'Verified', 'Closed');

-- MTBF (jours) par équipement ayant au moins 2 incidents
SELECT equipment_id,
       ROUND((julianday(MAX(created_at)) - julianday(MIN(created_at))) / (COUNT(*) - 1), 1) AS mtbf_jours,
       COUNT(*) AS nb_incidents
FROM issues WHERE equipment_id IS NOT NULL
GROUP BY equipment_id HAVING COUNT(*) >= 2 ORDER BY mtbf_jours ASC;

-- Équipements à incidents répétés (seuil d'alerte GMAO)
SELECT equipment_id, equipment_name, COUNT(*) AS nb
FROM issues WHERE equipment_id IS NOT NULL
GROUP BY equipment_id HAVING nb >= 3 ORDER BY nb DESC;
```

## Structure du rapport final

Générer `audit/rapport_audit_YYYY-MM-DD.md` :

```markdown
# Rapport d'audit — GMAO Kabutare — YYYY-MM-DD
## Score global : XX/100 — [verdict]
## Scores par domaine (tableau KPI-1 → KPI-8 avec justification de chaque point perdu)
## Trouvailles critiques (sévérité Critique, avec fichier:ligne)
## Top 10 des correctifs priorisés (impact × effort)
## KPIs métier mesurés (MTTR, MTBF, conformité PM, disponibilité — valeurs ou limites)
## Limites de l'audit (ce qui n'a pas pu être mesuré et pourquoi)
```

## Ordre d'exécution

1. Audit backend (KPI-1, KPI-2, KPI-3) — inventaire complet des routes, croisement permissions.
2. Sécurité transverse — secrets, JWKS, CORS, IDs TEXT, uploads (MIME, taille, noms UUID).
3. Flutter (KPI-4) — greps du barème, `ApiClient._tryRefresh`, `showIssueCategorySelector`.
4. i18n (KPI-5) — `audit/tools/diff_arb.js` + `flutter gen-l10n`.
5. Tests (KPI-6) — `npm test` ×2 + `flutter analyze --no-fatal-infos`.
6. Documentation + standards GMAO (KPI-7, KPI-8) — diff doc↔code, requêtes annexe A.
7. Rapport final + mise à jour documentaire (proposer les diffs avant d'écrire).
8. Clôture : `python -X utf8 scripts/log_feature.py --nom "..." --desc "..."`.
