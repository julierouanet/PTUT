FROM quay.io/keycloak/keycloak:26.0

# Thèmes email personnalisés Hôpital de Kabutare
COPY themes/ /opt/keycloak/themes/

# Script de configuration du realm (kcadm — SMTP, options realm)
# --chmod=755 applique les permissions à la copie (pas de RUN chmod, Keycloak tourne non-root)
COPY --chmod=755 scripts/ /opt/keycloak/scripts/
