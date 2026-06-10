# Rapport d'audit — GMAO Kabutare — 2026-06-10

> Audit réalisé via le skill `.claude/skills/audit-gmao-kpi/SKILL.md` (grille KPI à 8 domaines).
> Audit en **lecture seule** sur le code applicatif. Branche auditée : `dev`.
> Outils d'audit : `audit/tools/diff_arb.js`, `audit/tools/kpi_queries.js`, `audit/tools/status_check.js`.

## Score global : **83,5/100 — Bon** (70–84)

| Domaine | Score | Max |
|---|---|---|
| KPI-1 · Conformité backend | 14 | 15 |
| KPI-2 · Sécurité & RBAC | 13 | 15 |
| KPI-3 · Audit trail | 9 | 10 |
| KPI-4 · Conformité Flutter | 13 | 15 |
| KPI-5 · i18n | 3,5 | 5 |
| KPI-6 · Tests & qualité | 9,5 | 10 |
| KPI-7 · Documentation à jour | 4 | 10 |
| KPI-8 · Standards GMAO | 17,5 | 20 |
| **Total** | **83,5** | **100** |

---

## Scores par domaine — justification de chaque point perdu

### KPI-1 · Conformité backend — 14/15

| Contrôle | Score | Preuve / justification |
|---|---|---|
| Pattern de route (validation → existence → DB sync → réponse) | 4/4 | Échantillon conforme : `db-service/src/routes/equipment.js:253-339` (PUT), `issues.js:253-392`, `inventory.js:36-80`, `departments.js:62-125`. Validation explicite, contrôle 404, DB synchrone, audit, réponse. |
| better-sqlite3 synchrone | 3/3 | Aucun `await db.prepare` dans tout le projet. Seul `await db.backup()` (`backups.js:75`) — API asynchrone officielle de better-sqlite3, légitime. Les handlers `async` ne le sont que pour des appels HTTP (Keycloak, auth-service). |
| Migrations idempotentes | **3/4 (−1)** | Idempotence obtenue par `try { db.exec('ALTER TABLE …') } catch (_) {}` au lieu de la garde `PRAGMA table_info` prescrite par CLAUDE.md : `db-service/src/database.js:121-181`, `539-542` ; `auth-service/src/database.js:165-168`. Le pattern avale **toute** erreur (pas seulement « duplicate column »). Le pattern PRAGMA est utilisé correctement ailleurs (`db-service/src/database.js:352-366`, rebuild `issues` gardé ligne ~200). |
| Codes HTTP conformes | 2/2 | Échantillon de 10 routes conforme (400/401/403/404/409/500). `502` utilisé pour les erreurs Keycloak amont (`auth-service/src/routes/roles.js:79`) — hors tableau CLAUDE.md mais sémantiquement correct. |
| CommonJS, conventions, un router/fichier | 2/2 | Conforme partout (`require`/`module.exports`, snake_case SQL, sections `// ──`). |

### KPI-2 · Sécurité & RBAC — 13/15

| Contrôle | Score | Preuve / justification |
|---|---|---|
| verifyToken + requireRole sur chaque endpoint | **4,5/6 (−1,5)** | 100 % des routes ont `verifyToken` (hors endpoints publics assumés : `/health`, `POST /api/auth/access-request`, `forgot-password`, `GET /api/notifications/vapid-key` — clé publique). **Écart** : `GET /api/users?role=X` accessible à *tout* utilisateur authentifié (`auth-service/src/routes/users.js:40-47`) — expose noms + emails de tous les porteurs d'un rôle à un simple `hospitalStaff`. Le besoin légitime (listes de techniciens assignables) est déjà couvert côté db-service par `GET /api/issues/:id/assignable-technicians` (`issues.js:114`, restreint admin/sup/tech). |
| Aucun secret en dur | **2,5/3 (−0,5)** | Tout passe par `process.env` (`auth-service/src/config.js`, `db-service/src/config.js`). **Réserve** : fallback `'kabutare-internal-secret-change-in-production'` en dur (`db-service/src/config.js:5`, `auth-service/src/config.js:5`) — un oubli de variable en prod laisse un secret connu publiquement (le warning `config.js:21-22` ne bloque pas le démarrage). |
| JWKS RS256 uniquement | 2/2 | `auth-service/src/middleware/auth.js:35` et `db-service/src/middleware/auth.js:35` : `jwt.verify(..., { algorithms: ['RS256'], issuer: KC_ISSUER })` via jwks-rsa. Aucun `JWT_SECRET`, aucun fallback HS256 (le « shim HS256 » décrit dans `contexte/context.md:265` n'existe plus — doc obsolète, voir KPI-7). |
| CORS liste blanche | 2/2 | `auth-service/src/index.js:23-41`, `db-service/src/index.js:35-53` : liste explicite + `CORS_ORIGIN` env. Nuance : la regex localhost db-service accepte tout port (`index.js:46`) vs liste de ports fixe côté auth — incohérence mineure, dev uniquement. |
| Pas de token loggé ; sidebar requiredPermission | 2/2 | Grep tokens/passwords dans les `console.*` : rien de sensible. Les 14 entrées de navigation déclarent `requiredPermission` (`flutter-app/lib/main.dart:261-274` ; `dashboard: null` est un choix assumé). |

### KPI-3 · Audit trail — 9/10

| Contrôle | Score | Preuve / justification |
|---|---|---|
| logAction sur 100 % des mutations | **6/7 (−1)** | **db-service : 36/38** mutations couvertes. Manquent : `PUT /api/sidebar/config` (`sidebar.js:40-60` — aucune trace de modification de la sidebar) et `PATCH /api/notifications/:id/read` (`push_notifications.js:149` — mineur). **auth-service : 10/18**. Manquent : `POST/PUT/DELETE /api/roles` (`roles.js:56`, `roles.js:96`, `roles.js:179` — création/modification/suppression de rôles **sans aucune trace**), `POST /api/users/department-request` (`users.js:379`), `POST /api/users/role-request` (`users.js:456`), `POST /api/users/:id/send-verify-email` (`users.js:541`), `PUT /api/users/me/notifications` (`users.js:590`), `POST /api/auth/access-request` (`auth.js:164` — tracé en table `access_requests` mais pas dans les logs centraux). Couverture globale : 46/56 = 82 % → 7 × 0,82 ≈ 5,7, arrondi 6. |
| Schéma logAction complet | 3/3 | 8 appels échantillonnés conformes (`action`, `target_type/id/name`, `details`, `...extractReqMeta(req)` / `...reqMeta(req)`) : `equipment.js:324`, `issues.js:309`, `inventory.js:109`, `departments.js:77`, `users.js:442`, `users.js:521`, `featureFlags.js:126`, `documents.js:75`. |

### KPI-4 · Conformité Flutter — 13/15

| Contrôle | Score | Preuve / justification |
|---|---|---|
| Zéro http direct hors ApiClient | **3/4 (−1)** | `auth_api_service.dart:24` (`http.post` vers Keycloak — login form-urlencoded, hors format JSON d'ApiClient, justifiable) et `login_screen.dart:105-106` (`http.get` sur `/health` — health dot, endpoints publics). Pas de fuite d'appels métier, mais 2 fichiers contournent la règle écrite. |
| Singletons ChangeNotifier, pas de Provider/Bloc | 3/3 | 6 services `extends ChangeNotifier` en singleton (`auth_service.dart:14`, `data_service.dart:18`, etc.). `pubspec.yaml` : aucun provider/riverpod/bloc/get_it. |
| Zéro print ; zéro Color(0xFF inline | **2/3 (−1)** | `print(` : zéro ✓. `Color(0xFF` hors `app_theme.dart` : 5 occurrences — `technician_update_screen.dart:2712,2718,2724`, `widgets/analytics/resolution_bar_chart.dart:27`, `widgets/issues/kanban_board.dart:190`. |
| Navigation conforme | 2/2 | `pushNamed` : zéro occurrence. Navigation principale par `ScreenType` + `MaterialPageRoute` pour les sous-écrans. |
| dart-define + SecureTokenStorage | 3/3 | `api_config.dart:27-38` (`String.fromEnvironment`), tokens via `SecureTokenStorage` (`api_client.dart:21-34`). `ApiClient._tryRefresh` (`api_client.dart:251-285`) : rotation stricte respectée — les deux tokens exigés, `onSessionExpired` sinon. `showIssueCategorySelector` branché sur les 8 points d'entrée (sidebar, bottom nav, main, hub ×2, dashboard ×3, staff view, issue tracking ×2) ; exception EquipmentListScreen respectée. |

### KPI-5 · i18n — 3,5/5

| Contrôle | Score | Preuve / justification |
|---|---|---|
| Clés ARB synchronisées | 3/3 | `node audit/tools/diff_arb.js` : « Clés app_fr.arb : 1416 / app_en.arb : 1416 / Orphelines : 0 / ✅ Clés strictement synchronisées. » `flutter gen-l10n` passe (warning `synthetic-package` non bloquant). |
| Aucune chaîne UI en dur | **0,5/2 (−1,5)** | Chaînes françaises en dur nombreuses dans les écrans d'administration : `user_management_screen.dart:282,298,377,439,471-477`, `user_detail_screen.dart:339,682,713,732,744,763,797,854,861,877,895`, `account_settings_screen.dart:154,501,514,532,547,565,702`, `role_detail_screen.dart:438`, `issue_detail_screen.dart:252`. Un anglophone admin verra du français. |

### KPI-6 · Tests & qualité — 9,5/10

| Contrôle | Score | Preuve / justification |
|---|---|---|
| npm test auth-service | 3/3 ⚠️ | **159/160**. L'unique échec (`tests/auth.test.js:123` — `/health` renvoie `degraded` au lieu de `ok`) est dû à un **appel réseau réel** vers Keycloak/Brevo depuis l'environnement de test (handle `TLSWRAP` ouvert détecté par Jest). Échec d'environnement, non pénalisé — mais le défaut d'isolation est classé au top 10. |
| npm test db-service | 3/3 | **113/113 passed** (2 suites). |
| flutter analyze --no-fatal-infos | 3/3 | **0 error, 0 warning, 89 infos** (curly_braces, deprecated `value`→`initialValue`…). Passe. |
| Tests Jest conformes | **0,5/1 (−0,5)** | `DB_PATH=':memory:'` et mock `express-rate-limit` présents (`auth.test.js:7,50`, `featureFlags.test.js:7,39`). **Écart** : le test `/health` (`tests/auth.test.js:121`) dépend de la connectivité externe — non hermétique. |

### KPI-7 · Documentation à jour — 4/10

| Contrôle | Score | Preuve / justification |
|---|---|---|
| Endpoints documentés | **1,5/4 (−2,5)** | Absents de `contexte/context.md` : tout le module **`/api/departments`** (6 routes, `departments.js`), **`/api/analytics`**, **`/api/features`** db-service, **`/api/admin/backups`** (4 routes), **`/api/notifications`** push (6 routes), `GET /api/equipment/by-tag/:tagNumber`, `GET /api/issues/:id/assignable-technicians`, les routes **role-request/role-requests** (3), `GET /api/users/:id`, `POST /api/users/:id/send-verify-email`, `GET /api/roles/:name/permissions|hierarchy|users`, `POST /api/auth/forgot-password`. **Erreur factuelle** : `context.md:150-157` décrit `POST /api/auth/access-request` comme « enregistre une demande pending pour traitement admin » alors que le code **crée immédiatement le compte Keycloak** avec rôle hospitalStaff et mot de passe permanent (`auth-service/src/routes/auth.js:161-224`). |
| Schémas DB documentés | **2/4 (−2)** | Tables réelles absentes de la doc : `push_subscriptions`, `features` + `feature_role_overrides` (côté **db-service**, `database.js:381-402` — ne pas confondre avec `feature_flags` auth-service documentée), `backup_settings`, `backup_history` (`database.js:422-429`), `notifications` (`database.js:793`), `role_hierarchy` (auth-service, cf. `roles.js:138`). Colonnes `issues.location_text/location_tag` (`database.js:148-149`) non documentées. `context.md:265` (« fallback HS256 shim ») et `context.md:667-677` (« verifyToken : JWT_SECRET partagé », défaut `kabutare-hospital-secret-key...`) sont **obsolètes** — le code est 100 % JWKS RS256. `contexte.md:36-37` : « 14 permissions » — il en existe au moins 16 (`manageFeatures`, `manageBackups` — `flutter-app/lib/main.dart:272-273`). |
| Compteur d'écrans exact | **0,5/2 (−1,5)** | **23 fichiers** dans `flutter-app/lib/screens/` vs section « Écrans (15) » (`context.md:872`). Non listés : `equipment_detail_screen.dart`, `user_detail_screen.dart`, `role_detail_screen.dart`, `analytics_screen.dart`, `feature_management_screen.dart`, `backup_management_screen.dart` (+ `issue_staff_detail_screen` mentionné §3.1 mais absent du tableau). |

### KPI-8 · Standards GMAO — 17,5/20

| Standard | Score | Preuve / justification |
|---|---|---|
| MTTR | **2/3 (−1)** | Calculable par `AVG(julianday(updated_at) − julianday(created_at))`. **Limite structurelle** : pas de colonne `resolved_at` dans `issues` (`db-service/src/database.js:49-64`) — toute mutation post-clôture (note, réassignation) fausse le MTTR. Affiché dans ReportsScreen (FEAT-036). Valeur réelle non mesurable localement (0 incident dans le snapshot). |
| MTBF | 3/3 ⚠️ | Schéma complet (`issues.equipment_id` + `created_at` indexés). Requête annexe A exécutée sans erreur — résultat vide faute de données locales. |
| Taux de conformité PM | 4/4 ⚠️ | `preventive_maintenance_plans` (`database.js:322-331` : `frequency_months`, `last_completed_date`) + index unique par équipement (`database.js:346`). Calcul JCI possible tel quel. ⚠️ Table absente du snapshot local (antérieur au module PM) — valeur non mesurée. |
| Taux de disponibilité | 3/3 | Mesuré sur le snapshot local (pré-migration FR→EN) : **77,1 %** ((259 « En service » + 3 « Disponible ») / 340). Le service applique la migration de statuts au démarrage (`database.js`, cf. context.md §2.2) — en prod la requête annexe A fonctionne directement. |
| Historique PM consultable | **1,5/2 (−0,5)** | Colonnes FEAT-044 présentes (`database.js:352-366`) et alimentées par `POST /api/equipment/:id/maintenance` (`equipment.js:372-505` : checklist_snapshot, duration_minutes, parts_used, maintenance_type). Remplissage **réel** non vérifiable localement (colonnes absentes du snapshot) — capacité prouvée, usage non prouvé. |
| Alerte stock + déstockage auto | 2/2 | Statut calculé (`Rupture` si stock=0, `Faible` si <min — `inventory.js`) ; déstockage transactionnel depuis incident avec rollback 409 si stock insuffisant (`issues.js:274-286`) et depuis PM (`parts_used`, `equipment.js`). |
| Notifications PM + escalade | **1/2 (−1)** | Job quotidien J-7/J-0 → `pm_due` vers techniciens + superviseurs (`db-service/src/jobs/pm_reminder_job.js:53-60`, `index.js:30`). **Escalade automatique des incidents non résolus après délai : absente** (exigence 4.3 du cahier des charges) — seule l'escalade *manuelle* existe (`PATCH /api/issues/:id/escalate`, `issues.js:394`). |
| Export Excel/PDF | 1/1 | Export CSV (EquipmentListScreen, IssueTrackingScreen) + PDF multi-sections côté client (`PdfReportService`, FEAT-036/039), conditionnés par `canGenerateReports`. Exigence 4.6 couverte (CSV ≈ Excel). |

---

## Trouvailles critiques

| # | Sévérité | Constat | Preuve |
|---|---|---|---|
| 1 | **Critique** | `POST /api/auth/access-request` crée **immédiatement** un compte Keycloak actif (mot de passe permanent, login direct) sans validation admin ni vérification d'email, sur un endpoint **public** et **sans rate-limiter** (les limiters de `index.js:51-71` couvrent `/login`, `/register`, `/forgot-password` — pas `/access-request`). Création de comptes en masse possible ; la doc décrit un flux « pending » qui n'existe plus. | `auth-service/src/routes/auth.js:161-224`, `auth-service/src/index.js:51-71` |
| 2 | **Majeur** | Mutations de rôles **sans audit trail** : création, modification de permissions et suppression de rôles ne laissent aucune trace dans les logs — précisément les opérations les plus sensibles du RBAC. | `auth-service/src/routes/roles.js:56,96,179` |
| 3 | **Majeur** | `GET /api/users?role=X` expose noms + emails de tous les porteurs d'un rôle à tout utilisateur authentifié (y compris `hospitalStaff`). | `auth-service/src/routes/users.js:40-47` |
| 4 | **Majeur** | Fallback `INTERNAL_SECRET` connu en dur : si la variable d'environnement manque en prod, le secret inter-services est celui du dépôt public. Un warning console ne suffit pas — le service devrait refuser de démarrer en production. | `db-service/src/config.js:5`, `auth-service/src/config.js:5,21-22` |
| 5 | **Majeur** | Pas d'escalade automatique des incidents non résolus (exigence 4.3 du cahier des charges) — seul un endpoint manuel existe. | `contexte/resume_need_software_kabutare.md:59-61` vs `db-service/src/routes/issues.js:394` |

## Top 10 des correctifs priorisés (impact × effort)

| # | Correctif | Impact | Effort | Fichiers |
|---|---|---|---|---|
| 1 | Rate-limiter + (idéalement) vérification d'email ou validation admin sur `/api/auth/access-request` | Critique | Faible | `auth-service/src/index.js`, `routes/auth.js` |
| 2 | Ajouter `sendLog` sur les 3 mutations de `roles.js` + `PUT /api/sidebar/config` | Majeur | Faible | `auth-service/src/routes/roles.js`, `db-service/src/routes/sidebar.js` |
| 3 | Restreindre `GET /api/users?role=X` (admin/supervisor/technicien) ou ne renvoyer que id+nom | Majeur | Faible | `auth-service/src/routes/users.js:40` |
| 4 | Refuser le démarrage en prod (`NODE_ENV=production`) si `INTERNAL_SECRET` est la valeur par défaut | Majeur | Faible | `*/src/config.js` |
| 5 | Job d'escalade automatique : incidents `Reported`/urgents non pris en charge après N heures → notification superviseurs (réutiliser le pattern `pm_reminder_job`) | Majeur | Moyen | `db-service/src/jobs/` |
| 6 | Ajouter une colonne `resolved_at` à `issues` (migration additive) et la renseigner au passage à `Completed` — MTTR fiable | Majeur | Faible | `db-service/src/database.js`, `routes/issues.js` |
| 7 | Remettre `contexte/context.md` à niveau (endpoints, tables, écrans, §2.5/2.6 obsolètes, access-request) | Majeur | Moyen | `contexte/context.md` (fait partiellement par cet audit) |
| 8 | Internationaliser les chaînes en dur des écrans admin (user_management, user_detail, account_settings, role_detail, issue_detail) | Moyen | Moyen | `flutter-app/lib/screens/*` |
| 9 | Isoler le test `/health` auth-service (mocker fetch Keycloak/Brevo) — supprime l'échec env et le handle TLSWRAP | Moyen | Faible | `auth-service/tests/auth.test.js`, `routes/debug.js` |
| 10 | Remplacer les 5 `Color(0xFF…)` inline par `AppColors` + ajouter sendLog sur department-request/role-request | Mineur | Faible | `technician_update_screen.dart:2712-2724`, `resolution_bar_chart.dart:27`, `kanban_board.dart:190` |

## KPIs métier mesurés

| KPI | Valeur | Source / limite |
|---|---|---|
| Disponibilité globale | **77,1 %** (262/340 équipements) | Snapshot local `db-service/hospital.db` **pré-migration** (statuts FR : 259 « En service », 46 « En maintenance », 9 « Hors service », 9 « Transféré », 8 « Inactif », 6 « À éliminer », 3 « Disponible ») — proxy, la base de prod diffère |
| MTTR | Non mesurable localement | 0 incident dans le snapshot ; structurellement approximé par `updated_at` (pas de `resolved_at`) |
| MTBF | Non mesurable localement | 0 incident dans le snapshot ; schéma prêt |
| Conformité PM | Non mesurable localement | Table `preventive_maintenance_plans` absente du snapshot (antérieur au module PM) ; schéma de prod prêt |
| Alerte stock | Non mesurable localement | Table `inventory` vide dans le snapshot ; calcul auto vérifié dans le code |

## Limites de l'audit

1. **Base locale obsolète** : `db-service/hospital.db` (400 Ko) date d'avant le module PM v3 et la migration de statuts FR→EN — tables `preventive_maintenance_plans`, `pm_protocols`, colonnes FEAT-044 absentes, 0 incident. Les KPIs métier ont été audités en *capacité du schéma/code* ; les valeurs réelles doivent être mesurées sur la base de prod (`docker exec db-service-prod`).
2. **Keycloak non joignable** : les comportements Admin API (création users/rôles) sont audités sur code + tests mockés, pas en intégration réelle.
3. **Échantillonnage** : codes HTTP (10 routes), schéma logAction (8 appels), chaînes en dur (écrans admin) — non exhaustif.
4. **Skill non invocable en session courante** : `.claude/skills/audit-gmao-kpi/SKILL.md` créé pendant l'audit ; le harnais charge les skills au démarrage — il sera invocable (`/audit-gmao-kpi`) à la prochaine session. La méthodologie du skill a été appliquée manuellement à l'identique.
5. **`verification/suivi_verifications.xlsx`** et l'environnement Python n'ont pas été audités (hors périmètre grille).
