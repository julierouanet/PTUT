# 📝 TODO — Modifications par page (GMAO Kabutare)

> Date : 2026-06-20
> Document de cadrage. **Aucun code ici** — juste l'organisation des idées, page par page.
> Légende statut : ✨ Nouvelle feature · 🔄 Refonte · 🐛 Bug/QA · 🎨 UI · ❓ À décider · ⬜ Non encore réfléchi

---

## 🔐 1. Page Authentification — `login_screen.dart`

| # | Modification | Type |
|---|---|---|
| 1.1 | **Auth technicien externe** : il saisit un code fourni par un technicien interne pour éditer **une issue précise** | ✨ |
| 1.2 | « Request access » → devient une vraie **création de compte** | 🔄 |
| 1.3 | Choisir l'**administrateur lead** (dans les paramètres) dont les coordonnées s'affichent sur la page de connexion pour les demandes d'aide | ✨ |
| 1.4 | Vérifier que **Forgot password** fonctionne réellement | 🐛 |
| 1.5 | Ajouter le **logo ISIS** + lien vers une page « À propos / qui a fait le projet » | 🎨 |
| 1.6 | Faire une **création de compte complète** pour détecter les bugs | 🐛 |

**À cadrer** : durée de vie du code technicien externe, périmètre des droits, sécurité.

---

## 🛠️ 2. Module Équipement

### 2.A Page Équipement — onglet **Liste** — `equipment_list_screen.dart`

| # | Modification | Type |
|---|---|---|
| 2.A.1 | La pastille de **statut déborde** sur la colonne suivante (collée) → fix layout | 🐛 |
| 2.A.2 | **Régénérer** la liste d'équipements | 🔄 |
| 2.A.3 | **Reset de la base de données** | ❓ |
| 2.A.4 | **Retirer** l'édition d'équipement d'ici → la laisser uniquement en page détail | 🔄 |

### 2.B Page Équipement — onglet **Catégorie** — `category_detail_screen.dart`

| # | Modification | Type |
|---|---|---|
| 2.B.1 | **Notification** si une sous-catégorie ne contient aucun équipement | ✨ |
| 2.B.2 | **Déplacer** modif/suppression des sous-catégories vers leur page détail | 🔄 |

### 2.C Page **Détail Équipement** — `equipment_detail_screen.dart`

**Arborescence**
| # | Modification | Type |
|---|---|---|
| 2.C.1 | Arborescence complète : **Département › Catégorie › Sous-catégorie › Équipement** (catégorie manquante en haut) | 🎨 |

**Onglet Information**
| # | Modification | Type |
|---|---|---|
| 2.C.2 | Bouton d'édition **individuelle** à droite de chaque info | ✨ |
| 2.C.3 | Mettre le **tag** dans « infos générales » | 🎨 |
| 2.C.4 | Ajouter une **description** de l'équipement, liée à la **sous-catégorie** (ex. pèse-personne) | ✨ |
| 2.C.5 | Ajouter le **modèle** de l'équipement dans infos générales | ✨ |
| 2.C.6 | Notif **missing data / reference lifespan** → **cliquable** → mène à l'écran de correction | ✨ |
| 2.C.7 | Afficher si l'équipement a un **incident reporté** + accès rapide | ✨ |
| 2.C.8 | **Résumé** : nb d'incidents liés + maintenance à jour ? + édition du **label** | ✨ |

**Onglet Maintenance**
| # | Modification | Type |
|---|---|---|
| 2.C.9 | Les **notifications** ne s'affichent **plus ici** (uniquement onglet Information) | 🔄 |
| 2.C.10 | Revoir la partie **maintenance préventive** | 🔄 |
| 2.C.11 | Rendre **cliquables** les anciennes maintenances → accès à l'**ancienne étiquette** | ✨ |

**Onglet Incidents**
| # | Modification | Type |
|---|---|---|
| 2.C.12 | Les **notifications** ne s'affichent **plus ici** (uniquement onglet Information) | 🔄 |

**Onglet Documents**
| # | Modification | Type |
|---|---|---|
| 2.C.13 | Les **notifications** ne s'affichent **plus ici** (uniquement onglet Information) | 🔄 |

### 2.D Page **Détail Sous-catégorie** — `subcategory_detail_screen.dart`

| # | Modification | Type |
|---|---|---|
| 2.D.1 | Ajouter l'**arborescence** (comme la page détail équipement) | 🎨 |
| 2.D.2 | **Retirer** la notif reference lifespan (elle se multiplie par le nb d'équipements) | 🐛 |
| 2.D.3 | Ajouter **infos générales** : description de l'objet + reference lifespan | ✨ |

### 2.E Page **Détail Département** — `department_detail_screen.dart`

| # | Modification | Type |
|---|---|---|
| 2.E.1 | Dashboard **plus expressif** | 🔄 |
| 2.E.2 | Afficher les **notifications** dans la liste d'équipements | ✨ |
| 2.E.3 | Envisager une refonte de la page avec des **onglets** | 🔄 |

---

## 🎫 3. Page Issue Tracking — `issue_tracking_screen.dart`

| # | Modification | Type |
|---|---|---|
| 3.1 | **3 onglets** : (a) Mes signalements · (b) Toutes les issues · (c) Issues terminées | 🔄 |
| 3.2 | **Supprimer** le panneau de détail à droite | 🔄 |
| 3.3 | Au clic sur une issue → ouvrir la **page détaillée** de l'issue | 🔄 |

---

## 👨‍🔧 4. Page Technicien — `technician_update_screen.dart`

| # | Modification | Type |
|---|---|---|
| 4.1 | Réordonner les onglets : **« To validate » en premier** | 🎨 |
| 4.2 | Déplacer le **Schedule** dans une nouvelle page dédiée | 🔄 |
| 4.3 | Onglet To validate : remplacer boutons Validate + Detail par **un seul bouton** → ouvre les détails, permet de **valider** ET **réassigner** à d'autres techniciens | 🔄 |

---

## 📊 5. Page Reports — `reports_screen.dart`

| # | Modification | Type |
|---|---|---|
| 5.1 | « Breakdown by status » **à côté de** « Issue statistics » | 🎨 |
| 5.2 | « Equipment by category » **à côté de** « Equipment by department » | 🎨 |

---

# ⚠️ Pages OUBLIÉES (existent dans l'app, rien de prévu dessus)

> Décide pour chacune : **à modifier**, **à vérifier**, ou **hors scope**.

## 6. Détail / Formulaire Issue

| Écran | À décider |
|---|---|
| `issue_detail_screen.dart` / `issue_staff_detail_screen.dart` | C'est la « page détaillée » ciblée en 3.3 — convient-elle telle quelle ou refonte ? | ⬜ |
| `issue_form_screen.dart` | Formulaire de signalement — aucune modif prévue ? | ⬜ |

## 7. Catalogue Fabricant / Modèle (FEAT-065)

| Écran | À décider |
|---|---|
| `brand_detail_screen.dart` | Tu ajoutes le « modèle » au détail équipement (2.C.5) mais ne touches pas ces pages | ⬜ |
| `model_detail_screen.dart` | Lien avec la description par sous-catégorie (2.C.4) ? | ⬜ |

## 8. Accueil & Dashboard

| Écran | À décider |
|---|---|
| `home_hub_screen.dart` / `dashboard_screen.dart` | Dashboard principal — aucune modif prévue ? | ⬜ |
| `equipment_hub_screen.dart` | Hub d'entrée du module équipement | ⬜ |
| `inventory_screen.dart` | Écran inventaire | ⬜ |

## 9. Module Utilisateurs & Rôles

| Écran | À décider |
|---|---|
| `user_management_screen.dart` | Lien avec « admin lead » (1.3) et la création de compte (1.2) | ⬜ |
| `user_detail_screen.dart` | | ⬜ |
| `role_detail_screen.dart` | | ⬜ |

## 10. Paramètres

| Écran | À décider |
|---|---|
| `settings_screen.dart` | Reçoit « admin lead » (1.3) — autre chose ? | ⬜ |
| `account_settings_screen.dart` | Préférences compte / notifications (FEAT-029) | ⬜ |

## 11. Analytics vs Reports

| Écran | À décider |
|---|---|
| `analytics_screen.dart` | **Distinct** de `reports_screen` — tes modifs (§5) ne touchent que Reports. Doublon à fusionner ? | ⬜ |

## 12. Écrans admin / technique

| Écran | À décider |
|---|---|
| `backup_management_screen.dart` | Sauvegardes | ⬜ |
| `logs_screen.dart` | Journal d'audit | ⬜ |
| `feature_management_screen.dart` | Feature flags | ⬜ |
| `debug_test_screen.dart` | **À retirer du build prod ?** | ❓ |

---

# 🧩 Chantiers transverses (à cadrer AVANT de coder)

1. **Système de notifications par équipement** — centralisé sur l'onglet Information, retiré ailleurs (2.C.9/12/13, 2.D.2, 2.E.2). Logique commune = mini-chantier.
2. **Reset / régénération de la base** (2.A.2, 2.A.3) — opération destructive. Décider : reset complet vs reseed démo. ⚠️ Voir piège `docker compose down -v`.
3. **Technicien externe + code à usage unique** (1.1) — nouveau flux d'auth + sécurité = la feature la plus lourde, à traiter seule.
4. **Description liée à la sous-catégorie** (2.C.4, 2.D.3) — nouvelle colonne DB sur `subcategories` → met à jour `contexte.md`.

---

# 🎯 Suggestion de priorisation

**Quick wins (UI / bugs)** : 2.A.1, 2.C.1, 2.C.3, 4.1, 5.1, 5.2, 1.5
**Moyens (refonte écran)** : 3.x, 4.2, 4.3, 2.E.x, 2.B.x
**Gros chantiers (cadrage requis)** : 1.1, 1.2, système de notifications, reset DB, 2.C maintenance préventive
