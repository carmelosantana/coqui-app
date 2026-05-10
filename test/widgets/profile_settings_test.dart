import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Pages/settings_page/subwidgets/profile_settings.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

class _FakeApiService extends CoquiApiService {
  final Map<String, CoquiProfile> _profiles = {
    'caelum': const CoquiProfile(
      name: 'caelum',
      displayName: 'Caelum',
      description: 'A calm companion.',
      isDefault: true,
      soul: '# Caelum\n\nA calm companion.',
    ),
  };

  @override
  Future<Map<String, dynamic>> healthCheck() async => {'status': 'ok'};

  @override
  Future<List<CoquiProfile>> getProfiles() async {
    final profiles = _profiles.values.toList(growable: false)
      ..sort((left, right) => left.label.compareTo(right.label));
    return profiles;
  }

  @override
  Future<CoquiProfile> getProfile(String name) async {
    return _profiles[name]!;
  }

  @override
  Future<CoquiProfile> createProfile({
    required String name,
    String? description,
    String? soul,
    String? backstory,
    Map<String, dynamic>? preferences,
  }) async {
    final profile = CoquiProfile(
      name: name,
      displayName: name[0].toUpperCase() + name.substring(1),
      description: description ?? '',
      soul: soul,
    );
    _profiles[name] = profile;
    return profile;
  }

  @override
  Future<CoquiProfile> updateProfile(
    String name, {
    String? description,
    String? soul,
    String? backstory,
    Map<String, dynamic>? preferences,
    bool clearBackstory = false,
    bool clearPreferences = false,
  }) async {
    final current = _profiles[name]!;
    final updated = current.copyWith(
      description: description ?? current.description,
      soul: soul ?? current.soul,
    );
    _profiles[name] = updated;
    return updated;
  }

  @override
  Future<void> deleteProfile(String name) async {
    _profiles.remove(name);
  }
}

class _FakeInstanceService extends InstanceService {
  final CoquiInstance _instance = CoquiInstance(
    id: 'instance-1',
    name: 'Local Coqui',
    baseUrl: 'http://localhost:3300',
    apiKey: '',
    isActive: true,
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureDefaultInstance() async {}

  @override
  List<CoquiInstance> getInstances() => [_instance];

  @override
  CoquiInstance? getActiveInstance() => _instance;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    required _FakeApiService apiService,
    required InstanceProvider instanceProvider,
    required ProfileProvider profileProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InstanceProvider>.value(value: instanceProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileSettings(),
          ),
        ),
      ),
    );
  }

  testWidgets('profile settings loads and displays discovered profiles',
      (tester) async {
    final apiService = _FakeApiService();
    final instanceProvider = InstanceProvider(
      instanceService: _FakeInstanceService(),
      apiService: apiService,
    );
    final profileProvider = ProfileProvider(apiService: apiService);

    addTearDown(() {
      instanceProvider.dispose();
      profileProvider.dispose();
    });

    await tester.pumpWidget(buildSubject(
      apiService: apiService,
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Create Profile'), findsOneWidget);
    expect(find.text('Caelum'), findsOneWidget);
    expect(find.text('A calm companion.'), findsOneWidget);
  });

  test('profile provider can create and delete a profile', () async {
    final apiService = _FakeApiService();
    final profileProvider = ProfileProvider(apiService: apiService);

    addTearDown(() {
      profileProvider.dispose();
    });

    final created = await profileProvider.createProfile(
      name: 'nova',
      description: 'A bold collaborative strategist.',
    );

    expect(created, isNotNull);
    expect(
      profileProvider.profiles.any((profile) => profile.name == 'nova'),
      isTrue,
    );

    final deleted = await profileProvider.deleteProfile('nova');

    expect(deleted, isTrue);
    expect(
      profileProvider.profiles.any((profile) => profile.name == 'nova'),
      isFalse,
    );
  });
}