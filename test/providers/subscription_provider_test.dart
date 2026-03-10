import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Providers/subscription_provider.dart';
import 'package:coqui_app/Services/iap_subscription_service.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

void main() {
  group('SubscriptionProvider', () {
    late SaasApiService apiService;
    late IapSubscriptionService iapService;
    late SubscriptionProvider provider;

    setUp(() {
      apiService = SaasApiService(baseUrl: 'https://test.example.com');
      iapService = IapSubscriptionService(apiService: apiService);
      provider = SubscriptionProvider(
        apiService: apiService,
        iapService: iapService,
      );
    });

    test('initial state', () {
      expect(provider.plans, isEmpty);
      expect(provider.activeSubscription, isNull);
      expect(provider.isLoading, false);
      expect(provider.lastError, isNull);
      expect(provider.hasActiveSubscription, false);
      expect(provider.iapStatus, IapStatus.uninitialized);
      expect(provider.isPurchasing, false);
    });

    test('clearError resets error and notifies', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearError();
      expect(provider.lastError, isNull);
      expect(notifyCount, 1);
    });

    test('canPurchaseViaPlan delegates to iap service', () {
      expect(provider.canPurchaseViaPlan(1), false);
      expect(provider.canPurchaseViaPlan(99), false);
    });

    test('getStorePriceForPlan returns null when not available', () {
      expect(provider.getStorePriceForPlan(1), isNull);
    });

    test('hasActiveSubscription reflects subscription status', () {
      expect(provider.hasActiveSubscription, false);
    });

    test('loadSubscription requires auth token', () async {
      // No token set — should be a no-op.
      await provider.loadSubscription();
      expect(provider.activeSubscription, isNull);
    });

    test('purchaseViaPlan clears error first', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.purchaseViaPlan(1);
      // Should have notified at least once for clearError.
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('iapStatus reflects service state', () {
      iapService.status = IapStatus.ready;
      expect(provider.iapStatus, IapStatus.ready);

      iapService.status = IapStatus.noProducts;
      expect(provider.iapStatus, IapStatus.noProducts);
    });
  });

  group('SubscriptionProvider with subscription data', () {
    test('Subscription model integration', () {
      final sub = Subscription(
        id: 1,
        status: 'active',
        purchaseSource: 'apple',
        cancelAtPeriodEnd: false,
        createdAt: DateTime(2024, 1, 1),
        plan: SubscriptionPlan(
          id: 2,
          name: 'pro',
          displayName: 'Pro',
        ),
      );

      expect(sub.isActive, true);
      expect(sub.isIap, true);
      expect(sub.isStripe, false);
      expect(sub.plan?.displayName, 'Pro');
    });

    test('Stripe subscription is correctly identified', () {
      final sub = Subscription(
        id: 2,
        status: 'active',
        stripeSubscriptionId: 'sub_123',
        purchaseSource: 'stripe',
        cancelAtPeriodEnd: false,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(sub.isStripe, true);
      expect(sub.isIap, false);
    });

    test('Google Play subscription is correctly identified', () {
      final sub = Subscription(
        id: 3,
        status: 'active',
        purchaseSource: 'google',
        cancelAtPeriodEnd: false,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(sub.isIap, true);
      expect(sub.isStripe, false);
    });
  });
}
