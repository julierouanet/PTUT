FROM quay.io/keycloak/keycloak:26.0

# Thèmes email personnalisés Hôpital de Kabutare
COPY themes/ /opt/keycloak/themes/

# Script de configuration du realm (kcadm — SMTP, options realm)
COPY scripts/ /opt/keycloak/scripts/
RUN chmod +x /opt/keycloak/scripts/configure-realm.sh
