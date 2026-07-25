import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

void main() {
  test('brand + layout tokens match spec', () {
    expect(CoquiTokens.brand.primaryLime, const Color(0xFFCAE763));
    expect(CoquiTokens.surface.chatBg, const Color(0xFF0E110E));
    expect(CoquiTokens.personaRailWidth, 74);
    expect(CoquiTokens.sessionRailWidth, 250);
    expect(CoquiTokens.loopPanelWidth, 300);
    expect(CoquiTokens.footerBand, 74);
    expect(CoquiTokens.personaTint['nova']!.bg, const Color(0xFF3A2B52));
  });
}
