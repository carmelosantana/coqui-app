import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Models/user_profile.dart';
import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Models/hosted_instance.dart';
import 'package:coqui_app/Models/billing_event.dart';
import 'package:coqui_app/Models/region.dart';

void main() {
  group('UserProfile', () {
    test('parses from JSON', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'displayName': 'Test User',
        'githubUsername': 'testuser',
        'image': 'https://github.com/testuser.png',
        'email': 'test@example.com',
        'role': 'user',
        'sshPublicKey': 'ssh-ed25519 AAAA...',
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(profile.id, 1);
      expect(profile.displayName, 'Test User');
      expect(profile.githubUsername, 'testuser');
      expect(profile.email, 'test@example.com');
      expect(profile.role, 'user');
      expect(profile.sshPublicKey, 'ssh-ed25519 AAAA...');
      expect(profile.displayLabel, 'Test User');
    });

    test('displayLabel falls back to GitHub username', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'displayName': null,
        'githubUsername': 'testuser',
        'role': 'user',
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(profile.displayLabel, 'testuser');
    });

    test('displayLabel falls back to User', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'role': 'user',
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(profile.displayLabel, 'User');
    });

    test('handles missing optional fields', () {
      final profile = UserProfile.fromJson({
        'id': 1,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(profile.id, 1);
      expect(profile.displayName, isNull);
      expect(profile.githubUsername, isNull);
      expect(profile.image, isNull);
      expect(profile.email, isNull);
      expect(profile.role, 'user');
      expect(profile.sshPublicKey, isNull);
    });
  });

  group('Plan', () {
    late Plan plan;

    setUp(() {
      plan = Plan.fromJson({
        'id': 1,
        'name': 'lite',
        'displayName': 'Lite',
        'priceInCents': 1500,
        'iapPriceInCents': 1999,
        'stripePriceId': 'price_abc123',
        'iapAppleProductId': 'com.coquibot.lite.monthly',
        'iapGoogleProductId': 'coquibot_lite_monthly',
        'vcpuCount': 1,
        'ramMb': 2048,
        'diskGb': 55,
        'bandwidth': 2,
        'vultrPlan': 'vc2-1c-2gb',
        'maxInstances': 1,
        'isActive': true,
      });
    });

    test('parses from JSON', () {
      expect(plan.id, 1);
      expect(plan.name, 'lite');
      expect(plan.displayName, 'Lite');
      expect(plan.priceInCents, 1500);
      expect(plan.iapPriceInCents, 1999);
      expect(plan.iapAppleProductId, 'com.coquibot.lite.monthly');
      expect(plan.iapGoogleProductId, 'coquibot_lite_monthly');
    });

    test('formattedPrice returns dollar string', () {
      expect(plan.formattedPrice, '\$15.00/mo');
    });

    test('formattedIapPrice returns IAP dollar string', () {
      expect(plan.formattedIapPrice, '\$19.99/mo');
    });

    test('formattedIapPrice returns null when no IAP price', () {
      final p = Plan.fromJson({
        'id': 1,
        'name': 'test',
        'displayName': 'Test',
        'priceInCents': 1500,
        'vcpuCount': 1,
        'ramMb': 1024,
        'diskGb': 25,
        'bandwidth': 1,
        'vultrPlan': 'vc2-1c-1gb',
        'maxInstances': 1,
      });
      expect(p.formattedIapPrice, isNull);
    });

    test('formattedRam converts MB to GB', () {
      expect(plan.formattedRam, '2 GB');
    });

    test('formattedRam shows MB for sub-GB', () {
      final p = Plan.fromJson({
        'id': 1,
        'name': 'test',
        'displayName': 'Test',
        'priceInCents': 500,
        'vcpuCount': 1,
        'ramMb': 512,
        'diskGb': 10,
        'bandwidth': 1,
        'vultrPlan': 'vc2-1c-512mb',
        'maxInstances': 1,
      });
      expect(p.formattedRam, '512 MB');
    });

    test('features returns descriptive list', () {
      expect(plan.features, [
        '1 vCPU',
        '2 GB',
        '55 GB SSD',
        '2 TB bandwidth',
        '1 instance',
      ]);
    });

    test('features pluralizes correctly', () {
      final p = Plan.fromJson({
        'id': 2,
        'name': 'pro',
        'displayName': 'Pro',
        'priceInCents': 5900,
        'vcpuCount': 4,
        'ramMb': 8192,
        'diskGb': 160,
        'bandwidth': 4,
        'vultrPlan': 'vc2-4c-8gb',
        'maxInstances': 3,
      });
      expect(p.features.first, '4 vCPUs');
      expect(p.features.last, '3 instances');
    });
  });

  group('Subscription', () {
    test('parses from JSON', () {
      final sub = Subscription.fromJson({
        'id': 1,
        'status': 'active',
        'stripeSubscriptionId': 'sub_abc123',
        'purchaseSource': 'stripe',
        'currentPeriodStart': '2025-01-01T00:00:00.000Z',
        'currentPeriodEnd': '2025-02-01T00:00:00.000Z',
        'cancelAtPeriodEnd': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
        'plan': {
          'id': 1,
          'name': 'lite',
          'displayName': 'Lite',
        },
      });

      expect(sub.id, 1);
      expect(sub.status, 'active');
      expect(sub.isActive, true);
      expect(sub.isStripe, true);
      expect(sub.isIap, false);
      expect(sub.plan?.name, 'lite');
    });

    test('identifies IAP subscriptions', () {
      final appleSub = Subscription.fromJson({
        'id': 1,
        'status': 'active',
        'purchaseSource': 'apple',
        'cancelAtPeriodEnd': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });
      expect(appleSub.isIap, true);

      final googleSub = Subscription.fromJson({
        'id': 2,
        'status': 'active',
        'purchaseSource': 'google',
        'cancelAtPeriodEnd': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });
      expect(googleSub.isIap, true);
    });

    test('displayStatus shows cancellation', () {
      final sub = Subscription.fromJson({
        'id': 1,
        'status': 'active',
        'purchaseSource': 'stripe',
        'cancelAtPeriodEnd': true,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });
      expect(sub.displayStatus, 'Cancels at period end');
    });

    test('displayStatus shows standard statuses', () {
      expect(
        Subscription.fromJson({
          'id': 1,
          'status': 'active',
          'purchaseSource': 'stripe',
          'cancelAtPeriodEnd': false,
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).displayStatus,
        'Active',
      );
      expect(
        Subscription.fromJson({
          'id': 1,
          'status': 'canceled',
          'purchaseSource': 'stripe',
          'cancelAtPeriodEnd': false,
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).displayStatus,
        'Canceled',
      );
    });

    test('handles missing optional fields', () {
      final sub = Subscription.fromJson({
        'id': 1,
        'status': 'active',
        'cancelAtPeriodEnd': false,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(sub.stripeSubscriptionId, isNull);
      expect(sub.purchaseSource, 'stripe');
      expect(sub.currentPeriodStart, isNull);
      expect(sub.currentPeriodEnd, isNull);
      expect(sub.plan, isNull);
    });
  });

  group('HostedInstance', () {
    test('parses from JSON with full data', () {
      final instance = HostedInstance.fromJson({
        'id': 1,
        'label': 'my-bot',
        'status': 'active',
        'subdomain': 'my-bot-abc123',
        'mainIp': '192.168.1.1',
        'apiPort': 8080,
        'apiKey': 'key_abc123',
        'vultrInstanceId': 'vultr-123',
        'region': 'ewr',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'snapshots': [
          {
            'id': 1,
            'vultrSnapshotId': 'snap-123',
            'description': 'Daily backup',
            'status': 'complete',
            'sizeGb': 55,
            'createdAt': '2025-01-01T00:00:00.000Z',
          },
        ],
        'latestMetric': {
          'id': 1,
          'cpuPercent': 25.5,
          'ramPercent': 60.0,
          'diskPercent': 30.0,
          'recordedAt': '2025-01-01T12:00:00.000Z',
        },
      });

      expect(instance.id, 1);
      expect(instance.label, 'my-bot');
      expect(instance.isActive, true);
      expect(instance.url, 'https://my-bot-abc123.coqui.bot');
      expect(instance.mainIp, '192.168.1.1');
      expect(instance.snapshots.length, 1);
      expect(instance.latestMetric?.cpuPercent, 25.5);
    });

    test('status helpers work correctly', () {
      expect(
        HostedInstance.fromJson({
          'id': 1,
          'label': 'test',
          'status': 'provisioning',
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).isProvisioning,
        true,
      );
      expect(
        HostedInstance.fromJson({
          'id': 1,
          'label': 'test',
          'status': 'stopped',
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).isStopped,
        true,
      );
    });

    test('displayStatus returns human-readable labels', () {
      expect(
        HostedInstance.fromJson({
          'id': 1,
          'label': 't',
          'status': 'active',
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).displayStatus,
        'Running',
      );
      expect(
        HostedInstance.fromJson({
          'id': 1,
          'label': 't',
          'status': 'provisioning',
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).displayStatus,
        'Provisioning...',
      );
    });

    test('url returns null when no subdomain', () {
      final instance = HostedInstance.fromJson({
        'id': 1,
        'label': 'test',
        'status': 'provisioning',
        'createdAt': '2025-01-01T00:00:00.000Z',
      });
      expect(instance.url, isNull);
    });
  });

  group('BillingEvent', () {
    test('parses from JSON', () {
      final event = BillingEvent.fromJson({
        'id': 1,
        'type': 'charge',
        'amountInCents': 1500,
        'currency': 'usd',
        'description': 'Lite plan monthly',
        'stripeInvoiceId': 'inv_abc123',
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(event.id, 1);
      expect(event.formattedAmount, '\$15.00');
      expect(event.displayType, 'Payment');
    });

    test('displayType maps correctly', () {
      expect(
        BillingEvent.fromJson({
          'id': 1,
          'type': 'refund',
          'amountInCents': 500,
          'createdAt': '2025-01-01T00:00:00.000Z',
        }).displayType,
        'Refund',
      );
    });

    test('handles default currency', () {
      final event = BillingEvent.fromJson({
        'id': 1,
        'type': 'charge',
        'amountInCents': 1000,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });
      expect(event.currency, 'usd');
    });
  });

  group('Region', () {
    test('parses from JSON', () {
      final region = Region.fromJson({
        'id': 'ewr',
        'city': 'New Jersey',
        'country': 'US',
        'continent': 'North America',
      });

      expect(region.id, 'ewr');
      expect(region.displayLabel, 'New Jersey, US');
    });
  });

  group('InstanceSnapshot', () {
    test('parses from JSON', () {
      final snap = InstanceSnapshot.fromJson({
        'id': 1,
        'vultrSnapshotId': 'snap-123',
        'description': 'Daily backup',
        'status': 'complete',
        'sizeGb': 55,
        'createdAt': '2025-01-01T00:00:00.000Z',
      });

      expect(snap.id, 1);
      expect(snap.description, 'Daily backup');
      expect(snap.sizeGb, 55);
    });
  });

  group('InstanceMetric', () {
    test('parses from JSON', () {
      final metric = InstanceMetric.fromJson({
        'id': 1,
        'cpuPercent': 45.5,
        'ramPercent': 72.3,
        'diskPercent': 30.0,
        'recordedAt': '2025-01-01T12:00:00.000Z',
      });

      expect(metric.cpuPercent, 45.5);
      expect(metric.ramPercent, 72.3);
      expect(metric.diskPercent, 30.0);
    });

    test('handles integer values', () {
      final metric = InstanceMetric.fromJson({
        'id': 1,
        'cpuPercent': 50,
        'ramPercent': 80,
        'diskPercent': 30,
        'recordedAt': '2025-01-01T12:00:00.000Z',
      });

      expect(metric.cpuPercent, 50.0);
    });
  });
}
