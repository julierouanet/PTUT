# Audit de conformité — Rwanda Hospital Accreditation Standards (3e édition, août 2022)

> **Application auditée** : GMAO Kabutare — Module 1 (Équipements & Maintenance)
> **Date de l'audit** : 2026-06-12
> **Référentiel** : Rwanda Hospital Accreditation Standards — Performance Assessment Toolkit, 3rd Edition (11 Aug 2022), 167 p.
> **Périmètre** : 11 standards directement ou partiellement couverts par le Module 1.
> **Méthode** : notation 0–3 de chaque niveau d'effort (L1/L2/L3), score standard = L1×1 + L2×2 + L3×3 (max 18).
> **Important** : l'audit évalue ce que l'application **supporte techniquement**, pas l'usage réel par l'hôpital.

---

## 1. Résumé exécutif

L'application obtient **72/198 points (≈ 36 %)** sur les 11 standards du périmètre. Elle est **forte là où c'est critique** : RA3 S1 (infrastructure/PPM, 14/18) et RA3 S5 ★ biomédical (12/18) sont les deux meilleurs scores, portés par l'inventaire complet avec tags, les protocoles PM avec checklists, l'historique de maintenance et le taux de conformité PM. Le système d'incidents (RA5 S6, 8/18) est solide mais ignore les notions de *near miss*, événement sentinelle et analyse des causes racines. Les standards eau/déchets/médicaments (RA3 S6, S16, RA4 S21) ne sont couverts que marginalement — c'est attendu, ils relèvent des futurs Modules 2 et 7. **Verdict : bon socle d'accréditation pour RA3 S1/S5, avec 4 quick wins identifiés qui feraient passer RA3 S5 à ~16/18.**

---

## 2. Analyse par standard

### RA1 S4 — Management of health information (PDF p. 23-24)

**L1 : 1** — Présent : collecte de données structurée et validée par whitelists serveur (`db-service/src/routes/issues.js:48-51`, `equipment.js:10-17`), contrôle d'accès RBAC (`verifyToken`/`requireRole` sur toutes les routes), confidentialité (JWT RS256, audit des accès). Manque : le standard vise l'information *sanitaire* (DHIS-2, audits de dossiers patients, registres) — hors périmètre du Module 1 ; aucun module de politiques/procédures.
**L2 : 1** — Présent : la gestion des données est forcée par le code (validation, statuts whitelistés, horodatage automatique `created_at`/`updated_at`). Manque : aucun export DHIS-2 ni transmission mensuelle MOH.
**L3 : 1** — Présent : les données sont exploitables pour la décision — endpoint `GET /api/analytics` avec filtres de période (`db-service/src/routes/analytics.js:12-83`), dashboard KPI, rapports PDF 6 sections. Manque : contrôle qualité des données (valeurs extrêmes, données manquantes), rapports mensuels avec courbes de tendance.
**Score** : **6/18**
**Fichiers de preuve** : `db-service/src/database.js:78-97` (table `logs`), `analytics.js:12`, `auth-service/src/utils/logger.js`.
**Gaps critiques** : pas d'export DHIS-2/MOH ; pas de revue qualité des données.

---

### RA1 S6 — Risk management (PDF p. 27-28)

**L1 : 1** — Présent : la table `issues` constitue un registre d'événements opérationnels avec catégorie (`Biomedical`/`Infrastructure`/`IT`), urgence (`Faible`→`Critique`) et responsable (`assigned_group`, `assigned_technician`) ; la criticité ABC des équipements (`equipment.criticality`, `database.js:542`) est une classification de risque. Manque : pas de *registre des risques* au sens du standard (probabilité × impact, risques cliniques/financiers/médico-légaux, propriétaire du risque) ni de plan de gestion des risques.
**L2 : 1** — Présent : responsabilité assignée par incident, workflow de prise en charge avec horodatage `taken_at` (`database.js:152`), mise à jour tracée. Manque : pas de leader désigné « risk management », pas de suivi de formation.
**L3 : 1** — Présent : agrégation et affichage des données d'incidents (dashboard alertes ≥24h, analytics, rapport PDF section 3). Manque : plans de réduction de récurrence, suivi PDSA.
**Score** : **6/18**
**Fichiers de preuve** : `db-service/src/database.js:211-232` (schéma issues), `issues.js:48-51`, `equipment.js:17`.
**Gaps critiques** : pas de registre des risques avec impact/probabilité ; pas de module d'actions correctives.

---

### RA3 S1 — Infrastructure, utilities, resources & equipment (PDF p. 74-75)

**L1 : 2** — Présent : référentiel complet infra/équipements/mobilier via les 3 macro-catégories (`Biomedical`/`Infrastructure`/`IT`, `database.js:453-463`), ~626 sous-catégories, table `locations` (bâtiment + département), checklists d'équipement par protocole PM (`pm_protocols.checklist` JSON, `database.js:571-582`), PPM planifiée pour infrastructure ET équipements. Manque : pas de module « plan » documenté revu avec le plan stratégique (critère documentaire).
**L2 : 3** — Tous les critères sont supportés : inspections routinières via incidents type `Inspection` (`issues.js:50`) et `maintenance_records` ; chaque équipement de chaque service peut figurer au calendrier PPM (`preventive_maintenance_plans`, `database.js:321-332` + `next_preventive_maintenance` dénormalisé) ; preuves documentées de maintenance — demandes (issues), complétion (statuts `Completed`/`Verified`/`Closed`), et enregistrements PPM (`maintenance_records.maintenance_type`, `checklist_snapshot`, `duration_minutes`, `database.js:351-367`).
**L3 : 2** — Présent : listes d'inventaire ✓, checklists ✓, enregistrements PPM ✓, complétion des demandes ✓ ; agrégation et tendances via rapports PDF par période et analytics. Manque : génération de plans d'action à partir de l'analyse.
**Score** : **14/18** ✅
**Fichiers de preuve** : `database.js:321-367, 453-582`, `equipment.js:372` (POST maintenance), `equipment.js:507` (PUT pm-plan), `flutter-app/lib/services/pdf_report_service.dart:119-296`.
**Gaps critiques** : module « plans d'action » manquant (seul frein vers 18).

---

### RA3 S5 ★ — Biomedical equipment safety (PDF p. 83-84) — CRITIQUE

**L1 : 2** — Présent : inventaire **complet** des biomédicaux (table `equipment` + macro-catégorie `Biomedical`) ; numéro d'inventaire attaché à chaque pièce ✓✓ (`equipment_tags`, 1 équipement → N tags physiques, `database.js:111-117` ; recherche par tag `equipment.js:72`). Données de remplacement présentes (`manuf_year`, `install_date`, `warranty_end_date`, `criticality`, statuts `To be disposal`/`Disposed`) **mais aucun module formel de plan de remplacement** ; suivi de formation du personnel hors périmètre.
**L2 : 2** — Présent : étiquette PDF de maintenance avec date d'intervention et prochaine échéance, imprimable et collable sur l'équipement (`equipment.js:545` GET `/:id/maintenance-label/:record_id`) — répond directement au critère « tagged with date of inspection and next due date » ; enregistrements montrant inspection/test/maintenance planifiés (`maintenance_records` + plans PM avec fréquence + rappels email J-7/J0 automatiques, `db-service/src/jobs/pm_reminder_job.js:56-82`) ; technicien tracé par intervention (`technician_id`). Manque : documentation de formation dans les dossiers du personnel (hors app).
**L3 : 2** — Présent : **l'application EST le « biomedical maintenance software »** cité par le standard — le rapport reflète le plan de maintenance (taux de conformité PM = % d'équipements sans PM en retard, `pdf_report_service.dart:139, 228-246` ; filtre « PM en retard » dans EquipmentListScreen) ; analyse des pannes par période/département possible via rapports. Manque : rapport trimestriel formalisé des types de pannes au comité de sécurité ; module d'actions de réduction des risques.
**Score** : **12/18** ✅
**Fichiers de preuve** : `database.js:111-117, 541-542`, `equipment.js:72, 372, 507, 545`, `pm_reminder_job.js`, `pdf_report_service.dart:227-283`.
**Gaps critiques** : ① plan de remplacement formel absent (données déjà en base) ; ② pas d'analyse trimestrielle des pannes par type ; ③ pas de champ `resolved_at` → MTTR approximé (admis dans le PDF généré lui-même, `pdf_report_service.dart:277`).

---

### RA3 S6 — Stable safe water sources (PDF p. 85-86)

**L1 : 0** — Rien ne couvre le plan de gestion de l'eau (sources, stockage, approvisionnement d'urgence, budget, autonomie en jours).
**L2 : 1** — Présent : les châteaux d'eau, pompes et plomberie peuvent être enregistrés comme équipements `Infrastructure` (mots-clés `plumbing`, `pump` dans le mapping, `database.js:493-499`) avec incidents et maintenance tracés. Manque : propreté des conteneurs, disponibilité des kits de test.
**L3 : 0** — Tests hebdomadaires (pH, biologique, chimique) impossibles à planifier : la fréquence PM est en **mois** uniquement (`frequency_months`, `database.js:325`).
**Score** : **2/18** ❌
**Gaps critiques** : fréquence PM mensuelle minimum bloque les tests hebdomadaires ; pas de typologie « test/traitement d'eau ». Relève surtout du futur Module 2.

---

### RA3 S7 — Stable electricity sources (PDF p. 87-88)

**L1 : 1** — Présent : générateurs, UPS, équipements électriques inventoriés (catégorie `Electrical Equipment` → Infrastructure, `database.js:521`) ; la criticité `A` permet d'identifier les équipements critiques nécessitant un secours. Manque : plan de gestion de l'énergie, plan de site affiché, identification formelle des zones critiques (NICU, bloc…).
**L2 : 2** — Présent : les sources d'énergie alternatives peuvent être **incluses au calendrier de maintenance préventive planifiée** (plan PM sur un générateur) avec interventions documentées — critère central du niveau. Manque : compétence du personnel (interviews, hors app).
**L3 : 1** — Présent : les tests **trimestriels** des batteries/UPS sont planifiables (`frequency_months = 3`) et documentables (`maintenance_records` + `checklist_snapshot`). Manque : test **hebdomadaire** documenté du générateur (fréquence mois uniquement) ; suivi du stock carburant.
**Score** : **8/18** ⚠️
**Fichiers de preuve** : `database.js:325, 493-535`, `equipment.js:372`.
**Gaps critiques** : pas de fréquence PM hebdomadaire ; pas de checklist « niveau carburant ».

---

### RA3 S16 — Storage and disposal of infectious medical waste (PDF p. 101)

**L1 : 0** — Aucune politique/procédure de gestion des déchets dans l'app.
**L2 : 1** — Présent : incinérateur et sites de stockage enregistrables comme équipements Infrastructure (mot-clé `incinerator`/`waste`, `database.js:496-498`) avec maintenance et incidents tracés (« well maintained and secure »). Manque : ségrégation, étiquetage, EPI.
**L3 : 1** — Présent : un système d'inspection **au moins mensuel** est planifiable (plan PM `frequency_months = 1` sur l'incinérateur/zone de stockage) avec résultats documentés en `maintenance_records`. Manque : rapport au comité IPC, actions correctives.
**Score** : **5/18** ❌
**Gaps critiques** : relève du futur Module 2 (Santé Environnementale) — la feature flag `environmental_health_module` existe déjà, désactivée (`database.js:415`).

---

### RA4 S21 — Safe medication use (PDF p. 141-142)

**L1 : 0** — Aucune gestion des qualifications du pharmacien ni des politiques médicamenteuses.
**L2 : 1** — Présent : l'absence de rupture de stock des essentiels est traçable — `inventory` avec catégorie `Consommable médical` (`inventory.js:51`), `min_stock`, statut calculé `Normal`/`Faible`/`Rupture`. Manque : chaîne du froid, stupéfiants, médicaments à haut risque.
**L3 : 1** — Présent : données de contrôle de stock (stock insuffisant/manquant ✓ via statuts + section « Inventaire critique » du rapport PDF, `pdf_report_service.dart:284`). Manque : **pas de date de péremption** dans `inventory` (`database.js:66-76`) ; pas d'événements indésirables ni d'erreurs médicamenteuses.
**Score** : **5/18** ❌
**Gaps critiques** : champ `expiry_date` absent de la table `inventory` ; le médicament en tant que tel relève du futur Module 7 (Logistique).

---

### RA5 S1 — Quality and safety program (PDF p. 152-153)

**L1 : 1** — Présent : des indicateurs qualité/sécurité **mesurés en continu avec définition et formule claires** : taux de disponibilité, taux de résolution, MTTR, conformité PM (`pdf_report_service.dart:119-145` ; hint explicite « % of equipment with PM not overdue », `app_localizations_en.dart:3861`). Manque : fiche de poste QI Officer, plan qualité hospitalier, comité.
**L2 : 1** — Présent : suivi périodique possible (rapports filtrés par période → revue trimestrielle réalisable). Manque : tout le volet comité/formation.
**L3 : 0** — Aucun support d'évaluation annuelle du plan qualité ni de fixation d'objectifs.
**Score** : **3/18** ❌
**Gaps critiques** : pas d'indicateurs paramétrables avec cibles ; relève en grande partie du futur Module 3 (Accréditation).

---

### RA5 S5 — Clinical outcomes are monitored (PDF p. 158-159)

**L1 : 1** — Le standard vise les **résultats cliniques** (mortalité maternelle/néonatale, indicateurs EIDSR) — hors périmètre. L'app contribue indirectement : indicateurs définis avec formule pour la disponibilité des équipements supportant les conditions à haut risque, collecte exacte et horodatée.
**L2 : 1** — Agrégation, analyse et comparaison temporelle supportées pour les données *équipements* (rapports par période) — pas pour les données cliniques.
**L3 : 0** — Aucune comparaison de résultats cliniques inter-départements/inter-hôpitaux/benchmarks possible.
**Score** : **3/18** ❌
**Gaps critiques** : standard intrinsèquement clinique — l'app n'y contribuera jamais qu'indirectement (fiabilité du plateau technique).

---

### RA5 S6 — Incident, near miss and sentinel event reporting (PDF p. 160-161)

**L1 : 1** — Présent : le « manner in which reporting takes place » est entièrement outillé — signalement multicanal (sidebar, dashboard, bottom nav) avec pré-qualification par catégorie, formulaire structuré, photos (max 5, `issues.js:476`), accessible à tous les rôles (`reportIssue` pour `hospitalStaff`). Manque : définitions et types **near miss / événement sentinelle** absents (`VALID_ISSUE_TYPES = ['Panne','Maintenance','Inspection','Autre']`, `issues.js:50`) ; pas de processus RCA ; pas de volet « just culture ».
**L2 : 2** — Présent : rapports soumis depuis chaque département ✓ (`issues.department`), **catégorisés par type, sévérité, personnes et lieux** ✓✓ (type, `urgency` 4 niveaux, `reporter`/`reporter_id`/`assigned_technician`, `location_id`/`location_text`) ; gestion selon un workflow horodaté à 9 statuts avec prise en charge tracée (`taken_at`) et audit complet de chaque mutation ; le déclarant est informé du suivi (notifications email Brevo + push + in-app, `notifications` table `database.js:793-808`, préférences FEAT-029). Manque : délais réglementaires configurables, outils nationaux de revue.
**L3 : 1** — Présent : données agrégées, analysées et affichées ✓ (dashboard incidents prioritaires + alertes ≥24h, `analytics.js:49-60`, rapport PDF section 3). Manque : plans anti-récurrence, leçons apprises, cycle PDSA.
**Score** : **8/18** ⚠️
**Fichiers de preuve** : `issues.js:48-51, 146, 253, 394, 434, 476`, `database.js:211-232, 793-808`, `analytics.js`.
**Gaps critiques** : types near miss/sentinelle absents ; pas de module RCA/leçons apprises.

---

## 3. Matrice de conformité

| Standard | Titre | Score /18 | Statut |
|---|---|---:|---|
| **RA3 S1** | Infrastructure, utilities & equipment | **14** | ✅ Conforme (socle solide) |
| **RA3 S5 ★** | Biomedical equipment safety | **12** | ✅ Conforme (socle solide) |
| RA3 S7 | Stable electricity sources | 8 | ⚠️ Partiel |
| RA5 S6 | Incident & near miss reporting | 8 | ⚠️ Partiel |
| RA1 S4 | Management of health information | 6 | ⚠️ Partiel |
| RA1 S6 | Risk management | 6 | ⚠️ Partiel |
| RA3 S16 | Infectious medical waste | 5 | ❌ Non couvert (Module 2) |
| RA4 S21 | Safe medication use | 5 | ❌ Non couvert (Module 7) |
| RA5 S1 | Quality and safety program | 3 | ❌ Non couvert (Module 3) |
| RA5 S5 | Clinical outcomes monitored | 3 | ❌ Hors périmètre app |
| RA3 S6 | Stable safe water sources | 2 | ❌ Non couvert (Module 2) |
| **TOTAL** | | **72/198 (36 %)** | |

---

## 4. Top 5 des gaps les plus bloquants pour l'accréditation

1. **Pas de plan de remplacement formel des biomédicaux** (RA3 S5 L1 — standard ★ critique). Toutes les données existent déjà (`manuf_year`, `install_date`, `warranty_end_date`, `criticality`, statuts de fin de vie) mais aucun écran/rapport ne les consolide en plan de remplacement.
2. **Pas de champ `resolved_at` sur les incidents** → MTTR approximé (limite reconnue dans le rapport PDF lui-même) et impossibilité de prouver le respect des délais de traitement (RA3 S5 L3, RA5 S6 L2).
3. **Types « near miss » et « événement sentinelle » absents** du système d'incidents, et aucun support d'analyse des causes racines (RA5 S6 L1) — le vocabulaire du standard n'est pas représentable.
4. **Fréquence PM en mois uniquement** : les tests hebdomadaires exigés (générateur RA3 S7 L3, eau RA3 S6 L3) ne sont pas planifiables.
5. **Aucun module transverse d'actions correctives / plans d'action** (PDSA) — bloque le passage au L3 de quatre standards (RA3 S1, RA3 S5, RA1 S6, RA5 S6).

---

## 5. Roadmap recommandée

### Quick wins (petits développements, gros impact accréditation)

| # | Développement | Standards impactés | Effort |
|---|---|---|---|
| 1 | Colonne `issues.resolved_at` (posée au passage en `Completed`) + MTTR strict dans les rapports | RA3 S5, RA5 S6, RA5 S1 | ~1 jour |
| 2 | Écran/rapport **« Plan de remplacement »** : tableau calculé âge × criticité × garantie × statut, exportable PDF | RA3 S5 L1 → 3 | ~2-3 jours |
| 3 | Ajouter `Near miss` et `Événement sentinelle` à `VALID_ISSUE_TYPES` + champ `severity` distinct de l'urgence + i18n | RA5 S6 L1 → 2 | ~1-2 jours |
| 4 | `frequency_days` (ou `frequency_weeks`) en complément de `frequency_months` dans les plans PM → tests hebdo générateurs/eau | RA3 S7, RA3 S6 | ~1-2 jours |
| 5 | Champ `expiry_date` sur `inventory` + alerte péremption dans la section « Inventaire critique » | RA4 S21 L3 | ~1 jour |
| 6 | Rapport trimestriel automatique « pannes par type d'équipement » (agrégation `issues` × `subcategory`) destiné au comité de sécurité | RA3 S5 L3 → 3 | ~2 jours |

### Développements lourds (features majeures, à planifier)

| # | Développement | Standards impactés |
|---|---|---|
| A | **Registre des risques** : table `risks` (catégorie, impact, probabilité, propriétaire, actions, revue) | RA1 S6 → ~12 |
| B | **Module actions correctives / PDSA** : actions liées à un incident ou une analyse, avec suivi de réalisation | RA1 S6, RA3 S1, RA3 S5, RA5 S6 (déblocage L3) |
| C | **Module RCA** : analyse des causes racines liée aux incidents critiques/sentinelles | RA5 S6 L1-L2 |
| D | **Indicateurs qualité paramétrables** (définition, formule, cible, fréquence) + tableau de bord comité qualité | RA5 S1 — cœur du futur Module 3 |
| E | Modules 2 (déchets, eau) et 7 (pharmacie/stocks médicaments) du PTUT | RA3 S6, S16, RA4 S21 |

### Standards atteignables au niveau 3 avec des ajouts mineurs

- **RA3 S5 ★** : quick wins 1 + 2 + 6 → **~16-17/18**. C'est la cible prioritaire : standard critique, et l'app est déjà le « biomedical maintenance software » que le standard cite comme preuve.
- **RA3 S1** : déjà 14/18 ; le module actions correctives (B) le porterait à ~17/18.
- **RA5 S6** : quick wins 1 + 3 + module RCA léger → **~12-13/18**.
- **RA3 S7** : quick win 4 + checklist carburant générateur → **~12/18**.

---

*Audit réalisé en lecture seule sur le code (branche `dev`, commit a7361d2). Pages du référentiel citées : 23-28, 74-75, 83-88, 101-102, 141-142, 152-153, 158-161.*
