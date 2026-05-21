FROM quay.io/keycloak/keycloak:26.0

# Ajout de curl (nécessaire pour l'API REST Keycloak dans configure-realm.sh)
# smtpServer ne peut pas être mis à jour via kcadm → on utilise l'API REST
USER root
RUN microdnf install -y curl && microdnf clean all
USER keycloak

# Thèmes email personnalisés Hôpital de Kabutare
COPY themes/ /opt/keycloak/themes/

# Script de configuration du realm
# --chmod=755 applique les permissions à la copie (Keycloak tourne non-root)
COPY --chmod=755 scripts/ /opt/keycloak/scripts/
