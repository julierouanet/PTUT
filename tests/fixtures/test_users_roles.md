# Comptes de test Keycloak — Recette RBAC

> **Environnement cible** : recette uniquement (`dev.kabutare.duckdns.org`)  
> **Realm Keycloak** : `kabutare-hospital`  
> **Console admin** : `https://dev.kabutare.duckdns.org/realms/kabutare-hospital` (ou port 8081 en local)  
> **⚠️ Ne jamais créer ces comptes en production**

---

## Procédure de création des comptes

### Via la console Keycloak (recommandé pour la recette)

1. Se connecter à la console admin Keycloak de l'environnement dev
2. Naviguer vers **Users** → **Add user**
3. Renseigner : Username (= email), First name, Last name, Email, **Email verified = ON**
4. Onglet **Credentials** → Set password → décocher "Temporary"
5. Onglet **Role mappings** → Assign role (rôle Keycloak realm)
6. Onglet **Attributes** → Ajouter l'attribut `department` avec la valeur correspondante

### Via l'application (accès demandé)

Utiliser la page de connexion → "Demander un accès" → renseigner email + département → l'admin ICT (`test.admin@kabutare.rw`) crée ensuite le compte via "Gestion des utilisateurs".

---

## Comptes de test (7 rôles)

### 1. Personnel hospitalier — `hospitalStaff`

| Champ | Valeur |
|---|---|
| **Email** | `test.staff@kabutare.rw` |
| **Prénom** | Marie |
| **Nom** | UWIMANA |
| **Rôle Keycloak** | `hospitalStaff` |
| **Département** | OPD |
| **Mot de passe** | `TestStaff@2026!` |
| **Attribut `department`** | `OPD` |

**Permissions applicatives attendues** : `viewEquipment`, `reportIssue`, `trackIssues`

**Équipements de référence pour les scénarios** :
- Utiliser `eq-003` (Tensiomètre électronique Omron — département OPD) pour SCN-STAFF-03

**Vérification post-création** :
```
GET /api/auth/me → "permissions": ["viewEquipment", "reportIssue", "trackIssues"]
```

---

### 2. Superviseur — `supervisor`

| Champ | Valeur |
|---|---|
| **Email** | `test.supervisor@kabutare.rw` |
| **Prénom** | Jean-Pierre |
| **Nom** | HABIMANA |
| **Rôle Keycloak** | `supervisor` |
| **Département** | Médecine Interne |
| **Mot de passe** | `TestSupervisor@2026!` |
| **Attribut `department`** | `Médecine Interne` |

**Permissions applicatives attendues** : `viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`

**Vérification post-création** :
```
GET /api/auth/me → "permissions": ["viewEquipment", "reportIssue", "trackIssues", "approveRequests", "assignTasks"]
```

---

### 3. Technicien généraliste — `technician`

| Champ | Valeur |
|---|---|
| **Email** | `test.technician@kabutare.rw` |
| **Prénom** | Patrick |
| **Nom** | NIYOMUGABO |
| **Rôle Keycloak** | `technician` |
| **Département** | ICT |
| **Mot de passe** | `TestTech@2026!` |
| **Attribut `department`** | `ICT` |

**Permissions applicatives attendues** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

**Incidents de référence** :
- Créer un incident `ISS-TEST-TECH-01` assigné à ce technicien avant les tests SCN-TECH-01 et SCN-TECH-04

**Vérification post-création** :
```
GET /api/auth/me → "permissions": ["viewEquipment", "reportIssue", "trackIssues", "updateRepairs", "registerParts"]
```

---

### 4. Technicien biomédical — `technician_biomedical`

| Champ | Valeur |
|---|---|
| **Email** | `test.tech.bio@kabutare.rw` |
| **Prénom** | Solange |
| **Nom** | MUKAMANA |
| **Rôle Keycloak** | `technician_biomedical` |
| **Département** | Laboratoire |
| **Mot de passe** | `TestBio@2026!` |
| **Attribut `department`** | `Laboratoire` |

**Permissions applicatives attendues** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

**Équipements de référence** :
- Les équipements de catégorie "Imagerie" ou "Laboratoire" (issus du XLSX ou `eq-024` — Scanner IRM)

**Incidents de référence** :
- Créer un incident `ISS-TEST-BIO-01` sur un équipement biomédical, assigné à ce technicien avant SCN-BIO-03

**Vérification post-création** :
```
GET /api/auth/me → "permissions": ["viewEquipment", "reportIssue", "trackIssues", "updateRepairs", "registerParts"]
```

---

### 5. Technicien informatique — `technician_it`

| Champ | Valeur |
|---|---|
| **Email** | `test.tech.it@kabutare.rw` |
| **Prénom** | Emmanuel |
| **Nom** | NKURUNZIZA |
| **Rôle Keycloak** | `technician_it` |
| **Département** | ICT |
| **Mot de passe** | `TestIT@2026!` |
| **Attribut `department`** | `ICT` |

**Permissions applicatives attendues** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

**Incidents de référence** :
- Créer un incident `ISS-TEST-IT-01` sur `eq-001` (Serveur Dell PowerEdge), statut "Assigned", assigné à ce technicien

**Vérification post-création** :
```
GET /api/auth/me → "permissions": ["viewEquipment", "reportIssue", "trackIssues", "updateRepairs", "registerParts"]
```

---

### 6. Technicien infrastructure — `technician_infra`

| Champ | Valeur |
|---|---|
| **Email** | `test.tech.infra@kabutare.rw` |
| **Prénom** | Claudine |
| **Nom** | INGABIRE |
| **Rôle Keycloak** | `technician_infra` |
| **Département** | Infrastructure |
| **Mot de passe** | `TestInfra@2026!` |
| **Attribut `department`** | `Administration` |

**Permissions applicatives attendues** : `viewEquipment`, `reportIssue`, `trackIssues`, `updateRepairs`, `registerParts`

**Incidents de référence** :
- Créer un incident `ISS-TEST-INFRA-01` avec `location_id` (lieu sans équipement), catégorie "Infrastructure", assigné à ce technicien, pour SCN-INFRA-01
- Exemple de lieu : "Bâtiment Principal — Couloir urgences"

**Vérification post-création** :
```
GET /api/auth/me → "permissions": ["viewEquipment", "reportIssue", "trackIssues", "updateRepairs", "registerParts"]
```

---

### 7. Administrateur ICT — `admin`

| Champ | Valeur |
|---|---|
| **Email** | `test.admin@kabutare.rw` |
| **Prénom** | Administrateur |
| **Nom** | TEST |
| **Rôle Keycloak** | `admin` |
| **Département** | ICT |
| **Mot de passe** | `TestAdmin@2026!` |
| **Attribut `department`** | `ICT` |

**Permissions applicatives attendues** : toutes les 14 permissions (`viewEquipment`, `reportIssue`, `trackIssues`, `approveRequests`, `assignTasks`, `updateRepairs`, `registerParts`, `manageEquipment`, `manageUsers`, `manageDepartments`, `manageCategories`, `generateReports`, `viewInventory`, `changeDepartment`)

**Vérification post-création** :
```
GET /api/auth/me → "permissions": [14 permissions listées]
```

> ℹ️ Ce compte admin de test est **distinct** du compte admin de production. Ne jamais utiliser le compte `admin@kabutare.rw` de production pour les tests.

---

## Données de référence à pré-créer

### Équipements de test

Ces équipements doivent exister dans la base de données de recette. Les données seed legacy (`eq-001` à `eq-045`) couvrent la plupart des besoins.

| ID | Nom | Département | Catégorie | Statut | Utilisé dans |
|---|---|---|---|---|---|
| `eq-001` | Serveur Dell PowerEdge R750 | Administration | Équipement ICT | Operational | SCN-IT-01, SCN-CROSS-03 |
| `eq-003` | Tensiomètre électronique Omron | OPD | Équipement biomédical | Operational | SCN-STAFF-03 |
| `eq-024` | Scanner IRM Siemens 1.5T | Chirurgie | Équipement biomédical | Operational | SCN-BIO-03 |
| `eq-041` | Autoclave Steris 400 | Bloc Opératoire | Stérilisation | Maintenance | SCN-BIO-01 |

### Incidents pré-créés

À créer manuellement avant la session de recette :

| ID suggéré | Équipement | Département | Urgence | Statut initial | Assigné à | Utilisé dans |
|---|---|---|---|---|---|---|
| `ISS-TEST-TECH-01` | `eq-001` | ICT | Moyen | Assigned | `test.technician@kabutare.rw` | SCN-TECH-01, SCN-TECH-04 |
| `ISS-TEST-BIO-01` | `eq-024` | Chirurgie | Urgent | Assigned | `test.tech.bio@kabutare.rw` | SCN-BIO-03 |
| `ISS-TEST-IT-01` | `eq-001` | ICT | Moyen | Assigned | `test.tech.it@kabutare.rw` | SCN-IT-01 |
| `ISS-TEST-INFRA-01` | *(lieu)* | Administration | Moyen | Assigned | `test.tech.infra@kabutare.rw` | SCN-INFRA-01 |
| `ISS-TEST-CROSS-01` | `eq-003` | OPD | Critique | Reported | *(non assigné)* | SCN-CROSS-01 |

### Articles d'inventaire

| ID | Nom | Stock actuel | Stock minimum | Utilisé dans |
|---|---|---|---|---|
| `inv-001` | Gants stériles (boîte 100) | 45 | 20 | SCN-TECH-02 |
| `inv-002` | Masques chirurgicaux | 12 | 15 | — |

### Lieux d'infrastructure

| ID | Nom | Bâtiment | Département |
|---|---|---|---|
| `loc-test-01` | Couloir principal — urgences | Bâtiment Principal | Urgences |
| `loc-test-02` | Salle électrique — RDC | Bâtiment Technique | Administration |

---

## Checklist de préparation avant session de recette

- [ ] Environnement dev opérationnel : `https://dev.kabutare.duckdns.org/health` répond `{"status":"ok"}`
- [ ] Realm Keycloak `kabutare-hospital` accessible en dev
- [ ] 7 comptes de test créés avec les rôles et attributs corrects
- [ ] Données seed chargées (`node seed.js` dans auth-service-dev et db-service-dev)
- [ ] Incidents pré-créés (statuts "Assigned" + techniciens assignés)
- [ ] Articles d'inventaire vérifiés (stocks corrects)
- [ ] Lieux d'infrastructure créés (`loc-test-01`, `loc-test-02`)
- [ ] Boîte mail de test accessible pour vérifier les notifications email
- [ ] Ce fichier imprimé ou ouvert sur un second écran pendant la recette

---

## Commandes de vérification rapide (pour le technicien ICT)

```bash
# Vérifier que les 7 comptes ont le bon rôle (remplacer l'email et le token)
curl -H "Authorization: Bearer <TOKEN>" https://dev.kabutare.duckdns.org/auth/api/auth/me | jq '.permissions'

# Vérifier les incidents pré-créés
curl -H "Authorization: Bearer <TOKEN>" https://dev.kabutare.duckdns.org/db/api/issues | jq '[.[] | {id, status, assigned_technician}]'

# Vérifier les stocks d'inventaire
curl -H "Authorization: Bearer <TOKEN>" https://dev.kabutare.duckdns.org/db/api/inventory | jq '[.[] | {id, name, current_stock, min_stock}]'
```

---

*Document généré le 2026-06-04 — à mettre à jour avant chaque session de recette.*
