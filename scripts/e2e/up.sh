#!/usr/bin/env bash
#
# up.sh — Bring up the Coqui E2E backend harness (idempotent).
#
# 1. Ensures an Ollama container is running and the model is present.
# 2. Builds the coqui-api image via the Core compose files.
# 3. Starts coqui-api on :3300 and waits for it to report healthy.
#
# NOTE on the coqui-api launch:
#   The documented invocation is
#     docker compose -f "$CORE/compose.yaml" -f "$CORE/compose.api.yaml" up -d coqui-api
#   That path is attempted first. However the current Core `compose.api.yaml`
#   ships a `command: ["./bin/coqui", "--api-only", ...]` that is malformed for
#   the present CLI: the Dockerfile ENTRYPOINT is already `["./bin/coqui"]`, so
#   Docker runs `./bin/coqui ./bin/coqui --api-only ...` and the binary reports
#   `Command "./bin/coqui" is not defined.` The real subcommand is `api`, and
#   binding to a network address additionally requires COQUI_API_KEY.
#   Until Core is fixed, if the compose service does not become healthy this
#   script falls back to a corrected `docker run` of the same freshly-built
#   image (subcommand `api`, generated key), sharing the same network/volume.
#
# Usage:  bash scripts/e2e/up.sh
#
# Env overrides:
#   CORE            Path to the Core/coqui checkout
#   OLLAMA_HOST     Ollama URL the API container should reach
#   COQUI_API_PORT  Host port for coqui-api (default 3300)
#   OLLAMA_MODEL    Model to ensure present (default llama3.2:1b)
#   COQUI_API_KEY   API key (auto-generated + persisted if unset)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

CORE="${CORE:-/home/carmelo/Projects/CoquiBot/Core/coqui}"
OLLAMA_HOST="${OLLAMA_HOST:-http://host.docker.internal:11434}"
COQUI_API_PORT="${COQUI_API_PORT:-3300}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:1b}"
OLLAMA_CONTAINER="coqui-ollama"
API_CONTAINER="coqui-api"
COMPOSE_NETWORK="coqui"
WORKSPACE_VOLUME="coqui_workspace"
HEALTH_URL="http://localhost:${COQUI_API_PORT}/api/v1/health"

log() { printf '\033[36m[e2e/up]\033[0m %s\n' "$*"; }

wait_health() {
  # $1 = attempts
  local attempts="$1"
  for _ in $(seq 1 "$attempts"); do
    if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# ── 0. Resolve / persist an API key ──────────────────────────────────────────
# The API server refuses to bind to a network address without a key, so one is
# always needed. Reuse an existing value; otherwise generate and persist it so
# seed.sh (a separate invocation) uses the same key.
if [ -z "${COQUI_API_KEY:-}" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi
if [ -z "${COQUI_API_KEY:-}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    COQUI_API_KEY="e2e-$(openssl rand -hex 12)"
  else
    COQUI_API_KEY="e2e-$(date +%s)-$RANDOM"
  fi
  log "Generated COQUI_API_KEY and wrote it to ${ENV_FILE}"
fi
printf 'COQUI_API_KEY=%s\n' "$COQUI_API_KEY" > "$ENV_FILE"
export COQUI_API_KEY

# ── 1. Ensure the Ollama container is running ────────────────────────────────
if docker ps --format '{{.Names}}' | grep -qx "$OLLAMA_CONTAINER"; then
  log "Ollama container '$OLLAMA_CONTAINER' already running."
elif docker ps -a --format '{{.Names}}' | grep -qx "$OLLAMA_CONTAINER"; then
  log "Starting existing Ollama container '$OLLAMA_CONTAINER'."
  docker start "$OLLAMA_CONTAINER" >/dev/null
else
  log "Creating Ollama container '$OLLAMA_CONTAINER'."
  docker run -d --name "$OLLAMA_CONTAINER" \
    -p 11434:11434 \
    -v ollama:/root/.ollama \
    ollama/ollama >/dev/null
fi

log "Waiting for Ollama daemon..."
for _ in $(seq 1 30); do
  docker exec "$OLLAMA_CONTAINER" ollama list >/dev/null 2>&1 && break
  sleep 1
done

# ── 2. Ensure the model is present (pull only if absent) ─────────────────────
if docker exec "$OLLAMA_CONTAINER" ollama list | grep -q "$OLLAMA_MODEL"; then
  log "Model '$OLLAMA_MODEL' already present."
else
  log "Pulling model '$OLLAMA_MODEL' (this may take a while)..."
  docker exec "$OLLAMA_CONTAINER" ollama pull "$OLLAMA_MODEL"
fi

# ── 3. Build + start coqui-api ───────────────────────────────────────────────
if [ ! -f "$CORE/compose.yaml" ] || [ ! -f "$CORE/compose.api.yaml" ]; then
  echo "ERROR: Core compose files not found under '$CORE'." >&2
  echo "       Set CORE=/path/to/Core/coqui and retry." >&2
  exit 1
fi

COMPOSE=(docker compose -f "$CORE/compose.yaml" -f "$CORE/compose.api.yaml")

log "Building coqui-api image (first build may take several minutes)..."
OLLAMA_HOST="$OLLAMA_HOST" COQUI_API_PORT="$COQUI_API_PORT" "${COMPOSE[@]}" build coqui-api

log "Starting coqui-api via docker compose..."
OLLAMA_HOST="$OLLAMA_HOST" COQUI_API_PORT="$COQUI_API_PORT" "${COMPOSE[@]}" up -d coqui-api || true

log "Waiting for coqui-api health at $HEALTH_URL ..."
if wait_health 20; then
  echo "coqui-api ready at http://localhost:${COQUI_API_PORT}"
else
  # Fallback: the compose service did not come up healthy (known malformed
  # command in Core compose.api.yaml). Relaunch the same built image with the
  # corrected invocation, sharing the compose network + workspace volume.
  log "compose coqui-api not healthy; applying corrected launch (see header note)."
  log "  cause: $("${COMPOSE[@]}" logs --tail 3 coqui-api 2>/dev/null | tr -d '\r' | grep -m1 -i 'not defined\|error\|api key' || echo 'see docker logs coqui-api')"

  docker rm -f "$API_CONTAINER" >/dev/null 2>&1 || true
  docker run -d --name "$API_CONTAINER" \
    --network "$COMPOSE_NETWORK" \
    --add-host host.docker.internal:host-gateway \
    -e OLLAMA_HOST="$OLLAMA_HOST" \
    -e COQUI_API_KEY="$COQUI_API_KEY" \
    -p "${COQUI_API_PORT}:3300" \
    -v "${WORKSPACE_VOLUME}:/app/workspace" \
    --entrypoint ./bin/coqui \
    coqui:dev api --host 0.0.0.0 --port 3300 --workspace /app/workspace >/dev/null

  log "Waiting for coqui-api health (corrected launch)..."
  if wait_health 60; then
    echo "coqui-api ready at http://localhost:${COQUI_API_PORT}"
  else
    echo "ERROR: coqui-api did not become healthy. Recent logs:" >&2
    docker logs --tail 40 "$API_CONTAINER" >&2 || true
    exit 1
  fi
fi

# ── 4. Report ────────────────────────────────────────────────────────────────
ollama_version="$(docker exec "$OLLAMA_CONTAINER" ollama --version 2>/dev/null | head -n1 || echo 'unknown')"
log "Ollama: ${ollama_version}"
log "API key persisted to ${ENV_FILE} (used automatically by seed.sh)."
