import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Providers/auth_provider.dart';
import 'package:coqui_app/Providers/subscription_provider.dart';
import 'package:coqui_app/Services/iap_subscription_service.dart';

/// Pricing page showing available hosting plans.
///
/// Platform-aware pricing:
/// - On iOS/Android with IAP products: shows store price + "Subscribe" button.
/// - On iOS/Android without IAP products: shows web price + link to coquibot.ai.
/// - On web/desktop: shows web price + Stripe checkout button.
class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subProvider = context.read<SubscriptionProvider>();
      if (subProvider.plans.isEmpty) {
        subProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: Consumer2<SubscriptionProvider, AuthProvider>(
        builder: (context, subProvider, auth, _) {
          if (subProvider.isLoading && subProvider.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Error banner
              if (subProvider.lastError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subProvider.lastError!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: subProvider.clearError,
                      ),
                    ],
                  ),
                ),

              // Active subscription banner
              if (subProvider.hasActiveSubscription) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have an active '
                          '${subProvider.activeSubscription?.plan?.displayName ?? ''} '
                          'subscription.',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // IAP not available notice (mobile without store products)
              if (_showIapNotice(subProvider))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: colorScheme.secondaryContainer,
                  child: Text(
                    'In-app subscriptions are not yet available. '
                    'Subscribe at coquibot.ai for now.',
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),

              // Plan cards
              Expanded(
                child: subProvider.plans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No plans available',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Responsive grid: 1 column mobile, 3 columns desktop.
                          final crossAxisCount =
                              constraints.maxWidth > 800 ? 3 : 1;
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio:
                                  crossAxisCount == 1 ? 2.2 : 0.75,
                            ),
                            itemCount: subProvider.plans.length,
                            itemBuilder: (context, index) {
                              return _PlanCard(
                                plan: subProvider.plans[index],
                                isLoggedIn: auth.isLoggedIn,
                                hasActiveSubscription:
                                    subProvider.hasActiveSubscription,
                                canPurchaseViaIap:
                                    subProvider.canPurchaseViaPlan(
                                  subProvider.plans[index].id,
                                ),
                                storePrice: subProvider.getStorePriceForPlan(
                                  subProvider.plans[index].id,
                                ),
                                isPurchasing: subProvider.isPurchasing,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _showIapNotice(SubscriptionProvider provider) {
    if (!PlatformInfo.isIOS && !PlatformInfo.isAndroid) return false;
    return provider.iapStatus == IapStatus.noProducts;
  }
}

// ── Plan Card ────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool isLoggedIn;
  final bool hasActiveSubscription;
  final bool canPurchaseViaIap;
  final String? storePrice;
  final bool isPurchasing;

  const _PlanCard({
    required this.plan,
    required this.isLoggedIn,
    required this.hasActiveSubscription,
    required this.canPurchaseViaIap,
    this.storePrice,
    required this.isPurchasing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name
            Text(
              plan.displayName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _displayPrice,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  '/mo',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Features
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(feature, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Subscribe button
            SizedBox(
              width: double.infinity,
              child: _buildSubscribeButton(context),
            ),
          ],
        ),
      ),
    );
  }

  String get _displayPrice {
    // Show store price if available (includes Apple/Google markup).
    if (storePrice != null) return storePrice!;
    // Otherwise show the IAP price if set, falling back to web price.
    if (plan.formattedIapPrice != null &&
        (PlatformInfo.isIOS || PlatformInfo.isAndroid)) {
      return plan.formattedIapPrice!.replaceAll('/mo', '');
    }
    return plan.formattedPrice.replaceAll('/mo', '');
  }

  Widget _buildSubscribeButton(BuildContext context) {
    if (hasActiveSubscription) {
      return const OutlinedButton(
        onPressed: null,
        child: Text('Current Plan'),
      );
    }

    if (!isLoggedIn) {
      return FilledButton(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        child: const Text('Sign In to Subscribe'),
      );
    }

    // On mobile with IAP available for this plan.
    if (canPurchaseViaIap) {
      return FilledButton(
        onPressed: isPurchasing
            ? null
            : () =>
                context.read<SubscriptionProvider>().purchaseViaPlan(plan.id),
        child: isPurchasing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Subscribe'),
      );
    }

    // Web/desktop or no IAP products — link to web checkout.
    return FilledButton(
      onPressed: () => _webCheckout(context),
      child: const Text('Subscribe on Web'),
    );
  }

  Future<void> _webCheckout(BuildContext context) async {
    try {
      // For plans with Stripe, we could create a checkout session.
      // For now, link to the pricing page.
      await launchUrlString('https://coquibot.ai/pricing');
    } catch (_) {
      // Fail silently — button press acknowledged.
    }
  }
}
