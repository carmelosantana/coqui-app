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
import 'package:coqui_app/Theme/coqui_tokens.dart';

class _FakeProfileProvider extends ProfileProvider {
  _FakeProfileProvider(this._list)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final List<CoquiProfile> _list;
  @override
  List<CoquiProfile> get profiles => _list;
  @override
  Future<void> fetchProfiles() async {}
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

void main() {
  testWidgets('desktop shell shows persona + session rails', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(
          value: _FakeProfileProvider(const [
            CoquiProfile(name: 'orchestrator', displayName: 'Home', isDefault: true),
          ]),
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: _FakeChatProvider()),
        ChangeNotifierProvider<RoleProvider>.value(value: _FakeRoleProvider()),
        ChangeNotifierProvider<LoopProvider>.value(value: _FakeLoopProvider()),
        ChangeNotifierProvider(create: (_) => ShellController()),
      ],
      child: const MaterialApp(home: CoquiShell()),
    ));
    expect(find.byKey(const ValueKey('persona-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-rail')), findsOneWidget);
    final w = t.getSize(find.byKey(const ValueKey('persona-rail'))).width;
    expect(w, CoquiTokens.personaRailWidth);
  });
}
