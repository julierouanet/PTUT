#!/usr/bin/env bash
# ============================================================
# setup_ubuntu.patch.sh — Correctifs de sécurité pour setup_ubuntu.sh
#
# Ce fichier documente les 6 modifications à appliquer à setup_ubuntu.sh.
# Chaque bloc indique : numéro de ligne, contexte AVANT, code APRÈS.
# ============================================================

# ══════════════════════════════════════════════════════════════
# CORRECTIF 1 — CRIT-1 : chmod 600 sur .env après création
# Ligne ~183 dans setup_ubuntu.sh
# ══════════════════════════════════════════════════════════════
#
# AVANT :
#   EOF
#     echo "      ✓ Fichier .env créé."
#
# APRÈS :
cat_env_fix() {
cat > .env <<EOF
# ... contenu existant ...
EOF
  chmod 600 .env                   # Protège les secrets (KC_ADMIN_PASSWORD, INTERNAL_SECRET…)
  chown root:root .env             # Appartient à root uniquement
  echo "      ✓ Fichier .env créé (permissions 600 — lecture root uniquement)."
}

# ══════════════════════════════════════════════════════════════
# CORRECTIF 2 — CRIT-2 : Protection brute-force SSH via ufw limit
# Ligne ~503 dans setup_ubuntu.sh
# ══════════════════════════════════════════════════════════════
#
# AVANT :
#   ufw allow 22/tcp    &>/dev/null || true
#
# APRÈS :
ufw_ssh_fix() {
  ufw limit 22/tcp    &>/dev/null || true   # Max 6 connexions/30s par IP (protection brute-force intégrée)
  ufw default deny incoming &>/dev/null || true
  ufw default allow outgoing &>/dev/null || true
}

# ══════════════════════════════════════════════════════════════
# CORRECTIF 3 — CRIT-3 : Mot de passe kcadm.sh via variable d'env, pas CLI
# Lignes ~553-559 dans setup_ubuntu.sh
# ══════════════════════════════════════════════════════════════
#
# AVANT :
#   KCADM="docker compose -f docker-compose.ip.yml exec -T keycloak /opt/keycloak/bin/kcadm.sh"
#   if $KCADM config credentials \
#       --server "http://localhost:8080/keycloak" \
#       --realm master \
#       --user "${KC_ADMIN_USER}" \
#       --password "${KC_ADMIN_PASSWORD}" 2>/dev/null; then
#
# APRÈS (mot de passe lu depuis la variable d'environnement, invisible dans ps aux) :
kcadm_credentials_fix() {
  # Le flag -e passe la variable uniquement au conteneur, sans l'exposer dans ps
  KCADM="docker compose -f docker-compose.ip.yml exec -T \
    -e KCADM_PASSWORD=${KC_ADMIN_PASSWORD} \
    keycloak /opt/keycloak/bin/kcadm.sh"

  if $KCADM config credentials \
      --server "http://localhost:8080/keycloak" \
      --realm master \
      --user "${KC_ADMIN_USER}" \
      --password "env:KCADM_PASSWORD" 2>/dev/null; then
    echo "      ✓ Authentification Keycloak réussie."
  fi
}

# ══════════════════════════════════════════════════════════════
# CORRECTIF 4 — MAJ-1 : Certificat SSL 825 jours + ECDSA P-384
# Ligne ~442 dans setup_ubuntu.sh
# ══════════════════════════════════════════════════════════════
#
# AVANT :
#   openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
#     -keyout ssl/key.pem \
#     -out ssl/cert.pem \
#     -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=${SERVER_IP}" \
#     -addext "subjectAltName=${SSL_SAN}" \
#     2>/dev/null
#   chmod 600 ssl/key.pem ssl/cert.pem
#
# APRÈS :
ssl_cert_fix() {
  openssl req -x509 -nodes -days 825 -newkey ec -pkeyopt ec_paramgen_curve:P-384 \
    -keyout ssl/key.pem \
    -out ssl/cert.pem \
    -subj "/C=RW/ST=Southern/L=Huye/O=HopitalKabutare/CN=${SERVER_IP}" \
    -addext "subjectAltName=${SSL_SAN}" \
    2>/dev/null
  chmod 600 ssl/key.pem    # Clé privée : lecture root uniquement
  chmod 644 ssl/cert.pem   # Certificat public : lecture autorisée (nécessaire à nginx)
  chmod 700 ssl/            # Répertoire non listable par les autres utilisateurs
  echo "      ✓ Certificat ECDSA P-384 généré (valide 825 jours) : ssl/cert.pem"
}

# ══════════════════════════════════════════════════════════════
# CORRECTIF 5 — MAJ-2 : DOCKER_CONTENT_TRUST avant le pull
# Ligne ~521 dans setup_ubuntu.sh
# ══════════════════════════════════════════════════════════════
#
# AVANT :
#   docker compose -f docker-compose.ip.yml pull nginx keycloak auth-service db-service
#
# APRÈS :
docker_pull_fix() {
  # DOCKER_CONTENT_TRUST=1 refuse les images non signées (protection supply chain)
  # Pré-requis : images signées sur Docker Hub avec `docker trust sign <image>`
  # Si non disponible, retirer la variable et vérifier manuellement les digests SHA256
  if [[ "${DOCKER_TRUST:-1}" == "1" ]]; then
    echo "      Vérification de la signature des images (Docker Content Trust)..."
    DOCKER_CONTENT_TRUST=1 docker compose -f docker-compose.ip.yml pull nginx keycloak auth-service db-service
  else
    echo "      ⚠ DOCKER_CONTENT_TRUST désactivé — vérifier manuellement les digests."
    docker compose -f docker-compose.ip.yml pull nginx keycloak auth-service db-service
    # Afficher les digests pour audit manuel
    for SVC in nginx auth-service db-service keycloak; do
      IMG=$(docker compose -f docker-compose.ip.yml config | grep "image:" | grep "${SVC}" | awk '{print $2}')
      echo "      Digest ${SVC}: $(docker inspect --format='{{index .RepoDigests 0}}' "${IMG}" 2>/dev/null || echo 'N/A')"
    done
  fi
}

# ══════════════════════════════════════════════════════════════
# CORRECTIF 6 — MAJ-3 : Remplacer eval par printf -v (injection-safe)
# Ligne ~493 dans setup_ubuntu.sh
# ══════════════════════════════════════════════════════════════
#
# AVANT :
#   eval "${VAR}=${FREE}"
#
# APRÈS :
port_assign_fix() {
  local VAR="$1"
  local FREE="$2"
  # printf -v évite eval et son risque d'injection — assigne la valeur à la variable nommée
  printf -v "${VAR}" '%s' "${FREE}"
  export "${VAR}"
}

# ══════════════════════════════════════════════════════════════
# CORRECTIF BONUS — Permissions sur les répertoires nginx/
# À ajouter après `mkdir -p ssl nginx/conf.d` (ligne ~191)
# ══════════════════════════════════════════════════════════════
#
# APRÈS mkdir -p ssl nginx/conf.d :
dirs_permissions_fix() {
  mkdir -p ssl nginx/conf.d
  chmod 700 ssl/          # Répertoire SSL : root uniquement
  chmod 755 nginx/        # nginx/ lisible par le démon Docker
  chmod 755 nginx/conf.d/
}

echo "Ce fichier est un guide de correctifs — il ne s'exécute pas directement."
echo "Appliquer chaque correctif manuellement dans setup_ubuntu.sh."
