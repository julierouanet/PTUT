FROM quay.io/keycloak/keycloak:26.0

# Thèmes email personnalisés Hôpital de Kabutare
COPY themes/ /opt/keycloak/themes/

# Scripts de configuration du realm (kcadm : options realm + thème)
# --chmod=755 : permissions à la copie (ubi9-micro n'a pas de package manager)
COPY --chmod=755 scripts/ /opt/keycloak/scripts/
