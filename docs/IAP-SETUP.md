# In-App Purchase Setup Guide

This guide covers how to configure auto-renewable subscription products in Apple App Store Connect and Google Play Console for the Coqui app's hosting plans.

## Overview

The Coqui app offers hosting plan subscriptions via in-app purchases (IAP). The app fetches plan definitions from the SaaS API (`/api/v1/plans`), which include platform-specific product IDs:

- `iapAppleProductId` — Apple App Store product ID
- `iapGoogleProductId` — Google Play product ID

If these fields are null for a plan, that plan is only available via Stripe (web checkout). The app handles this gracefully — users see a "Subscribe on Web" button instead.

## Apple App Store Connect

### Prerequisites

- An active Apple Developer Program membership ($99/year)
- The app registered in App Store Connect
- A Paid Applications agreement signed in App Store Connect → Agreements, Tax, and Banking

### Step 1: Create a Subscription Group

1. Go to **App Store Connect** → Your App → **Subscriptions**
2. Click **+** next to "Subscription Groups"
3. Create a group named **"Coqui Hosting"**
4. This group holds all hosting plan tiers — users can upgrade/downgrade within the group

### Step 2: Create Subscription Products

For each plan, create a subscription product in the "Coqui Hosting" group:

| Plan | Product ID | Price | Duration |
|------|-----------|-------|----------|
| Lite | `com.coquibot.lite.monthly` | $19.99/mo | 1 Month |
| Pro | `com.coquibot.pro.monthly` | $34.99/mo | 1 Month |
| GPU | `com.coquibot.gpu.monthly` | $109.99/mo | 1 Month |

For each product:

1. Click **+** in the subscription group → **Create Subscription**
2. Enter the Reference Name (e.g., "Coqui Lite Monthly") and Product ID
3. Set the **Subscription Duration** to "1 Month"
4. Under **Subscription Prices**, click **+** and set the price
   - Use the pricing matrix — Apple has fixed price tiers
   - Choose the tier closest to the target price
5. Add a **Localization** (at minimum, English US):
   - **Display Name**: e.g., "Coqui Lite"
   - **Description**: e.g., "1 vCPU, 2 GB RAM, 55 GB SSD hosted Coqui instance"

### Step 3: Configure Server-to-Server Notifications (Recommended)

1. Go to **App Store Connect** → Your App → **App Information**
2. Under **App Store Server Notifications**, set the URL to:
   ```
   https://coquibot.ai/api/webhooks/apple
   ```
3. Select **Version 2** notifications
4. This enables real-time subscription status updates (renewals, cancellations, billing issues)

### Step 4: Set Up Sandbox Testing

1. Go to **App Store Connect** → **Users and Access** → **Sandbox** → **Test Accounts**
2. Create sandbox tester accounts for testing purchases
3. On your iOS device, sign in with the sandbox account under **Settings → App Store → Sandbox Account**
4. Sandbox subscriptions renew at accelerated rates:
   - 1 month → renews every 5 minutes
   - Subscriptions auto-expire after 6 renewals

### Step 5: Submit for Review

Subscription products must be submitted for review alongside an app binary. They'll be reviewed as part of your app submission.

## Google Play Console

### Prerequisites

- A Google Play Developer account ($25 one-time fee)
- The app registered in Google Play Console
- A Google Cloud project linked to the Play Console for server-side verification

### Step 1: Create Subscriptions

1. Go to **Google Play Console** → Your App → **Monetize** → **Products** → **Subscriptions**
2. Click **Create subscription** for each plan:

| Plan | Product ID | Base Plan Price | Billing Period |
|------|-----------|----------------|----------------|
| Lite | `coquibot_lite_monthly` | $19.99 | 1 Month |
| Pro | `coquibot_pro_monthly` | $34.99 | 1 Month |
| GPU | `coquibot_gpu_monthly` | $109.99 | 1 Month |

For each subscription:

1. Enter the **Product ID** (cannot be changed after creation)
2. Add a **Name** and **Description**:
   - Name: e.g., "Coqui Lite"
   - Description: e.g., "1 vCPU, 2 GB RAM, 55 GB SSD hosted Coqui instance"
3. Create a **Base Plan**:
   - Click "Add base plan"
   - Set the billing period to "1 Month"
   - Set the price (use "Set Price" → enter the amount)
   - Enable "Auto-renewing"
4. **Activate** the base plan and subscription

### Step 2: Configure Real-Time Developer Notifications (Recommended)

1. Go to **Google Play Console** → Your App → **Monetize** → **Monetization Setup**
2. Under **Real-time developer notifications**, set the Topic Name to a Google Cloud Pub/Sub topic:
   ```
   projects/your-project/topics/play-billing
   ```
3. Create a Cloud Function or endpoint that processes these notifications and forwards to:
   ```
   https://coquibot.ai/api/webhooks/google
   ```

### Step 3: License Testing

1. Go to **Google Play Console** → **Settings** → **License Testing**
2. Add your tester email addresses
3. Testers can make purchases without being charged
4. Test subscriptions renew every 5 minutes and auto-cancel after a few renewals

### Step 4: Set Up Google Play Billing Library

The Flutter `in_app_purchase` package handles the Play Billing Library integration automatically. Ensure:

- `billing_client` permissions are included (already handled by the package)
- The app is published to at least an internal test track before testing purchases

## Backend Configuration

### Database Plan Records

Update the `plans` table in the SaaS database to include IAP product IDs:

```sql
UPDATE plans SET
  iap_price_in_cents = 1999,
  iap_apple_product_id = 'com.coquibot.lite.monthly',
  iap_google_product_id = 'coquibot_lite_monthly'
WHERE name = 'lite';

UPDATE plans SET
  iap_price_in_cents = 3499,
  iap_apple_product_id = 'com.coquibot.pro.monthly',
  iap_google_product_id = 'coquibot_pro_monthly'
WHERE name = 'pro';

UPDATE plans SET
  iap_price_in_cents = 10999,
  iap_apple_product_id = 'com.coquibot.gpu.monthly',
  iap_google_product_id = 'coquibot_gpu_monthly'
WHERE name = 'gpu';
```

### Receipt Verification

The SaaS API endpoint `POST /api/v1/checkout/iap` handles receipt verification:

- **Apple**: Validates receipts against App Store Server API (v2)
- **Google**: Validates purchase tokens against Google Play Developer API

Environment variables required:

| Variable | Purpose |
|----------|---------|
| `APPLE_SHARED_SECRET` | App-specific shared secret from App Store Connect |
| `APPLE_ISSUER_ID` | App Store Connect API issuer ID |
| `APPLE_KEY_ID` | App Store Connect API key ID |
| `APPLE_PRIVATE_KEY` | App Store Connect API private key (`.p8` contents) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` | JSON key for the Google Play service account |

### Webhook Endpoints

- `POST /api/webhooks/apple` — App Store Server Notifications v2
- `POST /api/webhooks/google` — Google Play Real-Time Developer Notifications

These endpoints handle subscription lifecycle events: renewals, cancellations, grace periods, and billing retries.

## Pricing Strategy

IAP prices are typically higher than web prices to account for the 15-30% platform commission:

| Plan | Web Price | IAP Price | Effective Revenue |
|------|----------|----------|-------------------|
| Lite | $15.00/mo | $19.99/mo | ~$14.00/mo (30% fee) |
| Pro | $30.00/mo | $34.99/mo | ~$24.50/mo (30% fee) |
| GPU | $100.00/mo | $109.99/mo | ~$77.00/mo (30% fee) |

After the first year, Apple reduces the commission to 15% for auto-renewable subscriptions (Small Business Program eligible).

## Graceful Degradation

The app handles the following scenarios automatically:

1. **Products not configured**: If `iapAppleProductId`/`iapGoogleProductId` is null for a plan, the app shows "Subscribe on Web" instead.
2. **Products not found in store**: If product IDs are configured but not yet approved/active in the store, the app logs a warning and falls back to web checkout.
3. **Store unavailable**: On platforms without IAP support (web, desktop), or if the store is temporarily unavailable, users are directed to web checkout.
4. **Verification fails**: If the backend can't verify a receipt, the purchase is still completed with the store. The user is told their purchase is safe and to try restoring later.

## Testing Checklist

- [ ] Create sandbox/test accounts on both platforms
- [ ] Verify subscription products appear in the app
- [ ] Test purchase flow end-to-end (sandbox)
- [ ] Test receipt verification with the backend
- [ ] Test subscription cancellation and reactivation
- [ ] Test restore purchases on a fresh install
- [ ] Test graceful fallback when products aren't configured
- [ ] Test on a device without an app store account
- [ ] Test upgrade/downgrade between plans (Apple subscription group)
