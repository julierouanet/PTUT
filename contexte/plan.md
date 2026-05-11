# Protocole de déploiement — Hôpital Kabutare (réseau local)

## Contexte

Le système doit être déployé sur un **serveur interne à l'hôpital** (réseau local uniquement, pas d'accès Internet entrant). Deux modes d'accès pour les utilisateurs :

1. **Application Android (APK)** — distribuée via un lien de téléchargement servi par le serveur lui-même.
2. **Navigateur Web** — accès depuis un poste de l'hôpital via une URL pointant sur le serveur.

Contraintes / décisions prises :

- **Pas de nom de domaine acheté** → on utilise un **DDNS gratuit (DuckDNS)** pour obtenir un hostname `*.duckdns.org` qui permet d'émettre un certificat **Let's Encrypt** valide (challenge DNS-01, donc sans exposer le port 80 sur Internet).
- **Nginx en reverse-proxy mono-port** : un seul vhost HTTPS qui sert à la fois le front Flutter Web, les deux APIs (sous-chemins `/auth/` et `/db/`), et l'APK téléchargeable (`/download/app.apk`).
- **APK Android** compilé localement et déposé dans le répertoire web servi par Nginx.

> ⚠️ Conséquence : les utilisateurs accèdent à `https://<hostname>.duckdns.org/` (et **non** à `https://192.168.x.y/` — un certificat Let's Encrypt ne peut pas être émis pour une IP). Le DNS local de l'hôpital (ou un fichier hosts sur les postes) devra résoudre ce hostname vers l'IP locale du serveur. Voir [Phase 1](#phase-1--réseau-de-lhôpital-ip-fixe--ddns--dns-local).

---

## Vue d'ensemble de l'architecture cible

```
                   Réseau LAN hôpital (ex: 192.168.1.0/24)
                  ┌──────────────────────────────────────────┐
                  │  Postes / téléphones Android             │
                  │  → résolvent kabutare.duckdns.org        │
                  │     vers 192.168.1.50 (DNS local)        │
                  └──────────────────┬───────────────────────┘
                                     │ HTTPS 443
                                     ▼
   ┌──────────────────────────────────────────────────────────┐
   │  Serveur 192.168.1.50 (Linux + Docker + Nginx)           │
   │                                                          │
   │   Nginx :443 (TLS Let's Encrypt sur kabutare.duckdns.org)│
   │   ├── /                  → /var/www/flutter-app (SPA)    │
   │   ├── /auth/             → 127.0.0.1:3001 (auth-service) │
   │   ├── /db/               → 127.0.0.1:3002 (db-service)   │
   │   └── /download/app.apk  → /var/www/downloads/app.apk    │
   │                                                          │
   │   Docker Compose                                         │
   │   ├── auth-service-prod  (vol auth_data_prod)            │
   │   └── db-service-prod    (vol db_data_prod)              │
   └──────────────────────────────────────────────────────────┘
```

---

## Phase 0 — Prérequis serveur

| Élément               | Détail                                                           |
| --------------------- | ---------------------------------------------------------------- |
| Linux Debian/Ubuntu   | accès sudo                                                       |
| RAM                   | 2 Go minimum                                                     |
| Disque                | 10 Go libre                                                      |
| **IP locale fixe**    | ex: 192.168.1.50 (réservation DHCP sur le routeur)               |
| Internet sortant      | requis pour `apt`, `docker pull`, l'API DuckDNS et Let's Encrypt |
| Ports LAN à ouvrir    | **443** (HTTPS) — c'est tout                                     |
| Logiciels à installer | Docker, Docker Compose v2, Nginx, certbot, git, curl             |

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin nginx certbot \
                    python3-certbot-dns-duckdns git curl openssl
sudo systemctl enable --now docker nginx
sudo usermod -aG docker "$USER"   # se reconnecter ensuite
```

> Aucune installation Node ou Flutter sur le serveur : tout passe par des images Docker (`node:20-alpine` pour les services, `ghcr.io/cirruslabs/flutter:3.41.4` pour le build web et APK).

---

## Phase 1 — Réseau de l'hôpital (IP fixe + DDNS + DNS local)

### 1.1 IP fixe sur le serveur

Réserver une IP fixe pour le serveur sur le routeur DHCP de l'hôpital (ex. `192.168.1.50`). Vérifier :

```bash
ip a              # confirmer l'IP
ping -c1 8.8.8.8  # vérifier l'accès Internet sortant
```

### 1.2 Compte DuckDNS

Créer un compte gratuit sur https://www.duckdns.org → choisir un sous-domaine (ex. `kabutare.duckdns.org`) → noter le **token** (UUID).

Sur le serveur, configurer un script cron qui actualise l'IP publique de l'hôpital toutes les 5 minutes (utile pour les renouvellements de cert) :

```bash
sudo tee /etc/duckdns/duck.sh >/dev/null <<'EOF'
#!/bin/sh
echo url="https://www.duckdns.org/update?domains=kabutare&token=<TOKEN>&ip=" \
  | curl -k -o /var/log/duckdns.log -K -
EOF
sudo chmod 700 /etc/duckdns/duck.sh
( crontab -l 2>/dev/null; echo "*/5 * * * * /etc/duckdns/duck.sh" ) | crontab -
```

> L'IP publique pointée par DuckDNS n'a pas besoin d'être joignable depuis Internet — le challenge utilisé pour le cert est **DNS-01** (validation par TXT record), pas HTTP-01.

### 1.3 Résolution DNS interne — `kabutare.duckdns.org` → IP locale

C'est l'étape **clé** pour que les postes hospitaliers puissent atteindre le serveur via le hostname (sinon le navigateur tenterait l'IP publique → impossible depuis le LAN).

**Trois options selon les capacités du routeur de l'hôpital** :

- **Option A** — _Override DNS sur le routeur (recommandé)_ : la plupart des routeurs pro permettent d'ajouter une entrée DNS statique (`kabutare.duckdns.org → 192.168.1.50`). Pousser ensuite ce DNS aux clients via DHCP.
- **Option B** — _DNS local sur le serveur_ : installer `dnsmasq` sur le serveur et configurer le routeur DHCP pour distribuer `192.168.1.50` comme DNS primaire. Le `dnsmasq` répond avec l'IP locale pour le hostname et délègue tout le reste à `8.8.8.8`.
- **Option C** — _Fichiers hosts par appareil (dépannage)_ : éditer `/etc/hosts` sur les postes Linux/Mac, `C:\Windows\System32\drivers\etc\hosts` sur Windows. **Pas applicable sur Android sans root** — donc cette option ne marche pas pour l'APK.

Tester depuis un poste de l'hôpital :

```bash
ping kabutare.duckdns.org      # doit répondre 192.168.1.50
```

---

## Phase 2 — Certificat HTTPS via Let's Encrypt + DuckDNS (DNS-01)

```bash
# Stocker le token DuckDNS pour certbot
sudo mkdir -p /etc/letsencrypt
sudo tee /etc/letsencrypt/duckdns.ini >/dev/null <<EOF
dns_duckdns_token = <TOKEN_DUCKDNS>
EOF
sudo chmod 600 /etc/letsencrypt/duckdns.ini

# Émission du certificat
sudo certbot certonly \
  --authenticator dns-duckdns \
  --dns-duckdns-credentials /etc/letsencrypt/duckdns.ini \
  --dns-duckdns-propagation-seconds 60 \
  -d kabutare.duckdns.org \
  --agree-tos -m admin@kabutare.local --no-eff-email
```

Le certificat est déposé dans `/etc/letsencrypt/live/kabutare.duckdns.org/`. Le renouvellement automatique tourne via `certbot.timer` ; la commande ci-dessus est rejouée tous les 60 jours sans action manuelle.

> Les certificats Let's Encrypt sont **automatiquement reconnus par Android 7+ et tous les navigateurs récents** — pas d'avertissement à accepter, pas de CA à pousser sur les appareils.

---

## Phase 3 — Cloner le dépôt et générer les secrets

```bash
sudo mkdir -p /opt && cd /opt
sudo git clone <url-du-repo> kabutare
sudo chown -R "$USER":"$USER" /opt/kabutare
cd /opt/kabutare
git checkout main
```

Créer le fichier secrets (chemin codé en dur dans le `Jenkinsfile`, mais aussi utilisé par les commandes manuelles ci-dessous) :

```bash
sudo mkdir -p /etc/kabutare
sudo tee /etc/kabutare/.env >/dev/null <<EOF
JWT_SECRET=$(openssl rand -hex 48)
JWT_REFRESH_SECRET=$(openssl rand -hex 48)
INTERNAL_SECRET=$(openssl rand -hex 32)
EOF
sudo chmod 600 /etc/kabutare/.env
```

> Les 3 variables sont **obligatoires** ; sans elles, les services démarrent avec des secrets par défaut connus (cf. avertissement émis par `auth-service/src/config.js`).

---

## Phase 4 — Adapter le code à l'architecture single-port

Trois fichiers à modifier **avant** de construire les images Docker et le front.

### 4.1 Nouveau vhost Nginx unique

Remplacer **tous** les fichiers `nginx/conf.d/*.conf` du dépôt par un seul nouveau vhost. Créer [nginx/conf.d/kabutare.conf](nginx/conf.d/kabutare.conf) :

```nginx
server {
    listen 80;
    server_name kabutare.duckdns.org;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name kabutare.duckdns.org;

    ssl_certificate     /etc/letsencrypt/live/kabutare.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/kabutare.duckdns.org/privkey.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 25m;   # uploads (XLSX, photos, APK download)

    # ── Auth service ────────────────────────────────
    # Le slash final dans proxy_pass strippe le préfixe /auth de l'URL upstream.
    # Front appelle https://kabutare.duckdns.org/auth/api/auth/login
    #   → upstream reçoit /api/auth/login
    location /auth/ {
        proxy_pass         http://127.0.0.1:3001/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # ── DB service ──────────────────────────────────
    location /db/ {
        proxy_pass         http://127.0.0.1:3002/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # ── Téléchargement APK ──────────────────────────
    location = /download/app.apk {
        alias /var/www/downloads/app.apk;
        add_header Content-Disposition 'attachment; filename="kabutare.apk"';
    }
    location /download/ {
        alias /var/www/downloads/;
        autoindex on;            # liste le contenu (utile si plusieurs versions)
    }

    # ── App Flutter Web (SPA, fallback /index.html) ─
    root  /var/www/flutter-app;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    gzip on;
    gzip_types text/plain text/css application/javascript application/json;
}
```

Activer le vhost :

```bash
sudo cp /opt/kabutare/nginx/conf.d/kabutare.conf /etc/nginx/conf.d/
sudo rm -f /etc/nginx/conf.d/default.conf       # éviter conflit
sudo mkdir -p /var/www/flutter-app /var/www/downloads
sudo nginx -t && sudo systemctl reload nginx
```

### 4.2 CORS — autoriser le nouveau hostname

Le front et les APIs sont sur la **même origine** (`https://kabutare.duckdns.org`), mais les services valident l'`Origin` header. Modifier la whitelist :

- [auth-service/src/index.js](auth-service/src/index.js) — tableau `allowed`
- [db-service/src/index.js](db-service/src/index.js) — idem

Remplacer les entrées `lucaslopvet.fr` par :

```js
const allowed = ["https://kabutare.duckdns.org"];
```

> Ces fichiers seront re-copiés dans les images Docker au prochain `up --build` (Phase 5).

### 4.3 (Aucune modif Flutter requise)

[flutter-app/lib/services/api_config.dart:38-52](flutter-app/lib/services/api_config.dart#L38) compose les URLs en concaténant `${AUTH_URL}/api/auth/login` etc. Avec `AUTH_URL=https://kabutare.duckdns.org/auth` et `DB_URL=https://kabutare.duckdns.org/db`, les appels sortent en `https://kabutare.duckdns.org/auth/api/auth/login` → Nginx les achemine vers `auth-service:3001/api/auth/login`. La fonction `assertSecureUrls()` accepte tout HTTPS, donc OK.

---

## Phase 5 — Démarrer les microservices Docker

```bash
cd /opt/kabutare
set -a; source /etc/kabutare/.env; set +a
docker compose -p gestion-equipement-medical-prod \
  -f docker-compose.yml up -d --build
```

Vérifier :

```bash
docker compose -p gestion-equipement-medical-prod ps   # both healthy
curl -fsS http://localhost:3001/health
curl -fsS http://localhost:3002/health
curl -fsS https://kabutare.duckdns.org/auth/health      # via Nginx
curl -fsS https://kabutare.duckdns.org/db/health
```

---

## Phase 6 — Compiler et déployer le Flutter Web

Build via container Flutter (pas besoin d'installer Flutter sur le serveur) :

```bash
cd /opt/kabutare
docker run --rm \
  -v "$(pwd)/flutter-app":/app \
  -e PUB_CACHE=/app/.pub-cache \
  -w /app \
  ghcr.io/cirruslabs/flutter:3.41.4 \
  bash -c "flutter pub get && flutter build web --release \
    --dart-define=AUTH_URL=https://kabutare.duckdns.org/auth \
    --dart-define=DB_URL=https://kabutare.duckdns.org/db"

# Publication
sudo rm -rf /var/www/flutter-app/*
sudo cp -r flutter-app/build/web/. /var/www/flutter-app/
sudo chown -R www-data:www-data /var/www/flutter-app
```

---

## Phase 7 — Compiler l'APK Android et le servir

### 7.1 Build APK

```bash
cd /opt/kabutare
docker run --rm \
  -v "$(pwd)/flutter-app":/app \
  -e PUB_CACHE=/app/.pub-cache \
  -w /app \
  ghcr.io/cirruslabs/flutter:3.41.4 \
  bash -c "flutter pub get && flutter build apk --release \
    --dart-define=AUTH_URL=https://kabutare.duckdns.org/auth \
    --dart-define=DB_URL=https://kabutare.duckdns.org/db"
```

L'APK est généré dans `flutter-app/build/app/outputs/flutter-apk/app-release.apk`.

> L'APK signé avec une clé de **debug** par défaut. Pour une distribution interne hospitalière c'est acceptable, mais Google Play et certaines politiques de sécurité d'entreprise exigeront une clé de release. Si besoin : générer un keystore avec `keytool`, configurer `flutter-app/android/app/build.gradle` avec un `signingConfig`, puis rebuilder.

### 7.2 Publier sur Nginx

```bash
sudo cp flutter-app/build/app/outputs/flutter-apk/app-release.apk \
        /var/www/downloads/app.apk
sudo chown www-data:www-data /var/www/downloads/app.apk
```

Les utilisateurs téléchargent en ouvrant **`https://kabutare.duckdns.org/download/app.apk`** depuis le navigateur de leur téléphone Android, puis activent « Sources inconnues » dans les paramètres pour installer.

> Versions multiples : nommer `app-v1.2.0.apk` ; le listing `autoindex on` les expose tous sous `/download/`.

---

## Phase 8 — Initialiser les données

```bash
# Utilisateurs (admin@kabutare.rw / Admin1234!  — à changer immédiatement)
docker exec auth-service-prod node seed.js

# OPTION A — données démo (45 équipements fictifs)
docker exec db-service-prod node seed.js

# OPTION B — inventaire physique réel (à privilégier en production)
docker cp /chemin/vers/inventaire.xlsx db-service-prod:/tmp/inventory.xlsx
docker exec db-service-prod node scripts/import_inventory.js \
  --xlsx /tmp/inventory.xlsx
```

L'import est idempotent (`UPSERT` par défaut, `created_at` préservé).

---

## Phase 9 — Vérification end-to-end

Depuis un poste interne à l'hôpital :

```bash
# 1. Hostname résolu vers IP locale
nslookup kabutare.duckdns.org   # doit retourner 192.168.1.50

# 2. Front Flutter Web accessible
curl -I https://kabutare.duckdns.org/   # 200 OK + index.html

# 3. APIs accessibles via Nginx
curl https://kabutare.duckdns.org/auth/health
curl https://kabutare.duckdns.org/db/health

# 4. Login + appel API authentifié
TOKEN=$(curl -s -X POST https://kabutare.duckdns.org/auth/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@kabutare.rw","password":"Admin1234!"}' \
  | jq -r .accessToken)
curl https://kabutare.duckdns.org/db/api/equipment \
  -H "Authorization: Bearer $TOKEN"

# 5. APK téléchargeable
curl -I https://kabutare.duckdns.org/download/app.apk    # 200 OK
```

Sur un téléphone Android : ouvrir le navigateur, aller sur `https://kabutare.duckdns.org/download/app.apk`, installer, lancer l'app, se connecter.

---

## Maintenance

### Sauvegardes (cron quotidien)

```bash
docker run --rm -v auth_data_prod:/d:ro -v /backup:/b alpine \
  tar czf /b/auth_$(date +%F).tar.gz -C /d .
docker run --rm -v db_data_prod:/d:ro   -v /backup:/b alpine \
  tar czf /b/hospital_$(date +%F).tar.gz -C /d .
```

### Mises à jour applicatives

```bash
cd /opt/kabutare
git pull
set -a; source /etc/kabutare/.env; set +a
docker compose -p gestion-equipement-medical-prod -f docker-compose.yml up -d --build
# Reconstruire le Flutter Web (Phase 6) et l'APK (Phase 7) si du code front a changé
```

### Renouvellement TLS

Automatique via `certbot.timer`. Vérifier : `sudo certbot renew --dry-run`.

### Logs

```bash
docker logs -f auth-service-prod
docker logs -f db-service-prod
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

L'audit applicatif (login, mutations) est en base : table `logs` du `db-service`.

---

## Pièges à éviter

| Piège                                                        | Conséquence                                                                                                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `docker compose down -v`                                     | Détruit `auth_data_prod` / `db_data_prod` → perte des utilisateurs et de l'inventaire.                                                      |
| Rebuild Docker sans avoir modifié la whitelist CORS          | Le navigateur bloque les requêtes XHR avec « CORS error ».                                                                                  |
| Build Flutter sans `--dart-define`                           | L'app pointe vers les URL par défaut (`auth.lucaslopvet.fr`) → connexion impossible.                                                        |
| Accès direct via `https://192.168.1.50/`                     | Erreur de certificat (CN ne correspond pas à l'IP). Toujours utiliser le hostname DDNS.                                                     |
| Hostname non résolu sur Android                              | Téléphone hors du wifi hôpital, ou résolution DNS locale absente → app injoignable.                                                         |
| APK signé en debug poussé en prod long terme                 | À chaque rebuild, la signature change → impossible d'installer en mise à jour, l'ancien doit être désinstallé. Passer en signature release. |
| Oublier d'ajouter un dossier dans le `Dockerfile db-service` | Code non embarqué dans l'image (cas du dossier `scripts/` pour `import_inventory.js`).                                                      |

---

## Fichiers critiques (modifier / créer)

- **À créer** : `/etc/kabutare/.env`, `/etc/letsencrypt/duckdns.ini`, `/etc/duckdns/duck.sh`, `nginx/conf.d/kabutare.conf` (ou `/etc/nginx/conf.d/kabutare.conf`)
- **À modifier** : [auth-service/src/index.js](auth-service/src/index.js) (CORS), [db-service/src/index.js](db-service/src/index.js) (CORS)
- **Inchangés** : [docker-compose.yml](docker-compose.yml), Dockerfiles, [flutter-app/lib/services/api_config.dart](flutter-app/lib/services/api_config.dart), seed/import scripts
- **À supprimer / ignorer** : les vhosts existants `nginx/conf.d/{app,auth,db,dev-*}.conf` (spécifiques à `lucaslopvet.fr`)
