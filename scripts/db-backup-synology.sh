#!/usr/bin/env bash
# © Frank-Christian Struve 2026 · Version 26 R3
# SpielPlaner — Synology-spezifisches DB-Backup
#
# Verwendung: als „Geplante Aufgabe → Benutzerdefiniertes Script"
# im DSM Aufgaben-Planer, taeglich nachts. User: root (DSM-Default).
#
# Voraussetzung: Container "spielplaner-db-1" laeuft, MARIADB_ROOT_PASSWORD
# in dessen Environment ist gesetzt.
#
# Default-Ziel: /volume1/spielplaner_dev/backups/db/daily/db-YYYY-MM-DDTHHMMSS.sql.gz
# Retention: 30 Tage daily, monatliche Kopie behalten 12 Monate.
#
# Unterschied zu scripts/db-backup.sh:
#   - Nutzt /usr/local/bin/docker exec direkt (kein „docker compose")
#   - Liest MARIADB_ROOT_PASSWORD aus der Container-ENV, NICHT aus der
#     Repo-.env (die ist auf Synology nur fuer root lesbar)
#   - Schreibt Log nach /volume1/spielplaner_dev/backups/db/backup.log
#
# Manuelle Pruefung:
#   sudo /usr/local/bin/bash /volume1/spielplaner_dev/spielplaner/scripts/db-backup-synology.sh

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/volume1/spielplaner_dev/backups/db}"
DAILY_DIR="${BACKUP_ROOT}/daily"
MONTHLY_DIR="${BACKUP_ROOT}/monthly"
LOG_FILE="${BACKUP_ROOT}/backup.log"
DOCKER_BIN="${DOCKER_BIN:-/usr/local/bin/docker}"
CONTAINER="${DB_CONTAINER:-spielplaner-db-1}"

RETENTION_DAILY="${BACKUP_RETENTION_DAILY:-30}"
RETENTION_MONTHLY="${BACKUP_RETENTION_MONTHLY:-12}"

mkdir -p "${DAILY_DIR}" "${MONTHLY_DIR}"

log() {
  printf '[%s] %s\n' "$(date +%FT%T%z)" "$*" | tee -a "${LOG_FILE}" >&2
}

TS="$(date +%Y-%m-%dT%H%M%S)"
TARGET="${DAILY_DIR}/db-${TS}.sql.gz"

log "Start backup → ${TARGET}"

if ! "${DOCKER_BIN}" ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
  log "ERROR: Container ${CONTAINER} nicht aktiv"
  exit 2
fi

# Dump in den Container, gzip + Datei auf Host
set +e
"${DOCKER_BIN}" exec -i "${CONTAINER}" sh -c '
  mariadb-dump --user=root --password=$MARIADB_ROOT_PASSWORD \
    --single-transaction --quick --routines --triggers --events \
    --default-character-set=utf8mb4 \
    $MARIADB_DATABASE
' | gzip -9 > "${TARGET}"
PIPESTATUS_COPY=("${PIPESTATUS[@]}")
set -e

if [[ "${PIPESTATUS_COPY[0]}" -ne 0 ]]; then
  log "ERROR: mariadb-dump fehlgeschlagen (rc=${PIPESTATUS_COPY[0]})"
  rm -f "${TARGET}"
  exit 3
fi

if [[ ! -s "${TARGET}" ]]; then
  log "ERROR: Backup-Datei leer"
  rm -f "${TARGET}"
  exit 4
fi

# Integritaets-Check des gzip
if ! gunzip -t "${TARGET}" 2>/dev/null; then
  log "ERROR: gzip-Integritaetspruefung fehlgeschlagen"
  rm -f "${TARGET}"
  exit 5
fi

SIZE_KB=$(du -k "${TARGET}" | cut -f1)
log "OK ${SIZE_KB} KiB"

# Monthly-Snapshot: am 1. des Monats Hardlink in monthly/
DAY_OF_MONTH="$(date +%d)"
if [[ "${DAY_OF_MONTH}" == "01" ]]; then
  MONTH_TS="$(date +%Y-%m)"
  MONTHLY_TARGET="${MONTHLY_DIR}/db-${MONTH_TS}.sql.gz"
  if [[ ! -f "${MONTHLY_TARGET}" ]]; then
    ln "${TARGET}" "${MONTHLY_TARGET}" 2>/dev/null || cp "${TARGET}" "${MONTHLY_TARGET}"
    log "Monthly snapshot → ${MONTHLY_TARGET}"
  fi
fi

# Retention daily
find "${DAILY_DIR}" -name 'db-*.sql.gz' -type f -mtime "+${RETENTION_DAILY}" -delete 2>/dev/null || true
# Retention monthly (12 Monate ~ 365 Tage)
find "${MONTHLY_DIR}" -name 'db-*.sql.gz' -type f -mtime "+$((RETENTION_MONTHLY * 31))" -delete 2>/dev/null || true

log "Done. Retention: ${RETENTION_DAILY}d daily, ${RETENTION_MONTHLY}m monthly"
