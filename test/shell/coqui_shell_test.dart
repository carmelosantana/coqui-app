import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:coqui_app/Pages/shell/coqui_shell.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

void main() {
  testWidgets('desktop shell shows persona + session rails', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => ShellController(),
      child: const MaterialApp(home: CoquiShell()),
    ));
    expect(find.byKey(const ValueKey('persona-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-rail')), findsOneWidget);
    final w = t.getSize(find.byKey(const ValueKey('persona-rail'))).width;
    expect(w, CoquiTokens.personaRailWidth);
  });
}
