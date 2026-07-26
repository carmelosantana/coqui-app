# Coqui E2E Harness

Docker + Ollama harness that stands up a real `coqui-api` backend so the Flutter
app can be exercised end-to-end against a local instance.

## Prerequisites

- Docker (with `docker compose`) available and running.
- The Core backend checkout at `/home/carmelo/Projects/CoquiBot/Core/coqui`
  (override with `CORE=/path/to/Core/coqui`).
- Enough disk for the `ollama/ollama` image and the `llama3.2:1b` model.

## Run

```bash
# 1. Bring up Ollama + coqui-api and wait for health.
bash scripts/e2e/up.sh

# 2. Seed one profile + one session and confirm it is listed.
bash scripts/e2e/seed.sh
```

## What each script does

### `up.sh` (idempotent)
1. Resolves an API key: reuses `$COQUI_API_KEY` / `scripts/e2e/.env`, else
   generates one and writes it to `scripts/e2e/.env` (gitignored) so `seed.sh`
   reuses it. A key is mandatory because the API server refuses to bind to a
   network address without one.
2. Ensures the `coqui-ollama` container is running — starts it if stopped,
   creates it (port `11434`, volume `ollama`) if absent.
3. Ensures the `llama3.2:1b` model is present, pulling it only if missing.
4. Builds + starts `coqui-api` on `:3300` via
   `docker compose -f "$CORE/compose.yaml" -f "$CORE/compose.api.yaml" up -d coqui-api`
   (image builds on first run — allow several minutes).
5. Polls `GET http://localhost:3300/api/v1/health`, prints
   `coqui-api ready at http://localhost:3300` and the Ollama version.

Useful env overrides: `CORE`, `OLLAMA_HOST`, `COQUI_API_PORT`, `OLLAMA_MODEL`,
`COQUI_API_KEY`.

#### Known Core issue + fallback

The current Core `compose.api.yaml` ships a `command:`
(`["./bin/coqui", "--api-only", ...]`) that is malformed for the present CLI:
the Dockerfile `ENTRYPOINT` is already `["./bin/coqui"]`, so Docker runs
`./bin/coqui ./bin/coqui --api-only ...` and the binary reports
`Command "./bin/coqui" is not defined.` The correct subcommand is `api`.
Until Core is fixed, if the compose service does not become healthy, `up.sh`
automatically relaunches the **same freshly-built `coqui:dev` image** with the
corrected invocation (`./bin/coqui api --host 0.0.0.0 --port 3300 --workspace
/app/workspace`, with the generated key), reusing the compose `coqui` network
and `coqui_workspace` volume. **Recommended Core fix** in `compose.api.yaml`:

```yaml
    command: ["api", "--host", "0.0.0.0", "--port", "3300", "--workspace", "/app/workspace"]
```

Once Core is fixed the compose path succeeds directly and the fallback is a
no-op.

### `seed.sh` (idempotent)
Creates one persona and one session through the same API routes the Flutter app
uses (`CoquiApiService`), then confirms:

- `POST /api/v1/profiles` — `{"name","description","soul"}` (default name `caelum`).
  "Already exists" responses (HTTP 409, or 4xx with an existing/duplicate
  message) are treated as success.
- `POST /api/v1/sessions/resolve` — `{"model_role","profile"}`. Resolve is used
  instead of plain `POST /sessions` so re-runs reuse the profile's latest
  interactive session rather than creating duplicates.
- `GET /api/v1/profiles` — prints the list and verifies the seeded persona is
  present.

Useful env overrides: `COQUI_BASE_URL`, `COQUI_API_PORT`, `COQUI_API_KEY`,
`PROFILE_NAME`, `MODEL_ROLE`.

## Auth

The API server requires a key when bound to a network address, so `up.sh`
always provisions one and persists it to `scripts/e2e/.env`. `seed.sh` loads
that file automatically and sends `Authorization: Bearer <key>` (the header the
app's `CoquiApiService` uses). To pin your own key instead:

```bash
export COQUI_API_KEY=your-key
bash scripts/e2e/up.sh
bash scripts/e2e/seed.sh
```

When configuring the Flutter app to talk to this instance, use the same key
(printed in `scripts/e2e/.env`).

## Point the app at the instance

In the Flutter app, configure the Coqui instance base URL to:

```
http://localhost:3300
```

`CoquiApiService` prepends `/api/v1` automatically, so use the bare origin (no
`/api/v1` suffix). Leave the API key blank unless the backend was started with
`COQUI_API_KEY` set.

## Results

_Task 26 fills this in with the results of an actual end-to-end app run against
the seeded instance._

### Harness bring-up (Task 25 — verified 2026-07-25)

- Ollama container: reused running `coqui-ollama` on `:11434`
  (ollama version 0.32.1).
- `coqui:dev` image: built successfully via the Core compose files.
- `coqui-api` health (`GET /api/v1/health`): **reachable, HTTP 200**
  (via the corrected-launch fallback — see "Known Core issue" above; the
  compose service itself failed with `Command "./bin/coqui" is not defined.`).
- Profile seeded: `caelum` created (HTTP 201) and confirmed in
  `GET /api/v1/profiles` (`count: 1`). Session resolved (HTTP 201).
- Idempotency: re-running `seed.sh` returns HTTP 409 for the profile (handled)
  and reuses the session (HTTP 200); exit 0.
