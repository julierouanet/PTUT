#!/usr/bin/env bash
# ============================================================
# setup_ubuntu.sh — Provisionnement serveur Ubuntu vierge
# Déploiement IP-only (HTTPS self-signed) de l'application
# Hôpital de Kabutare.
#
# Pré-requis :
#   - Ubuntu  22.04 / 24.04 LTS
#   - build_and_push.sh exécuté au préalable sur la machine dev
#     (images poussées sur Docker Hub)
#   - Seulement ces deux fichiers à copier sur le serveur :
#       scp setup_ubuntu.sh docker-compose.ip.secured.yml user@IP:~/kabutare/
#   - Exécuter depuis le répertoire contenant ces fichiers :
#       sudo bash setup_ubuntu.sh
# ============================================================
set -euo pipefail
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# ── Vérification root ─────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  echo "Erreur : ce script doit être exécuté avec sudo." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo ""
echo "========================================================"
echo " Déploiement Hôpital de Kabutare — serveur IP-only"
echo "========================================================"
echo ""

# ── Mode réseau : public ou WiFi local uniquement ─────────────
echo "  Mode d'accès réseau :"
echo ""
echo "  1) Public (internet)     — accessible depuis n'importe où via l'IP publique"
echo "                             + optionnellement depuis le WiFi interne"
echo "  2) WiFi local uniquement — accessible seulement depuis le réseau WiFi"
echo "                             de l'hôpital (adresse IP privée)"
echo ""
read -rp "  Votre choix [1/2, défaut=2] : " NETWORK_MODE_INPUT
NETWORK_MODE="${NETWORK_MODE_INPUT:-2}"
echo ""
if [[ "${NETWORK_MODE}" == "1" ]]; then
  echo "  → Mode PUBLIC : l'application sera accessible depuis internet."
else
  NETWORK_MODE="2"
  echo "  → Mode WiFi LOCAL : l'application sera accessible uniquement sur le réseau interne."
fi
echo ""

# ── Étape 1 : Mise à jour système ────────────────────────────
read -rp "[1/9] Mettre à jour le système maintenant ? [o/N] : " UPDATE_SYS
if [[ "${UPDATE_SYS,,}" == "o" ]]; then
  echo "      Mise à jour en cours..."
  apt-get update -qq
  apt-get upgrade -y -qq
  echo "      ✓ Système à jour."
else
  echo "      Mise à jour ignorée."
fi

# ── Étape 2 : Installation Docker ────────────────────────────
echo "[2/9] Vérification de Docker..."
if command -v docker &>/dev/null; then
  echo "      Docker déjà installé : $(docker --version)"
  read -rp "      Réinstaller / mettre à jour Docker ? [o/N] : " UPDATE_DOCKER
  INSTALL_DOCKER="${UPDATE_DOCKER,,}"
else
  read -rp "      Docker n'est pas installé. L'installer maintenant ? [O/n] : " INSTALL_DOCKER_INPUT
  INSTALL_DOCKER="${INSTALL_DOCKER_INPUT:-o}"
  INSTALL_DOCKER="${INSTALL_DOCKER,,}"
fi
if [[ "${INSTALL_DOCKER:-o}" == "o" ]]; then
  apt-get install -y -qq ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  echo "      ✓ Docker installé."
else
  echo "      Installation Docker ignorée."
fi

# ── Étape 3 : Détection des IPs ──────────────────────────────
echo "[3/9] Détection des IPs du serveur..."

# IP locale (WiFi hôpital — plages privées 192.168.x.x / 10.x.x.x / 172.16-31.x.x)
DETECTED_LOCAL_IP=$(hostname -I | tr ' ' '\n' \
  | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' \
  | head -1 || true)

if [[ "${NETWORK_MODE}" == "2" ]]; then
  # ── Mode WiFi local : on n'utilise que l'IP privée ─────────
  echo "      IP locale détectée : ${DETECTED_LOCAL_IP:-aucune}"
  read -rp "      Confirmer ou saisir l'IP WiFi du serveur [${DETECTED_LOCAL_IP}] : " USER_LOCAL_IP
  LOCAL_IP="${USER_LOCAL_IP:-${DETECTED_LOCAL_IP}}"
  if [[ -z "${LOCAL_IP}" ]]; then
    echo "      ✗ Aucune IP locale fournie — impossible de continuer." >&2
    exit 1
  fi
  SERVER_IP="${LOCAL_IP}"
  echo "      ✓ IP WiFi retenue : ${SERVER_IP}"
  echo "      → Accès uniquement depuis le réseau interne de l'hôpital."

else
  # ── Mode public : IP publique + IP locale optionnelle ───────
  DETECTED_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
    || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
    || hostname -I | awk '{print $1}')

  echo "      IP publique détectée : ${DETECTED_IP}"
  read -rp "      Confirmer ou saisir l'IP publique [${DETECTED_IP}] : " USER_IP
  SERVER_IP="${USER_IP:-${DETECTED_IP}}"
  echo "      ✓ IP publique retenue : ${SERVER_IP}"

  echo ""
  echo "      IP locale réseau interne détectée : ${DETECTED_LOCAL_IP:-aucune}"
  echo "      (utilisée par les appareils connectés au WiFi de l'hôpital)"
  read -rp "      Saisir l'IP locale du serveur sur le WiFi hôpital [${DETECTED_LOCAL_IP}] (Entrée pour ignorer) : " USER_LOCAL_IP
  LOCAL_IP="${USER_LOCAL_IP:-${DETECTED_LOCAL_IP}}"
  if [[ -n "${LOCAL_IP}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
    echo "      ✓ IP locale retenue : ${LOCAL_IP}"
    echo "      → Les appareils WiFi accéderont via https://${LOCAL_IP}/app_isis/"
  else
    LOCAL_IP=""
    echo "      Pas d'IP locale configurée — accès WiFi interne désactivé."
  fi
fi

# ── Étape 4 : Création du fichier .env ───────────────────────
echo "[4/9] Configuration des variables d'environnement..."

# Construction de la valeur CORS (IP publique + IP locale si définie)
CORS_ORIGINS="https://${SERVER_IP}"
if [[ -n "${LOCAL_IP}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
  CORS_ORIGINS="${CORS_ORIGINS},https://${LOCAL_IP}"
fi

# KC_PUBLIC_URL : URL publique SANS :443 — Keycloak normalise les URLs HTTPS standard
# et supprime le port 443 dans le claim "iss" du JWT. KC_ISSUER doit correspondre exactement.
HTTP_PORT_TMP="${HTTP_PORT:-80}"
HTTPS_PORT_TMP="${HTTPS_PORT:-443}"
if [[ "${HTTPS_PORT_TMP}" == "443" ]]; then
  KC_PUBLIC_URL="https://${SERVER_IP}"
else
  KC_PUBLIC_URL="https://${SERVER_IP}:${HTTPS_PORT_TMP}"
fi

if [[ -f ".env" ]]; then
  echo "      Un fichier .env existe déjà, il sera conservé."
  # Mettre à jour les IPs
  if grep -q "^SERVER_IP=" .env; then
    sed -i "s|^SERVER_IP=.*|SERVER_IP=${SERVER_IP}|" .env
  else
    echo "SERVER_IP=${SERVER_IP}" >> .env
  fi
  if grep -q "^LOCAL_IP=" .env; then
    sed -i "s|^LOCAL_IP=.*|LOCAL_IP=${LOCAL_IP}|" .env
  else
    echo "LOCAL_IP=${LOCAL_IP}" >> .env
  fi
  if grep -q "^CORS_ORIGIN=" .env; then
    sed -i "s|^CORS_ORIGIN=.*|CORS_ORIGIN=${CORS_ORIGINS}|" .env
  else
    echo "CORS_ORIGIN=${CORS_ORIGINS}" >> .env
  fi
  if grep -q "^KC_PUBLIC_URL=" .env; then
    sed -i "s|^KC_PUBLIC_URL=.*|KC_PUBLIC_URL=${KC_PUBLIC_URL}|" .env
  else
    echo "KC_PUBLIC_URL=${KC_PUBLIC_URL}" >> .env
  fi
  # Ne JAMAIS régénérer un mot de passe existant — uniquement le demander s'il manque
  if ! grep -q "^DEBUG_MODE_PASSWORD=" .env; then
    read -rp "      Mot de passe de déverrouillage du mode Debug & Test : " -s DEBUG_MODE_PASSWORD_INPUT; echo
    echo "DEBUG_MODE_PASSWORD=${DEBUG_MODE_PASSWORD_INPUT}" >> .env
  fi
else
  echo "      Création du fichier .env..."

  read -rp "      Docker Hub username : " DOCKER_USER_INPUT
  read -rp "      Mot de passe admin Keycloak : " -s KC_ADMIN_PASSWORD_INPUT; echo
  read -rp "      Mot de passe PostgreSQL Keycloak : " -s KC_DB_PASSWORD_INPUT; echo
  read -rp "      Mot de passe de déverrouillage du mode Debug & Test : " -s DEBUG_MODE_PASSWORD_INPUT; echo

  INTERNAL_SECRET_GEN=$(openssl rand -hex 32)

  cat > .env <<EOF
SERVER_IP=${SERVER_IP}
LOCAL_IP=${LOCAL_IP}
CORS_ORIGIN=${CORS_ORIGINS}
KC_PUBLIC_URL=${KC_PUBLIC_URL}
DOCKER_USER=${DOCKER_USER_INPUT}

INTERNAL_SECRET=${INTERNAL_SECRET_GEN}
DEBUG_MODE_PASSWORD=${DEBUG_MODE_PASSWORD_INPUT}

KC_ADMIN_USER=admin
KC_ADMIN_PASSWORD=${KC_ADMIN_PASSWORD_INPUT}
KC_CLIENT_SECRET_AUTH=changez-moi-apres-creation-client-keycloak
KC_DB_PASSWORD=${KC_DB_PASSWORD_INPUT}

VAPID_PUBLIC_KEY=
VAPID_PRIVATE_KEY=
VAPID_CONTACT=mailto:admin@hospital.local

BREVO_SMTP_HOST=smtp-relay.brevo.com
BREVO_SMTP_PORT=587
BREVO_SMTP_LOGIN=
BREVO_SMTP_PASSWORD=
BREVO_FROM_EMAIL=noreply@hospital.local
BREVO_FROM_NAME="Hôpital de Kabutare"

BREVO_API_KEY=
EOF
  chmod 600 .env           # Secrets lisibles par root uniquement (CRIT-1)
  chown root:root .env
  echo "      ✓ Fichier .env créé (permissions 600)."
fi

# Charger les variables pour la suite du script
set -a; source .env; set +a

# ── Étape 5 : Certificat SSL + config Nginx ──────────────────
echo "[5/9] Génération du certificat SSL et configuration Nginx..."
mkdir -p ssl nginx/conf.d
chmod 700 ssl/               # Répertoire SSL non listable par les autres utilisateurs
chmod 755 nginx/ nginx/conf.d/
# Supprimer si c'est un dossier (artefact Docker d'un montage raté)
[[ -d nginx/conf.d/ip.conf ]] && rm -rf nginx/conf.d/ip.conf

# Config Nginx (toujours régénérée pour garantir la cohérence)
cat > nginx/conf.d/ip.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    http2  on;
    server_name _;

    # ── Compression gzip ─────────────────────────────────────
    # Réduit la taille des fichiers JS Flutter de 8-15 MB → 2-4 MB
    gzip              on;
    gzip_vary         on;
    gzip_proxied      any;
    gzip_comp_level   6;
    gzip_min_length   256;
    gzip_types
        text/plain text/css text/javascript
        application/javascript application/x-javascript
        application/json application/wasm
        image/svg+xml font/woff font/woff2;
    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;
    location /auth/ {
        proxy_pass         http://auth-service:3001/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_read_timeout 60s;
    }
    location /db/ {
        proxy_pass         http://db-service:3002/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_read_timeout 60s;
    }
    # Redirect /keycloak (sans slash) → /keycloak/admin/
    # sans ça, nginx ne matche pas /keycloak/ et sert Flutter à la place
    location = /keycloak {
        return 301 /keycloak/admin/;
    }

    # Ressources statiques Keycloak (JS/CSS) — cache 7 jours + réécriture IP.
    # sub_filter corrige les URLs absolues IP_PUBLIQUE → hôte courant du navigateur
    # pour éviter les erreurs CORS/CSP quand accès depuis le WiFi local.
    location ~* ^/keycloak/resources/.+\.(js|css)$ {
        proxy_pass              http://keycloak:8080;
        proxy_http_version      1.1;
        proxy_set_header        Host              $host;
        proxy_set_header        X-Forwarded-Proto https;
        proxy_set_header        X-Forwarded-Port  443;
        # Désactiver la compression upstream pour que sub_filter puisse lire le contenu
        proxy_set_header        Accept-Encoding   "";
        add_header              Cache-Control "public, max-age=604800, immutable";
        proxy_read_timeout      30s;
        sub_filter              'https://__NGINX_SERVER_IP__/keycloak' 'https://$host/keycloak';
        sub_filter_once         off;
        sub_filter_types        text/javascript application/javascript text/css;
    }

    # Fonts et images Keycloak — cache uniquement, pas de sub_filter nécessaire
    location ~* ^/keycloak/resources/.+\.(woff2?|ttf|eot|png|gif|ico|svg)$ {
        proxy_pass              http://keycloak:8080;
        proxy_http_version      1.1;
        proxy_set_header        Host              $host;
        proxy_set_header        X-Forwarded-Proto https;
        add_header              Cache-Control "public, max-age=604800, immutable";
        proxy_read_timeout      30s;
    }

    location /keycloak/ {
        proxy_pass              http://keycloak:8080/keycloak/;
        proxy_http_version      1.1;
        proxy_set_header        Host              $host;
        proxy_set_header        X-Real-IP         $remote_addr;
        proxy_set_header        X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto https;
        proxy_set_header        X-Forwarded-Port  443;
        # Désactiver la compression upstream pour que sub_filter puisse lire le contenu
        proxy_set_header        Accept-Encoding   "";
        proxy_buffer_size       128k;
        proxy_buffers           4 256k;
        proxy_busy_buffers_size 256k;
        proxy_read_timeout      90s;
        # Réécriture des redirects (Location header) : relatif → le navigateur
        # résout par rapport à l'IP depuis laquelle il accède
        proxy_redirect          ~^https?://[^/]+(/keycloak/.*) $1;
        # Réécriture du CONTENU HTML/JS/JSON : remplace l'IP publique par $host
        # → corrige CORS ("Cross-Origin Request Blocked") et CSP ("frame-src 'self'")
        # quand on accède depuis le WiFi local (IP privée ≠ IP publique Keycloak)
        sub_filter              'https://__NGINX_SERVER_IP__/keycloak' 'https://$host/keycloak';
        sub_filter_once         off;
        sub_filter_types        text/html application/javascript application/json text/css;
        # Page de chargement si Keycloak n'est pas encore prêt
        error_page 502 503 504 /keycloak-loading.html;
    }

    # Page de chargement Keycloak (statique, accessible uniquement via error_page)
    location = /keycloak-loading.html {
        root  /usr/share/nginx/html;
        add_header Cache-Control "no-store";
        internal;
    }

    # ── Certificat CA téléchargeable — MIME dédié pour Android/iOS ──
    # location exacte (priorité sur les regex et les prefixes) ; surtout PAS de
    # bloc `types {}` dans /setup/ : il écraserait la table MIME héritée et
    # servirait index.html en octet-stream.
    location = /setup/kabutare-ca.crt {
        root         /usr/share/nginx/html;
        default_type application/x-x509-ca-cert;
    }

    # ── Page d'installation PWA (publique, statique) ──
    location /setup/ {
        root  /usr/share/nginx/html;
        index index.html;
    }

    location = / { return 301 /app_isis/; }
    location = /app_isis { return 301 /app_isis/; }
    # (?:app_isis/)? : le service worker est aussi enregistré à la RACINE
    # (/flutter_service_worker.js, cf. index.html) — même règle no-cache,
    # sinon la mise à jour silencieuse n'est pas garantie sur ce chemin.
    location ~* ^/(?:app_isis/)?(flutter_service_worker\.js|flutter_bootstrap\.js)$ {
        root       /usr/share/nginx/html;
        try_files  /$1 =404;
        expires    0;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma        "no-cache";
    }
    location ~* ^/app_isis/(.+\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot))$ {
        root       /usr/share/nginx/html;
        try_files  /$1 =404;
        expires    1y;
        add_header Cache-Control "public, immutable";
    }
    location /app_isis/ {
        alias      /usr/share/nginx/html/;
        try_files  $uri $uri/ @flutter_fallback;
        add_header Cache-Control "no-cache";
    }
    location @flutter_fallback {
        root       /usr/share/nginx/html;
        try_files  /index.html =404;
        add_header Cache-Control "no-cache";
    }
    location / {
        root      /usr/share/nginx/html;
        try_files $uri @flutter_root_fallback;
    }
    location @flutter_root_fallback {
        root      /usr/share/nginx/html;
        try_files /index.html =404;
        add_header Cache-Control "no-cache";
    }
    client_max_body_size 10M;
}
NGINXEOF
# Injecter l'IP publique réelle dans le placeholder sub_filter
# (le heredoc est entre guillemets simples → pas d'expansion shell directe)
sed -i "s/__NGINX_SERVER_IP__/${SERVER_IP}/g" nginx/conf.d/ip.conf
echo "      ✓ Configuration Nginx générée."

# ── Page de chargement Keycloak (toujours régénérée) ──────────
cat > nginx/keycloak-loading.html << 'KCLOADEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Keycloak — Démarrage en cours…</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #F9FAFB; font-family: system-ui, -apple-system, Arial, sans-serif; }
    .wrap {
      position: fixed; inset: 0; display: flex; flex-direction: column;
      align-items: center; justify-content: center;
    }
    .icon {
      width: 64px; height: 64px; background: #2563EB; border-radius: 16px;
      display: flex; align-items: center; justify-content: center;
      margin-bottom: 20px; box-shadow: 0 4px 14px rgba(37,99,235,.25);
    }
    .icon svg { width: 36px; height: 36px; fill: #fff; }
    .title { font-size: 1.05rem; font-weight: 600; color: #111827; margin-bottom: 4px; }
    .sub   { font-size: .78rem; color: #6B7280; margin-bottom: 28px; }
    .track { width: 220px; height: 4px; background: #E5E7EB; border-radius: 99px; overflow: hidden; margin-bottom: 10px; }
    #bar   { height: 100%; width: 0%; background: #2563EB; border-radius: 99px; transition: width .3s ease; }
    #msg   { font-size: .75rem; color: #9CA3AF; font-variant-numeric: tabular-nums; margin-bottom: 32px; }
    .btn   { font-size: .8rem; color: #2563EB; background: none; border: 1px solid #DBEAFE;
             border-radius: 8px; padding: 6px 16px; cursor: pointer; display: none; }
    .btn:hover { background: #EFF6FF; }
  </style>
</head>
<body>
<div class="wrap">
  <div class="icon">
    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path d="M19 8h-4V4a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v4H5a1 1 0 0 0-1 1v4a1
               1 0 0 0 1 1h4v4a1 1 0 0 0 1 1h4a1 1 0 0 0 1-1v-4h4a1 1 0 0 0 1-1V9a1
               1 0 0 0-1-1z"/>
    </svg>
  </div>
  <div class="title">Hôpital de Kabutare</div>
  <div class="sub">Console d'administration — démarrage en cours</div>
  <div class="track"><div id="bar"></div></div>
  <div id="msg">Connexion à Keycloak…</div>
  <button class="btn" id="btn" onclick="retry()">Réessayer maintenant</button>
</div>
<script>
  var bar=document.getElementById('bar'), msg=document.getElementById('msg'),
      btn=document.getElementById('btn'), attempts=0, MAX=24, pct=0, barTimer;
  barTimer = setInterval(function(){pct+=(90-pct)*.025; bar.style.width=Math.min(pct,90)+'%';},200);
  function check(){
    attempts++;
    fetch('/keycloak/health/ready')
      .then(function(r){return r.text();})
      .then(function(t){
        if(t.indexOf('"UP"')!==-1||t.indexOf('"status":"UP"')!==-1){
          clearInterval(barTimer); bar.style.width='100%';
          msg.textContent='Keycloak prêt — redirection…';
          setTimeout(function(){window.location.reload();},400);
        } else { schedule(); }
      }).catch(function(){schedule();});
  }
  function schedule(){
    if(attempts>=MAX){
      clearInterval(barTimer);
      msg.textContent='Keycloak ne répond pas — vérifier les logs Docker.';
      btn.style.display='inline-block'; return;
    }
    var wait=5;
    msg.textContent='Nouvelle tentative dans '+wait+' s… ('+attempts+'/'+MAX+')';
    var cd=setInterval(function(){
      wait--;
      if(wait<=0){clearInterval(cd);msg.textContent='Connexion à Keycloak…';check();}
      else{msg.textContent='Nouvelle tentative dans '+wait+' s… ('+attempts+'/'+MAX+')';}
    },1000);
  }
  function retry(){btn.style.display='none';attempts=0;pct=0;
    barTimer=setInterval(function(){pct+=(90-pct)*.025;bar.style.width=Math.min(pct,90)+'%';},200);
    check();}
  setTimeout(check,2000);
</script>
</body>
</html>
KCLOADEOF
echo "      ✓ Page de chargement Keycloak générée."

# ── PKI interne à deux étages : CA racine + certificat serveur ─
# La CA « Kabutare Hospital Root CA » est installée UNE SEULE FOIS sur chaque
# appareil (guide sur https://IP/setup/) : plus d'avertissement navigateur et
# contexte sécurisé complet (indispensable au service worker / PWA).
# ca-key.pem ne quitte JAMAIS le serveur et n'est jamais servi par Nginx.

# SAN inclut l'IP publique + l'IP locale si définie
# → le même certificat est valide sur le WiFi hôpital ET depuis internet
SSL_SAN="IP:${SERVER_IP}"
if [[ -n "${LOCAL_IP}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
  SSL_SAN="${SSL_SAN},IP:${LOCAL_IP}"
  echo "      Certificat couvrant : ${SERVER_IP} (internet) + ${LOCAL_IP} (WiFi hôpital)"
fi

# Génère le certificat serveur signé par la CA existante (ssl/ca.pem).
# ECDSA P-384 : plus rapide que RSA-2048, aussi sûr que RSA-3072 (MAJ-1)
# 825 jours : durée max acceptée par Chrome/Firefox/Safari depuis 2020
generate_server_cert() {
  openssl req -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-384 \
    -keyout ssl/key.pem -out ssl/server.csr \
    -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=${SERVER_IP}" \
    2>/dev/null
  # Fichier d'extensions temporaire (plus portable qu'une substitution de processus)
  printf "subjectAltName=%s\nextendedKeyUsage=serverAuth\n" "${SSL_SAN}" > ssl/server.ext
  openssl x509 -req -in ssl/server.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem \
    -CAcreateserial -days 825 -out ssl/cert.pem \
    -extfile ssl/server.ext \
    2>/dev/null
  rm -f ssl/server.csr ssl/server.ext
  chmod 600 ssl/key.pem    # Clé privée serveur : root uniquement
  chmod 644 ssl/cert.pem   # Certificat public : lisible par nginx
}

if [[ -f "ssl/ca.pem" && -f "ssl/ca-key.pem" && -f "ssl/cert.pem" && -f "ssl/key.pem" ]] \
   && openssl x509 -in ssl/cert.pem -checkend 2592000 &>/dev/null; then
  # CA présente + cert serveur encore valide > 30 jours → ne rien régénérer
  echo "      Certificat existant conservé (CA + cert serveur valides > 30 jours)."

elif [[ -f "ssl/ca.pem" && -f "ssl/ca-key.pem" ]]; then
  # Cert serveur expiré ou expirant sous 30 jours, mais CA intacte →
  # re-signer UNIQUEMENT le cert serveur : les appareils qui ont déjà
  # installé la CA n'ont RIEN à refaire.
  echo "      Renouvellement du certificat serveur (CA conservée)..."
  generate_server_cert
  # Recharger le certificat si le conteneur nginx tourne déjà (re-provisionnement)
  docker restart nginx-ip &>/dev/null || true
  echo "      ✓ Certificat serveur re-signé (825 jours) — aucune action requise sur les appareils."

else
  # Première exécution — ou migration depuis l'ancien cert auto-signé sans CA :
  # on régénère tout en mode CA (les appareils installeront la CA via /setup/).
  echo "      Génération de la PKI interne (CA racine + certificat serveur)..."
  # CA racine ECDSA P-384, 10 ans — générée une seule fois
  openssl req -x509 -nodes -days 3650 -newkey ec -pkeyopt ec_paramgen_curve:P-384 \
    -keyout ssl/ca-key.pem -out ssl/ca.pem \
    -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=Kabutare Hospital Root CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    2>/dev/null
  chmod 600 ssl/ca-key.pem   # Clé CA : root uniquement — ne quitte jamais le serveur
  chmod 644 ssl/ca.pem       # CA publique : distribuée aux appareils via /setup/
  generate_server_cert
  echo "      ✓ CA « Kabutare Hospital Root CA » (10 ans) + cert serveur (825 jours) générés."
fi

# ── Page d'installation PWA /setup/ (toujours régénérée) ──────
echo "      Génération de la page d'installation /setup/..."

# Garde-fou : la CA publique doit exister (générée par le bloc PKI ci-dessus)
if [[ ! -f "ssl/ca.pem" ]]; then
  echo "      ✗ ssl/ca.pem introuvable — impossible de générer la page /setup/." >&2
  echo "        La PKI doit être générée avant la page d'installation. Relancer le script." >&2
  exit 1
fi

# Répertoire créé par le SCRIPT avant `docker compose up` — jamais par Docker
# (sinon Docker créerait un répertoire vide et Nginx servirait un 403).
mkdir -p setup
chmod 755 setup

# CA publique téléchargeable (extension .crt reconnue par Android/iOS/Windows).
# Seule la partie PUBLIQUE est copiée — ca-key.pem ne quitte jamais ssl/.
cp ssl/ca.pem setup/kabutare-ca.crt
chmod 644 setup/kabutare-ca.crt

# QR code généré LOCALEMENT au provisionnement — jamais de lib JS depuis un
# CDN : le LAN de l'hôpital n'a pas forcément accès à internet.
if ! command -v qrencode &>/dev/null; then
  apt-get install -y -qq qrencode 2>/dev/null || true
fi
QR_OK=false
if command -v qrencode &>/dev/null; then
  if qrencode -t SVG -o setup/qr.svg "https://${SERVER_IP}/setup/" 2>/dev/null; then
    QR_OK=true
  fi
fi

# Guide d'installation (anglais — audience : personnel hospitalier non technique).
# Page autonome : CSS inline, aucun JS, aucune ressource externe.
cat > setup/index.html << 'SETUPEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Install the Kabutare Hospital app</title>
<style>
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  body{background:#F9FAFB;color:#111827;font-family:system-ui,-apple-system,Arial,sans-serif;line-height:1.55}
  .wrap{max-width:640px;margin:0 auto;padding:32px 20px 48px}
  header{text-align:center;margin-bottom:28px}
  header img{width:72px;height:72px;object-fit:contain;margin-bottom:12px}
  h1{font-size:1.35rem;font-weight:700;margin-bottom:6px}
  .sub{font-size:.85rem;color:#6B7280}
  .card{background:#fff;border:1px solid #E5E7EB;border-radius:12px;padding:20px;margin-bottom:16px}
  .step{display:inline-block;background:#2563EB;color:#fff;font-size:.75rem;font-weight:700;
        border-radius:99px;padding:2px 10px;margin-bottom:10px;letter-spacing:.03em}
  h2{font-size:1.02rem;font-weight:600;margin-bottom:8px}
  p{font-size:.88rem;color:#374151;margin-bottom:8px}
  .btn{display:inline-block;background:#2563EB;color:#fff;text-decoration:none;font-size:.9rem;
       font-weight:600;border-radius:8px;padding:10px 18px;margin-top:4px}
  details{border:1px solid #E5E7EB;border-radius:8px;margin-bottom:8px;background:#F9FAFB}
  summary{cursor:pointer;padding:10px 12px;font-size:.9rem;font-weight:600;color:#111827}
  details ol{padding:2px 16px 12px 32px;font-size:.85rem;color:#374151}
  details li{margin-bottom:4px}
  .note{font-size:.78rem;color:#6B7280;margin-top:8px}
  footer{text-align:center;margin-top:24px}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <img src="/app_isis/icons/Icon-192.png" alt="Kabutare Hospital logo">
    <h1>Install the Kabutare Hospital app</h1>
    <div class="sub">Medical equipment management &mdash; one-time setup, about 2 minutes</div>
  </header>

  <div class="card">
    <span class="step">STEP 1</span>
    <h2>Download the security certificate</h2>
    <p>This certificate tells your device that the hospital server can be trusted.
       You only need to install it once per device.</p>
    <a class="btn" href="/setup/kabutare-ca.crt" download>Download security certificate</a>
  </div>

  <div class="card">
    <span class="step">STEP 2</span>
    <h2>Install the certificate on your device</h2>
    <details>
      <summary>Android phone or tablet</summary>
      <ol>
        <li>Open <strong>Settings</strong> &rarr; <strong>Security</strong> &rarr; <strong>More security settings</strong></li>
        <li>Tap <strong>Install from device storage</strong> (or &ldquo;Install certificates&rdquo;)</li>
        <li>Choose <strong>CA certificate</strong>, then tap <strong>Install anyway</strong></li>
        <li>Select the downloaded file <strong>kabutare-ca.crt</strong></li>
      </ol>
    </details>
    <details>
      <summary>iPhone or iPad</summary>
      <ol>
        <li>Download the certificate with <strong>Safari</strong> (Step 1), then tap <strong>Allow</strong></li>
        <li>Open <strong>Settings</strong> &rarr; <strong>Profile Downloaded</strong> &rarr; <strong>Install</strong></li>
        <li>Then go to <strong>Settings</strong> &rarr; <strong>General</strong> &rarr; <strong>About</strong> &rarr; <strong>Certificate Trust Settings</strong></li>
        <li>Turn on <strong>Full Trust</strong> for &ldquo;Kabutare Hospital Root CA&rdquo;</li>
      </ol>
    </details>
    <details>
      <summary>Windows PC &mdash; Chrome or Edge</summary>
      <ol>
        <li>Open the downloaded <strong>kabutare-ca.crt</strong> file</li>
        <li>Click <strong>Install Certificate&hellip;</strong></li>
        <li>Choose <strong>Local Machine</strong>, then <strong>Next</strong></li>
        <li>Select <strong>Place all certificates in the following store</strong> &rarr; <strong>Trusted Root Certification Authorities</strong></li>
        <li>Click <strong>Finish</strong> and restart the browser</li>
      </ol>
    </details>
    <details>
      <summary>Firefox (any computer)</summary>
      <ol>
        <li>Open <strong>Settings</strong> &rarr; <strong>Privacy &amp; Security</strong> &rarr; <strong>Certificates</strong></li>
        <li>Click <strong>View Certificates&hellip;</strong> &rarr; <strong>Authorities</strong> &rarr; <strong>Import&hellip;</strong></li>
        <li>Select <strong>kabutare-ca.crt</strong></li>
        <li>Check <strong>Trust this CA to identify websites</strong>, then click <strong>OK</strong></li>
      </ol>
    </details>
  </div>

  <div class="card">
    <span class="step">STEP 3</span>
    <h2>Add the app to your home screen</h2>
    <details>
      <summary>Android &mdash; Chrome</summary>
      <ol>
        <li>Open the app (button below)</li>
        <li>Tap the <strong>&#8942;</strong> menu (top right)</li>
        <li>Tap <strong>Install app</strong> (or &ldquo;Add to Home screen&rdquo;)</li>
      </ol>
    </details>
    <details>
      <summary>iPhone &mdash; Safari</summary>
      <ol>
        <li>Open the app (button below) in Safari</li>
        <li>Tap the <strong>Share</strong> button (square with an arrow)</li>
        <li>Tap <strong>Add to Home Screen</strong>, then <strong>Add</strong></li>
      </ol>
    </details>
    <details>
      <summary>Computer &mdash; Chrome or Edge</summary>
      <ol>
        <li>Open the app (button below)</li>
        <li>Click the <strong>install icon</strong> in the address bar (screen with a down arrow)</li>
        <li>Click <strong>Install</strong></li>
      </ol>
    </details>
    <p class="note">Afterwards, the app opens full screen from its own icon, like a normal app.</p>
  </div>

  <footer>
    <a class="btn" href="/app_isis/">Open the app</a>
  </footer>
</div>
</body>
</html>
SETUPEOF

# Affiche A4 imprimable (QR + 3 étapes) — placeholder __SETUP_URL__ remplacé
# ci-dessous par sed (heredoc quoté → pas d'expansion shell directe).
cat > setup/poster.html << 'POSTEREOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Kabutare Hospital app &mdash; installation poster</title>
<style>
  @page{size:A4;margin:0}
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  body{background:#fff;color:#111827;font-family:system-ui,-apple-system,Arial,sans-serif;
       width:210mm;min-height:297mm;margin:0 auto;padding:22mm 18mm;text-align:center}
  h1{font-size:26pt;font-weight:700;margin-bottom:4mm}
  .sub{font-size:13pt;color:#6B7280;margin-bottom:10mm}
  #qr{width:90mm;height:90mm;margin-bottom:6mm}
  .url{font-size:20pt;font-weight:700;color:#2563EB;margin-bottom:12mm;word-break:break-all}
  .steps{text-align:left;display:inline-block;font-size:13pt;line-height:1.7}
  .steps b{color:#2563EB}
  .foot{margin-top:14mm;font-size:10pt;color:#6B7280}
</style>
</head>
<body>
  <h1>Scan to install the hospital equipment app</h1>
  <div class="sub">Kabutare Hospital &mdash; medical equipment management</div>
  <img id="qr" src="qr.svg" alt="QR code &mdash; scan it with your phone camera">
  <div class="url">__SETUP_URL__</div>
  <div class="steps">
    <div><b>1.</b> Connect to the hospital WiFi, then scan the QR code (or type the address)</div>
    <div><b>2.</b> Follow the guide: install the security certificate (one time only)</div>
    <div><b>3.</b> Add the app to your home screen</div>
  </div>
  <div class="foot">Need help? Contact the IT department.</div>
</body>
</html>
POSTEREOF
sed -i "s|__SETUP_URL__|https://${SERVER_IP}/setup/|g" setup/poster.html

if [[ "${QR_OK}" != "true" ]]; then
  # Dégradation gracieuse : pas de qrencode → affiche sans QR, URL en gros caractères
  sed -i '/id="qr"/d' setup/poster.html
  echo "      ⚠ qrencode indisponible — affiche générée sans QR code (URL seule)."
fi
chmod 644 setup/index.html setup/poster.html
# `|| true` : sous set -e, un test faux en fin de liste && tuerait le script
[[ ! -f setup/qr.svg ]] || chmod 644 setup/qr.svg
echo "      ✓ Page /setup/ générée (guide d'installation + affiche A4 imprimable)."

# ── Étape 6 : Vérification et assignation des ports ──────────
echo "[6/9] Vérification de la disponibilité des ports..."

port_in_use() {
  ss -tlnH "sport = :$1" 2>/dev/null | grep -q .
}

# Retourne le premier port libre à partir du port demandé
find_free_port() {
  local port=$1
  local count=0
  while port_in_use "${port}" && [[ ${count} -lt 20 ]]; do
    port=$((port + 1))
    count=$((count + 1))
  done
  echo "${port}"
}

# Met à jour ou ajoute une variable dans .env et l'exporte
set_env_port() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" .env
  else
    echo "${key}=${val}" >> .env
  fi
  export "${key}=${val}"
}

HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
KC_HOST_PORT="${KC_HOST_PORT:-8080}"

for ENTRY in "HTTP_PORT:${HTTP_PORT}" "HTTPS_PORT:${HTTPS_PORT}" "KC_HOST_PORT:${KC_HOST_PORT}"; do
  VAR="${ENTRY%%:*}"
  WANTED="${ENTRY#*:}"
  FREE=$(find_free_port "${WANTED}")
  if [[ "${FREE}" != "${WANTED}" ]]; then
    PROCESS=$(ss -tlnpH "sport = :${WANTED}" 2>/dev/null | awk '{print $6}' | head -1)
    echo "      ⚠ Port ${WANTED} occupé (${PROCESS:-inconnu}) → port ${FREE} assigné automatiquement."
    set_env_port "${VAR}" "${FREE}"
    printf -v "${VAR}" '%s' "${FREE}"   # Évite eval (risque d'injection) — MAJ-3
    export "${VAR}"
  else
    echo "      ✓ Port ${WANTED} disponible."
  fi
done

# ── Mise à jour KC_PUBLIC_URL et CORS si HTTPS_PORT a changé ─
# KC_PUBLIC_URL est calculé à l'étape 4 en supposant le port 443.
# Si le port a été réassigné (ex: 443→444), on recalcule et met à jour le .env.
# Sans ça : Keycloak génère des tokens avec iss=https://IP mais les services
# attendent https://IP:444 → échec de validation JWT sur toutes les requêtes.
if [[ "${HTTPS_PORT}" != "443" ]]; then
  KC_PUBLIC_URL="https://${SERVER_IP}:${HTTPS_PORT}"
  # Reconstruire CORS avec le bon port pour les deux IPs
  CORS_ORIGINS="https://${SERVER_IP}:${HTTPS_PORT}"
  if [[ -n "${LOCAL_IP:-}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
    CORS_ORIGINS="${CORS_ORIGINS},https://${LOCAL_IP}:${HTTPS_PORT}"
  fi
  sed -i "s|^KC_PUBLIC_URL=.*|KC_PUBLIC_URL=${KC_PUBLIC_URL}|" .env
  sed -i "s|^CORS_ORIGIN=.*|CORS_ORIGIN=${CORS_ORIGINS}|"      .env
  export KC_PUBLIC_URL CORS_ORIGINS
  echo "      ✓ KC_PUBLIC_URL mis à jour : ${KC_PUBLIC_URL}"
  echo "      ✓ CORS_ORIGIN mis à jour   : ${CORS_ORIGINS}"
fi

# ── Étape 7 : Configuration du pare-feu ──────────────────────
echo "[7/9] Configuration du pare-feu (ufw)..."
if command -v ufw &>/dev/null; then
  # Politique par défaut : tout bloquer en entrée, tout autoriser en sortie (CRIT-2)
  ufw default deny incoming  &>/dev/null || true
  ufw default allow outgoing &>/dev/null || true
  # SSH avec rate-limiting intégré : max 6 tentatives/30s par IP (anti-brute-force)
  ufw limit 22/tcp    &>/dev/null || true

  if [[ "${NETWORK_MODE}" == "2" ]]; then
    # Mode WiFi local : dériver le sous-réseau depuis LOCAL_IP (ex: 192.168.1.0/24)
    # et n'autoriser HTTP/HTTPS QUE depuis ce sous-réseau → internet bloqué
    WIFI_SUBNET=$(echo "${SERVER_IP}" | awk -F. '{print $1"."$2"."$3".0/24"}')
    ufw allow from "${WIFI_SUBNET}" to any port "${HTTP_PORT}"  proto tcp &>/dev/null || true
    ufw allow from "${WIFI_SUBNET}" to any port "${HTTPS_PORT}" proto tcp &>/dev/null || true
    echo "      ✓ Ports HTTP/HTTPS ouverts uniquement pour le sous-réseau WiFi : ${WIFI_SUBNET}"
  else
    # Mode public : ports ouverts pour tout le monde
    ufw allow "${HTTP_PORT}/tcp"  &>/dev/null || true
    ufw allow "${HTTPS_PORT}/tcp" &>/dev/null || true
    echo "      ✓ Ports HTTP/HTTPS ouverts publiquement."
  fi

  if ufw status | grep -q "Status: inactive"; then
    ufw --force enable
    echo "      ✓ Pare-feu activé (politique : deny incoming par défaut)."
  else
    echo "      ✓ Règles mises à jour (pare-feu déjà actif)."
  fi
  echo "      ✓ Ports ouverts : 22/tcp limité (SSH), ${HTTP_PORT} (HTTP), ${HTTPS_PORT} (HTTPS)"
else
  echo "      ufw non disponible — vérifier manuellement les règles de pare-feu."
fi

# ── Étape 8 : Pull des images Docker Hub ─────────────────────
# Le build Flutter est embarqué dans l'image kabutare-nginx.
# L'app utilise window.location.hostname — aucune substitution IP nécessaire au démarrage.
echo "[8/9] Pull des images depuis Docker Hub (${DOCKER_USER})..."
# DOCKER_CONTENT_TRUST=1 : refuse les images non signées (protection supply chain — MAJ-2)
# Pré-requis : images signées avec `docker trust sign <image>` sur la machine de build.
# Si la signature n'est pas configurée, retirer la variable et vérifier les digests SHA256 manuellement.
DOCKER_CONTENT_TRUST=1 docker compose -f docker-compose.ip.secured.yml pull nginx keycloak auth-service db-service
echo "      ✓ Images téléchargées."

# ── Étape 9 : Démarrage de la stack ──────────────────────────
echo "[9/9] Démarrage de la stack Docker Compose..."
# `|| true` : empêche set -euo pipefail de planter le script si Keycloak
# n'est pas encore healthy au moment où compose up rend la main.
# La boucle d'attente ci-dessous gère le cas du démarrage lent (premier boot = 2-3 min).
docker compose -f docker-compose.ip.secured.yml up -d || true

echo ""
echo "      Attente que Keycloak soit prêt (premier démarrage = compilation + init DB = 2-3 min)..."
ATTEMPTS=0
until [[ "$(docker inspect --format='{{.State.Health.Status}}' keycloak-ip 2>/dev/null)" == "healthy" ]]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [[ $ATTEMPTS -gt 48 ]]; then
    echo ""
    echo "      ⚠ Keycloak n'est pas healthy après 4 minutes."
    echo "        Logs Keycloak  : docker compose -f docker-compose.ip.secured.yml logs --tail=50 keycloak"
    echo "        État conteneur : docker inspect keycloak-ip | grep -A5 Health"
    break
  fi
  printf "."
  sleep 5
done
echo ""

# ── Résumé ────────────────────────────────────────────────────
# Construction des URLs avec les ports réellement utilisés
HTTPS_SUFFIX=""
[[ "${HTTPS_PORT}" != "443" ]] && HTTPS_SUFFIX=":${HTTPS_PORT}"
BASE_URL="https://${SERVER_IP}${HTTPS_SUFFIX}"

# ── Configuration Keycloak (realm, rôles, clients) ────────────
KC_CONFIGURED=false
if [[ "$(docker inspect --format='{{.State.Health.Status}}' keycloak-ip 2>/dev/null)" == "healthy" ]]; then
  echo "      Configuration automatique de Keycloak..."
  # CRIT-3 : mot de passe passé via -e (variable d'env dans le conteneur)
  # et non en argument CLI — évite l'exposition dans `ps aux` / /proc/<pid>/cmdline
  # Appels kcadm suivants : session stockée dans le conteneur (~/.keycloak/kcadm.config)
  # → plus besoin de repasser le mot de passe après l'auth initiale
  KCADM="docker compose -f docker-compose.ip.secured.yml exec -T \
    keycloak /opt/keycloak/bin/kcadm.sh"

  # Auth initiale : mot de passe passé via -e dans le conteneur (sh -c l'étend côté conteneur)
  # → jamais visible dans `ps aux` sur l'hôte (CRIT-3)
  if docker compose -f docker-compose.ip.secured.yml exec -T \
      -e KCADM_PASS="${KC_ADMIN_PASSWORD}" \
      -e KCADM_USER="${KC_ADMIN_USER}" \
      keycloak sh -c \
      '/opt/keycloak/bin/kcadm.sh config credentials \
       --server http://localhost:8080/keycloak \
       --realm master \
       --user "$KCADM_USER" \
       --password "$KCADM_PASS"' 2>/dev/null; then

    # Realm
    if ! $KCADM get realms/kabutare-hospital &>/dev/null; then
      $KCADM create realms \
        -s realm=kabutare-hospital \
        -s enabled=true \
        -s resetPasswordAllowed=true \
        -s loginWithEmailAllowed=true \
        -s verifyEmail=false 2>/dev/null \
        && echo "      ✓ Realm 'kabutare-hospital' créé." \
        || echo "      ⚠ Création du realm échouée."
    else
      echo "      Realm 'kabutare-hospital' existant — conservé."
    fi
    $KCADM update realms/kabutare-hospital \
      -s resetPasswordAllowed=true -s loginWithEmailAllowed=true \
      -s verifyEmail=false 2>/dev/null || true
    $KCADM update realms/kabutare-hospital -s emailTheme=kabutare 2>/dev/null || true

    # Rôles realm
    for ROLE in admin supervisor hospitalStaff technician_biomedical technician_it technician_infra; do
      $KCADM create roles -r kabutare-hospital -s name="${ROLE}" 2>/dev/null || true
    done
    echo "      ✓ Rôles realm configurés."

    # Client flutter-app (public, Direct Access Grants)
    if ! $KCADM get clients -r kabutare-hospital 2>/dev/null | grep -q '"flutter-app"'; then
      $KCADM create clients -r kabutare-hospital \
        -s clientId=flutter-app \
        -s publicClient=true \
        -s directAccessGrantsEnabled=true \
        -s "redirectUris=[\"${BASE_URL}/app_isis/*\"]" \
        -s "webOrigins=[\"${BASE_URL}\"]" 2>/dev/null \
        && echo "      ✓ Client 'flutter-app' créé." || true
    fi

    # Client auth-service (confidential, Service Accounts)
    if ! $KCADM get clients -r kabutare-hospital 2>/dev/null | grep -q '"auth-service"'; then
      $KCADM create clients -r kabutare-hospital \
        -s clientId=auth-service \
        -s publicClient=false \
        -s serviceAccountsEnabled=true \
        -s directAccessGrantsEnabled=false 2>/dev/null \
        && echo "      ✓ Client 'auth-service' créé." || true
    fi

    # Récupération automatique du secret auth-service → .env
    AUTH_SVC_UUID=$($KCADM get clients -r kabutare-hospital 2>/dev/null \
      | python3 -c "
import sys, json
try:
  for c in json.load(sys.stdin):
    if c.get('clientId') == 'auth-service':
      print(c['id']); break
except: pass
" 2>/dev/null)
    if [[ -n "${AUTH_SVC_UUID}" ]]; then
      KC_SECRET=$($KCADM get "clients/${AUTH_SVC_UUID}/client-secret" \
        -r kabutare-hospital 2>/dev/null \
        | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('value',''))
except: pass
" 2>/dev/null)
      if [[ -n "${KC_SECRET}" && "${KC_SECRET}" != "null" ]]; then
        sed -i "s|^KC_CLIENT_SECRET_AUTH=.*|KC_CLIENT_SECRET_AUTH=${KC_SECRET}|" .env
        export KC_CLIENT_SECRET_AUTH="${KC_SECRET}"
        echo "      ✓ KC_CLIENT_SECRET_AUTH mis à jour dans .env"
        docker compose -f docker-compose.ip.secured.yml up -d --force-recreate auth-service 2>/dev/null
        echo "      ✓ auth-service redémarré avec le nouveau secret."
      fi
    fi

    # ── Permissions Admin API : manage-users pour auth-service ────────────
    # Le service account du client auth-service doit pouvoir créer/modifier
    # des utilisateurs via l'Admin API Keycloak (inscription, gestion comptes).
    # Sans ce rôle → HTTP 403 sur POST /api/auth/register et les routes users.
    $KCADM add-roles \
      -r kabutare-hospital \
      --uusername service-account-auth-service \
      --cclientid realm-management \
      --rolename manage-users 2>/dev/null \
      && echo "      ✓ manage-users assigné au service account auth-service." \
      || echo "      ⚠ manage-users déjà assigné ou client non trouvé."

    # ── Redirect URIs multi-IP (local + publique) ─────────────────────────
    # Construction de la liste des URIs valides pour les deux IPs
    REDIRECT_URIS="[\"${BASE_URL}/*\""
    WEB_ORIGINS="[\"${BASE_URL}\""
    if [[ -n "${LOCAL_IP:-}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
      LOCAL_HTTPS_SUFFIX=""
      [[ "${HTTPS_PORT}" != "443" ]] && LOCAL_HTTPS_SUFFIX=":${HTTPS_PORT}"
      LOCAL_BASE_URL="https://${LOCAL_IP}${LOCAL_HTTPS_SUFFIX}"
      REDIRECT_URIS="${REDIRECT_URIS}, \"${LOCAL_BASE_URL}/*\""
      WEB_ORIGINS="${WEB_ORIGINS}, \"${LOCAL_BASE_URL}\""
    fi
    REDIRECT_URIS="${REDIRECT_URIS}]"
    WEB_ORIGINS="${WEB_ORIGINS}]"

    # Mettre à jour le client flutter-app avec les deux IPs
    FLUTTER_UUID=$($KCADM get clients -r kabutare-hospital 2>/dev/null \
      | python3 -c "
import sys, json
try:
  for c in json.load(sys.stdin):
    if c.get('clientId') == 'flutter-app':
      print(c['id']); break
except: pass
" 2>/dev/null)
    if [[ -n "${FLUTTER_UUID}" ]]; then
      $KCADM update "clients/${FLUTTER_UUID}" -r kabutare-hospital \
        -s "redirectUris=${REDIRECT_URIS}" \
        -s "webOrigins=${WEB_ORIGINS}" 2>/dev/null \
        && echo "      ✓ flutter-app : redirect URIs mis à jour (${SERVER_IP} + ${LOCAL_IP:-aucune IP locale})."
    fi

    # Mettre à jour security-admin-console (master realm) avec les deux IPs
    # → corrige "Invalid parameter: redirect_uri" depuis le WiFi local
    ADMIN_CONSOLE_UUID=$($KCADM get clients -r master 2>/dev/null \
      | python3 -c "
import sys, json
try:
  for c in json.load(sys.stdin):
    if c.get('clientId') == 'security-admin-console':
      print(c['id']); break
except: pass
" 2>/dev/null)
    if [[ -n "${ADMIN_CONSOLE_UUID}" ]]; then
      $KCADM update "clients/${ADMIN_CONSOLE_UUID}" -r master \
        -s "redirectUris=${REDIRECT_URIS}" \
        -s "webOrigins=${WEB_ORIGINS}" 2>/dev/null \
        && echo "      ✓ security-admin-console : redirect URIs mis à jour."
    fi

    KC_CONFIGURED=true
    echo "      ✓ Keycloak configuré."
  else
    echo "      ⚠ Authentification Keycloak échouée — configuration manuelle requise."
  fi
fi

# ── Initialisation des données ───────────────────────────────
echo ""
echo "========================================================"
echo " Initialisation des bases de données"
echo "========================================================"
echo ""
echo "  Comment souhaitez-vous initialiser les données ?"
echo ""
echo "  1) Seed de démonstration  — données fictives (équipements, incidents,"
echo "     départements, utilisateurs démo) insérées via node seed.js"
echo "  2) Restaurer un backup    — depuis des fichiers de sauvegarde existants"
echo "     (auth.db, hospital.db, dump SQL PostgreSQL Keycloak)"
echo "  3) Ignorer                — bases laissées dans leur état actuel"
echo ""
read -rp "  Votre choix [1/2/3, défaut=3] : " DATA_INIT_CHOICE
DATA_INIT_CHOICE="${DATA_INIT_CHOICE:-3}"
echo ""

# Validation SQLite via les magic bytes (Python3 déjà utilisé dans le script)
_is_sqlite() {
  python3 -c "
import sys
try:
  with open(sys.argv[1], 'rb') as f:
    sys.exit(0 if f.read(6) == b'SQLite' else 1)
except:
  sys.exit(1)
" "$1" 2>/dev/null
}

case "${DATA_INIT_CHOICE}" in

  # ── Option 1 : Seed de démonstration ─────────────────────────
  1)
    echo "      Insertion des données de démonstration..."
    echo ""

    # auth-service : permissions applicatives, rôles SQLite
    echo -n "      auth-service  : "
    if docker compose -f docker-compose.ip.secured.yml exec -T auth-service node seed.js 2>/dev/null; then
      echo "✓ Données de démonstration insérées."
    else
      echo "⚠ Ignoré (données déjà présentes ou service non prêt)."
      echo "        → Relancer manuellement : docker exec auth-service-ip node seed.js"
    fi

    # db-service : équipements, incidents, inventaire
    echo -n "      db-service    : "
    if docker compose -f docker-compose.ip.secured.yml exec -T db-service node seed.js 2>/dev/null; then
      echo "✓ Équipements, incidents, inventaire insérés."
    else
      echo "⚠ Ignoré (données déjà présentes ou service non prêt)."
      echo "        → Relancer manuellement : docker exec db-service-ip node seed.js"
    fi
    ;;

  # ── Option 2 : Restauration depuis un backup ─────────────────
  2)
    echo "      Restauration depuis des fichiers de sauvegarde."
    echo "      Les fichiers peuvent être placés dans ./backups/ pour détection automatique."
    echo ""

    # Créer le dossier backups s'il n'existe pas (permissions 700 — root uniquement)
    mkdir -p "${SCRIPT_DIR}/backups"
    chmod 700 "${SCRIPT_DIR}/backups"
    BACKUP_DIR="${SCRIPT_DIR}/backups"

    # ── Détection automatique des backups les plus récents ───────
    # Tri décroissant : le fichier le plus récent (ou le plus grand numéro de date) est retenu
    DETECTED_AUTH_DB=$(     find "${BACKUP_DIR}" -maxdepth 1 -name "auth*.db" \
                              2>/dev/null | sort -r | head -1 || true)
    DETECTED_HOSPITAL_DB=$( find "${BACKUP_DIR}" -maxdepth 1 -name "hospital*.db" \
                              2>/dev/null | sort -r | head -1 || true)
    DETECTED_KC_SQL=$(      find "${BACKUP_DIR}" -maxdepth 1 \
                              \( -name "keycloak*.sql" -o -name "keycloak*.dump" \) \
                              2>/dev/null | sort -r | head -1 || true)

    # ── Saisie interactive des chemins ───────────────────────────
    echo "      [A] auth.db — permissions applicatives (auth-service)"
    [[ -n "${DETECTED_AUTH_DB}" ]] && echo "          Détecté automatiquement : ${DETECTED_AUTH_DB}"
    read -rp "          Chemin complet${DETECTED_AUTH_DB:+ [${DETECTED_AUTH_DB}]} (Entrée pour ignorer) : " _IN
    AUTH_DB_BACKUP="${_IN:-${DETECTED_AUTH_DB}}"

    echo ""
    echo "      [B] hospital.db — équipements / incidents (db-service)"
    [[ -n "${DETECTED_HOSPITAL_DB}" ]] && echo "          Détecté automatiquement : ${DETECTED_HOSPITAL_DB}"
    read -rp "          Chemin complet${DETECTED_HOSPITAL_DB:+ [${DETECTED_HOSPITAL_DB}]} (Entrée pour ignorer) : " _IN
    HOSPITAL_DB_BACKUP="${_IN:-${DETECTED_HOSPITAL_DB}}"

    echo ""
    echo "      [C] keycloak.sql — dump PostgreSQL (utilisateurs, realm, clients Keycloak)"
    [[ -n "${DETECTED_KC_SQL}" ]] && echo "          Détecté automatiquement : ${DETECTED_KC_SQL}"
    read -rp "          Chemin complet${DETECTED_KC_SQL:+ [${DETECTED_KC_SQL}]} (Entrée pour ignorer) : " _IN
    KC_SQL_BACKUP="${_IN:-${DETECTED_KC_SQL}}"

    echo ""
    RESTORE_ANY=false

    # ── Restauration auth.db ──────────────────────────────────────
    if [[ -n "${AUTH_DB_BACKUP}" ]]; then
      echo "      ── auth.db ───────────────────────────────────────────"
      if [[ ! -f "${AUTH_DB_BACKUP}" ]]; then
        echo "      ✗ Fichier introuvable : ${AUTH_DB_BACKUP}"
      elif ! _is_sqlite "${AUTH_DB_BACKUP}"; then
        echo "      ✗ Le fichier ne semble pas être une base SQLite — ignoré."
      else
        # db-service dépend d'auth-service → arrêt des deux, redémarrage en ordre
        echo "         Arrêt de db-service et auth-service..."
        docker compose -f docker-compose.ip.secured.yml stop db-service auth-service 2>/dev/null
        if docker cp "${AUTH_DB_BACKUP}" auth-service-ip:/data/auth.db 2>/dev/null; then
          echo "      ✓ auth.db copié dans le volume auth_data_ip."
          RESTORE_ANY=true
        else
          echo "      ✗ Échec de la copie — le conteneur auth-service-ip existe-t-il ?"
        fi
        echo "         Redémarrage auth-service..."
        docker compose -f docker-compose.ip.secured.yml start auth-service 2>/dev/null
        # Attente de la santé d'auth-service avant de remonter db-service
        echo -n "         Attente auth-service healthy"
        _ATT=0
        until [[ "$(docker inspect --format='{{.State.Health.Status}}' \
                    auth-service-ip 2>/dev/null)" == "healthy" ]] \
              || [[ $_ATT -gt 12 ]]; do
          printf "."; sleep 5; _ATT=$((_ATT+1))
        done
        echo " ok"
        docker compose -f docker-compose.ip.secured.yml start db-service 2>/dev/null
        echo "         db-service redémarré."
      fi
      echo ""
    fi

    # ── Restauration hospital.db ──────────────────────────────────
    if [[ -n "${HOSPITAL_DB_BACKUP}" ]]; then
      echo "      ── hospital.db ───────────────────────────────────────"
      if [[ ! -f "${HOSPITAL_DB_BACKUP}" ]]; then
        echo "      ✗ Fichier introuvable : ${HOSPITAL_DB_BACKUP}"
      elif ! _is_sqlite "${HOSPITAL_DB_BACKUP}"; then
        echo "      ✗ Le fichier ne semble pas être une base SQLite — ignoré."
      else
        echo "         Arrêt de db-service..."
        docker compose -f docker-compose.ip.secured.yml stop db-service 2>/dev/null
        if docker cp "${HOSPITAL_DB_BACKUP}" db-service-ip:/data/hospital.db 2>/dev/null; then
          echo "      ✓ hospital.db copié dans le volume db_data_ip."
          RESTORE_ANY=true
        else
          echo "      ✗ Échec de la copie — le conteneur db-service-ip existe-t-il ?"
        fi
        docker compose -f docker-compose.ip.secured.yml start db-service 2>/dev/null
        echo "         db-service redémarré."
      fi
      echo ""
    fi

    # ── Restauration PostgreSQL Keycloak ──────────────────────────
    if [[ -n "${KC_SQL_BACKUP}" ]]; then
      echo "      ── keycloak PostgreSQL ───────────────────────────────"
      if [[ ! -f "${KC_SQL_BACKUP}" ]]; then
        echo "      ✗ Fichier introuvable : ${KC_SQL_BACKUP}"
      else
        echo "         Arrêt de Keycloak (évite les conflits d'accès concurrents)..."
        docker compose -f docker-compose.ip.secured.yml stop keycloak 2>/dev/null
        # Nettoyage complet avant restauration pour éviter les conflits d'objets
        echo "         Recréation de la base keycloak..."
        docker exec postgres-keycloak-ip psql -U keycloak \
          -c "DROP DATABASE IF EXISTS keycloak;" 2>/dev/null || true
        docker exec postgres-keycloak-ip psql -U keycloak \
          -c "CREATE DATABASE keycloak OWNER keycloak;" 2>/dev/null || true
        # Restauration du dump SQL (format pg_dump texte ou custom)
        echo "         Restauration en cours (30-60 s selon la taille du dump)..."
        if docker exec -i postgres-keycloak-ip psql -U keycloak -d keycloak \
            < "${KC_SQL_BACKUP}" > /dev/null 2>&1; then
          echo "      ✓ Base PostgreSQL Keycloak restaurée."
          RESTORE_ANY=true
          KC_CONFIGURED=true   # La config Keycloak est incluse dans le backup
        else
          echo "      ✗ Échec de la restauration — vérifier le format du fichier."
          echo "        Format attendu (texte pg_dump) :"
          echo "        docker exec postgres-keycloak-ip pg_dump -U keycloak keycloak \\"
          echo "          > backups/keycloak_YYYYMMDD.sql"
        fi
        # Redémarrage et attente de la santé de Keycloak
        echo "         Redémarrage Keycloak..."
        docker compose -f docker-compose.ip.secured.yml start keycloak 2>/dev/null
        echo -n "         Attente Keycloak healthy"
        _ATT=0
        until [[ "$(docker inspect --format='{{.State.Health.Status}}' \
                    keycloak-ip 2>/dev/null)" == "healthy" ]] \
              || [[ $_ATT -gt 24 ]]; do
          printf "."; sleep 5; _ATT=$((_ATT+1))
        done
        echo " ok"
      fi
      echo ""
    fi

    if [[ "${RESTORE_ANY}" == "false" ]]; then
      echo "      ⚠ Aucun fichier de backup valide fourni."
      echo "        Les bases de données sont dans leur état actuel."
      echo "        → Placer les fichiers dans ${SCRIPT_DIR}/backups/ et relancer l'étape 2,"
      echo "          ou relancer le script complet."
    fi
    ;;

  # ── Option 3 / défaut : ne rien faire ────────────────────────
  *)
    echo "      Initialisation ignorée — bases dans leur état actuel."
    ;;

esac

echo ""
echo "========================================================"
echo " ✓ Déploiement terminé !"
echo ""
if [[ "${NETWORK_MODE}" == "2" ]]; then
  echo " Mode réseau           : WiFi local uniquement (internet bloqué)"
else
  echo " Mode réseau           : Public (internet + WiFi interne)"
fi
echo ""
echo " Application Flutter  : ${BASE_URL}/app_isis/"
echo " Admin Keycloak        : ${BASE_URL}/keycloak/admin/"
echo " Health auth-service   : ${BASE_URL}/auth/health"
echo " Health db-service     : ${BASE_URL}/db/health"
[[ "${KC_HOST_PORT}" != "8080" ]] && \
  echo " Keycloak (SSH tunnel)  : localhost:${KC_HOST_PORT}"
if [[ -n "${LOCAL_IP:-}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
  echo ""
  echo " Accès WiFi hôpital    : https://${LOCAL_IP}/app_isis/"
  echo " (Même application, backend détecté automatiquement selon le réseau)"
fi
echo ""
echo " IMPORTANT — Le certificat est auto-signé."
echo " Le navigateur affichera un avertissement à accepter."
echo ""
if [[ "${KC_CONFIGURED}" == "true" ]]; then
  echo " Keycloak configuré automatiquement. Étapes restantes :"
  echo " 1. Créer les utilisateurs dans ${BASE_URL}/keycloak/admin/"
  echo "    (realm kabutare-hospital → Users → Add user)"
  echo " 2. Assigner les rôles : admin, supervisor, hospitalStaff,"
  echo "    technician_biomedical, technician_it, technician_infra"
else
  echo " IMPORTANT — Configuration Keycloak manuelle requise :"
  echo " 1. Ouvrir ${BASE_URL}/keycloak/admin/"
  echo " 2. Créer le realm 'kabutare-hospital'"
  echo " 3. Client 'flutter-app' (public, Direct Access Grants ON)"
  echo "    Redirect URI : ${BASE_URL}/app_isis/*  |  Web origins : ${BASE_URL}"
  echo " 4. Client 'auth-service' (confidential, Service Accounts ON)"
  echo "    Copier le client secret dans .env (KC_CLIENT_SECRET_AUTH)"
  echo " 5. Rôles : admin, supervisor, hospitalStaff,"
  echo "    technician_biomedical, technician_it, technician_infra"
  echo " 6. Redémarrer : docker compose -f docker-compose.ip.secured.yml restart auth-service"
fi
echo ""
echo " ── Sauvegardes ─────────────────────────────────────────"
echo " Pour créer un backup complet (depuis ${SCRIPT_DIR}) :"
echo ""
echo "   mkdir -p backups && chmod 700 backups"
echo ""
echo "   # SQLite — auth-service (permissions applicatives)"
echo "   docker cp auth-service-ip:/data/auth.db \\"
echo "     backups/auth_\$(date +%Y%m%d_%H%M).db"
echo ""
echo "   # SQLite — db-service (équipements, incidents)"
echo "   docker cp db-service-ip:/data/hospital.db \\"
echo "     backups/hospital_\$(date +%Y%m%d_%H%M).db"
echo ""
echo "   # PostgreSQL — Keycloak (utilisateurs, realm, clients)"
echo "   docker exec postgres-keycloak-ip pg_dump -U keycloak keycloak \\"
echo "     > backups/keycloak_\$(date +%Y%m%d_%H%M).sql"
echo ""
echo "   chmod 600 backups/*.db backups/*.sql   # Protéger les secrets"
echo ""
echo " Pour restaurer depuis ces fichiers :"
echo "   sudo bash setup_ubuntu.sh  → choisir option 2 (Restaurer un backup)"
echo "========================================================"
