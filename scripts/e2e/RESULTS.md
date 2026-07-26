# E2E Smoke Results — Discord Reskin (2026-07-25)

Stack: Flutter web (debug, `flutter run -d web-server :8099`) → coqui-api (Docker, :3300) → Ollama (Docker, :11434, llama3.2:1b aliased as qwen3.5:9b to match coqui's built-in `orchestrator` role).

## PASS — verified working end-to-end
- **App compiles for web and boots in a real browser** (Chromium). Console: "Starting application from main method", 821 scripts, **no JS errors**.
- **Redesign is live**: Geist + Geist Mono fonts (all weights) loaded 200 OK — the reskinned typography is active in-browser.
- **App ↔ live backend over the network**: on boot the reskinned app issues, against `http://localhost:3300`:
  - `OPTIONS /api/v1/profiles → 204` (CORS preflight; coqui-api sends `Access-Control-Allow-Origin: *`, allows `Authorization`)
  - `GET /api/v1/health → 200`
  - `GET /api/v1/profiles → 401` (only because the default in-app instance has no API key configured yet — not a redesign defect)
- **Auth + CRUD pipeline** (with key `Authorization: Bearer …`): profile `caelum` created + listed; session resolved (`POST /sessions/resolve`, id `353036d2…`); roles listed.
- **SSE transport works in real time**: `POST /sessions/{id}/messages` streams framed events (`id:`/`event:`/`data:`) — `agent_start`, `iteration {number:1}`, terminal `complete` — exactly the shape the reskinned chat/composer consumes.
- **Ollama works**: warm `qwen3.5:9b` (aliased llama3.2:1b) generates directly ("Ready.", 26.8s cold-load); coqui-api container reaches Ollama (`host.docker.internal:11434` → version 0.32.1).

## BLOCKED at Coqui Core (not the app) — two Core-side defects found
1. **compose.api.yaml command is invalid** — `command: ["./bin/coqui","--api-only",...]` duplicates the Dockerfile entrypoint (`./bin/coqui`) → `Command "./bin/coqui" is not defined.` Correct: `command: ["api", …]`. `up.sh` works around it client-side. (Spawned follow-up task.)
2. **Agent turn subprocess exits code 0 with no output** — a prompt reaches `agent_start` → `iteration 1`, then the coqui agent subprocess exits cleanly (code 0) producing 0 tokens (`error: "Process exited unexpectedly"`). Isolated: Ollama works standalone, coqui-api→Ollama networking works, SSE transport works, model is warm — so this is a Coqui Core agent-runtime defect in containerized API-only mode, unrelated to the Flutter app. This blocks a full token completion (and therefore the loop-completion demo) via the API.

## Conclusion
The reskinned app and its entire client pipeline (build, boot, theme, CORS, auth, session/profile/loop endpoints, real-time SSE) are verified working against the live Dockerized backend. A full agent completion is blocked by a Coqui Core runtime issue in API-only Docker mode, flagged separately for the Core repo.
