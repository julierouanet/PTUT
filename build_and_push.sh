#!/usr/bin/env bash
# ============================================================
# build_and_push.sh — Build et push des images Docker sur Hub
# À exécuter sur la machine du développeur (Linux, Mac, WSL).
# Usage : ./build_and_push.sh [DOCKER_USER]
#
# Images produites :
#   <user>/kabutare-auth-service:latest
#   <user>/kabutare-db-service:latest
#   <user>/kabutare-keycloak:latest
#   <user>/kabutare-nginx:latest  (inclut le build Flutter)
#
# Le build Flutter utilise l'image Docker cirruslabs/flutter
# — aucune installation locale de Flutter n'est requise.
# Les URLs Flutter contiennent le placeholder __SERVER_IP__,
# remplacé au démarrage du conteneur Nginx par $SERVER_IP.
# ============================================================
set -euo pipefail

DOCKER_USER="${1:-${DOCKER_USER:-}}"
if [[ -z "$DOCKER_USER" ]]; then
  read -rp "Docker Hub username : " DOCKER_USER
fi

TAG="latest"
AUTH_IMAGE="${DOCKER_USER}/kabutare-auth-service:${TAG}"
DB_IMAGE="${DOCKER_USER}/kabutare-db-service:${TAG}"
KC_IMAGE="${DOCKER_USER}/kabutare-keycloak:${TAG}"
NGINX_IMAGE="${DOCKER_USER}/kabutare-nginx:${TAG}"

FLUTTER_IMAGE="ghcr.io/cirruslabs/flutter:3.41.4"

echo ""
echo "========================================================"
echo " Images à builder et pusher :"
echo "  - ${AUTH_IMAGE}"
echo "  - ${DB_IMAGE}"
echo "  - ${KC_IMAGE}"
echo "  - ${NGINX_IMAGE}  (Flutter + Nginx)"
echo "========================================================"
echo ""

# ── Connexion Docker Hub ──────────────────────────────────────
echo "[0/6] Connexion à Docker Hub..."
docker login

# ── Étape 1 : Build Flutter web (placeholder IP) ─────────────
echo "[1/6] Build Flutter web (placeholder __SERVER_IP__)..."
echo "      Utilisation de l'image Docker Flutter : ${FLUTTER_IMAGE}"

# pub get
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)/flutter-app:/app" \
  -e PUB_CACHE=/app/.pub-cache \
  -w /app \
  "${FLUTTER_IMAGE}" \
  flutter pub get

# build web SANS --dart-define d'URL → détection automatique au runtime via Uri.base.
# Cela permet au même build de fonctionner depuis le WiFi de l'hôpital (IP locale)
# ET depuis internet (IP publique), sans recompilation.
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)/flutter-app:/app" \
  -e PUB_CACHE=/app/.pub-cache \
  -w /app \
  "${FLUTTER_IMAGE}" \
  flutter build web --release \
    --base-href /app_isis/

echo "      ✓ Flutter buildé dans flutter-app/build/web/"

# ── Étape 2 : Build auth-service ─────────────────────────────
echo "[2/6] Build auth-service..."
docker build \
  --platform linux/amd64 \
  -t "${AUTH_IMAGE}" \
  ./auth-service

docker push "${AUTH_IMAGE}"
echo "      ✓ ${AUTH_IMAGE} poussé."

# ── Étape 3 : Build db-service ───────────────────────────────
echo "[3/6] Build db-service..."
docker build \
  --platform linux/amd64 \
  -t "${DB_IMAGE}" \
  ./db-service

docker push "${DB_IMAGE}"
echo "      ✓ ${DB_IMAGE} poussé."

# ── Étape 4 : Build Keycloak (thèmes email personnalisés) ─────
echo "[4/6] Build Keycloak..."
docker build \
  --platform linux/amd64 \
  -t "${KC_IMAGE}" \
  ./keycloak

docker push "${KC_IMAGE}"
echo "      ✓ ${KC_IMAGE} poussé."

# ── Étape 5 : Build image Nginx + Flutter ────────────────────
echo "[5/6] Build image Nginx + Flutter..."
docker build \
  --platform linux/amd64 \
  -f Dockerfile.nginx \
  -t "${NGINX_IMAGE}" \
  .

docker push "${NGINX_IMAGE}"
echo "      ✓ ${NGINX_IMAGE} poussé."

echo ""
echo "========================================================"
echo " Toutes les images sont disponibles sur Docker Hub."
echo ""
echo " Prochaine étape : copier sur le serveur Ubuntu :"
echo "   scp setup_ubuntu.sh docker-compose.ip.yml user@SERVER_IP:~/kabutare/"
echo " Puis exécuter :"
echo "   sudo bash setup_ubuntu.sh"
echo "========================================================"
