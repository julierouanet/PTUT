#!/bin/sh
# ── Substitution du placeholder IP dans les JS compilés Flutter ──────────────
# Ce script est exécuté par le mécanisme /docker-entrypoint.d/ de l'image
# nginx officielle, avant le démarrage de nginx.
#
# Variable attendue : SERVER_IP (ex: 203.0.113.42)
# Action : remplace toutes les occurrences de __SERVER_IP__ dans les fichiers
#          *.js du build Flutter par la valeur de $SERVER_IP.
# ─────────────────────────────────────────────────────────────────────────────
set -e

if [ -z "${SERVER_IP}" ]; then
    printf '[nginx-ip] AVERTISSEMENT : SERVER_IP non défini — URLs Flutter non substituées.\n' >&2
    exit 0
fi

printf '[nginx-ip] Substitution __SERVER_IP__ → %s dans les JS Flutter...\n' "${SERVER_IP}"

find /usr/share/nginx/html -name '*.js' \
    -exec sed -i "s|__SERVER_IP__|${SERVER_IP}|g" {} \;

printf '[nginx-ip] ✓ Substitution terminée.\n'
