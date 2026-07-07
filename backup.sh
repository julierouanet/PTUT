#!/usr/bin/env bash
# ============================================================
# backup.sh — Sauvegarde des bases de données
# Hôpital de Kabutare — déploiement IP-only
#
# Usage :
#   sudo bash backup.sh               # sauvegarde complète
#   sudo bash backup.sh --auth        # auth.db uniquement
#   sudo bash backup.sh --hospital    # hospital.db uniquement
#   sudo bash backup.sh --keycloak    # PostgreSQL Keycloak uniquement
#   sudo bash backup.sh --keep 7      # fenêtre "derniers jours" (défaut : 7)
#
# Les fichiers sont créés dans ./backups/ (ignoré par git).
# Pour restaurer, utiliser setup_ubuntu.sh (option 2)
# ou les commandes manuelles affichées en fin de script.
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
BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +%Y%m%d_%H%M)
KEEP_DAYS=7

# ── Analyse des arguments ─────────────────────────────────────
DO_AUTH=false
DO_HOSPITAL=false
DO_KEYCLOAK=false
DO_ALL=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auth)      DO_AUTH=true;     DO_ALL=false ;;
    --hospital)  DO_HOSPITAL=true; DO_ALL=false ;;
    --keycloak)  DO_KEYCLOAK=true; DO_ALL=false ;;
    --keep)      shift; KEEP_DAYS="${1:-7}"     ;;
    *) echo "Option inconnue : $1" >&2; exit 1  ;;
  esac
  shift
done

if [[ "${DO_ALL}" == "true" ]]; then
  DO_AUTH=true
  DO_HOSPITAL=true
  DO_KEYCLOAK=true
fi

# ── Préparation du dossier backup ────────────────────────────
mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"   # accessible uniquement par root

echo ""
echo "========================================================"
echo " Backup — Hôpital de Kabutare — ${DATE}"
echo " Destination : ${BACKUP_DIR}"
echo "========================================================"
echo ""

ERRORS=0
BACKED_UP=()

# ── Vérification que la stack tourne ─────────────────────────
if ! docker compose -f "${COMPOSE_FILE}" ps --quiet 2>/dev/null | grep -q .; then
  echo "⚠ Aucun conteneur actif détecté — vérifier que la stack est démarrée."
  echo "  docker compose -f ${COMPOSE_FILE} ps"
  exit 1
fi

# ── Backup auth.db (SQLite — auth-service) ───────────────────
if [[ "${DO_AUTH}" == "true" ]]; then
  echo "── [1/3] auth.db (permissions applicatives) ──────────────"
  DEST="${BACKUP_DIR}/auth_${DATE}.db"
  if docker cp auth-service-ip:/data/auth.db "${DEST}" 2>/dev/null; then
    chmod 600 "${DEST}"
    SIZE=$(du -sh "${DEST}" | cut -f1)
    echo "   ✓ auth_${DATE}.db — ${SIZE}"
    BACKED_UP+=("auth_${DATE}.db")
  else
    echo "   ✗ Échec — conteneur auth-service-ip introuvable ou /data/auth.db absent."
    ERRORS=$((ERRORS + 1))
  fi
  echo ""
fi

# ── Backup hospital.db (SQLite — db-service) ─────────────────
if [[ "${DO_HOSPITAL}" == "true" ]]; then
  echo "── [2/3] hospital.db (équipements, incidents) ────────────"
  DEST="${BACKUP_DIR}/hospital_${DATE}.db"
  if docker cp db-service-ip:/data/hospital.db "${DEST}" 2>/dev/null; then
    chmod 600 "${DEST}"
    SIZE=$(du -sh "${DEST}" | cut -f1)
    echo "   ✓ hospital_${DATE}.db — ${SIZE}"
    BACKED_UP+=("hospital_${DATE}.db")
  else
    echo "   ✗ Échec — conteneur db-service-ip introuvable ou /data/hospital.db absent."
    ERRORS=$((ERRORS + 1))
  fi
  echo ""
fi

# ── Backup PostgreSQL Keycloak (pg_dump) ──────────────────────
if [[ "${DO_KEYCLOAK}" == "true" ]]; then
  echo "── [3/3] Keycloak PostgreSQL (utilisateurs, realm) ───────"
  DEST="${BACKUP_DIR}/keycloak_${DATE}.sql"
  if docker exec postgres-keycloak-ip \
      pg_dump -U keycloak keycloak > "${DEST}" 2>/dev/null; then
    chmod 600 "${DEST}"
    SIZE=$(du -sh "${DEST}" | cut -f1)
    echo "   ✓ keycloak_${DATE}.sql — ${SIZE}"
    BACKED_UP+=("keycloak_${DATE}.sql")
  else
    echo "   ✗ Échec — conteneur postgres-keycloak-ip introuvable."
    ERRORS=$((ERRORS + 1))
    rm -f "${DEST}"   # supprimer le fichier vide/partiel
  fi
  echo ""
fi

# ── Rotation automatique (${KEEP_DAYS}j glissants + 1 backup/mois) ────
# La date de chaque fichier est TOUJOURS extraite de son NOM (jamais de
# mtime — non fiable après un docker cp ou sur un volume monté).
echo "── Rotation : ${KEEP_DAYS} derniers jours + 1 backup/mois ────"
DELETED=0

rotate_pattern() {
  local pattern="$1"
  local -a files=()
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    files+=("${f}")
  done < <(find "${BACKUP_DIR}" -maxdepth 1 -name "${pattern}" 2>/dev/null | sort)

  # 0 ou 1 fichier : rien à faire.
  [[ ${#files[@]} -le 1 ]] && return

  # Comparaison sur la date seule (chaîne YYYYMMDD), jamais sur l'heure —
  # un seul appel à `date` au lieu d'un par fichier.
  local cutoff_ymd
  cutoff_ymd=$(date -d "-${KEEP_DAYS} days" +%Y%m%d)

  declare -A month_seen
  local f base datepart key

  # Les fichiers sont triés par ordre alphabétique == ordre chronologique
  # (format YYYYMMDD_HHMM) : le premier vu dans un mois est le plus ancien.
  for f in "${files[@]}"; do
    base="${f##*/}"
    datepart=$(echo "${base}" | grep -oE '[0-9]{8}_[0-9]{4}' | cut -d'_' -f1) || true
    if [[ -z "${datepart}" ]]; then
      echo "   ⚠ Nom de fichier non conforme ignoré : ${base}"
      continue
    fi

    # Fenêtre des ${KEEP_DAYS} derniers jours : conservé inconditionnellement.
    if (( 10#${datepart} >= 10#${cutoff_ymd} )); then
      continue
    fi

    key="${datepart:0:4}-${datepart:4:2}"
    if [[ -z "${month_seen[${key}]:-}" ]]; then
      month_seen[${key}]=1   # plus ancien du mois : conservé
    else
      if rm -f "${f}"; then
        echo "   🗑 Supprimé (mensuel, doublon de ${key}) : ${base}"
        DELETED=$((DELETED + 1))
      else
        echo "   ⚠ Échec suppression : ${base}"
      fi
    fi
  done
}

for PATTERN in "auth_*.db" "hospital_*.db" "keycloak_*.sql"; do
  rotate_pattern "${PATTERN}"
done
[[ ${DELETED} -eq 0 ]] && echo "   Aucun fichier supprimé."
echo ""

# ── Résumé ───────────────────────────────────────────────────
echo "========================================================"
if [[ ${ERRORS} -eq 0 ]]; then
  echo " ✓ Backup terminé — ${#BACKED_UP[@]} fichier(s) sauvegardé(s)"
else
  echo " ⚠ Backup terminé avec ${ERRORS} erreur(s)"
fi
echo ""
echo " Fichiers dans ${BACKUP_DIR}/ :"
ls -lh "${BACKUP_DIR}/" 2>/dev/null | tail -n +2 | awk '{print "   " $5 "  " $9}'
echo ""

# ── Commandes de restauration ─────────────────────────────────
if [[ ${#BACKED_UP[@]} -gt 0 ]]; then
  echo " Pour restaurer ces backups :"
  echo ""
  for F in "${BACKED_UP[@]}"; do
    if [[ "${F}" == auth_* ]]; then
      echo "   # auth.db :"
      echo "   sudo docker compose -f ${COMPOSE_FILE} stop db-service auth-service"
      echo "   sudo docker cp ${BACKUP_DIR}/${F} auth-service-ip:/data/auth.db"
      echo "   sudo docker compose -f ${COMPOSE_FILE} start auth-service db-service"
    elif [[ "${F}" == hospital_* ]]; then
      echo "   # hospital.db :"
      echo "   sudo docker compose -f ${COMPOSE_FILE} stop db-service"
      echo "   sudo docker cp ${BACKUP_DIR}/${F} db-service-ip:/data/hospital.db"
      echo "   sudo docker compose -f ${COMPOSE_FILE} start db-service"
    elif [[ "${F}" == keycloak_* ]]; then
      echo "   # Keycloak PostgreSQL :"
      echo "   sudo docker compose -f ${COMPOSE_FILE} stop keycloak"
      echo "   sudo docker exec postgres-keycloak-ip psql -U keycloak -c 'DROP DATABASE IF EXISTS keycloak;'"
      echo "   sudo docker exec postgres-keycloak-ip psql -U keycloak -c 'CREATE DATABASE keycloak OWNER keycloak;'"
      echo "   sudo docker exec -i postgres-keycloak-ip psql -U keycloak -d keycloak < ${BACKUP_DIR}/${F}"
      echo "   sudo docker compose -f ${COMPOSE_FILE} start keycloak"
    fi
    echo ""
  done
  echo " Ou via setup_ubuntu.sh → option 2 (détection automatique dans backups/)."
fi
echo "========================================================"
echo ""

exit ${ERRORS}
