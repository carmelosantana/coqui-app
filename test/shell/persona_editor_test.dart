import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Pages/shell/popovers/persona_editor.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class _FakeProfileProvider extends ProfileProvider {
  _FakeProfileProvider()
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));

  String? createdName;
  String? createdSoul;
  Map<String, dynamic>? createdPrefs;

  @override
  List<CoquiProfile> get profiles => const [];

  @override
  Future<CoquiProfile?> createProfile({
    required String name,
    String? description,
    String? soul,
    String? backstory,
    Map<String, dynamic>? preferences,
  }) async {
    createdName = name;
    createdSoul = soul;
    createdPrefs = preferences;
    return null;
  }
}

class _FakeRoleProvider extends RoleProvider {
  _FakeRoleProvider(this._roles)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));

  final List<CoquiRole> _roles;

  @override
  List<CoquiRole> get roles => _roles;

  @override
  Future<void> fetchRoles() async {}
}

Future<void> _pump(
  WidgetTester tester,
  _FakeProfileProvider profiles,
  _FakeRoleProvider roles,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profiles),
        ChangeNotifierProvider<RoleProvider>.value(value: roles),
      ],
      child: const MaterialApp(
        home: Scaffold(body: PersonaEditor()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final roles = [
    CoquiRole(name: 'planner', displayName: 'Planner', model: 'gpt-5'),
    CoquiRole(name: 'coder', displayName: 'Coder', model: 'gpt-5'),
  ];

  testWidgets('create records name, soul, model and selected roles',
      (tester) async {
    final profiles = _FakeProfileProvider();
    await _pump(tester, profiles, _FakeRoleProvider(roles));

    await tester.enterText(
      find.byKey(const ValueKey('persona-name')),
      'Sol',
    );
    await tester.enterText(
      find.byKey(const ValueKey('persona-model')),
      'gpt-5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('persona-soul')),
      '# Sol',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('role-planner')));
    await tester.tap(find.byKey(const ValueKey('role-coder')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('persona-editor-save')));
    await tester.pump();

    expect(profiles.createdName, 'Sol');
    expect(profiles.createdSoul, '# Sol');
    expect(profiles.createdPrefs, isNotNull);
    expect(profiles.createdPrefs!['model'], 'gpt-5');
    final allowed = profiles.createdPrefs!['allowed_roles'] as List;
    expect(allowed, containsAll(<String>['planner', 'coder']));
  });

  testWidgets('save is disabled while the name is empty', (tester) async {
    final profiles = _FakeProfileProvider();
    await _pump(tester, profiles, _FakeRoleProvider(roles));

    // No name entered — tapping save must be a no-op.
    await tester.tap(find.byKey(const ValueKey('persona-editor-save')));
    await tester.pump();

    expect(profiles.createdName, isNull);

    // Once a name is present, save fires.
    await tester.enterText(
      find.byKey(const ValueKey('persona-name')),
      'Nova',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('persona-editor-save')));
    await tester.pump();

    expect(profiles.createdName, 'Nova');
  });
}
