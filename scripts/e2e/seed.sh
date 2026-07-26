#!/usr/bin/env bash
#
# seed.sh — Seed one profile + one session into a running coqui-api (idempotent).
#
# Mirrors the request shapes the Flutter app uses (CoquiApiService):
#   createProfile  -> POST /api/v1/profiles          {"name","description?","soul?"}
#   createSession  -> POST /api/v1/sessions          {"model_role","profile?"}
#   resolveSession -> POST /api/v1/sessions/resolve   {"model_role","profile?"}
# Then confirms via GET /api/v1/profiles.
#
# Usage:  bash scripts/e2e/seed.sh
#
# Env overrides:
#   COQUI_API_PORT   Host port for coqui-api (default 3300)
#   COQUI_BASE_URL   Full base URL (default http://localhost:$COQUI_API_PORT)
#   COQUI_API_KEY    Bearer token (only if the server enforces auth; default empty)
#   PROFILE_NAME     Profile/persona name to seed (default caelum)
#   MODEL_ROLE       Session model role (default orchestrator)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Pick up the API key persisted by up.sh if not already in the environment.
if [ -z "${COQUI_API_KEY:-}" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

COQUI_API_PORT="${COQUI_API_PORT:-3300}"
BASE_URL="${COQUI_BASE_URL:-http://localhost:${COQUI_API_PORT}}"
API="${BASE_URL}/api/v1"
COQUI_API_KEY="${COQUI_API_KEY:-}"
PROFILE_NAME="${PROFILE_NAME:-caelum}"
MODEL_ROLE="${MODEL_ROLE:-orchestrator}"

log() { printf '\033[36m[e2e/seed]\033[0m %s\n' "$*"; }

# Build auth header args only when a key is configured. The app sends
# `Authorization: Bearer <key>` (CoquiApiService._headers).
AUTH=()
if [ -n "$COQUI_API_KEY" ]; then
  AUTH=(-H "Authorization: Bearer ${COQUI_API_KEY}")
fi

# api_post PATH JSON  -> prints "HTTP_STATUS<newline>BODY"
api_post() {
  local path="$1" data="$2"
  curl -sS -w $'\n%{http_code}' \
    -X POST "${API}${path}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "${AUTH[@]}" \
    -d "$data"
}

api_get() {
  local path="$1"
  curl -sS -X GET "${API}${path}" \
    -H "Accept: application/json" \
    "${AUTH[@]}"
}

# ── Preflight: server reachable? ─────────────────────────────────────────────
if ! curl -sf "${API}/health" >/dev/null 2>&1; then
  echo "ERROR: coqui-api not reachable at ${API}/health." >&2
  echo "       Run 'bash scripts/e2e/up.sh' first." >&2
  exit 1
fi

# ── 1. Create the profile (idempotent) ───────────────────────────────────────
log "Creating profile '${PROFILE_NAME}'..."
profile_payload=$(printf '{"name":"%s","description":"E2E seed persona","soul":"A calm, curious guide for end-to-end testing."}' "$PROFILE_NAME")
resp="$(api_post /profiles "$profile_payload")"
status="$(printf '%s' "$resp" | tail -n1)"
body="$(printf '%s' "$resp" | sed '$d')"

case "$status" in
  2*)
    log "Profile created (HTTP $status)."
    printf '%s\n' "$body"
    ;;
  409)
    log "Profile '${PROFILE_NAME}' already exists (HTTP 409) — continuing."
    ;;
  400|422)
    # Some servers return 400/422 with a 'already exists' style message.
    if printf '%s' "$body" | grep -qiE 'exist|duplicate|taken'; then
      log "Profile '${PROFILE_NAME}' already exists — continuing."
    else
      echo "ERROR: profile creation failed (HTTP $status):" >&2
      printf '%s\n' "$body" >&2
      exit 1
    fi
    ;;
  *)
    echo "ERROR: profile creation failed (HTTP $status):" >&2
    printf '%s\n' "$body" >&2
    exit 1
    ;;
esac

# ── 2. Create a session scoped to the profile (idempotent via resolve) ───────
# Use /sessions/resolve so re-runs reuse the latest interactive session for the
# profile scope instead of piling up new ones.
log "Resolving/creating a session for profile '${PROFILE_NAME}' (role ${MODEL_ROLE})..."
session_payload=$(printf '{"model_role":"%s","profile":"%s"}' "$MODEL_ROLE" "$PROFILE_NAME")
resp="$(api_post /sessions/resolve "$session_payload")"
status="$(printf '%s' "$resp" | tail -n1)"
body="$(printf '%s' "$resp" | sed '$d')"

if [[ "$status" == 2* ]]; then
  log "Session ready (HTTP $status)."
  printf '%s\n' "$body"
else
  echo "ERROR: session resolve failed (HTTP $status):" >&2
  printf '%s\n' "$body" >&2
  exit 1
fi

# ── 3. Confirm the seeded persona is listed ──────────────────────────────────
log "Confirming via GET /api/v1/profiles ..."
profiles="$(api_get /profiles)"
printf '%s\n' "$profiles"

if printf '%s' "$profiles" | grep -q "\"${PROFILE_NAME}\""; then
  log "OK — persona '${PROFILE_NAME}' is listed."
else
  echo "WARNING: persona '${PROFILE_NAME}' not found in GET /profiles output." >&2
  exit 1
fi

log "Seed complete. Point the app instance at: ${BASE_URL}"
