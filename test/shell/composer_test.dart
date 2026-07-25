import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/shell/chat/composer.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

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

  final List<String> sentPrompts = [];
  final List<PlatformFile> attached = [];

  @override
  Future<void> sendPrompt(String text) async {
    sentPrompts.add(text);
  }

  @override
  Future<void> attachFiles(List<PlatformFile> files) async {
    attached.addAll(files);
  }
}

Future<void> _pump(WidgetTester tester, _FakeChatProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ChatProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(body: Composer()),
      ),
    ),
  );
}

BoxDecoration _sendDeco(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(const ValueKey('composer-send')),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration as BoxDecoration;
}

BoxDecoration _loopDeco(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(const ValueKey('composer-loop')),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration as BoxDecoration;
}

void main() {
  testWidgets('send button rests then turns lime when input non-empty',
      (tester) async {
    await _pump(tester, _FakeChatProvider());

    expect(_sendDeco(tester).color, CoquiTokens.surface.sendResting);

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      'hi',
    );
    await tester.pump();

    expect(_sendDeco(tester).color, CoquiTokens.brand.primaryLime);
  });

  testWidgets('tapping send calls sendPrompt and clears the input',
      (tester) async {
    final provider = _FakeChatProvider();
    await _pump(tester, provider);

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      'hi',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pump();

    expect(provider.sentPrompts, ['hi']);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('composer-input')))
          .controller!
          .text,
      isEmpty,
    );
    // Send button returns to resting after clearing.
    expect(_sendDeco(tester).color, CoquiTokens.surface.sendResting);
  });

  testWidgets('tapping send while empty is a no-op', (tester) async {
    final provider = _FakeChatProvider();
    await _pump(tester, provider);

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pump();

    expect(provider.sentPrompts, isEmpty);
  });

  testWidgets('loop button toggles its active lime fill', (tester) async {
    await _pump(tester, _FakeChatProvider());

    expect(_loopDeco(tester).color, isNot(CoquiTokens.brand.primaryLime));

    await tester.tap(find.byKey(const ValueKey('composer-loop')));
    await tester.pump();

    expect(_loopDeco(tester).color, CoquiTokens.brand.primaryLime);
  });
}
