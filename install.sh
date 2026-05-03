#!/usr/bin/env bash
# © Frank-Christian Struve 2026 · Version 26 R3
# SpielPlaner · Erstinstallation (Dev-Pfad, lokaler Build)
#
# Ablauf:
#   1) Wenn keine .env existiert: interaktive Tech-Prompts (DB-Pass, JWT,
#      Tenant-Slug, TLS-Modus, WebPlaner ja/nein) und .env aus .env.example
#      generieren. Inhaltliche Konfig (Theatername, Admin, Firma, SMTP)
#      bleibt dem Browser-Setup-Wizard ueberlassen.
#   2) Profile aus .env-Werten zusammenbauen (webplaner, traefik).
#   3) Stack starten, auf DB warten, Migrationen, Seeds, Web hoch.
#
# ADR: docs/adr/0001-installer-architektur.md

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

prompt() {
  # prompt VAR_NAME "Frage" "default"
  local var="$1" question="$2" default="${3-}"
  local answer
  if [[ -n "$default" ]]; then
    read -r -p "  ${question} [${default}]: " answer
    eval "${var}=\"\${answer:-\$default}\""
  else
    read -r -p "  ${question}: " answer
    eval "${var}=\"\${answer}\""
  fi
}

prompt_choice() {
  # prompt_choice VAR_NAME "Frage" "default" "opt1|opt2|..."
  local var="$1" question="$2" default="$3" opts="$4"
  local answer
  while true; do
    read -r -p "  ${question} (${opts}) [${default}]: " answer
    answer="${answer:-$default}"
    if [[ "|${opts}|" == *"|${answer}|"* ]]; then
      eval "${var}=\"\${answer}\""
      break
    fi
    echo "    -> bitte eine der Optionen waehlen: ${opts}"
  done
}

gen_secret() {
  # gen_secret <bytes> hex|base64
  local bytes="$1" enc="$2"
  if [[ "$enc" == "hex" ]]; then
    openssl rand -hex "$bytes"
  else
    openssl rand -base64 "$bytes" | tr -d '\n'
  fi
}

write_env() {
  # write_env KEY VALUE   (idempotent: ersetzt bestehende Zeile, sonst anhaengen)
  local key="$1" value="$2"
  if grep -qE "^${key}=" .env 2>/dev/null; then
    # POSIX-kompatibles in-place-edit (sed -i Variante)
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' "s|^${key}=.*|${key}=${value}|" .env
    else
      sed -i "s|^${key}=.*|${key}=${value}|" .env
    fi
  else
    echo "${key}=${value}" >> .env
  fi
}

# ─────────────────────────────────────────────────────────────────────
# 1) .env aus Template generieren (nur beim ersten Lauf)
# ─────────────────────────────────────────────────────────────────────

if [[ ! -f .env ]]; then
  if [[ ! -f .env.example ]]; then
    echo "FEHLER: .env.example fehlt — Repo unvollstaendig?" >&2
    exit 1
  fi

  echo
  echo "========================================================"
  echo "  SpielPlaner — Erstinstallation"
  echo "  Es werden ein paar technische Werte abgefragt."
  echo "  Inhaltliche Konfiguration (Theatername, Admin-Account,"
  echo "  Firmendaten, SMTP) erfolgt anschliessend im Browser-"
  echo "  Setup-Wizard unter http://localhost:3000/setup"
  echo "========================================================"
  echo

  # --- Tech-Prompts ---
  prompt        DATA_ROOT          "Wo sollen Daten liegen (Hostpfad)" "./data"
  prompt        PUBLIC_TENANT_SLUG "Tenant-Slug fuer dieses Theater"   "insel"
  prompt_choice TLS_MODE           "TLS-Terminierung"                  "extern" "extern|traefik"

  TRAEFIK_DOMAIN_API=""
  TRAEFIK_DOMAIN_WEB=""
  TRAEFIK_DOMAIN_WEBPLANER=""
  TRAEFIK_LE_EMAIL=""
  if [[ "$TLS_MODE" == "traefik" ]]; then
    prompt TRAEFIK_DOMAIN_API       "Domain fuer API"               "api.spielplaner.example"
    prompt TRAEFIK_DOMAIN_WEB       "Domain fuer Suite-UI"          "app.spielplaner.example"
    prompt TRAEFIK_DOMAIN_WEBPLANER "Domain fuer oeffentliche Site" "www.example.com"
    prompt TRAEFIK_LE_EMAIL         "Mail fuer Lets-Encrypt"        ""
  fi

  prompt_choice ENABLE_WEBPLANER "WebPlaner (oeff. Theater-Website) mit installieren" "0" "0|1"

  echo
  echo "  -> Generiere Zufalls-Secrets (DB-Passwoerter, JWT, Cron-Token) ..."

  cp .env.example .env
  chmod 600 .env

  MARIADB_ROOT_PASSWORD="$(gen_secret 24 base64)"
  DB_PASSWORD="$(gen_secret 24 base64)"
  JWT_SECRET="$(gen_secret 32 hex)"
  REMINDER_CRON_TOKEN="$(gen_secret 24 hex)"

  write_env MYSQL_ROOT_PASSWORD   "$MARIADB_ROOT_PASSWORD"
  write_env MYSQL_PASSWORD        "$DB_PASSWORD"
  write_env DATABASE_URL          "mysql+asyncmy://spielplaner:${DB_PASSWORD}@db:3306/spielplaner?charset=utf8mb4"
  write_env JWT_SECRET            "$JWT_SECRET"
  write_env REMINDER_CRON_TOKEN   "$REMINDER_CRON_TOKEN"
  write_env DATA_ROOT             "$DATA_ROOT"
  write_env PUBLIC_TENANT_SLUG    "$PUBLIC_TENANT_SLUG"
  write_env ENABLE_WEBPLANER      "$ENABLE_WEBPLANER"
  write_env TLS_MODE              "$TLS_MODE"

  if [[ "$TLS_MODE" == "traefik" ]]; then
    write_env TRAEFIK_ENABLE             "true"
    write_env TRAEFIK_DOMAIN_API         "$TRAEFIK_DOMAIN_API"
    write_env TRAEFIK_DOMAIN_WEB         "$TRAEFIK_DOMAIN_WEB"
    write_env TRAEFIK_DOMAIN_WEBPLANER   "$TRAEFIK_DOMAIN_WEBPLANER"
    write_env TRAEFIK_LE_EMAIL           "$TRAEFIK_LE_EMAIL"
    # Public-URLs aus den Domains ableiten
    write_env PUBLIC_BASE_URL            "https://${TRAEFIK_DOMAIN_WEB}"
    write_env OIDC_ISSUER                "https://${TRAEFIK_DOMAIN_API}"
    write_env WEBPLANER_PUBLIC_URL       "https://${TRAEFIK_DOMAIN_WEBPLANER}"
  fi

  echo "  -> .env angelegt (chmod 600)."
  echo
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a

# ─────────────────────────────────────────────────────────────────────
# 2) Profile zusammenbauen
# ─────────────────────────────────────────────────────────────────────

PROFILES=()
[[ "${ENABLE_WEBPLANER:-0}" == "1" ]] && PROFILES+=("webplaner")
[[ "${TLS_MODE:-extern}" == "traefik" ]] && PROFILES+=("traefik")

PROFILE_FLAGS=()
for p in "${PROFILES[@]:-}"; do
  PROFILE_FLAGS+=(--profile "$p")
done

COMPOSE=(docker compose -f compose.yml --env-file .env "${PROFILE_FLAGS[@]}")

echo "==> Aktive Profile: ${PROFILES[*]:-<keine — nur Suite-Kern>}"

# ─────────────────────────────────────────────────────────────────────
# 3) Build + Start
# ─────────────────────────────────────────────────────────────────────

echo "==> Images bauen"
"${COMPOSE[@]}" build

echo "==> DB + Redis starten"
"${COMPOSE[@]}" up -d db redis

echo "==> Auf DB warten"
for i in {1..60}; do
  if "${COMPOSE[@]}" exec -T db mariadb-admin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; then
    echo "   DB bereit."
    break
  fi
  sleep 2
  [[ $i -eq 60 ]] && { echo "DB-Start fehlgeschlagen."; exit 1; }
done

echo "==> API starten"
"${COMPOSE[@]}" up -d api

echo "==> Alembic-Migrationen anwenden"
"${COMPOSE[@]}" exec -T api alembic upgrade head

echo "==> Seed-Daten (Lookups)"
"${COMPOSE[@]}" exec -T api python -m app.seeds

echo "==> Web + loffice starten"
"${COMPOSE[@]}" up -d web loffice

if [[ "${ENABLE_WEBPLANER:-0}" == "1" ]]; then
  echo "==> WebPlaner starten"
  "${COMPOSE[@]}" up -d webplaner
fi

if [[ "${TLS_MODE:-extern}" == "traefik" ]]; then
  echo "==> Traefik starten"
  "${COMPOSE[@]}" up -d traefik
fi

echo "==> Status"
"${COMPOSE[@]}" ps

cat <<EOF

========================================================
  SpielPlaner ist gestartet.

  Suite-UI :  http://localhost:3000
  API-Docs :  http://localhost:8000/docs
EOF

if [[ "${ENABLE_WEBPLANER:-0}" == "1" ]]; then
  echo "  WebPlaner:  http://localhost:3001"
fi

if [[ "${TLS_MODE:-extern}" == "traefik" ]]; then
  echo "  Traefik  :  https://${TRAEFIK_DOMAIN_WEB}  (LE-Cert kann ein paar Sekunden dauern)"
fi

cat <<EOF

  Naechster Schritt:
  -> Browser oeffnen, http://localhost:3000/setup aufrufen.
     Der Setup-Wizard fragt Theatername, Admin-Account,
     Firmendaten und (optional) SMTP ab.
========================================================
EOF
