#!/usr/bin/env bash
# ============================================================
# setup_ubuntu.sh — Provisionnement serveur Ubuntu vierge
# Déploiement IP-only (HTTPS self-signed) de l'application
# Hôpital de Kabutare.
#
# Pré-requis :
#   - Ubuntu 22.04 / 24.04 LTS
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
read -rp "[1/8] Mettre à jour le système maintenant ? [o/N] : " UPDATE_SYS
if [[ "${UPDATE_SYS,,}" == "o" ]]; then
  echo "      Mise à jour en cours..."
  apt-get update -qq
  apt-get upgrade -y -qq
  echo "      ✓ Système à jour."
else
  echo "      Mise à jour ignorée."
fi

# ── Étape 2 : Installation Docker ────────────────────────────
echo "[2/8] Vérification de Docker..."
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

# ── Étape 3 : Détection de l'IP publique ─────────────────────
echo "[3/8] Détection de l'IP publique du serveur..."
DETECTED_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
  || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
  || hostname -I | awk '{print $1}')

echo "      IP détectée : ${DETECTED_IP}"
read -rp "      Confirmer ou saisir l'IP publique [${DETECTED_IP}] : " USER_IP
SERVER_IP="${USER_IP:-${DETECTED_IP}}"
echo "      ✓ IP retenue : ${SERVER_IP}"

# ── Étape 4 : Création du fichier .env ───────────────────────
echo "[4/8] Configuration des variables d'environnement..."
if [[ -f ".env" ]]; then
  echo "      Un fichier .env existe déjà, il sera conservé."
  # S'assurer que SERVER_IP et DOCKER_USER sont à jour
  if grep -q "^SERVER_IP=" .env; then
    sed -i "s|^SERVER_IP=.*|SERVER_IP=${SERVER_IP}|" .env
  else
    echo "SERVER_IP=${SERVER_IP}" >> .env
  fi
else
  echo "      Création du fichier .env..."

  read -rp "      Docker Hub username : " DOCKER_USER_INPUT
  read -rp "      Mot de passe admin Keycloak : " -s KC_ADMIN_PASSWORD_INPUT; echo
  read -rp "      Mot de passe PostgreSQL Keycloak : " -s KC_DB_PASSWORD_INPUT; echo

  INTERNAL_SECRET_GEN=$(openssl rand -hex 32)

  cat > .env <<EOF
SERVER_IP=${SERVER_IP}
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

# ── Étape 5 : Certificat SSL self-signed ─────────────────────
echo "[5/8] Génération du certificat SSL self-signed..."
mkdir -p ssl
if [[ -f "ssl/cert.pem" && -f "ssl/key.pem" ]]; then
  echo "      Certificat existant conservé."
else
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=${SERVER_IP}" \
    -addext "subjectAltName=IP:${SERVER_IP}" \
    2>/dev/null
  chmod 600 ssl/key.pem ssl/cert.pem
  echo "      ✓ Certificat généré (valide 10 ans) : ssl/cert.pem"
fi

# ── Étape 6 : Vérification disponibilité des ports ───────────
echo "[6/8] Vérification de la disponibilité des ports..."
HTTP_PORT_CHECK="${HTTP_PORT:-80}"
HTTPS_PORT_CHECK="${HTTPS_PORT:-443}"
PORTS_OK=true

port_in_use() {
  ss -tlnH "sport = :$1" 2>/dev/null | grep -q .
}

for PORT in "${HTTP_PORT_CHECK}" "${HTTPS_PORT_CHECK}" "8080"; do
  if port_in_use "${PORT}"; then
    PROCESS=$(ss -tlnpH "sport = :${PORT}" 2>/dev/null | awk '{print $6}' | head -1)
    echo "      ✗ Port ${PORT} déjà utilisé — processus : ${PROCESS:-inconnu}"
    PORTS_OK=false
  else
    echo "      ✓ Port ${PORT} disponible."
  fi
done

if [[ "${PORTS_OK}" == "false" ]]; then
  echo ""
  echo "ERREUR : un ou plusieurs ports nécessaires sont déjà utilisés."
  echo "         Libérer ces ports avant de relancer le script."
  echo "         Diagnostic : sudo ss -tlnp | grep -E ':(${HTTP_PORT_CHECK}|${HTTPS_PORT_CHECK}|8080) '"
  exit 1
fi

# ── Étape 7 : Pull des images Docker Hub ─────────────────────
# Le build Flutter est embarqué dans l'image kabutare-nginx.
# La substitution de SERVER_IP se fait au démarrage du conteneur.
echo "[7/8] Pull des images depuis Docker Hub (${DOCKER_USER})..."
docker compose -f docker-compose.ip.yml pull nginx keycloak auth-service db-service
echo "      ✓ Images téléchargées."

# ── Étape 8 : Démarrage de la stack ──────────────────────────
echo "[8/8] Démarrage de la stack Docker Compose..."
docker compose -f docker-compose.ip.yml up -d

echo ""
echo "      Attente que Keycloak soit prêt (peut prendre 2-3 min)..."
ATTEMPTS=0
KC_READY_CHECK='exec 3<>/dev/tcp/localhost/9000 && echo -e "GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3 && cat <&3 | grep -q UP'
until docker compose -f docker-compose.ip.yml exec -T keycloak bash -c "${KC_READY_CHECK}" 2>/dev/null; do
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

# Configuration du realm Keycloak via kcadm (idempotent)
if docker compose -f docker-compose.ip.yml exec -T keycloak bash -c "${KC_READY_CHECK}" 2>/dev/null; then
  echo "      Configuration du realm via kcadm..."
  KCADM="docker compose -f docker-compose.ip.yml exec -T keycloak /opt/keycloak/bin/kcadm.sh"

  # Authentification admin
  $KCADM config credentials \
    --server "http://localhost:8080/keycloak" \
    --realm master \
    --user "${KC_ADMIN_USER}" \
    --password "${KC_ADMIN_PASSWORD}" 2>/dev/null || {
      echo "      ⚠ Realm kabutare-hospital introuvable — à créer manuellement dans l'admin Keycloak."
      echo "        Voir la section CONFIGURATION KEYCLOAK ci-dessous."
    }

  # Activation des fonctionnalités du realm (idempotent)
  $KCADM update "realms/kabutare-hospital" \
    --set "resetPasswordAllowed=true" \
    --set "verifyEmail=false" \
    --set "loginWithEmailAllowed=true" 2>/dev/null && \
  $KCADM update "realms/kabutare-hospital" \
    --set "emailTheme=kabutare" 2>/dev/null && \
    echo "      ✓ Realm kabutare-hospital configuré." || \
    echo "      ⚠ Configuration du realm ignorée (à faire manuellement)."
fi

# ── Résumé ────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo " ✓ Déploiement terminé !"
echo ""
echo " Application Flutter  : https://${SERVER_IP}/app_isis/"
echo " Admin Keycloak        : https://${SERVER_IP}/keycloak/admin/"
echo " Health auth-service   : https://${SERVER_IP}/auth/health"
echo " Health db-service     : https://${SERVER_IP}/db/health"
echo ""
echo " IMPORTANT — Le certificat est auto-signé."
echo " Le navigateur affichera un avertissement à accepter."
echo ""
echo " IMPORTANT — Configuration Keycloak requise (une seule fois) :"
echo " 1. Ouvrir https://${SERVER_IP}/keycloak/admin/"
echo " 2. Creer le realm 'kabutare-hospital' (ou importer un export)"
echo " 3. Client 'flutter-app' (public, Direct Access Grants ON)"
echo "    Redirect URI : https://${SERVER_IP}/app_isis/*"
echo "    Web origins  : https://${SERVER_IP}"
echo " 4. Client 'auth-service' (confidential, Service Accounts ON)"
echo "    Copier le client secret dans .env (KC_CLIENT_SECRET_AUTH)"
echo " 5. Roles realm : admin, supervisor, hospitalStaff,"
echo "    technician_biomedical, technician_it, technician_infra"
echo " 6. Redemarrer : docker compose -f docker-compose.ip.yml restart auth-service"
echo "========================================================"
