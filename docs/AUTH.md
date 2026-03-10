# GitHub OAuth Authentication

Coqui App uses GitHub OAuth for signing into the CoquiBot SaaS platform. This enables hosted instance management, subscriptions, and billing from the app.

## How It Works

The app uses a 3-legged OAuth flow through the CoquiBot SaaS backend:

```
User taps "Sign in with GitHub"
    │
    ▼
App calls POST /api/v1/auth/login/github on the SaaS backend
    │  ← Returns: GitHub authorization URL + CSRF state token
    ▼
App opens GitHub authorization URL in the system browser
    │
    ▼
User authenticates with GitHub and grants permissions
    │
    ▼
GitHub redirects to coquibot://auth/callback?code=...&state=...
    │
    ▼
App intercepts the deep link (app_links package)
    │
    ▼
App calls POST /api/v1/auth/callback/github with code + state
    │  ← Returns: API token + user profile
    ▼
Token stored in secure storage (Keychain/KeyStore)
    │
    ▼
User is logged in ✓
```

## Prerequisites

### 1. Running SaaS Backend

The app connects to the CoquiBot SaaS backend (default: `https://coquibot.ai`). The backend is a Next.js app in the `coquibot-saas` repository.

The backend must be running and reachable for login to work. If the backend is down or unreachable, you'll see **"Failed to start login"** in the app.

### 2. GitHub OAuth App

Create a GitHub OAuth App for the backend:

1. Go to [GitHub Developer Settings → OAuth Apps](https://github.com/settings/developers)
2. Click **New OAuth App**
3. Fill in the details:
   - **Application name**: `CoquiBot` (or your preferred name)
   - **Homepage URL**: `https://coquibot.ai` (or your backend URL)
   - **Authorization callback URL**: `https://coquibot.ai/api/v1/auth/callback/github` (or `http://localhost:3000/api/v1/auth/callback/github` for local dev)
4. Click **Register application**
5. Copy the **Client ID**
6. Generate a **Client Secret** and copy it

> **Note on callback URL**: For mobile/desktop apps, the actual OAuth callback goes through GitHub back to the SaaS backend URL (not the `coquibot://` deep link directly). The backend then redirects to the app's deep link scheme. The `redirectUri` parameter sent by the app tells the backend's login endpoint what URL GitHub should redirect back to after authorization.

### 3. Backend Environment Variables

Configure the following in the SaaS backend `.env`:

```env
# GitHub OAuth App credentials (from step 2)
AUTH_GITHUB_ID="your-github-oauth-app-client-id"
AUTH_GITHUB_SECRET="your-github-oauth-app-client-secret"

# NextAuth secret — generate with: openssl rand -base64 32
AUTH_SECRET="your-random-secret"

# Base URL of the SaaS backend
NEXT_PUBLIC_BASE_URL="https://coquibot.ai"
```

If `AUTH_GITHUB_ID` is not set, the backend returns a 500 error ("OAuth not configured"), which the app displays as "Failed to start login".

### 4. GitHub Permissions

The OAuth app requests these GitHub scopes:

- `read:user` — read the user's GitHub profile
- `user:email` — read the user's primary email address

No write access is requested.

## Deep Link Configuration

The app uses the `coquibot://` URL scheme to receive OAuth callbacks. This must be registered per platform.

| Platform | Status | Configuration File |
|----------|--------|--------------------|
| Android  | ✅ Configured | `android/app/src/main/AndroidManifest.xml` |
| iOS      | ✅ Configured | `ios/Runner/Info.plist` |
| macOS    | ✅ Configured | `macos/Runner/Info.plist` |
| Web      | N/A | Uses standard HTTP redirects |
| Linux    | ❌ Not supported | Desktop Linux lacks standard deep link handling |
| Windows  | ❌ Not supported | Would require registry-based protocol handler |

### Deep Link Format

```
coquibot://auth/callback?code=GITHUB_AUTH_CODE&state=CSRF_STATE_TOKEN
```

## API Endpoints

All auth endpoints are on the SaaS backend (`/api/v1/`):

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/auth/login/github` | Start OAuth flow — returns GitHub authorization URL + state |
| `POST` | `/auth/callback/github` | Exchange auth code for API token + user profile |
| `GET`  | `/auth/me` | Get the authenticated user's profile |

### Rate Limiting

Auth endpoints are rate-limited to **10 requests per 5 minutes** per IP.

## Token Storage

| Platform | Storage Backend |
|----------|----------------|
| iOS      | Keychain (`flutter_secure_storage`) |
| Android  | EncryptedSharedPreferences / KeyStore |
| macOS    | Keychain |
| Linux    | libsecret |
| Windows  | Windows Credential Manager |
| Web      | Falls back to sessionStorage |

Tokens persist across app restarts. On launch, the app calls `tryRestoreSession()` to load the stored token and validate it against `/auth/me`.

## Troubleshooting

### "Failed to start login"

This means the app could not reach the SaaS backend or the backend returned an error.

**Common causes:**

1. **Backend not running** — Ensure the SaaS backend is running at `https://coquibot.ai` (or your configured URL).
2. **OAuth not configured** — The backend needs `AUTH_GITHUB_ID` set in `.env`. Without it, the endpoint returns "OAuth not configured".
3. **Network error** — Check your internet connection. The app makes an HTTP POST to the backend.
4. **Backend URL mismatch** — The app hardcodes `https://coquibot.ai` as the SaaS URL (in `SaasApiService`). For local development, you'd need to modify the source or use `SaasApiService.setBaseUrl()`.

### OAuth callback not working (mobile/desktop)

After authenticating with GitHub, the browser should redirect back to the app via `coquibot://auth/callback`. If this doesn't happen:

1. **Verify deep link registration** — Check that the `coquibot://` scheme is registered in the platform-specific config (see Deep Link Configuration above).
2. **iOS/Android**: Ensure the app is installed (not just running via `flutter run` in some configurations).
3. **macOS**: Verify `CFBundleURLTypes` is present in `macos/Runner/Info.plist`.

### Token expired / automatic logout

If you're logged in but suddenly see the login screen:

- The stored token may have expired or been revoked server-side.
- The app automatically clears invalid tokens when it receives a 401 response.
- Sign in again to get a fresh token.

## Local Development

To test the OAuth flow against a local SaaS backend:

1. Run the SaaS backend locally (typically `pnpm dev` in the `coquibot-saas` repo)
2. Create a GitHub OAuth App with callback URL `http://localhost:3000/api/v1/auth/callback/github`
3. Set the env vars in the local `.env`
4. In the Flutter app, update the SaaS base URL before the OAuth flow (you can temporarily change the default in `SaasApiService` or call `setBaseUrl('http://localhost:3000')`)

For mobile testing against a local backend, use your machine's LAN IP instead of `localhost` (e.g., `http://192.168.1.x:3000`).
