# Scénarios de recette RBAC — Hôpital de District de Kabutare

> **Commanditaire** : Dr. NZABONIMANA Ephraim  
> **Application** : Gestion des Équipements Médicaux — Module 1  
> **Version** : 1.0 — Juin 2026  
> **Public cible** : testeur non-technique (médecin, chef de département, admin ICT)

---

## Mode d'emploi

1. Se connecter avec le compte de test indiqué dans chaque scénario (voir `tests/fixtures/test_users_roles.md` pour les identifiants)
2. Suivre les étapes **Given → When → Then** dans l'ordre
3. Cocher le résultat en fin de scénario : ☑ Réussi / ☑ Échoué / ☑ Non testé
4. Écrire toute observation dans la colonne **Notes**

> ⚠️ **Important** : ne jamais utiliser un compte de test en production. Ces comptes sont créés uniquement dans l'environnement de recette.

---

## Résumé des scénarios

| ID | Rôle | Type | Titre |
|---|---|---|---|
| SCN-STAFF-01 | hospitalStaff | Nominal | Consulter la liste des équipements |
| SCN-STAFF-02 | hospitalStaff | Accès refusé | Tenter de créer un équipement |
| SCN-STAFF-03 | hospitalStaff | Flux complet | Signaler un incident et le suivre |
| SCN-STAFF-04 | hospitalStaff | Accès refusé | Tenter de voir la liste des utilisateurs |
| SCN-SUP-01 | supervisor | Nominal | Approuver une demande de changement de département |
| SCN-SUP-02 | supervisor | Nominal | Assigner un incident à un technicien |
| SCN-SUP-03 | supervisor | Accès refusé | Tenter de supprimer un équipement |
| SCN-SUP-04 | supervisor | Flux complet | Gérer un incident de bout en bout (assignation → clôture) |
| SCN-TECH-01 | technician | Nominal | Mettre à jour le statut d'une réparation |
| SCN-TECH-02 | technician | Nominal | Enregistrer des pièces consommées |
| SCN-TECH-03 | technician | Accès refusé | Tenter d'accéder à l'inventaire des stocks |
| SCN-TECH-04 | technician | Flux complet | Prendre en charge et résoudre un incident |
| SCN-BIO-01 | technician_biomedical | Nominal | Accéder aux équipements biomédicaux et mettre à jour |
| SCN-BIO-02 | technician_biomedical | Accès refusé | Tenter d'approuver une demande de département |
| SCN-BIO-03 | technician_biomedical | Flux complet | Traiter un incident biomédical de A à Z |
| SCN-IT-01 | technician_it | Nominal | Mettre à jour un incident informatique |
| SCN-IT-02 | technician_it | Accès refusé | Tenter de gérer les utilisateurs |
| SCN-INFRA-01 | technician_infra | Nominal | Traiter un incident d'infrastructure |
| SCN-INFRA-02 | technician_infra | Accès refusé | Tenter de supprimer un inventaire |
| SCN-ADMIN-01 | admin | Nominal | Créer un nouvel utilisateur |
| SCN-ADMIN-02 | admin | Nominal | Accéder à tous les modules |
| SCN-ADMIN-03 | admin | Flux complet | Cycle de vie complet d'un équipement |
| SCN-CROSS-01 | Cross-rôles | Flux complet | Incident complet : staff → supervisor → technicien → clôture |
| SCN-CROSS-02 | Cross-rôles | Flux complet | Demande de changement de département : staff → admin |
| SCN-CROSS-03 | Cross-rôles | Escalade de privilège | hospitalStaff tente d'accéder à un endpoint admin |

---

## Bloc 1 — Rôle : `hospitalStaff` (Personnel hospitalier)

> **Compte de test** : `test.staff@kabutare.rw` / Mot de passe : voir `test_users_roles.md`  
> **Département** : OPD (Consultations externes)  
> **Permissions** : `viewEquipment`, `reportIssue`, `trackIssues`

---

### SCN-STAFF-01 — Consulter la liste des équipements
**Rôle testé** : `hospitalStaff`  
**Permission(s) vérifiée(s)** : `viewEquipment`  
**Préconditions** : au moins 5 équipements existent dans la base de données de test

**Given** l'utilisateur `test.staff@kabutare.rw` est connecté à l'application  
**When** il clique sur "Équipements" dans le menu de navigation  
**Then**
- La liste des équipements s'affiche (au moins 5 entrées visibles)
- Chaque équipement affiche son nom, département, statut et catégorie
- Le bouton "Ajouter un équipement" **n'est pas visible** ou est grisé
- Aucun message d'erreur n'apparaît

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-STAFF-02 — Tenter de créer un équipement (accès refusé)
**Rôle testé** : `hospitalStaff`  
**Permission(s) vérifiée(s)** : absence de `manageEquipment`  
**Préconditions** : utilisateur connecté en tant que `test.staff@kabutare.rw`

**Given** l'utilisateur `test.staff@kabutare.rw` est connecté  
**When** il tente d'accéder directement à l'URL de création d'équipement (ou utilise les outils développeur du navigateur pour envoyer une requête `POST /api/equipment`)  
**Then**
- L'interface ne propose pas de bouton "Ajouter" visible
- Si la tentative est faite via URL directe, l'application affiche une page d'accès refusé ou redirige vers le tableau de bord
- Si la tentative est faite via API, la réponse est **403 Interdit** avec le message d'erreur approprié
- Aucun équipement n'est créé dans la base de données

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-STAFF-03 — Signaler un incident et le suivre (flux complet)
**Rôle testé** : `hospitalStaff`  
**Permission(s) vérifiée(s)** : `reportIssue`, `trackIssues`  
**Préconditions** : au moins un équipement existe dans le département OPD

**Given** l'utilisateur `test.staff@kabutare.rw` est connecté  
**And** il est au tableau de bord  
**When** il clique sur "Signaler un incident"  
**Then** une fenêtre de sélection de catégorie s'affiche (Équipements Biomédicaux / Infrastructure / Informatique / Autre)

**When** il sélectionne la catégorie "Équipements Biomédicaux"  
**Then** le formulaire de signalement s'ouvre avec uniquement les équipements biomédicaux disponibles dans son département

**When** il remplit le formulaire :
- Équipement : sélectionner un équipement disponible
- Type de panne : "Panne"
- Urgence : "Urgent"
- Description : "L'équipement ne s'allume plus depuis ce matin"

**And** il clique sur "Soumettre"  
**Then**
- Un message de confirmation "Incident signalé avec succès" s'affiche
- L'incident apparaît dans la liste "Suivi des incidents" avec le statut "Reported"
- L'incident est attribué au département OPD
- Le nom du rapporteur correspond à l'utilisateur connecté

**When** il navigue vers "Suivi des incidents"  
**Then**
- L'incident créé est visible dans la liste
- Il peut voir le statut, l'urgence et la description
- Il **ne peut pas** modifier le statut de l'incident (bouton absent ou grisé)

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-STAFF-04 — Tenter de voir la liste des utilisateurs (accès refusé)
**Rôle testé** : `hospitalStaff`  
**Permission(s) vérifiée(s)** : absence de `manageUsers`  
**Préconditions** : utilisateur connecté en tant que `test.staff@kabutare.rw`

**Given** l'utilisateur `test.staff@kabutare.rw` est connecté  
**When** il inspecte le menu de navigation de l'application  
**Then** l'entrée "Gestion des utilisateurs" **n'est pas visible** dans la barre latérale

**When** il tente d'accéder directement à l'URL `/users` dans le navigateur  
**Then**
- L'application redirige vers le tableau de bord ou affiche une page "Accès refusé"
- Aucune donnée d'utilisateur (nom, email, rôle) n'est affichée

**When** il envoie une requête API `GET /api/users` avec son token (via outil développeur)  
**Then** la réponse est **403 Interdit**

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 2 — Rôle : `supervisor` (Superviseur / Chef de département)

> **Compte de test** : `test.supervisor@kabutare.rw`  
> **Département** : Médecine Interne  
> **Permissions** : `viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`

---

### SCN-SUP-01 — Approuver une demande de changement de département
**Rôle testé** : `supervisor`  
**Permission(s) vérifiée(s)** : `approveRequests`  
**Préconditions** : une demande de changement de département en statut "pending" existe (créée avec `test.staff@kabutare.rw`)

**Given** l'utilisateur `test.supervisor@kabutare.rw` est connecté  
**When** il navigue vers "Gestion des utilisateurs" → onglet "Demandes de département"  
**Then** la demande en attente de `test.staff@kabutare.rw` est visible avec le statut "En attente"

**When** il clique sur "Approuver" et confirme  
**Then**
- Le statut de la demande passe à "Approuvé"
- Un email de notification est envoyé à `test.staff@kabutare.rw` (à vérifier dans la boîte mail de test)
- Le département de `test.staff@kabutare.rw` est mis à jour dans le système

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-SUP-02 — Assigner un incident à un technicien
**Rôle testé** : `supervisor`  
**Permission(s) vérifiée(s)** : `assignTasks`  
**Préconditions** : un incident en statut "Reported" ou "Acknowledged" existe

**Given** l'utilisateur `test.supervisor@kabutare.rw` est connecté  
**When** il navigue vers "Suivi des incidents" → onglet "À valider"  
**Then** les incidents non assignés sont listés

**When** il sélectionne l'incident de test créé dans SCN-STAFF-03  
**And** il clique sur "Assigner" et sélectionne le technicien `test.tech.bio@kabutare.rw`  
**Then**
- Le statut de l'incident passe à "Assigned"
- Le nom du technicien assigné s'affiche dans les détails de l'incident
- Le technicien reçoit une notification (à vérifier si les préférences de notification sont activées)

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-SUP-03 — Tenter de supprimer un équipement (accès refusé)
**Rôle testé** : `supervisor`  
**Permission(s) vérifiée(s)** : absence de permission de suppression exclusive à `admin`  
**Préconditions** : utilisateur connecté en tant que `test.supervisor@kabutare.rw`

**Given** l'utilisateur `test.supervisor@kabutare.rw` est connecté  
**When** il consulte la fiche détail d'un équipement  
**Then** le bouton "Supprimer l'équipement" **n'est pas visible** (réservé à l'admin)

**When** il tente une requête API `DELETE /api/equipment/eq-001` avec son token  
**Then** la réponse est **403 Interdit**

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-SUP-04 — Gérer un incident de bout en bout (flux complet)
**Rôle testé** : `supervisor`  
**Permission(s) vérifiée(s)** : `assignTasks`, `approveRequests`, `trackIssues`  
**Préconditions** : un incident en statut "Reported" existe (créé par un `hospitalStaff`)

**Given** l'utilisateur `test.supervisor@kabutare.rw` est connecté  
**When** il ouvre le tableau de bord  
**Then** l'incident urgent apparaît dans la section "Incidents prioritaires"

**When** il clique sur l'incident pour voir les détails  
**Then** toutes les informations (équipement, département, description, urgence) sont visibles

**When** il change le statut à "Acknowledged" via le bouton correspondant  
**Then** le statut de l'incident est mis à jour dans la liste

**When** il assigne l'incident à `test.tech.bio@kabutare.rw`  
**Then** le statut passe à "Assigned" et le technicien apparaît dans les détails

**When** le technicien a résolu l'incident (statut "Completed"), le superviseur retourne sur l'incident  
**And** il clique sur "Vérifier" puis "Clôturer"  
**Then** le statut final est "Closed" et l'incident n'apparaît plus dans la liste des incidents ouverts

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 3 — Rôle : `technician` (Technicien généraliste)

> **Compte de test** : `test.technician@kabutare.rw`  
> **Département** : ICT (Maintenance)  
> **Permissions** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

---

### SCN-TECH-01 — Mettre à jour le statut d'une réparation
**Rôle testé** : `technician`  
**Permission(s) vérifiée(s)** : `updateRepairs`  
**Préconditions** : un incident en statut "Assigned" est attribué à `test.technician@kabutare.rw`

**Given** l'utilisateur `test.technician@kabutare.rw` est connecté  
**When** il navigue vers "Suivi des incidents"  
**Then** l'incident qui lui est assigné apparaît dans la liste avec son nom en tant que technicien assigné

**When** il clique sur l'incident et saisit son diagnostic :
- Diagnostic : "Condensateur défaillant sur la carte mère"
- Actions effectuées : "Remplacement du condensateur C12, test fonctionnel réalisé"
- Statut : "In Progress"

**And** il clique sur "Enregistrer"  
**Then**
- Le diagnostic et les actions sont sauvegardés
- Le statut de l'incident est mis à jour à "In Progress"
- La date de mise à jour est actualisée

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-TECH-02 — Enregistrer des pièces consommées lors d'une réparation
**Rôle testé** : `technician`  
**Permission(s) vérifiée(s)** : `registerParts`  
**Préconditions** : un incident "In Progress" est assigné au technicien ; au moins une pièce existe en stock dans l'inventaire (ex. `inv-001` avec stock > 0)

**Given** l'utilisateur `test.technician@kabutare.rw` est connecté  
**When** il ouvre un incident "In Progress" qui lui est assigné  
**And** il utilise la section "Pièces consommées" pour ajouter `inv-001` (Gants stériles) en quantité 2  
**And** il clique sur "Enregistrer"  
**Then**
- Les pièces consommées sont enregistrées dans les détails de l'incident
- Le stock de `inv-001` dans l'inventaire est **décrémenté de 2**
- Si le stock descend en dessous du seuil minimum, le statut de l'article passe à "Faible"

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-TECH-03 — Tenter d'accéder à l'inventaire des stocks (accès refusé)
**Rôle testé** : `technician`  
**Permission(s) vérifiée(s)** : absence de `viewInventory`  
**Préconditions** : utilisateur connecté en tant que `test.technician@kabutare.rw`

**Given** l'utilisateur `test.technician@kabutare.rw` est connecté  
**When** il parcourt le menu de navigation  
**Then** l'entrée "Inventaire" n'est **pas visible** dans la barre latérale ou le menu

**When** il tente une requête API `GET /api/inventory` avec son token  
**Then** la réponse est **403 Interdit**

> ℹ️ **Note** : les pièces consommées sur un incident (SCN-TECH-02) sont enregistrables via le formulaire d'incident — ce flux ne passe pas par l'écran Inventaire direct.

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-TECH-04 — Prendre en charge et résoudre un incident (flux complet)
**Rôle testé** : `technician`  
**Permission(s) vérifiée(s)** : `updateRepairs`, `registerParts`, `trackIssues`  
**Préconditions** : un incident en statut "Assigned" est attribué à `test.technician@kabutare.rw`

**Given** l'utilisateur `test.technician@kabutare.rw` est connecté  
**When** il ouvre l'incident qui lui est assigné  
**Then** un bouton "Prendre en charge" (ou chronomètre) est disponible

**When** il clique sur "Prendre en charge"  
**Then** l'horodatage de prise en charge est enregistré et un chronomètre démarre

**When** il saisit le diagnostic, les actions effectuées et marque le statut "Completed"  
**Then**
- L'incident passe au statut "Completed"
- Le chronomètre s'arrête
- Le superviseur peut voir l'incident en attente de vérification

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 4 — Rôle : `technician_biomedical` (Technicien biomédical)

> **Compte de test** : `test.tech.bio@kabutare.rw`  
> **Département** : Laboratoire  
> **Permissions** : identiques à `technician` — `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

---

### SCN-BIO-01 — Accéder aux équipements biomédicaux et les mettre à jour
**Rôle testé** : `technician_biomedical`  
**Permission(s) vérifiée(s)** : `viewEquipment`, `updateRepairs`  
**Préconditions** : des équipements de catégorie "Imagerie" ou "Laboratoire" existent

**Given** l'utilisateur `test.tech.bio@kabutare.rw` est connecté  
**When** il navigue vers "Équipements" et filtre par catégorie "Imagerie"  
**Then** les équipements biomédicaux correspondants sont affichés

**When** il ouvre la fiche d'un équipement et ajoute un enregistrement de maintenance :
- Date : date du jour
- Intervention : "Calibration annuelle du spectrophotomètre"
- Technicien : son propre nom

**And** il clique sur "Enregistrer"  
**Then** l'enregistrement apparaît dans l'historique de maintenance de l'équipement

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-BIO-02 — Tenter d'approuver une demande de département (accès refusé)
**Rôle testé** : `technician_biomedical`  
**Permission(s) vérifiée(s)** : absence de `approveRequests`  
**Préconditions** : utilisateur connecté en tant que `test.tech.bio@kabutare.rw`

**Given** l'utilisateur `test.tech.bio@kabutare.rw` est connecté  
**When** il tente d'accéder à la gestion des demandes de département  
**Then** l'onglet ou le menu correspondant **n'est pas visible**

**When** il tente une requête API `PUT /api/users/department-requests/[ID]` avec son token  
**Then** la réponse est **403 Interdit**

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-BIO-03 — Traiter un incident biomédical de A à Z (flux complet)
**Rôle testé** : `technician_biomedical`  
**Permission(s) vérifiée(s)** : `updateRepairs`, `registerParts`, `trackIssues`  
**Préconditions** : un incident de catégorie "Biomedical" en statut "Assigned" est attribué à `test.tech.bio@kabutare.rw`

**Given** l'utilisateur `test.tech.bio@kabutare.rw` est connecté  
**When** il ouvre l'incident assigné dans "Suivi des incidents"  
**Then** tous les détails (équipement, département, description, urgence) sont visibles

**When** il saisit le diagnostic et les actions :
- Diagnostic : "Panne du capteur de pression"
- Actions : "Remplacement du capteur référence REF-2024-P"
- Pièces consommées : 1 unité de la pièce de référence (si disponible en stock)
- Statut : "Completed"

**And** il enregistre  
**Then**
- L'incident passe à "Completed"
- L'historique de l'incident enregistre l'intervention
- Si des pièces ont été consommées, le stock est mis à jour
- Le superviseur voit l'incident en attente de vérification finale

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 5 — Rôle : `technician_it` (Technicien informatique)

> **Compte de test** : `test.tech.it@kabutare.rw`  
> **Département** : ICT  
> **Permissions** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

---

### SCN-IT-01 — Mettre à jour un incident informatique
**Rôle testé** : `technician_it`  
**Permission(s) vérifiée(s)** : `updateRepairs`  
**Préconditions** : un incident de catégorie "IT" en statut "Assigned" est attribué à `test.tech.it@kabutare.rw`

**Given** l'utilisateur `test.tech.it@kabutare.rw` est connecté  
**When** il ouvre l'incident IT qui lui est assigné  
**Then** le formulaire de mise à jour est accessible

**When** il saisit :
- Diagnostic : "Disque dur défaillant sur le serveur de radiologie"
- Actions : "Remplacement du disque, restauration depuis sauvegarde NAS"
- Statut : "In Progress"

**And** il enregistre  
**Then** les modifications sont sauvegardées et le statut est mis à jour

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-IT-02 — Tenter de gérer les utilisateurs (accès refusé)
**Rôle testé** : `technician_it`  
**Permission(s) vérifiée(s)** : absence de `manageUsers`  
**Préconditions** : utilisateur connecté en tant que `test.tech.it@kabutare.rw`

**Given** l'utilisateur `test.tech.it@kabutare.rw` est connecté  
**When** il parcourt tous les menus disponibles  
**Then** l'entrée "Gestion des utilisateurs" **n'est pas visible**

**When** il tente une requête API `POST /api/users` avec son token  
**Then** la réponse est **403 Interdit**

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 6 — Rôle : `technician_infra` (Technicien infrastructure)

> **Compte de test** : `test.tech.infra@kabutare.rw`  
> **Département** : Infrastructure  
> **Permissions** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

---

### SCN-INFRA-01 — Traiter un incident d'infrastructure (lieu sans équipement)
**Rôle testé** : `technician_infra`  
**Permission(s) vérifiée(s)** : `updateRepairs`, `trackIssues`  
**Préconditions** : un incident de type "Infrastructure" (avec `location_id`, sans `equipment_id`) en statut "Assigned" existe

**Given** l'utilisateur `test.tech.infra@kabutare.rw` est connecté  
**When** il ouvre l'incident d'infrastructure (ex. "Panne électrique — Bâtiment A")  
**Then** les détails du lieu (bâtiment, département) s'affichent à la place de l'équipement

**When** il saisit le diagnostic et les actions puis marque "Completed"  
**Then** l'incident est résolu et la catégorie "Infrastructure" est bien conservée

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-INFRA-02 — Tenter de supprimer un article d'inventaire (accès refusé)
**Rôle testé** : `technician_infra`  
**Permission(s) vérifiée(s)** : absence de `viewInventory` et de permission de suppression  
**Préconditions** : utilisateur connecté en tant que `test.tech.infra@kabutare.rw`

**Given** l'utilisateur `test.tech.infra@kabutare.rw` est connecté  
**When** il tente une requête API `DELETE /api/inventory/inv-001` avec son token  
**Then** la réponse est **403 Interdit**

**When** il tente d'accéder à l'écran Inventaire via l'interface  
**Then** l'entrée "Inventaire" **n'est pas visible** dans la navigation

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 7 — Rôle : `admin` (Administrateur ICT)

> **Compte de test** : `test.admin@kabutare.rw`  
> **Département** : ICT  
> **Permissions** : **toutes les 14 permissions** (+ manageFeatures, manageBackups)

---

### SCN-ADMIN-01 — Créer un nouvel utilisateur
**Rôle testé** : `admin`  
**Permission(s) vérifiée(s)** : `manageUsers`  
**Préconditions** : aucun utilisateur avec l'email `nouveau.test@kabutare.rw` n'existe

**Given** l'utilisateur `test.admin@kabutare.rw` est connecté  
**When** il navigue vers "Gestion des utilisateurs" → "Ajouter un utilisateur"  
**Then** le formulaire de création s'affiche

**When** il remplit les champs :
- Prénom : "Nouveau"
- Nom : "Testeur"
- Email : `nouveau.test@kabutare.rw`
- Département : "Pédiatrie"
- Rôle : "hospitalStaff"
- Mot de passe temporaire : `Test@2026!`

**And** il clique sur "Créer"  
**Then**
- Le nouvel utilisateur apparaît dans la liste avec le statut "Actif"
- Un email de bienvenue est envoyé à `nouveau.test@kabutare.rw`
- L'action est tracée dans les logs d'audit

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-ADMIN-02 — Accéder à tous les modules de l'application
**Rôle testé** : `admin`  
**Permission(s) vérifiée(s)** : toutes les 14 permissions  
**Préconditions** : utilisateur connecté en tant que `test.admin@kabutare.rw`

**Given** l'utilisateur `test.admin@kabutare.rw` est connecté  
**When** il parcourt le menu de navigation  
**Then** tous les modules suivants sont visibles et accessibles :
- ☐ Tableau de bord
- ☐ Équipements
- ☐ Signalement d'incident
- ☐ Suivi des incidents
- ☐ Inventaire
- ☐ Rapports
- ☐ Gestion des utilisateurs
- ☐ Paramètres
- ☐ Logs d'audit
- ☐ Paramètres du compte

**Then** aucun module n'affiche "Accès refusé" ou n'est grisé

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-ADMIN-03 — Cycle de vie complet d'un équipement (flux complet)
**Rôle testé** : `admin`  
**Permission(s) vérifiée(s)** : `manageEquipment`, `viewEquipment`  
**Préconditions** : aucun équipement avec l'ID `eq-test-recette` n'existe

**Given** l'utilisateur `test.admin@kabutare.rw` est connecté  
**When** il navigue vers "Équipements" → "Ajouter un équipement"  
**And** il remplit le formulaire (Étape 1/3 — Infos essentielles) :
- ID : `eq-test-recette`
- Nom : "Tensiomètre de test recette"
- Département : "Chirurgie"
- Catégorie : "Monitoring"

**And** il passe à l'étape 2 (Infos techniques) :
- Numéro de série : `SN-TEST-2026`
- Fabricant : "Omron"
- Année de fabrication : 2024

**And** il passe à l'étape 3 (GMAO & Maintenance) et confirme  
**Then** l'équipement `eq-test-recette` apparaît dans la liste avec le statut "Operational"

**When** il modifie le statut de l'équipement à "Maintenance"  
**Then** le statut est mis à jour et l'historique de modification est visible

**When** il supprime l'équipement avec la raison "Équipement de test — à supprimer"  
**Then** l'équipement disparaît de la liste et la suppression est tracée dans les logs

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Bloc 8 — Scénarios cross-rôles

### SCN-CROSS-01 — Flux incident complet : staff → supervisor → technicien → clôture
**Rôle(s) testé(s)** : `hospitalStaff`, `supervisor`, `technician_biomedical`  
**Permission(s) vérifiée(s)** : `reportIssue` (staff), `assignTasks` (supervisor), `updateRepairs` (tech), clôture (supervisor)  
**Préconditions** : les 3 comptes de test sont créés et accessibles

**Étape 1 — Signalement (compte : `test.staff@kabutare.rw`)**  
**Given** `test.staff@kabutare.rw` est connecté  
**When** il signale un incident urgent sur un équipement du département OPD :
- Catégorie : Équipements Biomédicaux
- Type : "Panne"
- Urgence : "Critique"
- Description : "Le moniteur cardiaque du bloc n'affiche plus les données du patient"

**Then** l'incident est créé avec le statut "Reported" et l'ID noté : `_______`

---

**Étape 2 — Prise en compte et assignation (compte : `test.supervisor@kabutare.rw`)**  
**Given** `test.supervisor@kabutare.rw` est connecté  
**When** il ouvre l'incident (visible dans "Incidents prioritaires" car urgence = Critique)  
**And** il change le statut à "Acknowledged"  
**And** il assigne l'incident à `test.tech.bio@kabutare.rw`  
**Then** le statut passe à "Assigned" et le technicien est notifié

---

**Étape 3 — Résolution (compte : `test.tech.bio@kabutare.rw`)**  
**Given** `test.tech.bio@kabutare.rw` est connecté  
**When** il ouvre l'incident assigné et clique "Prendre en charge"  
**And** il saisit :
- Diagnostic : "Câble de connexion du capteur défaillant"
- Actions : "Remplacement du câble — référence CBL-MON-2024"
- Statut : "Completed"

**Then** l'incident passe à "Completed"

---

**Étape 4 — Vérification et clôture (compte : `test.supervisor@kabutare.rw`)**  
**Given** `test.supervisor@kabutare.rw` est reconnecté  
**When** il ouvre l'incident "Completed"  
**And** il clique "Vérifier" puis "Clôturer"  
**Then** le statut final est "Closed" et l'incident n'apparaît plus dans les incidents ouverts

**Résultat global** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-CROSS-02 — Demande de changement de département : staff → admin
**Rôle(s) testé(s)** : `hospitalStaff`, `admin`  
**Permission(s) vérifiée(s)** : `changeDepartment` implicite (via demande), `approveRequests` (admin)  
**Préconditions** : `test.staff@kabutare.rw` est actuellement dans le département "OPD"

**Étape 1 — Soumission de la demande (compte : `test.staff@kabutare.rw`)**  
**Given** `test.staff@kabutare.rw` est connecté  
**When** il navigue vers "Paramètres du compte" → "Mon département"  
**And** il clique sur "Demander un changement de département"  
**And** il sélectionne "Pédiatrie" comme département cible  
**And** il confirme la demande  
**Then** un message de confirmation s'affiche : "Votre demande a été soumise"

**When** il tente de soumettre une deuxième demande  
**Then** le système lui indique qu'une demande est déjà en attente (1 seule demande autorisée simultanément)

---

**Étape 2 — Traitement par l'admin (compte : `test.admin@kabutare.rw`)**  
**Given** `test.admin@kabutare.rw` est connecté  
**When** il navigue vers "Gestion des utilisateurs" → "Demandes de département"  
**Then** la demande de `test.staff@kabutare.rw` est visible avec le statut "En attente"

**When** il approuve la demande avec une note : "Demande validée par l'administration"  
**Then**
- Le statut passe à "Approuvé"
- Le département de `test.staff@kabutare.rw` est mis à jour à "Pédiatrie"
- Un email de notification est envoyé à `test.staff@kabutare.rw`

**Résultat global** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

### SCN-CROSS-03 — Tentative d'escalade de privilège (hospitalStaff → endpoint admin)
**Rôle(s) testé(s)** : `hospitalStaff`  
**Permission(s) vérifiée(s)** : absence de toutes les permissions admin  
**Préconditions** : le testeur dispose d'un outil permettant d'envoyer des requêtes HTTP (navigateur avec DevTools ou Postman)

> ⚠️ **Ce scénario est réservé aux testeurs techniques.** Il vérifie que le système rejette correctement les tentatives d'accès non autorisé même si un attaquant possède un token valide.

**Given** `test.staff@kabutare.rw` est connecté et son token JWT est récupéré dans les DevTools (onglet Application → Cookies / Local Storage)  
**When** le testeur envoie les requêtes suivantes avec ce token :

| Requête | Code HTTP attendu |
|---|---|
| `GET /api/users` | **403** |
| `POST /api/users` | **403** |
| `GET /api/roles` | **403** |
| `DELETE /api/equipment/eq-001` | **403** |
| `GET /api/inventory` | **403** |
| `GET /api/logs` | **403** |
| `PUT /api/feature-flags/equipment` | **403** |
| `GET /api/users/department-requests` | **403** |

**Then** pour **chaque** requête :
- La réponse HTTP est exactement **403**
- Le corps de la réponse contient un message d'erreur (pas de données sensibles)
- Aucune donnée utilisateur, aucun inventaire, aucun log n'est retourné

**Résultat** : ☐ Réussi  ☐ Échoué  ☐ Non testé  
**Notes** : _______________

---

## Annexe — Grille de couverture des 14 permissions

| Permission | SCN couvrant le cas AUTORISÉ | SCN couvrant le cas REFUSÉ |
|---|---|---|
| `viewEquipment` | SCN-STAFF-01, SCN-BIO-01 | — (tous les rôles l'ont) |
| `reportIssue` | SCN-STAFF-03, SCN-CROSS-01 | — (tous les rôles l'ont) |
| `trackIssues` | SCN-STAFF-03, SCN-TECH-04 | — (tous les rôles l'ont) |
| `approveRequests` | SCN-SUP-01, SCN-CROSS-02 | SCN-BIO-02 |
| `assignTasks` | SCN-SUP-02, SCN-SUP-04 | SCN-TECH-03 (implicite) |
| `updateRepairs` | SCN-TECH-01, SCN-BIO-03 | SCN-STAFF-03 (implicite) |
| `registerParts` | SCN-TECH-02, SCN-BIO-03 | SCN-STAFF-04 (implicite) |
| `manageEquipment` | SCN-ADMIN-03 | SCN-STAFF-02, SCN-CROSS-03 |
| `manageUsers` | SCN-ADMIN-01 | SCN-STAFF-04, SCN-IT-02, SCN-CROSS-03 |
| `manageDepartments` | SCN-ADMIN-02 (accès Settings) | SCN-STAFF-04 (implicite) |
| `manageCategories` | SCN-ADMIN-02 (accès Settings) | SCN-CROSS-03 |
| `generateReports` | SCN-ADMIN-02 (accès Rapports) | SCN-CROSS-03 |
| `viewInventory` | SCN-ADMIN-02 (accès Inventaire) | SCN-TECH-03, SCN-INFRA-02, SCN-CROSS-03 |
| `changeDepartment` | SCN-CROSS-02 (demande staff) | — |

---

*Document généré le 2026-06-04 — à mettre à jour après chaque recette.*
