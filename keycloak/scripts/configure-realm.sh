#!/bin/bash
# ── Configuration du realm kabutare-hospital via kcadm ──────────────────────
# Idempotent : peut être relancé sans risque après chaque déploiement.
# Variables attendues dans l'environnement du conteneur keycloak-prod :
#   KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD,
#   BREVO_SMTP_HOST, BREVO_SMTP_PORT, BREVO_SMTP_LOGIN, BREVO_SMTP_PASSWORD,
#   BREVO_FROM_EMAIL, BREVO_FROM_NAME
set -e

# KC_HTTP_PORT=8081 en dev, 8080 en prod (injecté par docker-compose)
KC_URL="http://localhost:${KC_HTTP_PORT:-8080}"
REALM="kabutare-hospital"
KCADM="/opt/keycloak/bin/kcadm.sh"

echo "[KC-SETUP] Vérification que Keycloak est prêt..."
until bash -c "exec 3<>/dev/tcp/localhost/${KC_HTTP_PORT:-8080} 2>/dev/null" 2>/dev/null; do
  echo "[KC-SETUP] Port ${KC_HTTP_PORT:-8080} pas encore ouvert, attente 5s..."
  sleep 5
done
echo "[KC-SETUP] Keycloak répond, démarrage de la configuration."

echo "[KC-SETUP] Authentification admin..."
${KCADM} config credentials \
  --server "${KC_URL}" \
  --realm master \
  --user "${KEYCLOAK_ADMIN}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD}"

# NOTE : la configuration SMTP (smtpServer) est faite via l'API REST dans le Jenkinsfile
# kcadm ne supporte pas la mise à jour des champs Map<String,String> imbriqués
# L'image ubi9-micro n'ayant pas de package manager, curl ne peut pas être installé ici

echo "[KC-SETUP] Activation Forgot Password + Verify Email..."
${KCADM} update realms/${REALM} \
  --set "resetPasswordAllowed=true" \
  --set "verifyEmail=false" \
  --set "loginWithEmailAllowed=true"

echo "[KC-SETUP] Application du thème email kabutare..."
${KCADM} update realms/${REALM} \
  --set "emailTheme=kabutare"

echo "[KC-SETUP] Terminé — realm ${REALM} configuré."
