#!/usr/bin/env bash
# ============================================================
# import_inventory.sh — Import de l'inventaire physique XLSX
# Hôpital de Kabutare — déploiement IP-only
#
# Usage :
#   sudo bash import_inventory.sh <fichier.xlsx>
#   sudo bash import_inventory.sh <fichier.xlsx> --dry-run
#   sudo bash import_inventory.sh <fichier.xlsx> --insert-only
#
# Options :
#   --dry-run      Parse et valide le XLSX sans écrire en base
#   --insert-only  N'écrase pas les équipements existants
#
# Source de données attendue :
#   Feuille "Equipment Migration Template" — 339 équipements
#   Feuille "Standard_Departments"        — liste des départements
#   Feuille "Standard_Equipment_Names"    — liste des noms standard
#
# Normalisation automatique des statuts :
#   operational / Operational / opeational → operational
#   UNDER M / UNDERM                       → under_maintenance
#   IDDLE / iddle / IDDLE GO TO RBC        → idle
#   To be disposal / to be disposal        → to_be_disposed
#   DISPOSED                               → disposed
#   KIBIRIZI DH                            → transferred
#
# Normalisation automatique des départements :
#   Internal medicine → Internal Medicine
#   surgery / Surgery → Surgery
#   obstetrics and gynecology (variantes) → Obstetrics and Gynecology
# ============================================================
set -euo pipefail
export LC_ALL=C.UTF-8

# ── Vérification root ─────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  echo "Erreur : ce script doit être exécuté avec sudo." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

COMPOSE_FILE="docker-compose.ip.secured.yml"
CONTAINER="db-service-ip"
XLSX_DEST="/tmp/inventory_import.xlsx"
DRY_RUN=false
INSERT_ONLY=false
XLSX_FILE=""

# ── Analyse des arguments ─────────────────────────────────────
for ARG in "$@"; do
  case "${ARG}" in
    --dry-run)     DRY_RUN=true     ;;
    --insert-only) INSERT_ONLY=true ;;
    --*)
      echo "Option inconnue : ${ARG}" >&2
      echo "Usage : sudo bash import_inventory.sh <fichier.xlsx> [--dry-run] [--insert-only]" >&2
      exit 1
      ;;
    *)
      XLSX_FILE="${ARG}"
      ;;
  esac
done

# ── Vérification du fichier XLSX ──────────────────────────────
if [[ -z "${XLSX_FILE}" ]]; then
  echo "Erreur : fichier XLSX manquant." >&2
  echo ""
  echo "Usage : sudo bash import_inventory.sh <fichier.xlsx> [--dry-run] [--insert-only]"
  echo ""
  echo "Exemples :"
  echo "  sudo bash import_inventory.sh '/chemin/INVENTORY 2025-2026.xlsx'"
  echo "  sudo bash import_inventory.sh '/chemin/INVENTORY 2025-2026.xlsx' --dry-run"
  echo "  sudo bash import_inventory.sh '/chemin/INVENTORY 2025-2026.xlsx' --insert-only"
  exit 1
fi

if [[ ! -f "${XLSX_FILE}" ]]; then
  echo "Erreur : fichier introuvable : ${XLSX_FILE}" >&2
  exit 1
fi

# ── Vérification que la stack tourne ─────────────────────────
echo ""
echo "========================================================"
echo " Import inventaire — Hôpital de Kabutare"
echo " Fichier : $(basename "${XLSX_FILE}")"
[[ "${DRY_RUN}" == "true" ]]    && echo " Mode    : DRY-RUN (aucune écriture en base)"
[[ "${INSERT_ONLY}" == "true" ]] && echo " Mode    : INSERT-ONLY (pas d'écrasement)"
echo "========================================================"
echo ""

echo "── [1/4] Vérification du conteneur db-service ────────────"
if ! docker compose -f "${COMPOSE_FILE}" ps --quiet "${CONTAINER##*-ip}" 2>/dev/null | grep -q .; then
  # Essaie aussi avec le nom complet du conteneur
  if ! docker inspect "${CONTAINER}" &>/dev/null; then
    echo "   ✗ Conteneur ${CONTAINER} introuvable."
    echo "     Démarrer la stack : sudo docker compose -f ${COMPOSE_FILE} up -d"
    exit 1
  fi
fi

STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER}" 2>/dev/null || echo "absent")
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER}" 2>/dev/null || echo "N/A")
echo "   État   : ${STATUS}"
echo "   Santé  : ${HEALTH}"

if [[ "${STATUS}" != "running" ]]; then
  echo "   ✗ Le conteneur doit être en cours d'exécution (running)."
  exit 1
fi

if [[ "${HEALTH}" == "unhealthy" ]]; then
  echo "   ⚠ Le service est unhealthy — l'import peut échouer."
  read -rp "   Continuer quand même ? [o/N] : " CONT
  [[ "${CONT,,}" != "o" ]] && exit 0
fi
echo "   ✓ Conteneur prêt."
echo ""

# ── Vérification que le script d'import existe ────────────────
echo "── [2/4] Vérification du script d'import ─────────────────"
if ! docker exec "${CONTAINER}" test -f /app/scripts/import_inventory.js 2>/dev/null; then
  echo "   ✗ Script /app/scripts/import_inventory.js absent du conteneur."
  echo "     L'image doit être reconstruite avec le dossier scripts/ inclus."
  echo "     Vérifier le Dockerfile de db-service : COPY scripts/ ./scripts/"
  exit 1
fi
echo "   ✓ Script d'import présent."
echo ""

# ── Copie du fichier XLSX dans le conteneur ───────────────────
echo "── [3/4] Copie du fichier XLSX dans le conteneur ─────────"
FILESIZE=$(du -sh "${XLSX_FILE}" | cut -f1)
echo "   Taille : ${FILESIZE}"

if docker cp "${XLSX_FILE}" "${CONTAINER}:${XLSX_DEST}" 2>/dev/null; then
  echo "   ✓ Fichier copié → ${XLSX_DEST}"
else
  echo "   ✗ Échec de la copie du fichier."
  exit 1
fi
echo ""

# ── Exécution de l'import ─────────────────────────────────────
echo "── [4/4] Exécution de l'import ───────────────────────────"
echo ""

# Construction de la commande
IMPORT_CMD="node scripts/import_inventory.js --xlsx ${XLSX_DEST}"
[[ "${DRY_RUN}" == "true" ]]    && IMPORT_CMD="${IMPORT_CMD} --dry-run"
[[ "${INSERT_ONLY}" == "true" ]] && IMPORT_CMD="${IMPORT_CMD} --insert-only"

echo "   Commande : ${IMPORT_CMD}"
echo "   (Normalisation statuts + départements automatique)"
echo ""

if docker exec -w /app "${CONTAINER}" sh -c "${IMPORT_CMD}"; then
  echo ""
  echo "========================================================"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo " ✓ DRY-RUN terminé — aucune écriture effectuée."
    echo ""
    echo " Pour importer réellement :"
    echo "   sudo bash import_inventory.sh '${XLSX_FILE}'"
  else
    echo " ✓ Import terminé avec succès."
    echo ""
    echo " Pour vérifier les données importées :"
    echo "   docker exec ${CONTAINER} sqlite3 /data/hospital.db \\"
    echo "     'SELECT COUNT(*) as total FROM equipment;'"
    echo "   docker exec ${CONTAINER} sqlite3 /data/hospital.db \\"
    echo "     'SELECT department_id, COUNT(*) as nb FROM equipment GROUP BY department_id ORDER BY nb DESC;'"
    echo ""
    echo " Pour faire un backup après import :"
    echo "   sudo bash backup.sh --hospital"
  fi
  echo "========================================================"
else
  EXIT_CODE=$?
  echo ""
  echo "========================================================"
  echo " ✗ Import échoué (code: ${EXIT_CODE})"
  echo ""
  echo " Diagnostics :"
  echo "   docker logs ${CONTAINER} --tail 30"
  echo "   docker exec ${CONTAINER} node scripts/import_inventory.js --xlsx ${XLSX_DEST} --dry-run"
  echo "========================================================"
  # Nettoyage du fichier temporaire
  docker exec "${CONTAINER}" rm -f "${XLSX_DEST}" 2>/dev/null || true
  exit "${EXIT_CODE}"
fi

# ── Nettoyage du fichier temporaire ──────────────────────────
docker exec "${CONTAINER}" rm -f "${XLSX_DEST}" 2>/dev/null || true
