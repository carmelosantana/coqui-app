# Vercel Deployment Checklist

Pre-built static deployment of Coqui Web (Flutter WASM) on Vercel. No server-side build — Flutter is not available on Vercel.

## Prerequisites

- Flutter SDK installed locally (or in CI)
- Vercel CLI (`npm i -g vercel`) or use `npx vercel`
- Vercel account linked to the project

## Build Locally

```bash
# Install dependencies
flutter pub get

# Generate SQLite WASM service worker
dart run sqflite_common_ffi_web:setup --force

# Build
flutter build web --wasm --release
```

Or use the build script:

```bash
./scripts/build.sh --platform web --mode release
```

## Deploy

```bash
cd build/web && npx vercel --prod
```

## vercel.json Configuration

The repo ships a `vercel.json` that must stay in the project root (Vercel reads it before deploying). Key settings:

| Setting | Value | Why |
|---------|-------|-----|
| `buildCommand` | `null` | No build on Vercel — we deploy pre-built output |
| `outputDirectory` | `build/web` | Flutter's web build output |
| `framework` | `null` | Not a Next.js/Nuxt/etc. project |

## Required Headers

These headers are set in `vercel.json` and are **required** for WASM threading and SQLite OPFS:

| Header | Value | Required For |
|--------|-------|-------------|
| `Cross-Origin-Opener-Policy` | `same-origin` | SharedArrayBuffer (WASM threading) |
| `Cross-Origin-Embedder-Policy` | `require-corp` | SharedArrayBuffer (WASM threading) |

Without these headers, the SQLite WASM database will fail to initialize and the app will not function.

## Cache Strategy

| Files | Cache-Control | Rationale |
|-------|--------------|-----------|
| `index.html` | `no-cache, must-revalidate` | Always serve latest HTML |
| `flutter_bootstrap.js` | `no-cache, must-revalidate` | Bootstrap may change between deploys |
| `flutter_service_worker.js` | `no-cache, must-revalidate` | Service worker must be fresh |
| `manifest.json` | `no-cache` | PWA manifest updates |
| `*.wasm` | `public, max-age=31536000, immutable` | Content-addressed, never changes |
| `*.js` (hashed) | `public, max-age=31536000, immutable` | Content-addressed, never changes |
| `*.ttf, *.woff2` | `public, max-age=31536000, immutable` | Font files are stable |
| `*.png, *.jpg, *.svg` | `public, max-age=604800` | 1-week cache for images |
| `llms.txt`, `robots.txt` | `public, max-age=86400` | 1-day cache for discovery files |

## Security Headers

Set globally on all responses:

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`

## SPA Routing

The rewrite rule `/(.*) → /index.html` ensures Flutter handles all client-side routes. Vercel only applies this when no matching static file exists, so `llms.txt`, `robots.txt`, `manifest.json`, etc. are served directly.

## Static Assets Checklist

Verify these files exist in `build/web/` before deploying:

```
build/web/
├── index.html              ← Landing page + Flutter bootstrap
├── flutter_bootstrap.js    ← Flutter engine loader
├── main.dart.js            ← Compiled Dart (JS fallback)
├── main.dart.wasm          ← Compiled Dart (WASM)
├── sqflite_sw.js           ← SQLite service worker
├── sqlite3.wasm            ← SQLite WASM binary
├── manifest.json           ← PWA manifest
├── favicon.png             ← 32×32 favicon (coqui-icon)
├── coqui-icon.png          ← 1024×1024 logo
├── llms.txt                ← LLM-readable site description
├── robots.txt              ← Search engine directives
├── flutter_service_worker.js
├── icons/
│   ├── Icon-192.png        ← PWA icon
│   ├── Icon-512.png        ← PWA icon
│   ├── Icon-maskable-192.png
│   └── Icon-maskable-512.png
└── assets/                 ← Flutter assets (fonts, images)
```

Quick verification:

```bash
ls build/web/{index.html,sqflite_sw.js,sqlite3.wasm,llms.txt,robots.txt,favicon.png,coqui-icon.png}
```

## CI/CD with GitHub Actions

```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web to Vercel
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

      - name: Generate SQLite WASM files
        run: dart run sqflite_common_ffi_web:setup --force

      - name: Build WASM
        run: flutter build web --wasm --release

      - name: Deploy to Vercel
        run: cd build/web && npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
```

### Required GitHub Secrets

| Secret | Source |
|--------|--------|
| `VERCEL_TOKEN` | Vercel dashboard → Settings → Tokens |

## Vercel Project Settings

In the Vercel dashboard, ensure:

1. **Framework Preset** → Other (not auto-detected)
2. **Build Command** → Override: leave empty (vercel.json sets `null`)
3. **Output Directory** → Override: `build/web`
4. **Node.js Version** → Default is fine (only used for `npx vercel` CLI)
5. **Root Directory** → Project root (where `vercel.json` lives)

## Domain Setup

If using a custom domain (e.g., `app.coquibot.ai`):

1. Add domain in Vercel dashboard → Project → Settings → Domains
2. Update DNS: CNAME record pointing to `cname.vercel-dns.com`
3. Vercel auto-provisions TLS certificates
4. Update `<link rel="canonical">` and OG URLs in `web/index.html` to match

## Troubleshooting

### App loads but SQLite fails / blank screen after loading

Missing COOP/COEP headers. Verify with:

```bash
curl -sI https://your-domain.vercel.app | grep -i "cross-origin"
```

Expected output:

```
cross-origin-opener-policy: same-origin
cross-origin-embedder-policy: require-corp
```

### sqflite_sw.js 404

The SQLite service worker was not generated before build. Run:

```bash
dart run sqflite_common_ffi_web:setup --force
flutter build web --wasm --release
```

### Landing page flashes then disappears

The `#landing` overlay must use `position: fixed; z-index: 9999` to render above Flutter's canvas. This is already configured in `web/index.html`.

### External images/fonts fail to load

`Cross-Origin-Embedder-Policy: require-corp` blocks cross-origin resources that don't include `Cross-Origin-Resource-Policy` headers. All assets must be same-origin or include proper CORS headers.

### Old version cached after deploy

Clear the service worker cache. Users can hard-refresh (`Cmd+Shift+R` / `Ctrl+Shift+R`) or open DevTools → Application → Storage → Clear site data.
