import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/hosted_instance.dart';
import 'package:coqui_app/Providers/hosted_provider.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

void main() {
  group('HostedProvider', () {
    late SaasApiService apiService;
    late HostedProvider provider;

    setUp(() {
      apiService = SaasApiService(baseUrl: 'https://test.example.com');
      provider = HostedProvider(apiService: apiService);
    });

    test('initial state', () {
      expect(provider.instances, isEmpty);
      expect(provider.regions, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('clearError resets error and notifies', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearError();
      expect(provider.error, isNull);
      expect(notifyCount, 1);
    });

    test('loadAll requires auth token', () async {
      // No token set — should be a no-op.
      await provider.loadAll();
      expect(provider.instances, isEmpty);
      expect(provider.isLoading, false);
    });

    test('refreshInstances requires auth token', () async {
      await provider.refreshInstances();
      expect(provider.instances, isEmpty);
    });
  });

  group('HostedInstance model integration', () {
    test('active instance has correct helpers', () {
      final instance = HostedInstance(
        id: 1,
        label: 'my-coqui',
        status: 'active',
        subdomain: 'my-coqui',
        mainIp: '192.168.1.1',
        apiPort: 8080,
        apiKey: 'test-key-1234',
        region: 'ewr',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(instance.isActive, true);
      expect(instance.isProvisioning, false);
      expect(instance.isStopped, false);
      expect(instance.isError, false);
      expect(instance.url, 'https://my-coqui.coqui.bot');
      expect(instance.displayStatus, 'Running');
    });

    test('provisioning instance has correct helpers', () {
      final instance = HostedInstance(
        id: 2,
        label: 'test-coqui',
        status: 'provisioning',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(instance.isActive, false);
      expect(instance.isProvisioning, true);
      expect(instance.url, isNull);
      expect(instance.displayStatus, 'Provisioning...');
    });

    test('instance without subdomain has null URL', () {
      final instance = HostedInstance(
        id: 3,
        label: 'new-instance',
        status: 'installing',
        createdAt: DateTime(2024, 2, 1),
      );

      expect(instance.url, isNull);
      expect(instance.displayStatus, 'Installing...');
    });

    test('instance with snapshots', () {
      final instance = HostedInstance(
        id: 4,
        label: 'backup-test',
        status: 'active',
        createdAt: DateTime(2024, 1, 1),
        snapshots: [
          InstanceSnapshot(
            id: 1,
            vultrSnapshotId: 'snap-abc123',
            description: 'Daily backup',
            status: 'complete',
            sizeGb: 10,
            createdAt: DateTime(2024, 1, 15),
          ),
        ],
      );

      expect(instance.snapshots, hasLength(1));
      expect(instance.snapshots.first.description, 'Daily backup');
      expect(instance.snapshots.first.sizeGb, 10);
    });

    test('instance with latest metric', () {
      final instance = HostedInstance(
        id: 5,
        label: 'metrics-test',
        status: 'active',
        createdAt: DateTime(2024, 1, 1),
        latestMetric: InstanceMetric(
          id: 1,
          cpuPercent: 45.5,
          ramPercent: 62.3,
          diskPercent: 30.0,
          recordedAt: DateTime(2024, 1, 20),
        ),
      );

      expect(instance.latestMetric, isNotNull);
      expect(instance.latestMetric!.cpuPercent, 45.5);
      expect(instance.latestMetric!.ramPercent, 62.3);
    });
  });
}
