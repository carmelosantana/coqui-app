import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/shell/coqui_shell.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';

class _FakeProfileProvider extends ProfileProvider {
  _FakeProfileProvider(this._list)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final List<CoquiProfile> _list;
  @override
  List<CoquiProfile> get profiles => _list;
  @override
  Future<void> fetchProfiles() async {}
}

/// Counts fetch calls and always reports an empty list, so the strip's
/// initState fetch fires exactly once.
class _CountingProfileProvider extends ProfileProvider {
  _CountingProfileProvider()
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  int fetchCount = 0;
  @override
  List<CoquiProfile> get profiles => const [];
  @override
  Future<void> fetchProfiles() async {
    fetchCount++;
  }
}

class _InMemoryDatabaseService extends DatabaseService {
  @override
  Future<void> open(String databaseFile) async {}
  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async => const [];
  @override
  Future<List<CoquiMessage>> getMessages(String sessionId) async => const [];
}

class _FakeChatProvider extends ChatProvider {
  _FakeChatProvider()
      : super(
          apiService: CoquiApiService(baseUrl: 'http://localhost:0'),
          databaseService: _InMemoryDatabaseService(),
        );
  @override
  List<CoquiSession> get sessions => const [];
  @override
  bool isSessionStreaming(String id) => false;
}

class _FakeRoleProvider extends RoleProvider {
  _FakeRoleProvider()
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  @override
  Future<void> fetchRoles() async {}
}

class _FakeLoopProvider extends LoopProvider {
  _FakeLoopProvider()
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  @override
  Future<void> fetchLoops({String? status, bool silent = false}) async {}
  @override
  Future<void> fetchDefinitions({bool force = false}) async {}
}

Widget _wrap() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfileProvider>.value(
        value: _FakeProfileProvider(const [
          CoquiProfile(name: 'orchestrator', displayName: 'Home', isDefault: true),
          CoquiProfile(name: 'nova', displayName: 'Nova'),
        ]),
      ),
      ChangeNotifierProvider<ChatProvider>.value(value: _FakeChatProvider()),
      ChangeNotifierProvider<RoleProvider>.value(value: _FakeRoleProvider()),
      ChangeNotifierProvider<LoopProvider>.value(value: _FakeLoopProvider()),
      ChangeNotifierProvider(create: (_) => ShellController()),
    ],
    child: const MaterialApp(home: CoquiShell()),
  );
}

void main() {
  testWidgets('mobile shell shows persona strip and hides desktop side rails',
      (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_wrap());
    await t.pump();

    // The mobile scaffold and horizontal persona strip are present.
    expect(find.byKey(const ValueKey('mobile-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('persona-strip')), findsOneWidget);

    // The desktop side rails are absent: the persona rail never mounts, and the
    // session rail lives inside the closed drawer.
    expect(find.byKey(const ValueKey('persona-rail')), findsNothing);
    expect(find.byKey(const ValueKey('session-rail')), findsNothing);

    // A menu button is available to open the drawer.
    expect(find.byKey(const ValueKey('mobile-menu')), findsOneWidget);
  });

  testWidgets('mobile persona strip fetches profiles exactly once', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final profileProvider = _CountingProfileProvider();
    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: _FakeChatProvider()),
        ChangeNotifierProvider<RoleProvider>.value(value: _FakeRoleProvider()),
        ChangeNotifierProvider<LoopProvider>.value(value: _FakeLoopProvider()),
        ChangeNotifierProvider(create: (_) => ShellController()),
      ],
      child: const MaterialApp(home: CoquiShell()),
    ));
    // Let the post-frame callback run.
    await t.pump();

    expect(find.byKey(const ValueKey('persona-strip')), findsOneWidget);
    expect(profileProvider.fetchCount, 1);

    // A rebuild must not re-trigger the fetch (initState-bound, no loop).
    await t.pump();
    expect(profileProvider.fetchCount, 1);
  });
}
