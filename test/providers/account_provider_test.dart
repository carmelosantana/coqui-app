import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Models/billing_event.dart';

void main() {
  group('AccountProvider data models', () {
    test('hasSubscription logic with active subscription', () {
      final sub = Subscription.fromJson({
        'id': 1,
        'status': 'active',
        'purchaseSource': 'stripe',
        'cancelAtPeriodEnd': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(sub.isActive, true);
      expect(sub.isCanceled, false);
      expect(sub.isStripe, true);
      expect(sub.isIap, false);
    });

    test('hasSubscription logic with canceled subscription', () {
      final sub = Subscription.fromJson({
        'id': 1,
        'status': 'canceled',
        'purchaseSource': 'apple',
        'cancelAtPeriodEnd': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(sub.isActive, false);
      expect(sub.isCanceled, true);
      expect(sub.isIap, true);
    });

    test('plans formatting for account display', () {
      final plans = [
        Plan.fromJson({
          'id': 1,
          'name': 'lite',
          'displayName': 'Lite',
          'priceInCents': 1500,
          'iapPriceInCents': 1999,
          'vcpuCount': 1,
          'ramMb': 2048,
          'diskGb': 55,
          'bandwidth': 2,
          'vultrPlan': 'vc2-1c-2gb',
          'maxInstances': 1,
        }),
        Plan.fromJson({
          'id': 2,
          'name': 'pro',
          'displayName': 'Pro',
          'priceInCents': 5900,
          'iapPriceInCents': 7699,
          'vcpuCount': 4,
          'ramMb': 8192,
          'diskGb': 160,
          'bandwidth': 4,
          'vultrPlan': 'vc2-4c-8gb',
          'maxInstances': 3,
        }),
      ];

      expect(plans.length, 2);
      expect(plans[0].formattedPrice, '\$15.00/mo');
      expect(plans[0].formattedIapPrice, '\$19.99/mo');
      expect(plans[1].formattedPrice, '\$59.00/mo');
      expect(plans[1].formattedIapPrice, '\$76.99/mo');
    });

    test('billing events formatting', () {
      final events = [
        BillingEvent.fromJson({
          'id': 1,
          'type': 'charge',
          'amountInCents': 1500,
          'currency': 'usd',
          'description': 'Lite plan monthly',
          'createdAt': '2025-01-01T00:00:00.000Z',
        }),
        BillingEvent.fromJson({
          'id': 2,
          'type': 'refund',
          'amountInCents': 1500,
          'currency': 'usd',
          'description': 'Refund for Lite plan',
          'createdAt': '2025-01-02T00:00:00.000Z',
        }),
      ];

      expect(events[0].displayType, 'Payment');
      expect(events[0].formattedAmount, '\$15.00');
      expect(events[1].displayType, 'Refund');
    });
  });
}
