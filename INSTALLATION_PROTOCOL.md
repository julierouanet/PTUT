# Protocole d'Installation — Hôpital de Kabutare
## Déploiement IP-only sur serveur Ubuntu vierge

> **Version** : 1.0 — Mai 2026  
> **Stack** : Flutter Web · Node.js (auth-service, db-service) · Keycloak 26 · PostgreSQL 16 · Nginx  
> **Mode** : HTTPS auto-signé, accès par adresse IP publique (sans nom de domaine)

---

## Table des matières

1. [Vue d'ensemble de l'architecture](#1-vue-densemble)
2. [Prérequis](#2-prérequis)
3. [Étape 0 — Préparation des images (machine de dev)](#3-étape-0--préparation-des-images-machine-de-dev)
4. [Étape 1 — Préparation du serveur Ubuntu](#4-étape-1--préparation-du-serveur-ubuntu)
5. [Étape 2 — Déploiement automatique](#5-étape-2--déploiement-automatique)
6. [Étape 3 — Configuration initiale Keycloak](#6-étape-3--configuration-initiale-keycloak)
7. [Étape 4 — Seed des données de démonstration](#7-étape-4--seed-des-données-de-démonstration)
8. [Étape 5 — Vérifications et tests](#8-étape-5--vérifications-et-tests)
9. [Troubleshooting](#9-troubleshooting)
10. [Référence : variables d'environnement](#10-référence--variables-denvironnement)

---

## 1. Vue d'ensemble

```
Internet
    │  HTTPS :443
    ▼
┌─────────────────────────────────────────────┐
│  Nginx (nginx-ip)  — reverse-proxy + TLS    │
│  /          → Flutter Web (fichiers statiques)│
│  /auth/     → auth-service:3001             │
│  /db/       → db-service:3002               │
│  /keycloak/ → Keycloak:8080/keycloak/       │
└──────┬──────────┬───────────────┬───────────┘
       │          │               │
  auth-service  db-service    Keycloak
  (Node 20)    (Node 20)      (port 8080,
  SQLite       SQLite          interne seulement)
                                   │
                              PostgreSQL 16
```

**Routing résumé :**

| URL                                       | Service          |
|-------------------------------------------|------------------|
| `https://<IP>/`                           | Application Flutter |
| `https://<IP>/auth/health`                | Santé auth-service |
| `https://<IP>/db/health`                  | Santé db-service |
| `https://<IP>/keycloak/`                  | Keycloak (login) |
| `https://<IP>/keycloak/admin/`            | Console admin Keycloak |

---

## 2. Prérequis

### Sur la machine de développement

| Requis | Détail |
|--------|--------|
| Docker Desktop | Avec support `--platform linux/amd64` |
| Accès Docker Hub | Compte `litlewolf` avec Personal Access Token |
| Code source | Dépôt cloné, branche `main` à jour |

### Sur le serveur Ubuntu

| Requis | Détail |
|--------|--------|
| OS | Ubuntu 22.04 LTS ou 24.04 LTS (amd64) |
| Accès | SSH avec droits `sudo` |
| IP publique | Connue et fixe |
| RAM | 4 Go minimum recommandés (Keycloak est gourmand) |
| Disque | 20 Go minimum |
| Ports ouverts | 80/TCP et 443/TCP accessibles depuis Internet |

### Images Docker Hub requises

| Image | Poussée par | Statut |
|-------|------------|--------|
| `litlewolf/kabutare-auth-service:latest` | Jenkins (auto) | ✅ Public |
| `litlewolf/kabutare-db-service:latest` | Jenkins (auto) | ✅ Public |
| `litlewolf/kabutare-keycloak:latest` | Jenkins (auto) | ✅ Public |
| `litlewolf/kabutare-nginx:latest` | `build_and_push.sh` (manuel) | ⚠ Voir Étape 0 |

---

## 3. Étape 0 — Préparation des images (machine de dev)

> **À faire une seule fois**, ou à chaque modification de l'application Flutter.  
> Cette étape crée l'image `kabutare-nginx` qui contient le build Flutter.  
> Les 3 autres images sont mises à jour automatiquement par Jenkins à chaque push sur `main`.

### 3.1 Vérifier que Docker tourne

```bash
docker version
```

### 3.2 Lancer le script de build et push

Depuis la **racine du dépôt** :

```bash
chmod +x build_and_push.sh
./build_and_push.sh litlewolf
```

Le script va :
1. Vous demander de vous connecter à Docker Hub
2. Builder l'application Flutter avec les URLs contenant le placeholder `__SERVER_IP__`
3. Builder et pousser les 4 images sur Docker Hub

> **Note :** Le placeholder `__SERVER_IP__` sera remplacé par la vraie IP du serveur au démarrage du conteneur Nginx. L'image peut être réutilisée pour n'importe quel serveur.

### 3.3 Vérifier que les 4 images sont sur Docker Hub

```bash
docker manifest inspect litlewolf/kabutare-nginx:latest
docker manifest inspect litlewolf/kabutare-auth-service:latest
docker manifest inspect litlewolf/kabutare-db-service:latest
docker manifest inspect litlewolf/kabutare-keycloak:latest
```

Chaque commande doit retourner un JSON sans erreur.

---

## 4. Étape 1 — Préparation du serveur Ubuntu

### 4.1 Se connecter en SSH

```bash
ssh user@<IP_DU_SERVEUR>
```

### 4.2 Créer le répertoire de travail et transférer les fichiers

Depuis la **machine de développement** (dans la racine du dépôt) :

```bash
ssh user@<IP_DU_SERVEUR> "mkdir -p ~/kabutare"

scp setup_ubuntu.sh docker-compose.ip.yml user@<IP_DU_SERVEUR>:~/kabutare/
```

> Seuls ces deux fichiers sont nécessaires sur le serveur.  
> Le code source Flutter et les Dockerfiles restent sur la machine de dev.

---

## 5. Étape 2 — Déploiement automatique

Le script `setup_ubuntu.sh` automatise toutes les étapes d'installation. Il est **idempotent** : peut être relancé sans risque.

### 5.1 Lancer le script

Sur le serveur, dans le répertoire `~/kabutare/` :

```bash
cd ~/kabutare
sudo bash setup_ubuntu.sh
```

### 5.2 Ce que le script fait automatiquement

| Étape | Action |
|-------|--------|
| 1/7 | `apt update && apt upgrade` |
| 2/7 | Installation de Docker Engine + Compose V2 (si absent) |
| 3/7 | Détection automatique de l'IP publique (avec confirmation) |
| 4/7 | Création interactive du fichier `.env` (demande les mots de passe) |
| 5/7 | Génération du certificat SSL auto-signé (valide 10 ans) |
| 6/7 | Pull des 4 images depuis Docker Hub |
| 7/7 | `docker compose up -d` + attente Keycloak + configuration du realm |

### 5.3 Informations demandées pendant l'exécution

Le script pose 3 questions lors de la première installation :

```
Docker Hub username :          → litlewolf
Mot de passe admin Keycloak :  → (choisir un mot de passe fort)
Mot de passe PostgreSQL :      → (choisir un mot de passe fort)
```

> Le secret `INTERNAL_SECRET` est généré automatiquement avec `openssl rand -hex 32`.

### 5.4 Résultat attendu en fin de script

```
========================================================
 ✓ Déploiement terminé !

 Application Flutter  : https://<IP>
 Admin Keycloak        : https://<IP>/keycloak/admin/
 Health auth-service   : https://<IP>/auth/health
 Health db-service     : https://<IP>/db/health
========================================================
```

---

## 6. Étape 3 — Configuration initiale Keycloak

> **Obligatoire à la première installation.** Keycloak démarre vide — le realm et les clients doivent être créés.

### 6.1 Accéder à la console admin

Ouvrir dans le navigateur : `https://<IP>/keycloak/admin/`

> ⚠ Le navigateur affichera un avertissement de sécurité (certificat auto-signé).  
> Cliquer sur **Avancé → Continuer quand même** (Chrome) ou **Accepter le risque** (Firefox).

Se connecter avec :
- Utilisateur : `admin`
- Mot de passe : celui saisi lors du `setup_ubuntu.sh`

### 6.2 Créer le realm `kabutare-hospital`

1. Cliquer sur le menu déroulant **master** (en haut à gauche)
2. Cliquer sur **Create Realm**
3. **Realm name** : `kabutare-hospital`
4. Cliquer sur **Create**

### 6.3 Créer le client `flutter-app` (application Flutter)

Dans le realm `kabutare-hospital` → **Clients** → **Create client** :

| Champ | Valeur |
|-------|--------|
| Client type | OpenID Connect |
| Client ID | `flutter-app` |
| Name | Flutter App |

Cliquer **Next**, puis :

| Champ | Valeur |
|-------|--------|
| Client authentication | OFF (public) |
| Direct access grants | ON |

Cliquer **Next**, puis :

| Champ | Valeur |
|-------|--------|
| Valid redirect URIs | `https://<IP>/*` |
| Web origins | `https://<IP>` |

Cliquer **Save**.

### 6.4 Créer le client `auth-service` (service interne)

**Clients** → **Create client** :

| Champ | Valeur |
|-------|--------|
| Client type | OpenID Connect |
| Client ID | `auth-service` |

Cliquer **Next**, puis :

| Champ | Valeur |
|-------|--------|
| Client authentication | ON (confidential) |
| Service accounts roles | ON |

Cliquer **Save**.

Aller dans l'onglet **Credentials** du client `auth-service` et copier le **Client secret**.

### 6.5 Mettre à jour le fichier `.env` avec le secret client

Sur le serveur :

```bash
cd ~/kabutare
nano .env
```

Remplacer la ligne :
```
KC_CLIENT_SECRET_AUTH=changez-moi-apres-creation-client-keycloak
```
par le secret copié depuis Keycloak :
```
KC_CLIENT_SECRET_AUTH=<secret-copié>
```

Sauvegarder (`Ctrl+O`, `Ctrl+X`).

### 6.6 Créer les rôles du realm

Dans **Realm roles** → **Create role**, créer les 6 rôles suivants :

| Rôle | Description |
|------|-------------|
| `admin` | Administrateur système |
| `supervisor` | Superviseur médical |
| `hospitalStaff` | Personnel hospitalier |
| `technician_biomedical` | Technicien biomédical |
| `technician_it` | Technicien informatique |
| `technician_infra` | Technicien infrastructure |

### 6.7 Redémarrer auth-service pour prendre en compte le secret

```bash
cd ~/kabutare
docker compose -f docker-compose.ip.yml restart auth-service
```

### 6.8 Vérifier que auth-service est healthy

```bash
docker compose -f docker-compose.ip.yml ps auth-service
```

Le statut doit afficher `healthy`.

---

## 7. Étape 4 — Seed des données de démonstration

> Optionnel — peuple la base SQLite avec des utilisateurs et équipements de démonstration.

### 7.1 Seed auth-service (utilisateurs Keycloak + permissions)

```bash
docker exec auth-service-ip node seed.js
```

### 7.2 Seed db-service (équipements, départements, incidents)

```bash
docker exec db-service-ip node seed.js
```

> Les seeds sont **idempotents** : les relancer ne crée pas de doublons.

---

## 8. Étape 5 — Vérifications et tests

### 8.1 État des conteneurs

```bash
docker compose -f docker-compose.ip.yml ps
```

Résultat attendu (tous `healthy` sauf postgres qui affiche `healthy` aussi) :

```
NAME                   STATUS
nginx-ip               Up
auth-service-ip        Up (healthy)
db-service-ip          Up (healthy)
keycloak-ip            Up (healthy)
postgres-keycloak-ip   Up (healthy)
```

### 8.2 Tests dans le navigateur

| URL | Résultat attendu |
|-----|-----------------|
| `https://<IP>/` | Application Flutter (écran de login) |
| `https://<IP>/auth/health` | `{"status":"ok"}` |
| `https://<IP>/db/health` | `{"status":"ok"}` |
| `https://<IP>/keycloak/` | Page de login Keycloak |
| `https://<IP>/keycloak/admin/` | Console admin Keycloak |

> Tous les appels passent par Nginx en HTTPS. Le navigateur affichera un avertissement de certificat auto-signé à accepter **une seule fois**.

### 8.3 Vérification des logs en temps réel

```bash
# Tous les services
docker compose -f docker-compose.ip.yml logs -f

# Un service en particulier
docker compose -f docker-compose.ip.yml logs -f keycloak
docker compose -f docker-compose.ip.yml logs -f auth-service
docker compose -f docker-compose.ip.yml logs -f nginx-ip
```

### 8.4 Test de connexion complet

1. Ouvrir `https://<IP>/` dans le navigateur
2. Se connecter avec un compte créé via le seed (ou un compte créé dans Keycloak)
3. Vérifier l'accès au dashboard

---

## 9. Troubleshooting

### Keycloak démarre lentement ou reste "unhealthy"

```bash
# Vérifier les logs Keycloak
docker compose -f docker-compose.ip.yml logs --tail=50 keycloak

# Vérifier que PostgreSQL est healthy
docker compose -f docker-compose.ip.yml ps postgres-keycloak-ip

# Tester le health endpoint manuellement
docker exec keycloak-ip wget -qO- http://localhost:9000/health/ready
```

Keycloak peut prendre **jusqu'à 3 minutes** au premier démarrage (build du cache JPA).

---

### auth-service ou db-service : "Token invalide ou expiré"

Cause probable : `KC_ISSUER` dans le `.env` ne correspond pas à l'URL réelle du token.

```bash
# Vérifier la valeur actuelle
grep KC_ISSUER ~/kabutare/.env
# Doit afficher : KC_ISSUER=https://<IP>/keycloak/realms/kabutare-hospital

# Tester le endpoint de découverte Keycloak
curl -k https://<IP>/keycloak/realms/kabutare-hospital/.well-known/openid-configuration
```

---

### Nginx retourne 502 Bad Gateway

Le service en aval n'est pas encore démarré ou est unhealthy.

```bash
# Vérifier l'état de tous les services
docker compose -f docker-compose.ip.yml ps

# Redémarrer le service problématique
docker compose -f docker-compose.ip.yml restart auth-service
```

---

### L'application Flutter affiche des erreurs CORS

Vérifier que `CORS_ORIGIN` dans `.env` correspond exactement à `https://<IP>` (sans slash final).

```bash
grep CORS_ORIGIN ~/kabutare/.env
# Doit afficher : CORS_ORIGIN=https://203.0.113.42
```

Redémarrer après correction :
```bash
docker compose -f docker-compose.ip.yml restart auth-service db-service
```

---

### Certificat SSL : erreur "certificate verify failed"

Le certificat est auto-signé — c'est normal. Dans le navigateur, accepter l'exception de sécurité. Ce comportement **ne peut pas être évité** sans nom de domaine (Let's Encrypt requiert un domaine DNS).

---

### Arrêter / Redémarrer la stack

```bash
cd ~/kabutare

# Arrêter sans supprimer les données
docker compose -f docker-compose.ip.yml stop

# Redémarrer
docker compose -f docker-compose.ip.yml start

# Redémarrer après modification du .env
docker compose -f docker-compose.ip.yml up -d

# ⚠ DANGER — supprime TOUTES les données (SQLite, PostgreSQL)
# docker compose -f docker-compose.ip.yml down -v   # NE PAS EXÉCUTER en prod
```

---

### Mettre à jour les images après un nouveau build

```bash
cd ~/kabutare

# Pull des dernières images
docker compose -f docker-compose.ip.yml pull

# Redémarrer avec les nouvelles images
docker compose -f docker-compose.ip.yml up -d --force-recreate
```

---

## 10. Référence : variables d'environnement

Fichier : `~/kabutare/.env`

| Variable | Obligatoire | Description |
|----------|------------|-------------|
| `SERVER_IP` | ✅ | IP publique du serveur (ex: `203.0.113.42`) |
| `DOCKER_USER` | ✅ | Username Docker Hub (ex: `litlewolf`) |
| `INTERNAL_SECRET` | ✅ | Secret inter-services (généré auto) |
| `KC_ADMIN_USER` | ✅ | Login admin Keycloak (défaut: `admin`) |
| `KC_ADMIN_PASSWORD` | ✅ | Mot de passe admin Keycloak |
| `KC_CLIENT_SECRET_AUTH` | ✅ | Secret du client `auth-service` (depuis Keycloak) |
| `KC_DB_PASSWORD` | ✅ | Mot de passe PostgreSQL Keycloak |
| `VAPID_PUBLIC_KEY` | ⬜ | Clé publique Web Push (notifications) |
| `VAPID_PRIVATE_KEY` | ⬜ | Clé privée Web Push |
| `VAPID_CONTACT` | ⬜ | Email de contact Web Push |
| `BREVO_SMTP_HOST` | ⬜ | Hôte SMTP Brevo (emails Keycloak) |
| `BREVO_SMTP_PORT` | ⬜ | Port SMTP Brevo (défaut: 587) |
| `BREVO_SMTP_LOGIN` | ⬜ | Login SMTP Brevo |
| `BREVO_SMTP_PASSWORD` | ⬜ | Mot de passe SMTP Brevo |
| `BREVO_FROM_EMAIL` | ⬜ | Adresse expéditeur emails |
| `BREVO_FROM_NAME` | ⬜ | Nom expéditeur emails |
| `BREVO_API_KEY` | ⬜ | Clé API Brevo (emails applicatifs) |

> ✅ = Obligatoire · ⬜ = Optionnel (fonctionnalité désactivée si absent)
