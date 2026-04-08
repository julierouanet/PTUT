# Resume - Need Software Kabutare

## Informations generales

- **Commanditaire** : Dr. NZABONIMANA Ephraim (nzephmd@gmail.com / +250 788823228)
- **Entite** : Hopital de District de Kabutare (Rwanda)
- **Theme** : Suivi du fonctionnement hospitalier, signalement des pannes de materiels, accreditation, surveillance des maladies, sante environnementale et communautaire, ressources humaines

## Objectif global

Construire un logiciel complet de suivi de toutes les fonctionnalites des services de sante de l'hopital, compose de **7 modules** :

---

## Module 1 : Gestion des Equipements et Maintenance (PRINCIPAL)

> C'est le module principal du projet PTUT.

### But

Permettre au personnel de suivre, surveiller et signaler les problemes lies a tous les materiels (ICT, biomedicaux, infrastructure) dans tous les departements.

### Departements couverts (20+)

Administration, OPD, Medecine Interne, Pediatrie, Urgences, Laboratoire, Stomatologie, Kinesitherapie, Neonatologie, Maternite, Chirurgie, Bloc Operatoire, Ophtalmologie, TB-MR, GBV, Sante Mentale, ARV

### Categories de materiels

- Equipements ICT
- Materiels d'hygiene
- Equipements biomedicaux
- Equipements electriques
- Sterilisation et blanchisserie
- Pharmacie

### Utilisateurs et roles

| Role | Description | Permissions |
|------|-------------|-------------|
| Hospital Staff | Docteurs, infirmiers, techniciens labo | Voir equipements, signaler problemes, suivre ses demandes |
| Supervisors / Chefs de dept | Gestion des equipements du departement | Approuver demandes, assigner des taches de maintenance |
| Maintenance / Techniciens | Traiter les incidents signales | Mettre a jour le statut de reparation, enregistrer les pieces remplacees |
| Administrateur (ICT) | Configuration systeme, controle d'acces | Gerer utilisateurs, departements, categories, rapports |

### Exigences fonctionnelles

#### 4.1 Gestion des equipements
- Enregistrer et categoriser tous les materiels par departement, type, numero de serie, etat, emplacement, fournisseur
- Suivre le statut : Disponible, En Utilisation, En Maintenance, Hors Service
- Enregistrer les calendriers de maintenance et l'historique de service

#### 4.2 Signalement d'incidents
- Tout membre du personnel peut soumettre un rapport d'incident rapidement
- Le rapport inclut : ID/nom de l'equipement, type de probleme (ICT, hygiene, biomedical, electrique), description, upload photo optionnel
- Capture automatique du nom du rapporteur, departement et horodatage

#### 4.3 Notifications et escalades
- Notification automatique au superviseur du departement et a l'equipe de maintenance quand un incident est signale
- Alertes via : notifications in-app, SMS/email (si integre)
- Escalade des incidents non resolus apres un delai defini

#### 4.4 Suivi des incidents
- Les superviseurs voient les incidents ouverts, en cours et resolus
- Les techniciens mettent a jour la progression (diagnostic, pieces commandees, repare, teste)
- Le personnel suit le statut de resolution de ses signalements

#### 4.5 Inventaire et suivi des materiels
- Suivre les quantites de materiels d'hygiene et consommables
- Alertes de reapprovisionnement quand le stock est bas
- Rapports d'utilisation et pertes par departement

#### 4.6 Rapports et analyses
- Par departement : listes d'inventaire, rapports de maintenance, analyse des temps d'arret, rapports de couts
- Export en Excel / PDF

### Workflow type

1. Une infirmiere en Neonatologie remarque une couveuse en panne
2. Elle ouvre le systeme -> "Signaler un incident" -> selectionne Equipement Biomedical -> Couveuse #NEO-004 -> Description -> Soumettre
3. Le superviseur de Neonatologie et le technicien de maintenance sont notifies instantanement
4. Le technicien met a jour : En reparation
5. Apres reparation -> Le technicien marque Resolu, ajoute des notes de maintenance
6. Le superviseur verifie -> marque Cloture
7. Le systeme enregistre l'evenement et met a jour le statut de l'equipement

### Exigences non-fonctionnelles

| Categorie | Description |
|-----------|-------------|
| Performance | Supporter 200+ utilisateurs simultanes |
| Disponibilite | Fonctionnement 24/7 avec sauvegardes automatiques quotidiennes |
| Securite | Acces base sur les roles, connexions chiffrees (HTTPS), logs d'audit |
| Scalabilite | Ajout facile de nouveaux departements ou categories de materiels |
| Utilisabilite | Interface tableau de bord simple, responsive (mobile/tablette) |
| Interoperabilite | Integration optionnelle avec RH, achats, finance de l'hopital |

---

## Module 2 : Sante Environnementale

### Outil d'evaluation du tri des dechets
- Verification de la disponibilite et du bon etat des poubelles (poubelles a pedale)
- Tri par code couleur : dechets infectieux, anatomiques/hautement infectieux, objets tranchants, dechets generaux, dechets alimentaires
- Controle du placement des boites de securite (pas au sol)

### Outil d'evaluation quotidienne du lavage des mains
- Disponibilite et accessibilite des stations de lavage
- Disponibilite de l'eau et des fournitures
- Etat et fonctionnement des lavabos
- Affichage de la signalisation d'hygiene des mains
- Respect de la politique (temps, etapes, 5 moments du lavage)
- Accessibilite des distributeurs d'alcool

---

## Module 3 : Accreditation

Suivi et documentation des activites de conformite :

1. **Reunions departementales mensuelles** : departement, sujets, liste de presence, rapport
2. **Rapports d'incidents** : description, service concerne, action immediate, suivi
3. **Rapports de formation continue** : departement, sujet, scores de competence, presence
4. **Projets d'amelioration de la qualite (QI)** : departement, titre, rapport, presence
5. **Documentation d'accreditation** : politique/protocole revu, resume, presence
6. **Reunions de comites** : nom du comite, sujet, proces-verbal

---

## Module 4 : Sante Communautaire

- Rapports sur les accouchements a domicile (par service)
- Rapports hebdomadaires d'activites communautaires
- Etat du stock de medicaments dans les centres de sante communautaires
- Comptage et performance des agents de sante communautaire

---

## Module 5 : Surveillance des Maladies

- Evenements communautaires signales par les sentinelles
- Rapports sur les epidemies ou maladies emergentes
- Rapports de deces communautaires
- Rapports de reponse aux evenements

---

## Module 6 : Ressources Humaines

- **Missions** : processus d'autorisation de mission, rapport de resultat, partage de competences
- **Gestion du personnel** :
  - Plan de conges par departement
  - Processus d'arrangement et approbation du personnel
  - Demandes de permission selon le reglement
  - Espace commentaires, recommandations et plaintes du personnel
  - Analyse de la presence par departement
  - Statut et analyse du turnover (recrutements en attente, effectifs disponibles, urgences)

---

## Module 7 : Logistique

### Gestion des stocks
- Reception, demande, livraison

### Gestion des actifs
- Reception, demande, livraison
- Mouvement d'actifs entre services
- Mise au rebut d'actifs

---

## Module 8 : Gestion des Donnees

- L'hopital dispose deja d'une base de donnees ISIS Student fonctionnelle pour le suivi quotidien des donnees
- Besoin de formation des equipes IT comme administrateurs pour la mise a jour

---

## Perimetre du projet PTUT

Le projet PTUT se concentre principalement sur le **Module 1 : Gestion des Equipements et Maintenance**, qui est le module le plus detaille et prioritaire du cahier des charges. Les autres modules representent les besoins futurs de l'hopital.
