import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_profile_preference_schema.dart';
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
            id: 'persona_caelum',
            version: 1,
            avatar: {'tint': '#2b3a52', 'image_ref': null},
            soul: '# Caelum\n\nA calm companion.',
            preferenceDocument: {
              'prompt_directives': {
                'response_style': 'structured and measured',
                'collaboration': 'call out risks and assumptions early',
              },
              'behavior': {
                'planning_mode': 'deliberate',
                'critique_mode': false,
              },
              'prompts': {
                'features': {
                  'artifacts': true,
                  'projects': true,
                  'loops': true,
                  'todos': true,
                  'background_tasks': false,
                },
                'roles': {
                  'allow': ['orchestrator', 'analyst'],
                  'deny': [],
                },
                'prompt_sections': {
                  'tools': 'stub',
                },
              },
            },
            preferenceValues: {
              'prompt_directives': {
                'response_style': 'structured and measured',
                'collaboration': 'call out risks and assumptions early',
              },
              'behavior': {
                'planning_mode': 'deliberate',
                'critique_mode': false,
              },
              'prompts': {
                'features': {
                  'artifacts': true,
                  'projects': true,
                  'loops': true,
                  'todos': true,
                  'background_tasks': false,
                },
                'roles': {
                  'allow': ['orchestrator', 'analyst'],
                  'deny': [],
                },
              },
            },
          ),
          ...?profiles,
        };

  final Map<String, CoquiProfile> _profiles;
  final bool failDetailLookup;
  final bool failBackstoryLookup;
  final Map<String, String> _backstoryEntries = {
    'intro.md': '# Intro\n\nCaelum remembers quiet walks and long memory fragments.',
  };
  final Set<String> _backstoryFolders = {'', 'timeline'};
  String? lastUpdatedDescription;
  String? lastUpdatedSoul;

  @override
  Future<CoquiProfilePreferenceSchema> getProfilePreferenceSchema() async {
    return CoquiProfilePreferenceSchema.fromJson({
      'version': 1,
      'sections': [
        {
          'id': 'communication_style',
          'label': 'Communication Style',
          'description': 'How the profile speaks, collaborates, and frames feedback.',
          'fields': [
            {
              'id': 'response_style',
              'label': 'Response Style',
              'storage_path': 'prompt_directives.response_style',
              'input': 'suggested_text',
              'description': 'Choose how the profile should sound in normal replies.',
              'suggestions': ['structured and measured', 'brief and exact'],
            },
            {
              'id': 'collaboration',
              'label': 'Collaboration Style',
              'storage_path': 'prompt_directives.collaboration',
              'input': 'suggested_text',
              'description': 'Guide how the profile should work with the user while solving problems.',
              'suggestions': ['call out risks and assumptions early'],
            },
          ],
        },
        {
          'id': 'planning_reasoning',
          'label': 'Planning and Reasoning',
          'description': 'How the profile evaluates tradeoffs, plans work, and applies critique.',
          'fields': [
            {
              'id': 'planning_mode',
              'label': 'Planning Mode',
              'storage_path': 'behavior.planning_mode',
              'input': 'select',
              'description': 'Choose how structured the profile should be before acting.',
              'options': ['deliberate', 'structured'],
            },
            {
              'id': 'critique_mode',
              'label': 'Critique Mode',
              'storage_path': 'behavior.critique_mode',
              'input': 'toggle',
              'description': 'When enabled, the profile leans harder into critical review and challenge.',
            },
          ],
        },
        {
          'id': 'capabilities_tools',
          'label': 'Capabilities and Tools',
          'description': 'Control which major workflow features this profile can actively use.',
          'fields': [
            {
              'id': 'background_tasks',
              'label': 'Background Tasks',
              'storage_path': 'prompts.features.background_tasks',
              'input': 'toggle',
              'description': 'Allow background tasks and deferred execution.',
            },
          ],
        },
        {
          'id': 'roles_autonomy',
          'label': 'Roles and Autonomy',
          'description': 'Constrain which roles the profile can use or explicitly block.',
          'fields': [
            {
              'id': 'allow_roles',
              'label': 'Allowed Roles',
              'storage_path': 'prompts.roles.allow',
              'input': 'multi_select',
              'description': 'Allowed roles.',
              'options': [
                {'value': 'orchestrator', 'label': 'Orchestrator'},
                {'value': 'analyst', 'label': 'Analyst'},
                {'value': 'reviewer', 'label': 'Reviewer'},
              ],
            },
          ],
        },
      ],
      'deferred': {
        'advanced_editor': true,
        'unsupported_fields_hidden': true,
      },
    });
  }

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
    int? version,
  }) async {
    final current = _profiles[name]!;
    lastUpdatedDescription = description;
    lastUpdatedSoul = soul;
    final updated = current.copyWith(
      description: description ?? current.description,
      soul: soul ?? current.soul,
      preferences: clearPreferences
          ? const <String, dynamic>{}
          : (preferences ?? current.preferences),
      preferenceDocument: clearPreferences
          ? const <String, dynamic>{}
          : (preferences ?? current.preferenceDocument),
      preferenceValues: preferences == null
          ? current.preferenceValues
          : {
              'prompt_directives': Map<String, dynamic>.from(
                preferences['prompt_directives'] as Map? ?? const {},
              ),
              'behavior': Map<String, dynamic>.from(
                preferences['behavior'] as Map? ?? const {},
              ),
              'prompts': {
                'features': Map<String, dynamic>.from(
                  ((preferences['prompts'] as Map?)?['features'] as Map?) ??
                      const {},
                ),
                'roles': {
                  'allow': List<String>.from(
                    (((preferences['prompts'] as Map?)?['roles'] as Map?)?['allow']
                            as List?) ??
                        const [],
                  ),
                  'deny': List<String>.from(
                    (((preferences['prompts'] as Map?)?['roles'] as Map?)?['deny']
                            as List?) ??
                        const [],
                  ),
                },
              },
            },
    );
    _profiles[name] = updated;
    return updated;
  }

  @override
  Future<void> deleteProfile(String name, {int? version}) async {
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
    return CoquiBackstoryInspection(
      profile: name,
      available: true,
      reason: null,
      sourceFolder: 'profiles/$name/backstory',
      generatedBackstoryPath: 'profiles/$name/backstory.md',
      sourceFolderExists: true,
      hasGeneratedBackstory: true,
      generatedAt: '2026-05-10T12:00:00Z',
      lastModifiedAt: '2026-05-10T12:00:00Z',
      contentHash: 'abc123',
      needsRegeneration: false,
      totalFiles: 3,
      supportedFileCount: _backstoryEntries.length,
      successfulFileCount: _backstoryEntries.length,
      unsupportedFileCount: 0,
      failedFileCount: 0,
      totalTokens: 420,
      totalSizeBytes: 1024,
      content:
          '# Backstory\n\nCaelum remembers quiet walks and long memory fragments.',
      files: _backstoryEntries.entries
          .map(
            (entry) => {
              'path': 'profiles/$name/backstory/${entry.key}',
              'relative_path': entry.key,
              'token_estimate': 120,
              'size_bytes': entry.value.length,
              'status': 'supported',
            },
          )
          .toList(growable: false),
      folders: _backstoryFolders
          .map(
            (path) => {
              'path': path,
              'file_count': path.isEmpty
                  ? _backstoryEntries.length
                  : _backstoryEntries.keys.where((entry) => entry.startsWith('$path/')).length,
            },
          )
          .toList(growable: false),
      unsupportedFiles: [],
      errors: [],
    );
  }

  @override
  Future<String> getProfileBackstoryEntry(
    String profileName, {
    required String path,
  }) async {
    final content = _backstoryEntries[path];
    if (content == null) {
      throw CoquiException('Not found', statusCode: 404, code: 'not_found');
    }
    return content;
  }

  @override
  Future<CoquiBackstoryInspection> createProfileBackstoryFolder(
    String profileName, {
    required String path,
  }) async {
    _backstoryFolders.add(path);
    return inspectProfileBackstory(profileName);
  }

  @override
  Future<CoquiBackstoryInspection> upsertProfileBackstoryEntry(
    String profileName, {
    required String path,
    required String content,
  }) async {
    final segments = path.split('/');
    if (segments.length > 1) {
      _backstoryFolders.add(segments.sublist(0, segments.length - 1).join('/'));
    }
    _backstoryEntries[path] = content;
    return inspectProfileBackstory(profileName);
  }

  @override
  Future<CoquiBackstoryInspection> deleteProfileBackstoryEntry(
    String profileName, {
    required String path,
  }) async {
    _backstoryEntries.remove(path);
    return inspectProfileBackstory(profileName);
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

  Widget buildRouteSubject({
    required InstanceProvider instanceProvider,
    required ProfileProvider profileProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InstanceProvider>.value(value: instanceProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfilesPage(),
                    ),
                  );
                },
                child: const Text('Open Profiles'),
              ),
            ),
          ),
        ),
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

  testWidgets('profile workspace renders curated preference sections',
      (tester) async {
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

    expect(find.text('Communication Style'), findsOneWidget);
    expect(find.text('Planning and Reasoning'), findsOneWidget);
    expect(find.text('Capabilities and Tools'), findsOneWidget);
    expect(find.text('Roles and Autonomy'), findsOneWidget);
    expect(find.text('structured and measured'), findsOneWidget);
    expect(find.text('deliberate'), findsOneWidget);
    expect(find.text('Disabled'), findsWidgets);
    expect(find.text('orchestrator, analyst'), findsOneWidget);
    expect(find.text('is_valid'), findsNothing);
    expect(find.text('validation_errors'), findsNothing);
    expect(find.text('prompt_sections'), findsNothing);
  });

  testWidgets('profile workspace can edit curated preference sections',
      (tester) async {
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

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Edit').first);
    await tester.tap(find.widgetWithText(FilledButton, 'Edit').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey('preference-field-prompt_directives.response_style'),
      ),
      'brief and exact',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    final updatedDetail = profileProvider.detailFor('caelum');

    expect(find.text('brief and exact'), findsOneWidget);
    expect(
      updatedDetail?.preferenceValues?['prompt_directives']?['response_style'],
      'brief and exact',
    );
    expect(
      updatedDetail?.preferenceDocument?['prompts']?['prompt_sections']?['tools'],
      'stub',
    );
  });

  testWidgets('profile workspace can edit backstory source files',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
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

    await tester.ensureVisible(find.byTooltip('Edit source file').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit source file').first);
    await tester.pumpAndSettle();
    final entryDialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(
      entryDialogFields.at(1),
      '# Intro\n\nUpdated backstory source content.',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(
      profileProvider.backstoryEntryContentFor('caelum', 'intro.md'),
      '# Intro\n\nUpdated backstory source content.',
    );
  });

  testWidgets('profile workspace creates folders and files in folder context',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3400));
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

    await tester.ensureVisible(find.byKey(const ValueKey('backstory-folder-timeline')));
    await tester.tap(find.byKey(const ValueKey('backstory-folder-timeline')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Create Folder'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create Folder'));
    await tester.pumpAndSettle();
    expect(find.text('timeline'), findsWidgets);

    final folderField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(folderField, 'childhood');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('backstory-folder-timeline/childhood')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('backstory-folder-timeline/childhood')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New Source File'));
    await tester.pumpAndSettle();
    expect(find.text('timeline/childhood'), findsWidgets);

    final entryDialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(entryDialogFields.at(0), 'memories.md');
    await tester.enterText(
      entryDialogFields.at(1),
      '# Memories\n\nOrganized from the selected folder.',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(
      profileProvider.backstoryEntryContentFor(
        'caelum',
        'timeline/childhood/memories.md',
      ),
      '# Memories\n\nOrganized from the selected folder.',
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

  testWidgets('leaving profiles page prompts for unsaved changes',
      (tester) async {
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

    await tester.pumpWidget(buildRouteSubject(
      instanceProvider: instanceProvider,
      profileProvider: profileProvider,
    ));
    await tester.tap(find.text('Open Profiles'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    instanceProvider.pauseForDestructiveReset();

    await tester.enterText(
      find.byKey(const ValueKey('profile-description-field')),
      'Unsaved page exit change.',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Unsaved profile changes'), findsOneWidget);
    expect(find.text('Profiles'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Profiles'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Open Profiles'), findsOneWidget);
  });
}
