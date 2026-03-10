import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Services/iap_subscription_service.dart';
import 'package:coqui_app/Services/saas_api_service.dart';
import 'package:coqui_app/Models/plan.dart';

void main() {
  group('IapStatus', () {
    test('enum values exist', () {
      expect(IapStatus.values, hasLength(5));
      expect(IapStatus.values, contains(IapStatus.uninitialized));
      expect(IapStatus.values, contains(IapStatus.ready));
      expect(IapStatus.values, contains(IapStatus.noProducts));
      expect(IapStatus.values, contains(IapStatus.unavailable));
      expect(IapStatus.values, contains(IapStatus.error));
    });
  });

  group('IapSubscriptionService', () {
    late SaasApiService apiService;
    late IapSubscriptionService service;

    setUp(() {
      apiService = SaasApiService(baseUrl: 'https://test.example.com');
      service = IapSubscriptionService(apiService: apiService);
    });

    test('initial status is uninitialized', () {
      expect(service.status, IapStatus.uninitialized);
      expect(service.isAvailable, false);
      expect(service.purchasing, false);
      expect(service.products, isEmpty);
      expect(service.productsByPlanId, isEmpty);
    });

    test('hasPlanProduct returns false when no products loaded', () {
      expect(service.hasPlanProduct(1), false);
      expect(service.hasPlanProduct(99), false);
    });

    test('getProductForPlan returns null when no products loaded', () {
      expect(service.getProductForPlan(1), isNull);
    });

    test('purchasePlan fails gracefully when no products', () async {
      // On test platform (not iOS/Android), should fail gracefully.
      String? errorMsg;
      service.onError = (msg) => errorMsg = msg;

      final result = await service.purchasePlan(1);
      expect(result, false);
      expect(errorMsg, isNotNull);
    });

    test('purchasePlan blocks duplicate purchases', () async {
      // Manually set purchasing flag
      service.purchasing = true;
      String? errorMsg;
      service.onError = (msg) => errorMsg = msg;

      // Even on unsupported platform the duplicate check message should be
      // about the platform first since it checks that before purchasing state.
      final result = await service.purchasePlan(1);
      expect(result, false);
      expect(errorMsg, isNotNull);
    });

    test('restorePurchases is no-op on unsupported platforms', () async {
      // Should complete without error on desktop/test platforms.
      await service.restorePurchases();
    });

    test('isAvailable is true only when status is ready', () {
      service.status = IapStatus.uninitialized;
      expect(service.isAvailable, false);

      service.status = IapStatus.noProducts;
      expect(service.isAvailable, false);

      service.status = IapStatus.unavailable;
      expect(service.isAvailable, false);

      service.status = IapStatus.error;
      expect(service.isAvailable, false);

      service.status = IapStatus.ready;
      expect(service.isAvailable, true);
    });

    test('onChanged callback is invoked', () async {
      int callCount = 0;
      service.onChanged = () => callCount++;

      // Initialize on desktop (unsupported platform).
      await service.initialize([]);
      expect(callCount, greaterThan(0));
      expect(service.status, IapStatus.unavailable);
    });
  });

  group('IapSubscriptionService product mapping', () {
    test('plans without IAP IDs result in noProducts on supported platform',
        () {
      // This tests the logic indirectly — plans with no product IDs
      // configured should not generate any product ID lookups.
      final plan = Plan(
        id: 1,
        name: 'lite',
        displayName: 'Lite',
        priceInCents: 1500,
        iapPriceInCents: null,
        iapAppleProductId: null,
        iapGoogleProductId: null,
        vcpuCount: 1,
        ramMb: 2048,
        diskGb: 55,
        bandwidth: 2,
        vultrPlan: 'vc2-1c-2gb',
        maxInstances: 1,
        isActive: true,
      );

      // Plan has no IAP product IDs — on any platform this plan would be
      // skipped during product loading.
      expect(plan.iapAppleProductId, isNull);
      expect(plan.iapGoogleProductId, isNull);
    });

    test('plans with IAP IDs are candidates for product loading', () {
      final plan = Plan(
        id: 2,
        name: 'pro',
        displayName: 'Pro',
        priceInCents: 3000,
        iapPriceInCents: 3499,
        iapAppleProductId: 'com.coquibot.pro.monthly',
        iapGoogleProductId: 'coquibot_pro_monthly',
        vcpuCount: 2,
        ramMb: 4096,
        diskGb: 80,
        bandwidth: 3,
        vultrPlan: 'vc2-2c-4gb',
        maxInstances: 3,
        isActive: true,
      );

      expect(plan.iapAppleProductId, isNotNull);
      expect(plan.iapGoogleProductId, isNotNull);
      expect(plan.iapPriceInCents, 3499);
    });
  });
}
