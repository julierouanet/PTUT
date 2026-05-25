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
#       scp setup_ubuntu.sh docker-compose.ip.yml user@IP:~/kabutare/
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

# ── Étape 3 : Détection des IPs (publique + réseau local) ────
echo "[3/9] Détection des IPs du serveur..."

# IP publique (internet)
DETECTED_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
  || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
  || hostname -I | awk '{print $1}')

echo "      IP publique détectée : ${DETECTED_IP}"
read -rp "      Confirmer ou saisir l'IP publique [${DETECTED_IP}] : " USER_IP
SERVER_IP="${USER_IP:-${DETECTED_IP}}"
echo "      ✓ IP publique retenue : ${SERVER_IP}"

# IP locale (WiFi hôpital — plages privées 192.168.x.x / 10.x.x.x / 172.16-31.x.x)
DETECTED_LOCAL_IP=$(hostname -I | tr ' ' '\n' \
  | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' \
  | grep -v "^${SERVER_IP}$" | head -1 || true)

echo ""
echo "      IP locale réseau interne détectée : ${DETECTED_LOCAL_IP:-aucune}"
echo "      (utilisée par les appareils connectés au WiFi de l'hôpital)"
read -rp "      Saisir l'IP locale du serveur sur le WiFi hôpital [${DETECTED_LOCAL_IP}] (Entrée pour ignorer) : " USER_LOCAL_IP
LOCAL_IP="${USER_LOCAL_IP:-${DETECTED_LOCAL_IP}}"
if [[ -n "${LOCAL_IP}" ]]; then
  echo "      ✓ IP locale retenue : ${LOCAL_IP}"
  echo "      → Les appareils WiFi accéderont via https://${LOCAL_IP}/app_isis/"
else
  echo "      Pas d'IP locale configurée — accès WiFi interne désactivé."
fi

# ── Étape 4 : Création du fichier .env ───────────────────────
echo "[4/9] Configuration des variables d'environnement..."

# Construction de la valeur CORS (IP publique + IP locale si définie)
CORS_ORIGINS="https://${SERVER_IP}"
if [[ -n "${LOCAL_IP}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
  CORS_ORIGINS="${CORS_ORIGINS},https://${LOCAL_IP}"
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
else
  echo "      Création du fichier .env..."

  read -rp "      Docker Hub username : " DOCKER_USER_INPUT
  read -rp "      Mot de passe admin Keycloak : " -s KC_ADMIN_PASSWORD_INPUT; echo
  read -rp "      Mot de passe PostgreSQL Keycloak : " -s KC_DB_PASSWORD_INPUT; echo

  INTERNAL_SECRET_GEN=$(openssl rand -hex 32)

  cat > .env <<EOF
SERVER_IP=${SERVER_IP}
LOCAL_IP=${LOCAL_IP}
CORS_ORIGIN=${CORS_ORIGINS}
DOCKER_USER=${DOCKER_USER_INPUT}

INTERNAL_SECRET=${INTERNAL_SECRET_GEN}

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
  echo "      ✓ Fichier .env créé."
fi

# Charger les variables pour la suite du script
set -a; source .env; set +a

# ── Étape 5 : Certificat SSL + config Nginx ──────────────────
echo "[5/9] Génération du certificat SSL et configuration Nginx..."
mkdir -p ssl nginx/conf.d
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
    location = / { return 301 /app_isis/; }
    location = /app_isis { return 301 /app_isis/; }
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

if [[ -f "ssl/cert.pem" && -f "ssl/key.pem" ]]; then
  echo "      Certificat existant conservé."
else
  # SAN inclut l'IP publique + l'IP locale si définie
  # → le même certificat est valide sur le WiFi hôpital ET depuis internet
  SSL_SAN="IP:${SERVER_IP}"
  if [[ -n "${LOCAL_IP}" && "${LOCAL_IP}" != "${SERVER_IP}" ]]; then
    SSL_SAN="${SSL_SAN},IP:${LOCAL_IP}"
    echo "      Certificat couvrant : ${SERVER_IP} (internet) + ${LOCAL_IP} (WiFi hôpital)"
  fi

  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=${SERVER_IP}" \
    -addext "subjectAltName=${SSL_SAN}" \
    2>/dev/null
  chmod 600 ssl/key.pem ssl/cert.pem
  echo "      ✓ Certificat généré (valide 10 ans) : ssl/cert.pem"
fi

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
    eval "${VAR}=${FREE}"
  else
    echo "      ✓ Port ${WANTED} disponible."
  fi
done

# ── Étape 7 : Configuration du pare-feu ──────────────────────
echo "[7/9] Configuration du pare-feu (ufw)..."
if command -v ufw &>/dev/null; then
  # SSH en premier pour ne pas se bloquer
  ufw allow 22/tcp    &>/dev/null || true
  ufw allow "${HTTP_PORT}/tcp"  &>/dev/null || true
  ufw allow "${HTTPS_PORT}/tcp" &>/dev/null || true
  if ufw status | grep -q "Status: inactive"; then
    ufw --force enable
    echo "      ✓ Pare-feu activé."
  else
    echo "      ✓ Règles mises à jour (pare-feu déjà actif)."
  fi
  echo "      ✓ Ports ouverts : 22 (SSH), ${HTTP_PORT} (HTTP), ${HTTPS_PORT} (HTTPS)"
else
  echo "      ufw non disponible — vérifier manuellement les règles de pare-feu."
fi

# ── Étape 8 : Pull des images Docker Hub ─────────────────────
# Le build Flutter est embarqué dans l'image kabutare-nginx.
# La substitution de SERVER_IP se fait au démarrage du conteneur.
echo "[8/9] Pull des images depuis Docker Hub (${DOCKER_USER})..."
docker compose -f docker-compose.ip.yml pull nginx keycloak auth-service db-service
echo "      ✓ Images téléchargées."

# ── Étape 9 : Démarrage de la stack ──────────────────────────
echo "[9/9] Démarrage de la stack Docker Compose..."
docker compose -f docker-compose.ip.yml up -d

echo ""
echo "      Attente que Keycloak soit prêt (peut prendre 2-3 min)..."
ATTEMPTS=0
until [[ "$(docker inspect --format='{{.State.Health.Status}}' keycloak-ip 2>/dev/null)" == "healthy" ]]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [[ $ATTEMPTS -gt 36 ]]; then
    echo "      ⚠ Keycloak n'a pas démarré dans les 3 minutes."
    echo "        Vérifier les logs : docker compose -f docker-compose.ip.yml logs keycloak"
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
  KCADM="docker compose -f docker-compose.ip.yml exec -T keycloak /opt/keycloak/bin/kcadm.sh"

  if $KCADM config credentials \
      --server "http://localhost:8080/keycloak" \
      --realm master \
      --user "${KC_ADMIN_USER}" \
      --password "${KC_ADMIN_PASSWORD}" 2>/dev/null; then

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
        docker compose -f docker-compose.ip.yml up -d --force-recreate auth-service 2>/dev/null
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

# ── Seed données de démonstration (db-service) ───────────────
echo "      Seeding des données de démonstration (db-service)..."
if docker compose -f docker-compose.ip.yml exec -T db-service node seed.js 2>/dev/null; then
  echo "      ✓ Données insérées (équipements, incidents, inventaire)."
else
  echo "      ⚠ Seed ignoré (données déjà présentes ou service non prêt)."
  echo "        Pour relancer : docker exec db-service-ip node seed.js"
fi

echo ""
echo "========================================================"
echo " ✓ Déploiement terminé !"
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
  echo " 6. Redémarrer : docker compose -f docker-compose.ip.yml restart auth-service"
fi
echo "========================================================"
