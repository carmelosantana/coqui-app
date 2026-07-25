import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Theme/coqui_theme.dart';
import 'package:coqui_app/Theme/coqui_typography.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

void main() {
  test('dark theme wires tokens', () {
    final t = CoquiTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, CoquiTokens.surface.chatBg);
    expect(t.colorScheme.primary, CoquiTokens.brand.primaryLime);
  });
  test('mono helper uses GeistMono', () {
    expect(CoquiTypography.mono(size: 10).fontFamily, 'GeistMono');
  });
}
