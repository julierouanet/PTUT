#!/usr/bin/env bash
# ============================================================
# update.sh — Mise à jour d'un déploiement IP-only déjà provisionné
# Hôpital de Kabutare — déploiement IP-only (HTTPS auto-signé)
#
# Pré-requis :
#   - Une stack déjà provisionnée via setup_ubuntu.sh (docker-compose.ip.secured.yml
#     + .env déjà présents et fonctionnels dans ce répertoire)
#   - backup.sh copié à côté de ce script :
#       scp backup.sh user@IP:~/kabutare/
#   - De nouvelles images ont été poussées sur Docker Hub (build_and_push.sh)
#
# Usage :
#   sudo bash update.sh
#
# Ce script NE régénère PAS le certificat SSL, la config Nginx, le pare-feu
# ni le fichier .env — pour un provisionnement complet ou une reconfiguration,
# utiliser setup_ubuntu.sh.
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

COMPOSE_FILE="docker-compose.ip.secured.yml"

# Demande confirmation [o/N] ; quitte avec ${2} (défaut 1) si la réponse n'est pas "o".
confirm_or_abort() {
  local prompt="$1" abort_code="${2:-1}"
  local reply
  read -rp "${prompt}" reply
  if [[ "${reply,,}" != "o" ]]; then
    echo "      Mise à jour annulée."
    exit "${abort_code}"
  fi
}

echo ""
echo "========================================================"
echo " Mise à jour — Hôpital de Kabutare — déploiement IP-only"
echo "========================================================"
echo ""

# ── Pré-requis : déploiement déjà provisionné ─────────────────
if [[ ! -f "${COMPOSE_FILE}" || ! -f .env ]]; then
  echo "✗ Aucun déploiement détecté (${COMPOSE_FILE} ou .env manquant)." >&2
  echo "  Utiliser setup_ubuntu.sh pour un provisionnement initial." >&2
  exit 1
fi

if ! docker compose -f "${COMPOSE_FILE}" ps --quiet 2>/dev/null | grep -q .; then
  echo "✗ Aucun conteneur actif détecté — la stack ne semble pas démarrée." >&2
  echo "  docker compose -f ${COMPOSE_FILE} ps" >&2
  echo "  Utiliser setup_ubuntu.sh pour (re)provisionner la stack." >&2
  exit 1
fi

# Charger les variables depuis .env
set -a; source .env; set +a

# Défauts identiques à setup_ubuntu.sh — ces 3 variables ne sont écrites dans
# .env que si un port était occupé lors du provisionnement initial (sinon absentes).
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
KC_HOST_PORT="${KC_HOST_PORT:-8080}"

# ── Étape 1/5 : Backup automatique ────────────────────────────
echo "[1/5] Backup automatique avant mise à jour..."
if [[ ! -f "${SCRIPT_DIR}/backup.sh" ]]; then
  echo "      ⚠ backup.sh introuvable dans ${SCRIPT_DIR}."
  echo "        Le copier depuis la machine de dev : scp backup.sh user@IP:~/kabutare/"
  confirm_or_abort "      Continuer la mise à jour SANS backup ? [o/N] : "
else
  if bash "${SCRIPT_DIR}/backup.sh"; then
    echo "      ✓ Backup effectué."
  else
    echo "      ⚠ backup.sh a signalé une erreur (voir la sortie ci-dessus)."
    confirm_or_abort "      Continuer la mise à jour SANS backup valide ? [o/N] : "
  fi
fi
echo ""

# ── Étape 2/5 : Confirmation ───────────────────────────────────
echo "[2/5] Images à mettre à jour :"
echo "      - ${DOCKER_USER:-<DOCKER_USER>}/kabutare-nginx:latest"
echo "      - ${DOCKER_USER:-<DOCKER_USER>}/kabutare-keycloak:latest"
echo "      - ${DOCKER_USER:-<DOCKER_USER>}/kabutare-auth-service:latest"
echo "      - ${DOCKER_USER:-<DOCKER_USER>}/kabutare-db-service:latest"
echo ""
echo "      La mise à jour redémarre les services dont l'image a changé"
echo "      (coupure de service estimée : 1 à 2 minutes)."
echo ""
confirm_or_abort "      Continuer la mise à jour ? [o/N] : " 0
echo ""

# ── Étape 3/5 : Pull des images Docker Hub ────────────────────
echo "[3/5] Pull des images depuis Docker Hub..."
# DOCKER_CONTENT_TRUST=1 : refuse les images non signées (protection supply chain)
DOCKER_CONTENT_TRUST=1 docker compose -f "${COMPOSE_FILE}" pull nginx keycloak auth-service db-service
echo "      ✓ Images téléchargées."
echo ""

# ── Étape 4/5 : Redémarrage de la stack ───────────────────────
echo "[4/5] Redémarrage de la stack Docker Compose..."
# `|| true` : empêche set -euo pipefail de planter le script si un service
# n'est pas encore healthy au moment où compose up rend la main.
docker compose -f "${COMPOSE_FILE}" up -d || true
echo ""

FAILED_SERVICES=()

# Attend qu'un conteneur soit "healthy", ${2} tentatives × 5s.
# En cas de timeout : avertit, signale l'échec via le code de retour et rend
# la main (pas d'exit) pour ne pas bloquer l'attente des autres conteneurs.
wait_healthy() {
  local container="$1" max_attempts="$2" service="$3"
  echo -n "      Attente que ${container} soit prêt... "
  local attempts=0
  until [[ "$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null)" == "healthy" ]]; do
    attempts=$((attempts + 1))
    if [[ ${attempts} -gt ${max_attempts} ]]; then
      echo ""
      echo "      ⚠ ${container} n'est pas healthy après $((max_attempts * 5 / 60)) min."
      echo "        Logs : docker compose -f ${COMPOSE_FILE} logs --tail=50 ${service}"
      FAILED_SERVICES+=("${service}")
      return 1
    fi
    printf "."
    sleep 5
  done
  echo " ✓"
}

wait_healthy "nginx-ip"        12 "nginx"        || true
wait_healthy "auth-service-ip" 12 "auth-service" || true
wait_healthy "db-service-ip"   12 "db-service"   || true
KEYCLOAK_HEALTHY=true
wait_healthy "keycloak-ip"     48 "keycloak"     || KEYCLOAK_HEALTHY=false
echo ""

# ── Étape 5/5 : Re-synchronisation Keycloak ───────────────────
echo "[5/5] Re-synchronisation des rôles et permissions Keycloak..."
if [[ "${KEYCLOAK_HEALTHY}" == "true" ]]; then
  # Préfixe commun réutilisé pour la connexion et pour $KCADM (rôles/permissions)
  KC_EXEC=(docker compose -f "${COMPOSE_FILE}" exec -T)
  KCADM="${KC_EXEC[*]} keycloak /opt/keycloak/bin/kcadm.sh"

  # CRIT-3 : mot de passe passé via -e (variable d'env dans le conteneur),
  # jamais en argument CLI — évite l'exposition dans `ps aux` / /proc/<pid>/cmdline
  if "${KC_EXEC[@]}" \
      -e KCADM_PASS="${KC_ADMIN_PASSWORD}" \
      -e KCADM_USER="${KC_ADMIN_USER}" \
      keycloak sh -c \
      '/opt/keycloak/bin/kcadm.sh config credentials \
       --server http://localhost:8080/keycloak \
       --realm master \
       --user "$KCADM_USER" \
       --password "$KCADM_PASS"' 2>/dev/null; then

    # Rôles realm
    for ROLE in admin supervisor hospitalStaff technician_biomedical technician_it technician_infra; do
      $KCADM create roles -r kabutare-hospital -s name="${ROLE}" 2>/dev/null || true
    done
    echo "      ✓ Rôles realm re-synchronisés."

    # Permissions Admin API du service account auth-service
    for KC_SVC_ROLE in manage-users manage-realm query-realms view-users query-users; do
      $KCADM add-roles \
        -r kabutare-hospital \
        --uusername service-account-auth-service \
        --cclientid realm-management \
        --rolename "${KC_SVC_ROLE}" 2>/dev/null \
        && echo "      ✓ ${KC_SVC_ROLE} assigné au service account auth-service." \
        || echo "      ⚠ ${KC_SVC_ROLE} déjà assigné ou client non trouvé."
    done
  else
    echo "      ⚠ Authentification Keycloak échouée — re-synchronisation ignorée."
  fi
else
  echo "      ⚠ Ignoré — keycloak-ip n'est pas healthy (voir avertissement ci-dessus)."
fi
echo ""

# ── Résumé ──────────────────────────────────────────────────────
echo "========================================================"
if [[ ${#FAILED_SERVICES[@]} -eq 0 ]]; then
  echo " ✓ Mise à jour terminée — tous les services sont healthy."
else
  echo " ⚠ Mise à jour terminée avec ${#FAILED_SERVICES[@]} service(s) en échec de healthcheck :"
  for S in "${FAILED_SERVICES[@]}"; do
    echo "   - ${S}"
  done
fi
echo ""
echo " Application Flutter : ${KC_PUBLIC_URL:-<KC_PUBLIC_URL non défini>}/app_isis/"
echo ""
if [[ ${#FAILED_SERVICES[@]} -gt 0 ]]; then
  echo " ── Procédure de rollback manuelle ──────────────────────"
  echo " 1. Retagger l'ancienne image (si son digest a été noté avant l'update) :"
  echo "    docker tag <ancien_digest_ou_tag> <user>/kabutare-<service>:latest"
  echo "    docker compose -f ${COMPOSE_FILE} up -d <service>"
  echo " 2. Ou restaurer le dernier backup (créé à l'étape 1/5 dans"
  echo "    ${SCRIPT_DIR}/backups/) via :"
  echo "    sudo bash setup_ubuntu.sh   → choisir l'option 2 (Restaurer un backup)"
  echo ""
fi
echo "========================================================"
echo ""
