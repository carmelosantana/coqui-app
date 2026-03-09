# Coqui Web Deployment Guide

Coqui runs in the browser as a WebAssembly (WASM) application. No server-side code is needed — the entire app runs client-side. Users connect directly to their own Coqui API server from the browser.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐
│  Browser (WASM)  │  SSE   │  Coqui API Server │
│  ─────────────── │◄──────►│  (user-hosted)     │
│  Flutter app     │  HTTP  │                    │
│  SQLite (OPFS)   │        │                    │
│  Hive (IndexedDB)│        │                    │
└─────────────────┘         └──────────────────┘
```

- **No SSR / no backend** — the Docker container serves only static files (HTML, JS, WASM).
- **All user data stays in the browser** — sessions, messages, settings, and API keys are stored locally via SQLite WASM (OPFS) and Hive (IndexedDB).
- **Direct API connection** — the browser app connects to the user's Coqui API server. CORS must be configured on the API server.

## Browser Requirements

Flutter WASM requires browsers with WebAssembly Garbage Collection (WASM-GC) support:

| Browser | Minimum Version | Release Date |
|---------|:--------------:|:------------:|
| Chrome  | 119+           | Nov 2023     |
| Firefox | 120+           | Nov 2023     |
| Safari  | 18.2+          | Dec 2024     |
| Edge    | 119+           | Nov 2023     |

All major browsers have supported WASM-GC since late 2024. As of March 2026 this covers effectively all users.

## Quick Start (Local)

Build and serve the web app locally:

```bash
# Install dependencies
flutter pub get

# Build with WASM (release)
flutter build web --wasm --release

# Serve locally
cd build/web && python3 -m http.server 8080
# → Open http://localhost:8080
```

Or use the Makefile:

```bash
make web-serve    # Builds + serves on port 8080
```

Or the build script:

```bash
./scripts/build.sh --platform web --mode release
```

## Docker Deployment

The recommended deployment method. The Docker image is ~10MB (nginx:alpine + static files).

### Build and Run

```bash
# Build image
docker compose -f compose.web.yaml build

# Start container (port 8080)
docker compose -f compose.web.yaml up -d

# Stop
docker compose -f compose.web.yaml down
```

Or use Make targets:

```bash
make docker-web-build
make docker-web-start
make docker-web-stop
```

### Custom Port

Set the `COQUI_WEB_PORT` environment variable:

```bash
COQUI_WEB_PORT=3000 docker compose -f compose.web.yaml up -d
```

### Standalone Docker (without Compose)

```bash
docker build -f Dockerfile.web -t coqui-web .
docker run -d -p 8080:80 --name coqui-web coqui-web
```

## Vercel Deployment

The recommended static hosting option. Deploy the pre-built `build/web/` output directly — no server-side build step on Vercel.

### Quick Deploy

```bash
# 1. Build locally
flutter build web --wasm --release

# 2. Deploy
cd build/web && vercel --prod
```

Or with npx (no global install):

```bash
cd build/web && npx vercel --prod
```

### How It Works

The project includes a `vercel.json` in the repo root that configures:

- **No build command** — Vercel serves your pre-built `build/web/` output as-is. Flutter is not installed on Vercel.
- **SPA fallback** — all routes rewrite to `index.html` so Flutter handles client-side routing.
- **COOP/COEP headers** — `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` are set globally. Required for SharedArrayBuffer (WASM threading) and OPFS (SQLite WASM storage).
- **Cache strategy** — `index.html`, `flutter_bootstrap.js`, service worker, and manifest use `no-cache`. Hashed assets (`.js`, `.wasm`, fonts) are immutable with 1-year cache. Images get 1-week cache.
- **Security headers** — `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` are set on all responses.

### CI/CD with GitHub Actions

For automated deploys, build in GitHub Actions and deploy the output to Vercel:

```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter build web --wasm --release
      - run: cd build/web && npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
```

### Landing Page

The web build includes a lightweight HTML/CSS landing page baked into `index.html` that renders instantly while the WASM bundle loads. It explains what Coqui is, its privacy model, and links to project resources. Once Flutter's first frame renders, the landing page is replaced by the app.

### Important: Do NOT Build on Vercel

Vercel does not have the Flutter SDK. The `vercel.json` sets `buildCommand: null` intentionally. Always build locally or in CI, then deploy the `build/web/` output. A `scripts/install-flutter.sh` approach is not recommended — it would consume ~5-10 minutes of Vercel build time per deploy and is fragile.

## Static Hosting (S3, GitHub Pages, Cloudflare Pages)

Since the build output is purely static files, any static hosting works:

```bash
flutter build web --wasm --release
# Upload contents of build/web/ to your hosting provider
```

Requirements for your hosting provider:
- Serve `application/wasm` MIME type for `.wasm` files
- SPA fallback routing (all paths → `index.html`)
- Cross-Origin-Opener-Policy / Cross-Origin-Embedder-Policy headers
- HTTPS (required for service worker / PWA features)

## CORS Configuration

The Coqui API server must allow cross-origin requests from the web app's domain. The API server supports this via the `--cors-origin` flag:

```bash
# Allow all origins (development)
coqui api --cors-origin '*'

# Allow specific origins (production)
coqui api --cors-origin 'https://app.coqui.ai,http://localhost:8080'
```

If CORS is not configured, the browser will block API requests and you'll see errors in the console.

## Local Storage and Privacy

### What Data is Stored

| Storage | Technology | Data |
|---------|-----------|------|
| Session cache | SQLite WASM (OPFS) | Cached sessions, messages for offline viewing |
| Server configs | Hive (IndexedDB) | Server URLs, API keys, active server selection |
| User preferences | Hive (IndexedDB) | Theme color, brightness preference |

### Privacy and Security

- **All data stays in the browser.** Nothing is sent to the hosting server — it only serves static files.
- **API keys are stored locally** in the browser's IndexedDB. They are only sent to the user's own Coqui API server.
- **Browser storage can be cleared** via the browser's "Clear site data" option in Settings.
- **OPFS storage** (used by SQLite WASM) is origin-scoped and sandboxed by the browser.
- **No cookies** are used. No tracking, no analytics.
- **No server-side state.** The Docker container has zero knowledge of user activity.

### Storage Limits

Browser storage limits vary by browser but are typically generous for installed PWAs:

| Browser | OPFS + IndexedDB Quota |
|---------|:---------------------:|
| Chrome  | Up to 80% of disk     |
| Firefox | Up to 50% of disk     |
| Safari  | ~1GB per origin       |

For a chat application, this is far more than needed.

## PWA (Progressive Web App)

The web build includes a service worker and web manifest for PWA support:

- **Install as app** — users can "Add to Home Screen" on mobile or "Install" on desktop browsers
- **Offline shell** — the app shell (HTML, JS, WASM, fonts) is cached by the service worker
- **Offline data** — cached sessions and messages are available offline via SQLite WASM
- **Background sync** — when the network returns, the app reconnects to the API server

## Troubleshooting

### CORS Errors

If you see `Access to fetch has been blocked by CORS policy`:
- Ensure the Coqui API server is running with `--cors-origin` including your web app's origin
- Check that the origin includes the protocol (`http://` or `https://`)

### WASM Not Loading

If the app shows a blank page or loading spinner indefinitely:
- Check browser console for errors
- Ensure `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers are set
- Verify your browser supports WASM-GC (Chrome 119+, Firefox 120+, Safari 18.2+)

### SQLite Storage Errors

If local caching doesn't persist between sessions:
- OPFS requires HTTPS (or localhost) — plain HTTP won't work
- Check that `Cross-Origin-Embedder-Policy: require-corp` header is set
- Some browsers in private/incognito mode may restrict storage

### Cache Issues After Update

If the app shows an old version after deployment:
- Hard refresh: `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (macOS)
- Clear site data in browser settings
- The service worker will detect new versions and prompt for update
