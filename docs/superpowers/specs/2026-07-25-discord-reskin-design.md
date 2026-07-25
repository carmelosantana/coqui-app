# Coqui App — Discord Reskin & Reshell: Design Spec

- **Date:** 2026-07-25
- **Status:** Approved (brainstorming) — pending implementation plan
- **Repo:** `carmelosantana/coqui-app` — branch `feat/discord-redesign`
- **Design direction:** "1a — Habitat" (Discord-inspired, Coqui identity, dark-first)
- **Source of truth for tokens:** `docs/Flutter app Discord redesign/coqui-design-spec.json` (+ screenshots, `.dc.html` mockups)

## 1. Goal & scope

Reskin and reshell the existing Coqui Flutter client into a Discord-style interface,
**reusing the current state layer** (Provider), API service, models, and streaming.
The design spec's own recommendation is followed: *"Refactor the navigation shell over the
existing providers/streaming; do not rewrite."*

Decisions locked during brainstorming:

| Decision | Choice |
| --- | --- |
| Scope | **Reskin + reshell** over existing providers (no state-management rewrite) |
| Dropped features | **Delete entirely** (code, providers, services, models, tests) |
| E2E verification | **Local Docker stack** (`compose.api.yaml`) **+ Ollama in Docker**, app points at it |
| Primary build/verify target | **Web / Chrome** (desktop/mobile are follow-ons) |
| Version control | Git reconnected to `carmelosantana/coqui-app`; work on `feat/discord-redesign`; identity `Carmelo Santana <me@carmelosantana.com>` |

### Non-goals

- No migration off `provider`.
- No change to the Coqui core API contract (the app already targets it).
- Linux-desktop and Android targets are not required for sign-off (they need
  system packages / Android SDK that can't be installed unattended here). They remain buildable
  later; nothing in this work should break them.

## 2. Environment (verified)

- Flutter **3.44.8** stable / Dart **3.12.2** installed at `~/flutter`.
- `flutter doctor`: Chrome web ✓; Linux desktop ✗ (needs `clang cmake ninja libgtk-3-dev`, sudo-gated);
  Android ✗ (no SDK). Web + `flutter test` is the sign-off path.
- Docker present; `compose.api.yaml` runs `coqui-api` on `:3300` and is already Ollama-aware
  via `OLLAMA_HOST` (`http://host.docker.internal:11434`).
- Fonts **Geist / Geist Mono already bundled** in `pubspec.yaml` (no font work needed).

## 3. Architecture — the new nav shell

Replace the current `ChatDrawer + ChatPage` layout (`lib/Pages/main_page.dart`) with a
four-column Discord-style shell. New shell widgets live under `lib/Pages/shell/`.

```
┌────┬──────────────┬───────────────────────────┬─────────────┐
│ P  │  Session     │  Chat column (flex)       │  Loop       │
│ e  │  rail 250px  │  ┌ header 52px ──────────┐│  monitor    │
│ r  │  header      │  │ messages + loop cards ││  300px      │
│ s  │  search      │  │                       ││  (slide-in  │
│ o  │  PINNED      │  │                       ││   from      │
│ n  │  SESSIONS    │  │                       ││   right)    │
│ a  │  GROUP       │  └───────────────────────┘│  TOKENS     │
│ 74 │  ─────────── │  ┌ composer ─────────────┐│  ELAPSED    │
│ px │  footer band │  │ + ϟ [input] ↑         ││  timeline   │
│    │  (74px)      │  └───────────────────────┘│  Pause/Stop │
└────┴──────────────┴───────────────────────────┴─────────────┘
```

| Column | Width | Backed by | Contents |
| --- | --- | --- | --- |
| Persona rail | 74px, `#050705` | `profile_provider` (`GET /profiles`), instance/server providers | server-switcher orb → divider → orchestrator "home" (pinned, 4px lime left bar) → divider → persona circles (per-persona tint, status dot, 2px lime active ring) → add-persona (dashed lime) |
| Session rail | 250px, `#0a0c0a` | session/chat providers (`GET /sessions?profile=`, `POST /sessions/resolve`) | persona header (avatar + name + model mono + switch chevron); search; sections PINNED / SESSIONS / GROUP; footer band (server chip left, user + gear right) |
| Chat | flex | existing SSE streaming (`/sessions/{id}/messages`, `/turns/{id}/events`) | 52px channel header; message list (mono role tags, tool-call chips, inline loop cards with stage stepper); composer |
| Loop monitor | 300px, slide-in | `loop_provider` (`/loops/{id}` + `live`/`events` SSE, `pause`/`resume`/`stop`) | TOKENS / ELAPSED stats; stage timeline; Pause / Stop |

**Composer** (`lib/Pages/shell/composer/`): controls `+` attach, `ϟ` loop-launcher (monochrome,
lime fill when popover open), text input, `↑` send. Send is lime **only when input is non-empty**,
resting `#22271b`/`#8a8f80`.

**Popovers** as overlay widgets: loop-launcher (definitions + role-chains + goal input + Run),
server-switcher (server list + "Add a server"), persona-editor (avatar tint / name / model /
allowed-roles multi-select / `soul.md` textarea / Create).

**Responsive:** at `<640px` rails collapse to a persona strip + drawer (spec mobile breakpoint),
reusing `responsive_framework` already in the app. Desktop breakpoint `>=1024px` shows both rails
with the loop panel sliding in.

### Component ↔ existing-code map

| New shell piece | Reuses |
| --- | --- |
| Persona rail | `profile_provider`, `instance_provider`, `local_server_provider` |
| Session rail | existing session/chat providers + `coqui_api_service` sessions endpoints |
| Chat + composer | existing chat provider + SSE prompt streaming in `coqui_api_service` |
| Loop launcher / cards / monitor | `loop_provider` + `/loops` endpoints (add `live`/`events` wiring if missing) |
| Server switcher | existing `CoquiInstance` config abstraction |
| Persona editor | `profile_provider` + `/profiles/{name}` + backstory/soul endpoints |

## 4. Theme / design tokens

Rewrite `lib/Theme/` to the spec token set, exposed as a single `CoquiTokens` source so no
screen hardcodes hex:

- **Surfaces:** personaRail `#050705`, sessionRail `#0a0c0a`, chatBg `#0e110e`, footerWell `#070907`,
  card `#0c0f0c`, input `#181b12`, chip/hover `#171b12`.
- **Borders:** hairline `#16190f`, default `#23261f`, control `#2a2e22`, loopCard `#23301a`.
- **Brand:** primaryLime `#CAE763`, gradient `#CAE763→#74DA5C`, accentGreen `#37B880`, onPrimary `#0a0a0a`.
- **Status:** online `#37B880`, busy/warning `#e0b34d`, idle `#5a5f52`, error `#e06a5a`.
- **Text:** high `#e8e8e8`, body `#cfd3c6`, secondary `#c7ccbe`, muted `#8a8f80`, faint `#6b6f62`.
- **Persona tints:** orchestrator (lime gradient), caelum/nova/iris/muse/sol (bg+fg pairs).
- **Type:** Geist body; **Geist Mono** for labels/meta/models/roles/timestamps/section headers;
  scale per spec (sectionLabel 10/upper/0.1em, meta 10.5, listItem 13.5, body 14/1.55, title 15/700).
- **Radii:** sm 6, md 8, card 10, input 12, railOrb 16, avatar 9999, pill 9999.
- **Layout constants:** the 74px footer-band alignment rule (session-rail footer, composer, loop-panel
  controls share height and vertically center to align across columns).

## 5. Deletions (delete entirely)

Remove pages + providers + services + models + tests for features dropped from primary nav:
**Channels, MCP, background/automation Tasks, Projects, Credentials, Scheduled tasks, Webhooks,
Work, and the Human/Machine toggle.**

Footprint is large and cross-linked (approx. file counts referencing each keyword under `lib/`:
work ~40, project ~29, task ~26, channel ~25, schedule ~14, webhook ~11, mcp ~10, credential ~7),
so deletion is a dedicated, ordered phase:

1. Remove each feature's Pages + subwidgets.
2. Remove its Provider registration in `main.dart` and the provider/service/model files.
3. `flutter analyze` after each removal; fix references in kept code before proceeding.
4. Keep anything a retained feature genuinely depends on (e.g. shared models still referenced by
   chat/sessions/loops/profiles). When a dependency is discovered, keep the minimum and note it.

**Kept features:** Chat / sessions, Profiles / personas (+ persona editor with `soul.md`),
Loops (launcher + inline cards + monitor), Group sessions, Settings, Server switcher.

## 6. E2E harness (local Docker + Ollama)

1. Run **Ollama** in Docker (or reuse host Ollama) and pull a small model (e.g. `qwen2.5:3b` /
   `llama3.2:1b` — smallest that reliably completes a loop).
2. Bring up **`coqui-api` on `:3300`** via `docker compose -f compose.yaml -f compose.api.yaml up -d coqui-api`
   with `OLLAMA_HOST` pointing at the Ollama container/host.
3. Seed a profile + session (via API) so the reskinned UI has data.
4. Configure the app's instance to `http://localhost:3300`, run `flutter run -d chrome`.
5. Drive a real session and a real loop from the new UI; confirm SSE streaming, loop card stepper,
   and the loop monitor update live.

## 7. Testing strategy

- **TDD** for new shell logic: widget tests against a **mocked `coqui_api_service`** for —
  persona rail rendering + active/status states, session rail sectioning, composer send-enable
  logic, loop card stage stepper, server-switcher/persona-editor popovers.
- `flutter analyze` clean at every phase boundary.
- `flutter test` green.
- Live Docker + Ollama smoke run in Chrome as the end-to-end proof (Section 6).

## 8. Phasing (input to the implementation plan)

1. Design tokens + theme (`CoquiTokens`, `lib/Theme/` rewrite).
2. Nav-shell scaffold — four columns with placeholder content, responsive breakpoints.
3. Wire personas (persona rail) + sessions (session rail) to existing providers.
4. Chat column + composer + SSE streaming.
5. Loops — launcher popover, inline loop cards, slide-in monitor.
6. Popovers + persona editor (`soul.md`).
7. Responsive / mobile strip + drawer.
8. Feature deletions (ordered, analyze-gated).
9. Docker + Ollama end-to-end smoke run in Chrome.

Each phase ends analyze-clean and test-green; commits per phase on `feat/discord-redesign`.

## 9. Risks & open items

- **Loop `live`/`events` SSE:** `coqui_api_service` references `live` but the monitor may need
  explicit `/loops/{id}/live` + `/loops/{id}/events` wiring — confirm during Phase 5.
- **Deletion coupling:** shared models may be referenced by kept features; discover via
  `flutter analyze`, keep the minimum.
- **Desktop/mobile parity:** out of scope for sign-off but must remain buildable.
- **Ollama model size vs. loop completion:** pick the smallest model that reliably drives a loop.
