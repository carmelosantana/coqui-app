import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Pages/profiles_page/profile_manager.dart';
import 'package:coqui_app/Pages/profiles_page/profiles_page.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

class _FakeApiService extends CoquiApiService {
  _FakeApiService({
    Map<String, CoquiProfile>? profiles,
    this.failDetailLookup = false,
    this.failBackstoryLookup = false,
  }) : _profiles = {
          'caelum': const CoquiProfile(
            name: 'caelum',
            displayName: 'Caelum',
            description: 'A calm companion.',
            isDefault: true,
            soul: '# Caelum\n\nA calm companion.',
          ),
          ...?profiles,
        };

  final Map<String, CoquiProfile> _profiles;
  final bool failDetailLookup;
  final bool failBackstoryLookup;
  String? lastUpdatedDescription;
  String? lastUpdatedSoul;

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
    if (failDetailLookup) {
      throw CoquiException(
        'Not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
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
    lastUpdatedDescription = description;
    lastUpdatedSoul = soul;
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

  @override
  Future<CoquiBackstoryInspection> inspectProfileBackstory(String name) async {
    if (failBackstoryLookup) {
      throw CoquiException(
        'Not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    return const CoquiBackstoryInspection(
      profile: 'caelum',
      available: true,
      reason: null,
      sourceFolder: 'profiles/caelum/backstory',
      generatedBackstoryPath: 'profiles/caelum/backstory.md',
      sourceFolderExists: true,
      hasGeneratedBackstory: true,
      generatedAt: '2026-05-10T12:00:00Z',
      lastModifiedAt: '2026-05-10T12:00:00Z',
      contentHash: 'abc123',
      needsRegeneration: false,
      totalFiles: 3,
      supportedFileCount: 3,
      successfulFileCount: 3,
      unsupportedFileCount: 0,
      failedFileCount: 0,
      totalTokens: 420,
      totalSizeBytes: 1024,
      content:
          '# Backstory\n\nCaelum remembers quiet walks and long memory fragments.',
      files: [],
      folders: [],
      unsupportedFiles: [],
      errors: [],
    );
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
    required InstanceProvider instanceProvider,
    required ProfileProvider profileProvider,
    Widget child = const ProfilesPage(),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InstanceProvider>.value(value: instanceProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('profiles page renders a first-class profile destination',
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
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    expect(find.text('Profiles'), findsNWidgets(2));
    expect(find.text('Create Profile'), findsOneWidget);
    expect(find.text('Caelum'), findsNWidgets(2));
    expect(find.text('A calm companion.'), findsWidgets);
    expect(find.byKey(const ValueKey('profile-description-field')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-soul-field')), findsOneWidget);
    expect(find.text('Backstory Preview'), findsOneWidget);
    expect(find.textContaining('memory fragments'), findsOneWidget);
  });

  testWidgets('profiles page hides optional not found detail errors',
      (tester) async {
    final apiService = _FakeApiService(
      failDetailLookup: true,
      failBackstoryLookup: true,
    );
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
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    expect(find.text('Not found'), findsNothing);
    expect(find.text('Caelum'), findsWidgets);
    expect(
      find.textContaining('Backstory inspection is unavailable'),
      findsOneWidget,
    );
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

  testWidgets('profile manager can render without a scaffolded page wrapper',
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
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
      child: const Scaffold(
        body: SingleChildScrollView(
          child: ProfileManager(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    expect(find.text('Profiles'), findsOneWidget);
    expect(find.textContaining('continuity'), findsOneWidget);
  });

  testWidgets('selected profile can be edited inline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    final apiService = _FakeApiService();
    final instanceProvider = InstanceProvider(
      instanceService: _FakeInstanceService(),
      apiService: apiService,
    );
    final profileProvider = ProfileProvider(apiService: apiService);

    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      instanceProvider.dispose();
      profileProvider.dispose();
    });

    await tester.pumpWidget(buildSubject(
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    await tester.enterText(
      find.byKey(const ValueKey('profile-description-field')),
      'A steadier collaborative companion.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-soul-field')),
      '# Caelum\n\nA steadier collaborative companion.',
    );
    await tester.tap(find.byKey(const ValueKey('profile-save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      apiService.lastUpdatedDescription,
      'A steadier collaborative companion.',
    );
    expect(
      apiService.lastUpdatedSoul,
      '# Caelum\n\nA steadier collaborative companion.',
    );
  });

  testWidgets('switching profiles prompts for unsaved changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    final apiService = _FakeApiService(
      profiles: {
        'nova': const CoquiProfile(
          name: 'nova',
          displayName: 'Nova',
          description: 'A bold strategist.',
          soul: '# Nova\n\nA bold strategist.',
        ),
      },
    );
    final instanceProvider = InstanceProvider(
      instanceService: _FakeInstanceService(),
      apiService: apiService,
    );
    final profileProvider = ProfileProvider(apiService: apiService);

    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      instanceProvider.dispose();
      profileProvider.dispose();
    });

    await tester.pumpWidget(buildSubject(
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    await tester.enterText(
      find.byKey(const ValueKey('profile-description-field')),
      'A changed description.',
    );
    await tester.tap(find.text('Nova').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Unsaved profile changes'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final descriptionField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('profile-description-field')),
    );
    expect(descriptionField.controller?.text, 'A bold strategist.');
  });
}
