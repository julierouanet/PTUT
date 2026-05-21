#!/usr/bin/env bash
# ============================================================
# build_and_push.sh — Build et push des images Docker sur Hub
# À exécuter sur la machine du développeur (Linux, Mac, WSL).
# Usage : ./build_and_push.sh [DOCKER_USER]
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

echo ""
echo "========================================================"
echo " Images à builder et pusher :"
echo "  - ${AUTH_IMAGE}"
echo "  - ${DB_IMAGE}"
echo "  - ${KC_IMAGE}"
echo "========================================================"
echo ""

# ── Connexion Docker Hub ──────────────────────────────────────
echo "[1/4] Connexion à Docker Hub..."
docker login

# ── Build auth-service ────────────────────────────────────────
echo "[2/4] Build auth-service..."
docker build \
  --platform linux/amd64 \
  -t "${AUTH_IMAGE}" \
  ./auth-service

docker push "${AUTH_IMAGE}"
echo "      ✓ ${AUTH_IMAGE} poussé."

# ── Build db-service ──────────────────────────────────────────
echo "[3/4] Build db-service..."
docker build \
  --platform linux/amd64 \
  -t "${DB_IMAGE}" \
  ./db-service

docker push "${DB_IMAGE}"
echo "      ✓ ${DB_IMAGE} poussé."

# ── Build Keycloak (thèmes email personnalisés) ───────────────
echo "[4/4] Build Keycloak..."
docker build \
  --platform linux/amd64 \
  -t "${KC_IMAGE}" \
  ./keycloak

docker push "${KC_IMAGE}"
echo "      ✓ ${KC_IMAGE} poussé."

echo ""
echo "========================================================"
echo " Toutes les images sont disponibles sur Docker Hub."
echo " Prochaine étape : exécuter setup_ubuntu.sh sur le"
echo " serveur Ubuntu cible."
echo "========================================================"
