# In-App Purchase & Supporter Perks Setup

Step-by-step guide for configuring in-app purchases in the Apple ecosystem for the Coqui app's supporter donation system.

## Prerequisites

- Apple Developer Program membership ($99/year)
- Xcode with a valid signing identity
- Access to [App Store Connect](https://appstoreconnect.apple.com)
- The Coqui app already registered in App Store Connect with a valid Bundle ID

## 1. Agreements, Tax & Banking

Before you can sell anything, Apple requires completed financial agreements.

1. Go to **App Store Connect → Agreements, Tax, and Banking**
2. Accept the **Paid Applications** agreement
3. Complete the **Banking** section (bank account details for payouts)
4. Complete the **Tax** section (W-9 for US, W-8BEN for international)

Apple will not process any in-app purchases until all three sections are complete.

## 2. Create In-App Purchase Products

Navigate to **App Store Connect → Apps → Coqui → Monetization → In-App Purchases**.

Create three **non-consumable** products:

| Product ID | Reference Name | Price Tier |
|---|---|---|
| `coqui_supporter_small` | Supporter Donation (Small) | $4.99 |
| `coqui_supporter_medium` | Supporter Donation (Medium) | $9.99 |
| `coqui_supporter_large` | Supporter Donation (Large) | $19.99 |

For each product:

1. Click **"+"** → **Non-Consumable**
2. Set the **Reference Name** (internal, not shown to users)
3. Set the **Product ID** exactly as listed above
4. Set the **Price** to the corresponding tier
5. Add at least one **Localization** (English US):
   - **Display Name**: e.g. "Support Coqui ($4.99)"
   - **Description**: "One-time donation to support Coqui's open-source development. Unlocks customization perks including color themes and alternate app icons."
6. Add a **Review Screenshot** (screenshot of the supporter section in settings)
7. Submit for review

All three products unlock identical perks — they are simply different donation amounts.

## 3. StoreKit Testing Configuration (Local Development)

For local testing without App Store Connect sandbox, create a StoreKit configuration file:

1. In Xcode, **File → New → File → StoreKit Configuration File**
2. Name it `Configuration.storekit`
3. Add three products matching the IDs above:
   - Type: Non-Consumable
   - Product ID: `coqui_supporter_small`, `coqui_supporter_medium`, `coqui_supporter_large`
   - Price: 4.99, 9.99, 19.99
4. In the Xcode scheme (**Product → Scheme → Edit Scheme → Run → Options**):
   - Set **StoreKit Configuration** to `Configuration.storekit`

This enables instant purchase testing in the iOS Simulator without needing a sandbox account or network connectivity.

## 4. Sandbox Testing (Pre-Release)

For testing against Apple's real purchase infrastructure:

1. Go to **App Store Connect → Users and Access → Sandbox → Testers**
2. Create a **Sandbox Tester** account:
   - Use a unique email not associated with any real Apple ID
   - Set region/territory as needed
3. On your test device:
   - Sign out of the App Store (Settings → your name → Media & Purchases → Sign Out)
   - Launch the app and initiate a purchase
   - iOS will prompt you to sign in — use the sandbox tester credentials
4. Sandbox purchases do not charge real money
5. Sandbox transactions complete instantly (no 24-hour renewal cycles for non-consumables)

## 5. Flutter Plugin Configuration

The `in_app_purchase` plugin is already added to `pubspec.yaml`. No additional native configuration is required for iOS — the plugin uses StoreKit automatically.

Key files:
- `lib/Services/purchase_service.dart` — IAP wrapper (product queries, purchase handling, restore)
- `lib/Providers/supporter_provider.dart` — State management for supporter status and perks
- `lib/Pages/settings_page/subwidgets/supporter_settings.dart` — UI for donations and perk selection

### Product ID Constants

Product IDs are defined in `purchase_service.dart`:

```dart
class SupporterProducts {
  static const small = 'coqui_supporter_small';
  static const medium = 'coqui_supporter_medium';
  static const large = 'coqui_supporter_large';
  static const allIds = {small, medium, large};
}
```

These must exactly match the Product IDs created in App Store Connect.

## 6. Receipt Validation

The current implementation uses **client-side validation only** — purchase state is persisted locally in Hive. This is appropriate for supporter perks (cosmetic features):

- On successful purchase or restore, `is_supporter = true` is written to Hive `settings` box
- `SupporterProvider.isSupporter` reads this flag to gate perk access
- The theme system checks this flag before applying supporter themes

**Future enhancement**: When the subscription model is added for managed server instances, server-side receipt validation should be implemented via the Coqui API to prevent tampering and enable cross-device sync.

## 7. App Review Submission Notes

When submitting to App Store Review, include these notes in **App Store Connect → App Review Information → Notes**:

```
In-App Purchases:
- Three non-consumable one-time donation products ($4.99, $9.99, $19.99)
- All three unlock identical cosmetic perks (custom color themes, alternate app icons)
- These are voluntary supporter donations for an open-source project
- No content is locked behind the paywall that affects core functionality
- Restore Purchases button is available in Settings → Supporter section

To test:
1. Open the app → Settings
2. Scroll to the "Supporter" section
3. Tap any donation tier to initiate purchase
4. After purchase, custom themes and icon selector appear
```

## 8. Testing Checklist

### StoreKit Local Testing
- [ ] Products load correctly in the Supporter section
- [ ] Each tier button shows the correct price
- [ ] Tapping a tier initiates the purchase sheet
- [ ] Completing a purchase unlocks perks immediately
- [ ] Theme selector appears and themes apply correctly
- [ ] Icon selector appears (iOS only) and icons switch
- [ ] Cancelling a purchase shows no error (graceful dismiss)

### Sandbox Testing
- [ ] Products load from App Store Connect
- [ ] Purchase completes with sandbox tester account
- [ ] Restore Purchases recovers supporter status after clearing app data
- [ ] Purchasing multiple tiers works (stacking donations)
- [ ] Network error during purchase shows appropriate error message

### Non-iOS Platforms
- [ ] Supporter section shows GitHub Sponsors link instead of IAP buttons
- [ ] No Restore Purchases button
- [ ] No Icon Selector
- [ ] Theme selector is hidden (perks are IAP-locked)

### Edge Cases
- [ ] App launch with `is_supporter = true` in Hive applies saved theme
- [ ] Switching between supporter themes updates the entire app immediately
- [ ] Resetting to Default theme restores original Coqui brand colors
- [ ] Icon change persists across app restarts
- [ ] Supporter badge appears in settings header when unlocked

## 9. Pricing Notes

- Apple takes a 15-30% commission on in-app purchases (15% for developers earning under $1M/year via the Small Business Program)
- Net revenue per tier (at 15% commission): ~$4.24 / ~$8.49 / ~$16.99
- Prices are set in USD; Apple auto-converts for other territories
- Price can be changed later in App Store Connect without a new app submission
