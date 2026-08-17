import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coqui_app/Models/runtime_config.dart';
import 'package:coqui_app/Services/instance_service.dart';

const _origin = 'http://coqui.example:8080';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('coqui-app-instance-seed-');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    if (Hive.isBoxOpen('instances')) {
      await Hive.box('instances').clear();
      await Hive.box('instances').close();
    }
    if (await Hive.boxExists('instances')) {
      await Hive.deleteBoxFromDisk('instances');
    }
    await tempDir.delete(recursive: true);
  });

  test('without a bundled config the default instance is unchanged', () async {
    final service = InstanceService();
    await service.initialize();
    await service.ensureDefaultInstance();

    final instances = service.getInstances();
    expect(instances, hasLength(1));
    expect(instances.single.name, 'Local Coqui');
    expect(instances.single.baseUrl, 'http://localhost:3300');
    expect(instances.single.apiVersion, 'v1');
    expect(instances.single.apiKey, '');
    expect(instances.single.isActive, isTrue);
    expect(service.getActiveInstance()?.baseUrl, 'http://localhost:3300');
  });

  test('an explicitly not-bundled config seeds the same default', () async {
    final service = InstanceService(runtimeConfig: RuntimeConfig.notBundled);
    await service.initialize();
    await service.ensureDefaultInstance();

    expect(service.getInstances().single.baseUrl, 'http://localhost:3300');
  });

  test('a bundled config seeds an active same-origin instance', () async {
    final service = InstanceService(
      runtimeConfig: const RuntimeConfig(
        bundled: true,
        baseUrl: _origin,
        apiVersion: 'v1',
      ),
    );
    await service.initialize();
    await service.ensureDefaultInstance();

    final instances = service.getInstances();
    expect(instances, hasLength(1));
    expect(instances.single.name, InstanceService.bundledInstanceName);
    expect(instances.single.baseUrl, _origin);
    expect(instances.single.apiVersion, 'v1');
    expect(instances.single.apiKey, '');
    expect(instances.single.isActive, isTrue);
    expect(service.getActiveInstance()?.baseUrl, _origin);
  });

  test('a bundled config carries a non-default api version through', () async {
    final service = InstanceService(
      runtimeConfig: const RuntimeConfig(
        bundled: true,
        baseUrl: _origin,
        apiVersion: 'v2',
      ),
    );
    await service.initialize();
    await service.ensureDefaultInstance();

    expect(service.getInstances().single.apiVersion, 'v2');
  });

  test('seeding is idempotent and never duplicates', () async {
    final service = InstanceService(
      runtimeConfig: const RuntimeConfig(bundled: true, baseUrl: _origin),
    );
    await service.initialize();
    await service.ensureDefaultInstance();
    await service.ensureDefaultInstance();

    expect(service.getInstances(), hasLength(1));
  });

  test('a bundled config with no base url falls back to the default', () async {
    final service = InstanceService(
      runtimeConfig: const RuntimeConfig(bundled: true),
    );
    await service.initialize();
    await service.ensureDefaultInstance();

    expect(service.getInstances().single.baseUrl, 'http://localhost:3300');
  });
}
