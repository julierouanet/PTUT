# Rapport d'audit UX « œil neuf » — Parcours de signalement d'incident

| | |
|---|---|
| **Date** | 2026-07-08 |
| **Méthode** | Audit multi-agents : 5 agents « novices » indépendants (un par segment, sans visibilité croisée), passe dynamique (repli statique, voir Limitations), agent contradicteur vérifiant chaque preuve `fichier:ligne` dans le code réel |
| **Persona** | `hospitalStaff` (infirmier/médecin), première utilisation, permissions `viewEquipment` / `reportIssue` / `trackIssues` |
| **Langues** | FR + EN (clés ARB `app_fr.arb` / `app_en.arb`) |
| **Périmètre** | ① Points d'entrée → ② Sélecteur de catégorie → ③ Formulaire étape 1 → ④ Étape 2 + soumission → ⑤ Suivi |

**Sévérités** : `bloquant` = le novice se trompe de chemin ou abandonne ; `gênant` = hésitation, essai-erreur ; `mineur` = friction cosmétique.
**Couverture** : `E` = corrigé dans cette session (libellés ARB uniquement) ; `F-<n>` = couvert par le prompt d'implémentation de la page n ; `—` = documenté sans action (mineur non ARB sur une page sans gênant résiduel).

---

## 1. Résumé exécutif

**50 constats uniques** produits par les agents novices, **tous passés au contradicteur** : **36 confirmés, 14 requalifiés (sévérité corrigée), 0 réfuté**. Les 5 constats proposés « bloquant » ont tous été ramenés à « gênant » après vérification d'éléments compensateurs dans le code (échappatoires, garde-fous partiels).

| Sévérité finale | Nombre |
|---|---|
| Bloquant | **0** |
| Gênant | **20** |
| Mineur | **30** |

**Top 5 des constats les plus impactants :**

1. **UX-5-01** — L'écran de suivi affiche les statuts en **anglais brut** (« Waiting Materials », « Redirected ») à un utilisateur francophone, alors que les traductions existent dans les ARB et que `localizedName` existe dans le modèle : la seule information que le rapporteur vient chercher est illisible.
2. **UX-3-01** — Le bouton « Signaler par QR Code » (premier widget du formulaire, au-dessus du titre) force l'urgence à **Critique** sans l'annoncer avant le clic (explication uniquement en tooltip) : risque de tickets Critiques injustifiés.
3. **UX-3-08** — La « Recherche rapide » de l'onglet Infrastructure invite en français à taper un mot-clé mais ne matche que les chaînes anglaises du catalogue : « fuite » → zéro résultat, l'utilisateur croit la recherche cassée.
4. **UX-4-05** — En cas d'erreur réseau/serveur à la soumission, la snackbar affiche le jargon brut (`ApiException(500) http://… — …`) : l'infirmière ne sait pas si son signalement est parti (risque d'abandon ou de doublon).
5. **UX-4-03** — Le « N° de ticket » remis à la fin est un horodatage de 13 chiffres, sans bouton copier, jamais réaffiché dans l'écran de suivi : la promesse de traçabilité est vide.

**Faits transverses** : la même action de signalement porte 4 libellés différents selon l'écran (panne/incident/problème/« Signaler » seul — UX-1-01) ; ~15 clés FR du parcours ont des accents manquants (UX-1-09, 3-13, 4-09, 5-09) ; à trois endroits, une version localisée existe dans le code mais n'est pas branchée (`localizedName` statuts, départements, export CSV).

**Actions livrées avec ce rapport** : 24 constats corrigés ou atténués par correctifs de libellés ARB (étape E, FR+EN, `flutter gen-l10n` re-exécuté) ; 4 prompts d'implémentation autosuffisants pour les pages ①, ③, ④, ⑤ (étape F). La page ② n'a aucun constat gênant résiduel → aucun prompt (résultat valide).

---

## 2. Constats par segment

### Segment ① — Découverte & points d'entrée

**UX-1-01 — Terminologie de l'action « signaler »** · gênant · confirmé · **E**
- Libellé cité : FR `navReportIssue` = « Signaler » / EN « Report » ; `hubStaffReportButton` = « Signaler une panne » / « Report a breakdown » ; `dashboardWeatherReportBtn` = « Signaler un incident » / « Report an incident » ; `issuesReport` = « Signaler un incident » / « Report an issue » ; `equipDetailStaffReportButton` = « Signaler une panne » / « Report a breakdown » ; `dashboardReportProblem` = « Signaler un probleme » / « Report a problem »
- Preuve : main.dart:314 ; home_hub_screen.dart:228 ; dashboard_screen.dart:376 ; issue_tracking_screen.dart:374 ; equipment_staff_view.dart:186 ; app_fr.arb:13, 81, 135, 482, 1336, 1380, 1706
- Pourquoi : la même action porte quatre objets différents (panne / incident / problème / rien) ; « incident » est un mot chargé en milieu hospitalier (incident patient).
- Recommandation : un couple unique FR « Signaler une panne » / EN « Report a problem » sur tous les points d'entrée ; réserver incident/issue au suivi.
- Verdict contradicteur : confirmé — les 6 variantes vérifiées dans les ARB et aux points d'appel.

**UX-1-02 — Hub staff : double bouton rouge** · mineur (requalifié de gênant) · **E**
- Libellé cité : FR `hubStaffReportButton` = « Signaler une panne » ET `hubReportUrgentButton` = « Signaler un incident » (même écran, même action)
- Preuve : home_hub_screen.dart:148-158 (FAB) et 222-243 (gros bouton)
- Pourquoi : deux gros boutons rouges aux libellés différents pour la même action, sur le premier écran vu.
- Recommandation : aligner les deux libellés (fait en E) ; option structurelle : supprimer le FAB sur la vue staff.
- Verdict contradicteur : à requalifier mineur — les deux boutons appellent le même sélecteur, aucun choix n'est faux, hésitation auto-corrigée au premier clic.

**UX-1-03 — Tooltip du FAB rouge** · mineur · confirmé · **E**
- Libellé cité : FR `hubReportUrgentTooltip` = « Signaler un incident immédiatement » / EN « Report an incident immediately »
- Preuve : home_hub_screen.dart:158 ; app_fr.arb:483 / app_en.arb:462
- Pourquoi : « immédiatement » + rouge suggère un canal réservé aux urgences vitales.
- Recommandation : tooltip neutre « Signaler une panne d'équipement » / « Report an equipment problem ».
- Verdict contradicteur : confirmé mineur — un tooltip est rarement vu.

**UX-1-04 — Bottom nav mobile : libellé « Signaler » jamais visible** · gênant · confirmé · **F-1**
- Libellé cité : FR `navReportIssueShort` = « Signaler » / EN « Report » (constat structurel : jamais affiché)
- Preuve : app_bottom_nav.dart:34 (`labelBehavior: onlyShowSelected`) + :28-30 (l'item ouvre un modal sans jamais être sélectionné)
- Pourquoi : sur mobile, l'action principale du persona n'est qu'un triangle ⚠ sans texte.
- Recommandation : `labelBehavior: alwaysShow`.
- Verdict contradicteur : confirmé — mécanisme vérifié, le libellé n'apparaît effectivement jamais.

**UX-1-05 — Sidebar/drawer : « Signaler »/« Report » sans objet** · mineur (requalifié de gênant) · **E**
- Libellé cité : FR `navReportIssue` = « Signaler » / EN « Report »
- Preuve : main.dart:314 ; app_sidebar.dart:179 ; app_fr.arb:13
- Pourquoi : en EN, « Report » seul se lit d'abord comme un nom (« rapports »).
- Recommandation : verbe + objet : « Signaler une panne » / « Report a problem ».
- Verdict contradicteur : à requalifier mineur — l'icône ⚠ et l'absence de page « Reports » pour le staff rendent la confusion peu probable.

**UX-1-06 — Fiche équipement (vue staff) : le bouton perd l'équipement affiché** · gênant · confirmé · **F-1**
- Libellé cité : FR `equipDetailStaffReportButton` = « Signaler une panne » / EN « Report a breakdown »
- Preuve : equipment_staff_view.dart:183 (appelle `showIssueCategorySelector` sans paramètre) ; issue_category_selector.dart:56 ; equipment_detail_screen.dart:67-70, 239-241 (hospitalStaff reçoit bien cette vue)
- Pourquoi : l'infirmière est SUR la fiche de l'appareil, clique « Signaler une panne », et doit re-choisir catégorie puis re-chercher l'appareil qu'elle venait de désigner. NB : ne remet pas en cause le chemin `onReport` direct (intentionnel, autres rôles) — il constate son absence en vue staff.
- Recommandation : pré-sélectionner l'équipement affiché depuis la vue staff.
- Verdict contradicteur : confirmé — vue et absence de paramètre vérifiées ; seule la sous-affirmation « le filtre masque l'appareil » est inexacte (l'autocomplétion cherche dans tout l'inventaire).

**UX-1-07 — EN : « Issue Tracking » vs « Incidents »** · mineur · confirmé · **E**
- Libellé cité : FR `navIssueTracking` = « Suivi incidents » / EN « Issue Tracking » ; `navIssueTrackingShort` FR « Incidents » / EN « Incidents »
- Preuve : main.dart:313 ; app_fr.arb:12, 22 / app_en.arb:12, 22
- Pourquoi : le même écran porte deux noms EN selon le device.
- Recommandation : harmoniser la paire courte/longue.
- Verdict contradicteur : confirmé mineur — rattrapé par le bouton de signalement présent sur l'écran.

**UX-1-08 — « Météo de l'hôpital » vs « Hospital Status »** · mineur · confirmé · **E**
- Libellé cité : FR `dashboardWeatherTitle` = « Météo de l'hôpital » / EN « Hospital Status »
- Preuve : dashboard_screen.dart:318 ; app_fr.arb:1330 / app_en.arb:1309
- Pourquoi : métaphore FR absente de l'EN ; les deux langues ne racontent pas la même chose.
- Recommandation : aligner FR sur le sens EN (« État de l'hôpital »).
- Verdict contradicteur : confirmé mineur.

**UX-1-09 — Accents manquants (points d'entrée)** · mineur · confirmé · **E**
- Libellé cité : FR `navEquipment` = « Equipements » ; `dashboardReportProblem` = « Signaler un probleme » ; `issuesSubtitle` = « Gerer et suivre les incidents des equipements »
- Preuve : app_fr.arb:11, 81, 131
- Pourquoi : impression de brouillon, confiance entamée dès la première ouverture.
- Recommandation : corriger les accents.
- Verdict contradicteur : confirmé.

Éléments audités sans constat : visibilité du bouton principal (hub, dashboard, suivi) ; chemin `onReport` direct (intentionnel, hors défaut).

### Segment ② — Sélecteur de catégorie

**UX-2-01 — Tuile Biomédical : exemples de plateau technique** · mineur (requalifié de gênant) · **E**
- Libellé cité : FR `issueCategoryBiomedicalDesc` = « Scanner, IRM, échographe, analyseurs, moniteurs, pompes à perfusion, ventilateurs… » / EN idem
- Preuve : app_fr.arb:934 ; issue_category_selector.dart:24-30
- Pourquoi : les exemples (Scanner, IRM) sont du gros équipement rare en district ; le matériel quotidien (tensiomètre, concentrateur d'oxygène) est absent.
- Recommandation : exemples de matériel de service courant en tête de liste.
- Verdict contradicteur : à requalifier mineur — « moniteurs, pompes à perfusion » figurent déjà, titre sans ambiguïté, ellipse indiquant une liste non exhaustive.

**UX-2-02 — Tuile Infrastructure : titre vs description (lits, fauteuils roulants)** · mineur (requalifié de gênant) · **E**
- Libellé cité : FR `issueCategoryInfrastructure` = « Infrastructure & Électricité » ; desc = « Lits, tables d'examen, fauteuils roulants, éclairage, prises électriques, plomberie… »
- Preuve : app_fr.arb:935-936 ; issue_category_selector.dart:31-37
- Pourquoi : un lit d'hôpital est perçu comme du matériel de soin, pas de l'« infrastructure ».
- Recommandation : renommer « Bâtiment, Mobilier & Électricité ».
- Verdict contradicteur : à requalifier mineur — la description affiche « Lits… » en premier sur la tuile, et le scénario de blocage est faux (l'autocomplétion équipement n'est pas filtrée par catégorie).

**UX-2-03 — Climatisation absente de toutes les descriptions** · mineur (requalifié de gênant) · **E**
- Libellé cité : FR `issueCategoryInfrastructureDesc` (aucune mention clim/ventilation)
- Preuve : app_fr.arb:936 ; catalogue HVAC pourtant complet (issue_form_screen.dart:107-117)
- Pourquoi : pour un climatiseur en panne, aucune tuile ne se désigne ; repli sur « Autre » alors qu'un catalogue HVAC dédié existe.
- Recommandation : ajouter « climatisation » dans la description Infrastructure.
- Verdict contradicteur : à requalifier mineur — le titre « … & Électricité » couvre plausiblement la clim ; une mauvaise tuile ne bloque pas.

**UX-2-04 — « tous les équipements restent disponibles »** · mineur · confirmé · **E**
- Libellé cité : FR `issueCategoryOtherDesc` = « Problème non classé ou dont vous ne connaissez pas la catégorie — tous les équipements restent disponibles. » / EN « …all equipment remains available. »
- Preuve : app_fr.arb:940 / app_en.arb:919
- Pourquoi : phrase de développeur décrivant le filtre interne ; lisible comme « le matériel est encore en stock / fonctionne ».
- Recommandation : reformuler en langage utilisateur (« vous pourrez choisir n'importe quel équipement à l'étape suivante »).
- Verdict contradicteur : confirmé.

**UX-2-05 — Aucune indication que le choix est rattrapable** · mineur (requalifié de gênant) · **—**
- Libellé cité : constat structurel (titre `issueCategorySelectorTitle` sans texte d'aide)
- Preuve : issue_category_selector.dart:119-141 ; onglets réversibles du formulaire (issue_form_screen.dart:405-410)
- Pourquoi : peur de « mal classer » ; le choix est en réalité réversible mais rien ne le dit.
- Recommandation : sous-titre rassurant (nouvelle clé ARB + widget → hors périmètre E ; page ② sans gênant résiduel → pas de prompt).
- Verdict contradicteur : à requalifier mineur — la tuile « Autre / Je ne sais pas » est une échappatoire explicite qui désamorce la peur de mal classer.

**UX-2-06 — Tuiles IT et Autre en couleurs de typographie grisées** · mineur · confirmé · **—**
- Libellé cité : constat structurel
- Preuve : issue_category_selector.dart:41 (`textSecondary`), :48 (`textMuted`)
- Pourquoi : une icône grisée peut évoquer une option désactivée ou de second rang.
- Recommandation : couleurs d'accent dédiées (changement Dart ; page ② sans gênant résiduel → pas de prompt).
- Verdict contradicteur : confirmé mineur — seule l'icône est grisée, fond/bordure identiques.

**UX-2-07 — EN « Scanner » ambigu (bureautique vs imagerie)** · mineur · confirmé · **E**
- Libellé cité : EN `issueCategoryBiomedicalDesc` commençant par « Scanner »
- Preuve : app_en.arb:913
- Pourquoi : en EN, « Scanner » seul évoque d'abord le scanner de documents (tuile IT, à côté de « printers »).
- Recommandation : « CT scanner » en EN.
- Verdict contradicteur : confirmé.

### Segment ③ — Formulaire étape 1

**UX-3-01 — « Scan & Block » : conséquence (urgence Critique) non annoncée** · gênant (requalifié de bloquant) · **E (partiel) + F-3**
- Libellé cité : FR `issueFormScanBlock` = « Signaler par QR Code » / EN « Report by QR Code » ; tooltip `issueFormScanBlockTooltip` = « Mode ultra-rapide : scanner → urgence Critique → 2 champs à remplir »
- Preuve : issue_form_screen.dart:1196 (libellé), 1190 (explication en tooltip uniquement), 682-684 (urgence forcée + saut étape 2) ; trace statique : premier widget de l'écran, au-dessus du titre
- Pourquoi : libellé neutre pour un mode d'urgence maximale ; le tooltip est invisible sur tactile ; risque de tickets Critiques pour des pannes banales.
- Recommandation : libellé annonçant la conséquence (fait en E) + texte visible sous le bouton (F-3).
- Verdict contradicteur : à requalifier gênant — le snackbar « Urgence mise à Critique » arrive avant soumission et le bouton Retour permet de corriger.

**UX-3-02 — Scan QR sur web : fallback texte incompréhensible** · gênant · confirmé · **E (partiel) + F-3**
- Libellé cité : FR `issueFormScanQrFallbackHint` = « ID ou numéro de série de l'équipement » / EN « Equipment ID or serial number »
- Preuve : issue_form_screen.dart:463-464, 571-573 (kIsWeb → dialogue texte), 615-650, 626-631
- Pourquoi : sur le poste web (déploiement principal), pas de caméra : on demande un ID/série sans dire où le lire → abandon de ce chemin.
- Recommandation : indiquer où trouver l'identifiant (fait en E sur le hint) ; recherche par nom dans le dialogue (F-3).
- Verdict contradicteur : confirmé gênant.

**UX-3-03 — Changement d'onglet : perte de saisie sous-protégée** · gênant (requalifié de bloquant) · **F-3**
- Libellé cité : FR `issueFormSwitchTabMessage` = « Les données saisies (description, photos) seront effacées si vous changez d'onglet. Continuer ? »
- Preuve : issue_form_screen.dart:382 + 264-265 (garde-fou limité à description/photos), 405-436 (reset total), 235 (`hasUnsavedData` existant non utilisé)
- Pourquoi : équipement/bâtiment/lieu/urgence sont effacés SANS confirmation ; le message, quand il s'affiche, ne liste pas tout ce qui est perdu.
- Recommandation : confirmation dès qu'un champ d'étape 1 est rempli + message exhaustif.
- Verdict contradicteur : à requalifier gênant — description et photos (le plus coûteux) sont bien protégées ; les champs d'étape 1 se ressaisissent vite.

**UX-3-04 — Hint « Ex: TG-0042 » du champ équipement** · mineur (requalifié de gênant) · **E**
- Libellé cité : FR `issueFormTagNumberHint` = « Ex: TG-0042 » / EN « E.g.: TG-0042 »
- Preuve : issue_form_screen.dart:1580 ; autocomplétion multi-champs 1562-1569
- Pourquoi : seul exemple = un code inconnu ; on ne devine pas que le nom fonctionne.
- Recommandation : hint orienté nom d'abord.
- Verdict contradicteur : à requalifier mineur — le label « Équipement concerné » invite à taper le nom, qui marche avec suggestions immédiates.

**UX-3-05 — Message d'erreur du champ équipement trompeur** · gênant · confirmé · **E**
- Libellé cité : FR `issueFormTagRequired` = « Veuillez saisir un numéro de tag et rechercher l'équipement » / EN « Please enter a tag number and search for the equipment »
- Preuve : issue_form_screen.dart:1589-1590 ; case « Équipement non répertorié » après (1653)
- Pourquoi : après avoir TAPÉ un nom sans cliquer une suggestion, l'erreur parle de « numéro de tag » ; pas de renvoi vers la case « non répertorié ».
- Recommandation : « Sélectionnez un équipement dans les suggestions, ou cochez “Équipement non répertorié” ».
- Verdict contradicteur : confirmé gênant.

**UX-3-06 — Onglet Infrastructure : équipement obligatoire** · gênant (requalifié de bloquant) · **F-3**
- Libellé cité : FR `issueFormRelatedEquipment` = « Équipement concerné * »
- Preuve : issue_form_screen.dart:1709-1726, 453-456 ; le serveur accepte pourtant Infrastructure sans équipement (issues.js:316)
- Pourquoi : pour une toilette bouchée ou un mur fissuré, on exige un « équipement » ; il faut deviner la case « non répertorié » et inventer un nom.
- Recommandation : équipement optionnel sur l'onglet Infrastructure.
- Verdict contradicteur : à requalifier gênant — la case « non répertorié » est visible juste sous le champ : friction et modèle mental faux, pas un cul-de-sac.

**UX-3-07 — Catalogue Infrastructure en anglais** · gênant · confirmé · **F-3**
- Libellé cité : constat structurel (valeurs de référence stockées en DB : « Tripped breaker », « Septic overflow », « Bed crank failure »)
- Preuve : issue_form_screen.dart:22-141 (`_kInfraCatalog`), 1862-1917 (dropdowns affichant les valeurs brutes)
- Pourquoi : les trois listes centrales du formulaire sont en anglais technique dans une UI par ailleurs française ; choix au hasard ou repli sur « Autre ».
- Recommandation : couche d'affichage traduite (valeur EN conservée pour le stockage) — jamais de traduction des valeurs stockées.
- Verdict contradicteur : confirmé gênant — constat d'affichage, recommandation conforme au périmètre.

**UX-3-08 — « Recherche rapide » Infrastructure inopérante en FR** · gênant (requalifié de bloquant) · **F-3**
- Libellé cité : FR `issueFormQuickSearchHint` = « Tapez un mot-clé pour trouver un problème... » / EN « Type a keyword to find an issue... »
- Preuve : issue_form_screen.dart:1819 (hint), 358-376 / 365-367 (`_searchInfraCatalog` ne matche que l'anglais)
- Pourquoi : « fuite », « ampoule » → zéro résultat ; l'utilisateur croit la recherche cassée.
- Recommandation : index de synonymes FR → valeur EN.
- Verdict contradicteur : à requalifier gênant — dropdowns et bouton « Mon problème ne figure pas dans la liste » offrent des replis.

**UX-3-09 — Départements affichés en anglais** · mineur (requalifié de gênant) · **F-3 (secondaire)**
- Libellé cité : FR `commonDepartment` = « Departement » ; items `d.displayName` anglais
- Preuve : issue_form_screen.dart:1737, 1998 ; departments.dart:65 (`localizedName` existant non utilisé)
- Pourquoi : label FR mais liste EN (« Theater », « OPD »).
- Recommandation : `localizedName` à l'affichage, `displayName` vers l'API.
- Verdict contradicteur : à requalifier mineur — dans un hôpital rwandais les départements sont désignés en anglais au quotidien.

**UX-3-10 — « Mon problème ne figure pas dans la liste » placé avant la liste** · mineur · confirmé · **F-3 (secondaire)**
- Preuve : issue_form_screen.dart:1778-1793 (bouton) avant 1796 (recherche) et 1859 (dropdowns)
- Pourquoi : ordre de lecture inversé ; clic par défaut sans avoir essayé le catalogue.
- Recommandation : déplacer sous les dropdowns.
- Verdict contradicteur : confirmé.

**UX-3-11 — Urgence sans aide au choix (SLA révélés trop tard)** · gênant · confirmé · **F-3**
- Libellé cité : FR `urgencyHigh` = « Urgent », `urgencyCritical` = « Critique » / EN « High », « Critical »
- Preuve : issue_form_screen.dart:1509-1534 (4 pastilles sans explication) ; 769-774 + 781 (SLA affichés seulement dans la modale de succès)
- Pourquoi : impossible de trancher Urgent vs Critique sans connaître les délais 2h/12h/48h/1 semaine, qui existent dans le code.
- Recommandation : afficher le SLA sous chaque pastille au moment du choix.
- Verdict contradicteur : confirmé gênant.

**UX-3-12 — Switch « Disponible pour intervention immédiate »** · mineur · confirmé · **E**
- Libellé cité : FR `issueFormEquipmentAvailableLabel` = « Disponible pour intervention immédiate » (hint : « L'équipement peut être mis hors tension pour la réparation »)
- Preuve : issue_form_screen.dart:2253-2280, défaut true (233), affiché aussi sur Infrastructure (1310)
- Pourquoi : le titre ne dit pas QUI est disponible (moi ? le technicien ? l'appareil ?).
- Recommandation : sujet explicite dans le titre.
- Verdict contradicteur : confirmé mineur.

**UX-3-13 — Accents manquants (formulaire)** · mineur · confirmé · **E**
- Libellé cité : FR `issueFormTitle` = « Signaler un probleme », `issueFormSubtitle`, `issueFormProblemType` = « Type de probleme * », `commonDepartment` = « Departement »
- Preuve : app_fr.arb:167, 168, 171, 58
- Verdict contradicteur : confirmé — sur le titre même de l'écran.

**UX-3-14 — EN « Please select » pour des champs de saisie libre** · mineur · confirmé · **E**
- Libellé cité : EN `issueFormBuildingRequired` = « Please select a building », `issueFormLocationRequired2` = « Please select a location » (FR : « saisir »)
- Preuve : app_en.arb:937-938 ; champs texte libres (issue_form_screen.dart:2039-2065)
- Verdict contradicteur : confirmé.

**UX-3-15 — Scan QR absent des onglets IT/Infra/Autre** · mineur · confirmé · **F-3 (secondaire)**
- Preuve : issue_form_screen.dart:1673 (trailingButton Biomédical uniquement) ; Scan & Block accepte pourtant l'IT (666-675)
- Verdict contradicteur : confirmé.

**UX-3-16 — Bouton « OK » codé en dur (dialogue Scan & Block web)** · mineur · confirmé · **F-3 (secondaire)**
- Preuve : issue_form_screen.dart:643 (`const Text('OK')`) vs 540 (dialogue jumeau localisé `issueFormScanQrFallbackConfirm`)
- Verdict contradicteur : confirmé.

### Segment ④ — Étape 2 + soumission

**UX-4-01 — « Délai cible (SLA) »** · gênant · confirmé · **E**
- Libellé cité : FR `issueFormSuccessSlaLabel` = « Délai cible (SLA) » / EN « Target deadline (SLA) »
- Preuve : app_fr.arb:1450 / app_en.arb:1429 ; issue_form_screen.dart:842
- Pourquoi : acronyme informatique + ambiguïté prise en charge/réparation ; risque d'organiser les soins sur une fausse promesse de réparation en 2 h.
- Recommandation : phrase explicite sans acronyme, précisant « prise en charge ».
- Verdict contradicteur : confirmé gênant.

**UX-4-02 — Libellés SLA : vocabulaires mélangés** · mineur · confirmé · **E**
- Libellé cité : FR `issueFormSla2h` = « 2 heures — urgence critique » vs `issueFormSla48h` = « 48 heures — priorité moyenne » ; EN non uniforme aussi (« 12 hours — urgent »)
- Preuve : app_fr.arb:1451-1454 / app_en.arb:1430-1433
- Recommandation : mêmes termes que le sélecteur d'urgence de l'étape 1.
- Verdict contradicteur : confirmé.

**UX-4-03 — Numéro de ticket : 13 chiffres inutilisables** · gênant · confirmé · **F-4**
- Libellé cité : FR `issueFormSuccessTicketId` = « N° de ticket : {id} »
- Preuve : issue_form_screen.dart:984 (id = `millisecondsSinceEpoch`), 782-784, 831 ; jamais montré sur les cartes de suivi (issue_tracking_screen.dart:730-743)
- Pourquoi : impossible à mémoriser/recopier, pas de bouton copier, non réaffiché dans le suivi.
- Recommandation : identifiant court lisible + bouton copier + affichage dans le suivi.
- Verdict contradicteur : confirmé gênant.

**UX-4-04 — Modale de succès : unique bouton « Fermer »** · mineur (requalifié de gênant) · **F-4 (secondaire)**
- Libellé cité : FR `issueFormSuccessClose` = « Fermer » (seul bouton)
- Preuve : issue_form_screen.dart:899-911, 1118
- Recommandation : bouton « Voir mon signalement » vers le suivi.
- Verdict contradicteur : à requalifier mineur — le hub affiche « Mes incidents actifs » avec compteur et la nav « Incidents » est permanente.

**UX-4-05 — Erreurs réseau/serveur affichées brutes** · gênant (requalifié de bloquant) · **F-4**
- Libellé cité : FR `issueFormError` = « Erreur lors de l'envoi: {error} »
- Preuve : issue_form_screen.dart:1121-1125 (`e.toString()` brut) ; db_api_service.dart:1224 (`ApiException($statusCode) $url — $message`)
- Pourquoi : jargon technique en anglais avec URL interne ; l'infirmière ne sait pas si l'incident est parti (abandon ou doublon).
- Recommandation : messages humains localisés par type d'erreur, sans URL ni classe d'exception.
- Verdict contradicteur : à requalifier gênant — la saisie est conservée, un ré-appui sur Soumettre suffit.

**UX-4-06 — Messages serveur FR figés dans une UI EN** · mineur · confirmé · **F-4 (secondaire)**
- Preuve : issues.js:317, 325, 402 (messages FR en dur) réinjectés via db_api_service.dart:907-914
- Verdict contradicteur : confirmé.

**UX-4-07 — Erreur brute interpolée dans l'encart photos** · mineur · confirmé · **F-4 (secondaire)**
- Libellé cité : FR `issueFormPhotoUploadFailedMessage` (avec `{error}` brut)
- Preuve : issue_form_screen.dart:869, 944 ; api_client.dart:343-348
- Verdict contradicteur : confirmé.

**UX-4-08 — Fermeture avec photos non envoyées : perte silencieuse** · gênant · confirmé · **F-4**
- Preuve : issue_form_screen.dart:899-911 (« Fermer » actif malgré l'erreur), 1118 (photos en mémoire perdues)
- Pourquoi : l'infirmière croit ses photos jointes ; aucun avertissement, aucun rattrapage ultérieur.
- Recommandation : confirmation avant fermeture quand l'encart d'échec est visible.
- Verdict contradicteur : confirmé gênant.

**UX-4-09 — Accents manquants (photos)** · mineur · confirmé · **E**
- Libellé cité : FR `issueFormPhotosHint` = « Ajoutez jusqu'a {max} photos… probleme », `issueFormMaxPhotos` = « …autorisees »
- Preuve : app_fr.arb:183, 186
- Verdict contradicteur : confirmé.

Éléments audités sans constat : caractère optionnel des photos, limite de 5 annoncée, conseil photo, principe du retry photos.

### Segment ⑤ — Suivi des incidents

**UX-5-01 — Statuts affichés en anglais brut** · gênant (requalifié de bloquant) · **F-5**
- Libellé cité : FR `issueStatusWaitingMaterials` = « En attente de matériel » (clé existante non branchée) — l'écran affiche la valeur `displayName` anglaise
- Preuve : issue_tracking_screen.dart:748 (`IssueStatusBadge(status: issue.status.displayName)`) ; status_badge.dart:151-152 ; issue.dart:104 (`localizedName` existant)
- Pourquoi : « Waiting Materials », « Acknowledged », « Redirected » illisibles pour un francophone — l'information centrale de l'écran.
- Recommandation : brancher `localizedName(l10n)` (adapter le mapping couleur du badge).
- Verdict contradicteur : à requalifier gênant — couleurs de badge et quasi-cognats (Assigned, Completed) évitent l'échec total.

**UX-5-02 — « Quelqu'un s'en occupe ? » sans réponse** · gênant · confirmé · **F-5**
- Preuve : issue_tracking_screen.dart:701-769 (ni `assignedTechnician` ni indicateur) ; issue.dart:230-237 (`isHandled` existant non utilisé)
- Pourquoi : Signalé/Pris en compte/Assigné = nuances administratives ; la question n°1 du rapporteur reste sans réponse.
- Recommandation : ligne binaire « Pris en charge par {technicien} » / « En attente de prise en charge ».
- Verdict contradicteur : confirmé gênant.

**UX-5-03 — Onglet « Tous les incidents » doublement trompeur** · mineur (requalifié de gênant) · **F-5 (secondaire)**
- Libellé cité : FR `issuesTabAll` = « Tous les incidents » / EN « All issues »
- Preuve : issue_tracking_screen.dart:163 (`statusNe: 'Completed'` — exclut les terminés) ; aucun filtre rapporteur
- Pourquoi : « Tous » = tout l'hôpital (pas dit) et pas vraiment tous (Completed exclus).
- Verdict contradicteur : à requalifier mineur — le ticket du novice reste toujours visible dans « Mes signalements », son parcours principal n'est pas trompé.

**UX-5-04 — Onglet « Terminés » : les tickets vérifiés en « ressortent »** · gênant · confirmé · **F-5**
- Libellé cité : FR `issuesTabCompleted` = « Termines » / EN « Completed »
- Preuve : issue_tracking_screen.dart:163-164 (Terminés = strictement `Completed` ; `Verified`/`Closed`/`Rejected` retournent dans « Tous »)
- Pourquoi : un ticket vérifié par le superviseur RESSORT de « Terminés » → le rapporteur croit son problème rouvert ou perdu.
- Recommandation : Terminés = ensemble des états finaux.
- Verdict contradicteur : confirmé gênant — comportement incohérent avéré.

**UX-5-05 — Message de liste vide identique sur les 3 onglets** · gênant · confirmé · **F-5**
- Libellé cité : FR `issuesNoMyIssues` = « Vous n'avez pas encore signale d'incident »
- Preuve : issue_tracking_screen.dart:618 (commun aux 3 onglets, cf. 346-348)
- Pourquoi : sur « Tous »/« Terminés » vide, le message accuse à tort le rapporteur — il peut croire son signalement perdu.
- Recommandation : un message par onglet + message « filtres actifs ».
- Verdict contradicteur : confirmé gênant.

**UX-5-06 — Compteurs d'onglets ≠ listes affichées** · gênant · confirmé · **F-5**
- Preuve : issue_tracking_screen.dart:303-307, 336-338 (compteurs sur cache client) vs 346-348 (listes en pages serveur) ; logiques de recherche différentes (267-272)
- Pourquoi : « Mes signalements (7) » avec une liste d'un autre nombre — quel chiffre croire ?
- Recommandation : compteurs alimentés par `paged.total` serveur.
- Verdict contradicteur : confirmé gênant — nuance : le compteur du bandeau (548) suit la même logique client que les onglets.

**UX-5-07 — Filtre « Groupe » : jargon d'assignation** · mineur · confirmé · **E**
- Libellé cité : FR `issuesFilterGroup` = « Groupe » / EN « Group »
- Preuve : app_fr.arb:1463 ; issue_tracking_screen.dart:544 ; VALID_GROUPS (issues.js:87)
- Recommandation : « Équipe en charge » / « Assigned team ».
- Verdict contradicteur : confirmé mineur — chips de valeurs traduites.

**UX-5-08 — Aucun identifiant de ticket sur les cartes** · mineur · confirmé · **F-5 (secondaire)**
- Preuve : issue_tracking_screen.dart:730-743 ; recherche sans `i.id` (267-272) ; atténuant : tri `created_at DESC` (issues.js:203-204)
- Verdict contradicteur : confirmé.

**UX-5-09 — Accents manquants (suivi)** · mineur · confirmé · **E**
- Libellé cité : FR `issuesTabCompleted` = « Termines », `issuesResolvedOn` = « Resolu le {date} », `issuesReportedByDate` = « Signale par {reporter} • {date} », `issuesNoMyIssues` = « …signale… », `issuesSubtitle`
- Preuve : app_fr.arb:131, 141, 159, 163, 164
- Verdict contradicteur : confirmé (numéros de ligne à ±2, contenu exact).

**UX-5-10 — Export CSV : statuts EN, en-têtes FR figées** · mineur · confirmé · **F-5 (secondaire)**
- Preuve : issue_tracking_screen.dart:671 (`displayName`), 661-664 (en-têtes en dur)
- Verdict contradicteur : confirmé.

---

## 3. Limitations

1. **Passe dynamique remplacée par une trace statique** : Docker Desktop lancé mais démon inaccessible (>4 min d'attente, pipe `dockerDesktopLinuxEngine` absent) → stack Keycloak/auth/db non démarrable, pas de session navigateur réelle ni de captures d'écran. En remplacement, trace de code écran par écran (ordre réel des widgets dans les `build()`), qui a corroboré les constats structurels UX-1-02, UX-2-05, UX-2-06, UX-3-01, UX-5-06. **Cette trace est une analyse statique, pas un test utilisateur réel** : les constats de layout dynamique (éléments hors écran, scroll, rendus responsive intermédiaires) n'ont pas pu être vérifiés.
2. **Couverture agents** : les 5 agents novices ont tous rendu une sortie exploitable au premier lancement — aucun segment « non couvert par agent ».
3. **Zones non auditées** (hors périmètre assumé) : parcours des rôles technicien/superviseur/admin, écran de détail d'incident au-delà de la vue rapporteur, notifications email/push, accessibilité (contrastes, lecteurs d'écran).

## 4. Annexe — Constats réfutés

Aucun constat n'a été réfuté par le contradicteur (0/50). Les 14 requalifications (sévérité abaissée, constat conservé) sont documentées dans les fiches ci-dessus avec leur justification.
