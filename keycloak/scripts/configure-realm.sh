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
until bash -c "exec 3<>/dev/tcp/localhost/8081 2>/dev/null" 2>/dev/null; do
  echo "[KC-SETUP] Port 8081 pas encore ouvert, attente 5s..."
  sleep 5
done
echo "[KC-SETUP] Keycloak répond, démarrage de la configuration."

echo "[KC-SETUP] Authentification admin..."
${KCADM} config credentials \
  --server "${KC_URL}" \
  --realm master \
  --user "${KEYCLOAK_ADMIN}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD}"

echo "[KC-SETUP] Configuration SMTP Brevo sur le realm ${REALM}..."
# kcadm ne supporte pas la mise à jour de smtpServer (Map imbriquée) → API REST directe

# Obtenir un token admin
KC_TOKEN=$(curl -sf -X POST "${KC_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&username=${KEYCLOAK_ADMIN}&password=${KEYCLOAK_ADMIN_PASSWORD}&grant_type=password" \
  | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "${KC_TOKEN}" ]; then
  echo "[KC-SETUP] ERREUR : impossible d'obtenir le token admin"
  exit 1
fi

# Mettre à jour smtpServer via l'API REST
curl -sf -X PUT "${KC_URL}/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${KC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"smtpServer\": {
      \"host\":            \"${BREVO_SMTP_HOST}\",
      \"port\":            \"${BREVO_SMTP_PORT}\",
      \"from\":            \"${BREVO_FROM_EMAIL}\",
      \"fromDisplayName\": \"${BREVO_FROM_NAME}\",
      \"replyTo\":         \"${BREVO_FROM_EMAIL}\",
      \"auth\":            \"true\",
      \"starttls\":        \"true\",
      \"ssl\":             \"false\",
      \"user\":            \"${BREVO_SMTP_LOGIN}\",
      \"password\":        \"${BREVO_SMTP_PASSWORD}\"
    }
  }"
echo "[KC-SETUP] SMTP configuré."

echo "[KC-SETUP] Activation Forgot Password + Verify Email..."
${KCADM} update realms/${REALM} \
  --set "resetPasswordAllowed=true" \
  --set "verifyEmail=false" \
  --set "loginWithEmailAllowed=true"

echo "[KC-SETUP] Application du thème email kabutare..."
${KCADM} update realms/${REALM} \
  --set "emailTheme=kabutare"

echo "[KC-SETUP] Terminé — realm ${REALM} configuré."
