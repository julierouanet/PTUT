#!/usr/bin/env bash
# ============================================================
# reset.sh — Nettoyage complet pour retester setup_ubuntu.sh
# Usage : sudo bash reset.sh
# ============================================================
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "Erreur : ce script doit être exécuté avec sudo." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo ""
echo "========================================================"
echo " Reset déploiement Hôpital de Kabutare"
echo "========================================================"
echo ""

# ── Arrêt et suppression de la stack Docker ───────────────────
echo "[1/3] Arrêt et suppression de la stack Docker Compose..."
if docker compose -f docker-compose.ip.secured.yml ps -q 2>/dev/null | grep -q .; then
  docker compose -f docker-compose.ip.secured.yml down -v --remove-orphans 2>/dev/null && \
    echo "      ✓ Containers, volumes et réseau supprimés." || \
    echo "      ⚠ Erreur lors du down (stack peut-être déjà arrêtée)."
else
  # Tenter quand même le down au cas où des volumes résiduels existent
  docker compose -f docker-compose.ip.secured.yml down -v --remove-orphans 2>/dev/null || true
  echo "      Aucun container actif trouvé — nettoyage des volumes résiduels effectué."
fi

# ── Suppression des fichiers générés ─────────────────────────
echo "[2/3] Suppression des fichiers générés..."

if [[ -f ".env" ]]; then
  rm -f .env
  echo "      ✓ .env supprimé."
else
  echo "      .env absent — ignoré."
fi

if [[ -d "ssl" ]]; then
  rm -rf ssl
  echo "      ✓ ssl/ supprimé."
else
  echo "      ssl/ absent — ignoré."
fi

if [[ -d "nginx" ]]; then
  rm -rf nginx
  echo "      ✓ nginx/ supprimé."
else
  echo "      nginx/ absent — ignoré."
fi

# ── Résumé ────────────────────────────────────────────────────
echo "[3/3] Vérification..."
echo ""
echo "      Containers actifs liés au projet :"
docker ps --filter name="-ip" --format "      - {{.Names}} ({{.Status}})" 2>/dev/null || true
echo ""
echo "========================================================"
echo " ✓ Reset terminé. Vous pouvez relancer :"
echo "   sudo bash setup_ubuntu.sh"
echo "========================================================"
echo ""
