#!/bin/bash
# ── Configuration du realm kabutare-hospital via kcadm ──────────────────────
# Idempotent : peut être relancé sans risque après chaque déploiement.
# Variables attendues dans l'environnement du conteneur keycloak-prod :
#   KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD,
#   BREVO_SMTP_HOST, BREVO_SMTP_PORT, BREVO_SMTP_LOGIN, BREVO_SMTP_PASSWORD,
#   BREVO_FROM_EMAIL, BREVO_FROM_NAME
set -e

KC_URL="http://localhost:8080"
REALM="kabutare-hospital"
KCADM="/opt/keycloak/bin/kcadm.sh"

echo "[KC-SETUP] Attente que Keycloak soit prêt..."
until curl -sf "${KC_URL}/health/ready" > /dev/null; do
  sleep 5
done

echo "[KC-SETUP] Authentification admin..."
${KCADM} config credentials \
  --server "${KC_URL}" \
  --realm master \
  --user "${KEYCLOAK_ADMIN}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD}"

echo "[KC-SETUP] Configuration SMTP Brevo sur le realm ${REALM}..."
${KCADM} update realms/${REALM} \
  --set "smtpServer.host=${BREVO_SMTP_HOST}" \
  --set "smtpServer.port=${BREVO_SMTP_PORT}" \
  --set "smtpServer.from=${BREVO_FROM_EMAIL}" \
  --set "smtpServer.fromDisplayName=${BREVO_FROM_NAME}" \
  --set "smtpServer.replyTo=${BREVO_FROM_EMAIL}" \
  --set "smtpServer.auth=true" \
  --set "smtpServer.starttls=true" \
  --set "smtpServer.ssl=false" \
  --set "smtpServer.user=${BREVO_SMTP_LOGIN}" \
  --set "smtpServer.password=${BREVO_SMTP_PASSWORD}"

echo "[KC-SETUP] Activation Forgot Password + Verify Email..."
${KCADM} update realms/${REALM} \
  --set "resetPasswordAllowed=true" \
  --set "verifyEmail=false" \
  --set "loginWithEmailAllowed=true"

echo "[KC-SETUP] Application du thème email kabutare..."
${KCADM} update realms/${REALM} \
  --set "emailTheme=kabutare"

echo "[KC-SETUP] Terminé — realm ${REALM} configuré."
