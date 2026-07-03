# Protocole de déploiement — Hôpital Kabutare (IP-only, certificat auto-signé)

## Contexte

Le système est déployé sur un **serveur de l'hôpital**. Le chemin de déploiement **par défaut** est l'accès direct par **IP publique brute** (pas de nom de domaine) avec un **certificat HTTPS auto-signé**. Deux modes d'accès utilisateur :

1. **Navigateur Web** — `https://<IP>/app_isis/` (depuis le WiFi hôpital ou Internet).
2. **Application Android (APK)** — compilée localement, pointant la même IP.

Décisions / contraintes :

- **Pas de nom de domaine acheté** → accès par **IP brute** + **certificat auto-signé** (ECDSA P-384, valide 825 jours). L'IP publique **et** l'IP locale du serveur sont placées dans le `subjectAltName` du certificat, donc le même cert fonctionne sur le WiFi interne et depuis Internet.
- **Provisionnement automatisé** via `setup_ubuntu.sh` : détection des IP, génération du cert, configuration Nginx, pare-feu, démarrage de la stack Docker et configuration Keycloak — le tout en une commande.
- **Nginx mono-port** : un seul vhost HTTPS (`server_name _`) qui sert le front Flutter Web (`/app_isis/`), les deux APIs (`/auth/`, `/db/`) et Keycloak (`/keycloak/`).
- **Aucune URL codée en dur côté Flutter** : `lib/services/api_config.dart` résout les URLs au runtime via `Uri.base` (l'hôte du navigateur). Aucun `--dart-define` n'est nécessaire pour l'IP-only.

> ✅ **CA interne — fin des avertissements navigateur** : le certificat serveur est signé par une **CA racine interne « Kabutare Hospital Root CA »** (générée par `setup_ubuntu.sh`). Chaque appareil installe cette CA **une seule fois** en suivant la page guidée `https://<IP>/setup/` (tutoriels Android / iPhone / Windows / Firefox + affiche A4 avec QR code à imprimer). Après installation : cadenas valide, aucun avertissement, et l'application est installable en PWA (« Install app » / « Add to Home Screen »). Sans la CA installée, le navigateur affiche l'avertissement classique — l'accès reste possible en l'acceptant manuellement.

> ⚠️ **Limitation connue — emails** : sans nom de domaine, il est **impossible de publier des enregistrements SPF/DKIM**. Les emails transactionnels (vérification de compte, reset mot de passe, notifications Brevo) risquent fort d'être **rejetés ou classés en spam**. Acceptable pour une mise en service interne ; pour un envoi fiable, basculer sur la famille « domaine » (voir [Annexe](#annexe--déploiement-avec-un-vrai-nom-de-domaine-optionnel)).

---

## Vue d'ensemble de l'architecture cible

```
        Réseau LAN hôpital (WiFi)            Internet (optionnel)
                  │                                  │
                  └──────────────┬───────────────────┘
                                 │ HTTPS :443
                                 │ (cert auto-signé, IP dans le SAN)
                                 ▼
   ┌──────────────────────────────────────────────────────────┐
   │  Serveur Ubuntu (Docker Compose)                          │
   │                                                          │
   │   Nginx :443 (server_name _ — accepte n'importe quelle IP)│
   │   ├── /app_isis/  → Flutter Web SPA (embarqué dans l'image)│
   │   ├── /auth/      → auth-service:3001                     │
   │   ├── /db/        → db-service:3002                       │
   │   └── /keycloak/  → keycloak:8080                         │
   │                                                          │
   │   Docker Compose (docker-compose.ip.secured.yml)         │
   │   ├── nginx-ip            (cert dans ./ssl)              │
   │   ├── auth-service-ip     (vol auth_data_ip)             │
   │   ├── db-service-ip       (vol db_data_ip)               │
   │   ├── keycloak-ip                                        │
   │   └── postgres-keycloak-ip (réseau isolé keycloak_db)    │
   └──────────────────────────────────────────────────────────┘
```

---

## Phase 0 — Prérequis serveur

| Élément               | Détail                                                            |
| --------------------- | ---------------------------------------------------------------- |
| Ubuntu 22.04 / 24.04  | accès `sudo`                                                     |
| RAM                   | 2 Go minimum (4 Go conseillé avec Keycloak + PostgreSQL)         |
| Disque                | 10 Go libre                                                      |
| IP                    | une IP publique et/ou une IP locale fixe (réservation DHCP)      |
| Internet sortant      | requis pour `apt`, `docker pull`                                 |
| Ports à ouvrir        | **443** (HTTPS) et **80** (redirection → 443) — c'est tout       |
| Logiciels             | Docker + Docker Compose v2 (installés par `setup_ubuntu.sh`)     |

> Aucune installation de Node ou Flutter sur le serveur : tout passe par des images Docker poussées sur Docker Hub (build effectué en amont sur la machine de développement via `build_and_push.sh`).

---

## Phase 1 — Déploiement automatisé (recommandé)

Le script `setup_ubuntu.sh` réalise l'intégralité du provisionnement. Copier sur le serveur **deux fichiers** suffit :

```bash
mkdir -p ~/kabutare && cd ~/kabutare
scp setup_ubuntu.sh docker-compose.ip.secured.yml user@<IP>:~/kabutare/
# (sur le serveur)
sudo bash setup_ubuntu.sh
```

Le script enchaîne 9 étapes interactives :

| Étape | Action |
|---|---|
| 1 | Mise à jour système (optionnelle) |
| 2 | Installation de Docker + Compose v2 |
| 3 | Détection de l'**IP publique** (`api.ipify.org`) et de l'**IP locale** (plages privées) |
| 4 | Génération du fichier `.env` (IP, `CORS_ORIGIN`, `KC_PUBLIC_URL`, secrets) |
| 5 | **Génération de la PKI interne** : CA racine ECDSA P-384 (10 ans) + cert serveur signé (825 j, SAN = IP publique + IP locale), config Nginx `ip.conf`, page d'installation `/setup/` (guide + affiche QR + CA téléchargeable) |
| 6 | Vérification / réattribution automatique des ports (80, 443, 8080) |
| 7 | Pare-feu `ufw` (deny incoming, SSH rate-limité, ouverture 80/443) |
| 8 | `docker compose pull` des images depuis Docker Hub |
| 9 | Démarrage de la stack + **configuration automatique de Keycloak** (realm, rôles, clients, secret `auth-service`) |

À la fin, le script propose l'initialisation des données (seed de démo / restauration d'un backup / ignorer) et affiche les URLs d'accès.

> Le certificat et la config Nginx sont **régénérés idempotemment** ; relancer le script ne casse rien (un `.env` ou un cert existant est conservé).

---

## Phase 2 — Équivalent manuel (si l'on ne veut pas le script)

### 2.1 Fichier `.env`

Copier `.env.ip.example` en `.env` et renseigner les valeurs (générer les secrets avec `openssl rand -hex 32`) :

```bash
cp .env.ip.example .env
# Renseigner au minimum : SERVER_IP, DOCKER_USER, INTERNAL_SECRET,
# KC_ADMIN_PASSWORD, KC_CLIENT_SECRET_AUTH, KC_DB_PASSWORD
# CORS_ORIGIN et KC_PUBLIC_URL doivent valoir https://<IP>
chmod 600 .env
```

### 2.2 PKI interne (CA racine + certificat serveur)

```bash
mkdir -p ssl && chmod 700 ssl

# 1. CA racine ECDSA P-384, 10 ans — générée UNE SEULE FOIS
openssl req -x509 -nodes -days 3650 -newkey ec -pkeyopt ec_paramgen_curve:P-384 \
  -keyout ssl/ca-key.pem -out ssl/ca.pem \
  -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=Kabutare Hospital Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"
chmod 600 ssl/ca-key.pem && chmod 644 ssl/ca.pem

# 2. Certificat serveur signé par la CA — 825 jours (max Chrome/Safari)
#    SAN avec IP publique (+ IP locale si différente)
openssl req -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-384 \
  -keyout ssl/key.pem -out ssl/server.csr \
  -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=<IP_PUBLIQUE>"
printf "subjectAltName=IP:<IP_PUBLIQUE>,IP:<IP_LOCALE>\nextendedKeyUsage=serverAuth\n" > ssl/server.ext
openssl x509 -req -in ssl/server.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem \
  -CAcreateserial -days 825 -out ssl/cert.pem -extfile ssl/server.ext
rm -f ssl/server.csr ssl/server.ext
chmod 600 ssl/key.pem && chmod 644 ssl/cert.pem
```

> ⚠️ `ca-key.pem` ne quitte **jamais** le serveur et n'est jamais servi par Nginx. Seule la CA **publique** (`ca.pem`, copiée en `setup/kabutare-ca.crt`) est distribuée aux appareils via `/setup/`.

### 2.3 Nginx

La config `nginx/conf.d/ip.conf` (server_name `_`, routage `/auth/`, `/db/`, `/keycloak/`, `/app_isis/`) est montée directement par `docker-compose.ip.secured.yml`. Le placeholder `__NGINX_SERVER_IP__` (réécriture sub_filter des ressources Keycloak) doit être remplacé par l'IP publique réelle :

```bash
sed -i "s/__NGINX_SERVER_IP__/<IP_PUBLIQUE>/g" nginx/conf.d/ip.conf
```

### 2.4 Démarrage

```bash
docker compose -f docker-compose.ip.secured.yml up -d
docker compose -f docker-compose.ip.secured.yml ps   # tous healthy
```

> `docker-compose.ip.secured.yml` est la variante **durcie** : réseaux cloisonnés (`frontend` / `backend` / `keycloak_db`), `cap_drop: ALL`, `no-new-privileges`, PostgreSQL isolé. C'est le compose recommandé pour l'IP-only.

---

## Phase 3 — Configuration Keycloak

Si `setup_ubuntu.sh` a réussi l'étape 9, Keycloak est **déjà configuré** (realm `kabutare-hospital`, 6 rôles, clients `flutter-app` et `auth-service`, secret injecté dans `.env`). Il reste à créer les utilisateurs.

En cas de configuration manuelle, ouvrir `https://<IP>/keycloak/admin/` et :

1. Créer le realm `kabutare-hospital` (`resetPasswordAllowed=true`, `loginWithEmailAllowed=true`).
2. Rôles realm : `admin`, `supervisor`, `hospitalStaff`, `technician_biomedical`, `technician_it`, `technician_infra`.
3. Client `flutter-app` : public, Direct Access Grants ON, redirect URI `https://<IP>/app_isis/*`, web origins `https://<IP>`.
4. Client `auth-service` : confidential, Service Accounts ON ; assigner le rôle `manage-users` (client `realm-management`) au service account ; copier le client secret dans `.env` (`KC_CLIENT_SECRET_AUTH`) puis `docker compose -f docker-compose.ip.secured.yml restart auth-service`.

> ⚠️ Le claim `iss` du JWT vaut `https://<IP>/keycloak/realms/kabutare-hospital`. `KC_ISSUER` (services Node) **doit** correspondre exactement, sinon toute validation JWT échoue. Le script gère ce calcul (variable `KC_PUBLIC_URL`).

---

## Phase 4 — Initialiser les données

```bash
# Utilisateurs / permissions applicatives (admin par défaut — à changer immédiatement)
docker exec auth-service-ip node seed.js

# OPTION A — données démo (équipements fictifs)
docker exec db-service-ip node seed.js

# OPTION B — inventaire physique réel (à privilégier en production)
docker cp /chemin/vers/inventaire.xlsx db-service-ip:/tmp/inventory.xlsx
docker exec db-service-ip node scripts/import_inventory.js --xlsx /tmp/inventory.xlsx
```

L'import est idempotent (`UPSERT` par défaut, `created_at` préservé). `setup_ubuntu.sh` propose ces opérations à son étape finale.

---

## Phase 5 — Compiler et distribuer l'APK Android

Le front Web est **embarqué dans l'image Docker `nginx`** (build effectué par `build_and_push.sh`). Pour l'APK Android, compiler localement **sans `--dart-define`** (résolution auto via `Uri.base`) :

```bash
cd flutter-app
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Distribuer l'APK par le moyen de votre choix (clé USB, partage réseau, ou en le déposant derrière Nginx). À l'ouverture, l'app pointe l'IP/host depuis lequel elle a été configurée.

> L'APK est signé avec la clé de **debug** par défaut. Pour une distribution durable, générer un keystore release (`keytool`) et configurer `android/app/build.gradle`.

---

## Phase 6 — Vérification end-to-end

```bash
# 1. Front Flutter accessible (-k : ignorer l'avertissement cert auto-signé)
curl -k -I https://<IP>/app_isis/          # 200 OK

# 2. APIs via Nginx
curl -k https://<IP>/auth/health           # {"status":"ok"}
curl -k https://<IP>/db/health

# 3. Login + appel authentifié
TOKEN=$(curl -sk -X POST https://<IP>/auth/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@kabutare.rw","password":"Admin1234!"}' | jq -r .accessToken)
curl -k https://<IP>/db/api/equipment -H "Authorization: Bearer $TOKEN"

# 4. Console Keycloak
curl -k -I https://<IP>/keycloak/admin/    # 200 / 302
```

```bash
# 5. Page d'installation + CA téléchargeable
curl -k -I https://<IP>/setup/                   # 200, HTML
curl -k -I https://<IP>/setup/kabutare-ca.crt    # 200, Content-Type: application/x-x509-ca-cert
```

Depuis un navigateur : ouvrir `https://<IP>/setup/`, suivre le guide (installer la CA « Kabutare Hospital Root CA » — une seule fois par appareil), puis ouvrir `https://<IP>/app_isis/` : cadenas valide, connexion, et installation PWA possible (« Install app » / « Add to Home Screen »). L'affiche imprimable avec QR code est sur `https://<IP>/setup/poster.html`.

---

## Maintenance

### Sauvegardes

```bash
mkdir -p backups && chmod 700 backups
docker cp auth-service-ip:/data/auth.db        backups/auth_$(date +%F).db
docker cp db-service-ip:/data/hospital.db      backups/hospital_$(date +%F).db
docker exec postgres-keycloak-ip pg_dump -U keycloak keycloak > backups/keycloak_$(date +%F).sql
chmod 600 backups/*.db backups/*.sql
```

Restauration : relancer `sudo bash setup_ubuntu.sh` → option 2 (placer les fichiers dans `./backups/`).

### Mises à jour applicatives

Reconstruire et pousser les images (machine dev, `build_and_push.sh`), puis sur le serveur :

```bash
docker compose -f docker-compose.ip.secured.yml pull
docker compose -f docker-compose.ip.secured.yml up -d
```

### Renouvellement du certificat serveur

Le certificat serveur est valide **825 jours** ; la CA racine, **10 ans**. Le renouvellement re-signe **uniquement** le cert serveur avec la CA existante : **aucune action sur les téléphones** (la CA installée reste valide).

- **Voie automatique (recommandée)** : relancer `sudo bash setup_ubuntu.sh` — si le cert expire sous 30 jours (contrôle `openssl x509 -checkend`), il est re-signé avec la CA existante et Nginx est redémarré ; sinon tout est conservé (idempotent).
- **Voie manuelle (2 commandes)** : rejouer le bloc « 2. Certificat serveur » de la Phase 2.2 (la CA existante signe le nouveau cert), puis `docker restart nginx-ip`.

> Ne supprimer `ssl/ca.pem` / `ssl/ca-key.pem` **que** si l'on veut volontairement changer de CA — cela obligerait à réinstaller la CA sur **tous** les appareils.

### Logs

```bash
docker logs -f auth-service-ip
docker logs -f db-service-ip
docker logs -f nginx-ip
```

L'audit applicatif (login, mutations) est en base : table `logs` du `db-service`.

---

## Pièges à éviter

| Piège                                            | Conséquence |
| ------------------------------------------------ | ----------- |
| `docker compose down -v`                         | Détruit `auth_data_ip` / `db_data_ip` / `keycloak_postgres_data_ip` → perte totale des données. Toujours `down` sans `-v`. |
| `KC_PUBLIC_URL` ≠ IP réellement utilisée         | `iss` du JWT incohérent → validation JWT échoue sur toutes les requêtes. Laisser `setup_ubuntu.sh` calculer la valeur. |
| Port 443 réassigné (ex. 444) sans recalcul       | `KC_PUBLIC_URL` et `CORS_ORIGIN` doivent inclure `:444`. Le script le gère (étape 6). |
| Build Flutter avec `--dart-define` en IP-only    | Fige une URL → casse l'accès multi-IP (WiFi local vs Internet). Ne **pas** fournir de dart-define. |
| Accès via une IP absente du SAN du certificat    | Erreur de certificat. Régénérer le cert en ajoutant l'IP au `subjectAltName`. |
| Compter sur les emails sans domaine              | SPF/DKIM impossibles → spam/rejet probable. Limitation assumée (voir Contexte). |

---

## Annexe — Déploiement avec un vrai nom de domaine (optionnel)

> Cette famille de déploiement est **conservée mais débranchée par défaut**. Elle ne s'utilise **que** si l'on dispose d'un véritable nom de domaine et d'un certificat valide (Let's Encrypt). Historiquement, le projet a utilisé un DDNS gratuit (DuckDNS) avec un certificat Let's Encrypt émis via le challenge **DNS-01**.

Principe :

- Faire pointer un nom de domaine (acheté, ou sous-domaine DDNS type `*.duckdns.org`) vers l'IP du serveur ; résolution locale via le DNS du routeur ou `dnsmasq` pour l'accès LAN.
- Émettre un certificat Let's Encrypt valide (challenge DNS-01 si le port 80 n'est pas exposé sur Internet) avec `certbot` et le plugin DNS du fournisseur.
- Utiliser la famille `docker-compose.yml` / `docker-compose.dev.yml`, ajuster la whitelist CORS (`auth-service/src/index.js`, `db-service/src/index.js`) avec le domaine, et compiler le front avec les `--dart-define` `AUTH_URL` / `DB_URL` / `KC_TOKEN_URL` pointant le domaine.

Avantages d'un vrai domaine : pas d'avertissement de certificat, et possibilité de publier des enregistrements **SPF/DKIM** pour fiabiliser les emails — c'est la seule manière de lever la limitation email de l'IP-only.
