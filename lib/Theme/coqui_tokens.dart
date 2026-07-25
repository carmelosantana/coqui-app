import 'package:flutter/material.dart';

abstract final class CoquiTokens {
  static const surface = _Surface();
  static const brand = _Brand();
  static const status = _Status();
  static const text = _Text();
  static const border = _Border();
  static const radii = _Radii();

  static const double personaRailWidth = 74;
  static const double sessionRailWidth = 250;
  static const double loopPanelWidth = 300;
  static const double footerBand = 74;
  static const double channelHeader = 52;

  static const Map<String, ({Color bg, Color fg})> personaTint = {
    'caelum': (bg: Color(0xFF2B3A52), fg: Color(0xFFBCD3F0)),
    'nova':   (bg: Color(0xFF3A2B52), fg: Color(0xFFCBBCF0)),
    'iris':   (bg: Color(0xFF52342B), fg: Color(0xFFF0C9BC)),
    'muse':   (bg: Color(0xFF2B5245), fg: Color(0xFFBCF0DD)),
    'sol':    (bg: Color(0xFF4A4426), fg: Color(0xFFEFE3A8)),
  };
}

class _Surface {
  const _Surface();
  final Color personaRail = const Color(0xFF050705);
  final Color sessionRail = const Color(0xFF0A0C0A);
  final Color chatBg      = const Color(0xFF0E110E);
  final Color footerWell  = const Color(0xFF070907);
  final Color card        = const Color(0xFF0C0F0C);
  final Color input       = const Color(0xFF181B12);
  final Color chip        = const Color(0xFF171B12);
  final Color hover       = const Color(0xFF171B12);
  final Color sendResting = const Color(0xFF22271B);
}

class _Brand {
  const _Brand();
  final Color primaryLime  = const Color(0xFFCAE763);
  final Color gradientEnd  = const Color(0xFF74DA5C);
  final Color accentGreen  = const Color(0xFF37B880);
  final Color onPrimary    = const Color(0xFF0A0A0A);
  LinearGradient get limeGradient => const LinearGradient(colors: [Color(0xFFCAE763), Color(0xFF74DA5C)]);
}

class _Status {
  const _Status();
  final Color online  = const Color(0xFF37B880);
  final Color busy    = const Color(0xFFE0B34D);
  final Color idle    = const Color(0xFF5A5F52);
  final Color error   = const Color(0xFFE06A5A);
  final Color warning = const Color(0xFFE0B34D);
}

class _Text {
  const _Text();
  final Color high      = const Color(0xFFE8E8E8);
  final Color body      = const Color(0xFFCFD3C6);
  final Color secondary = const Color(0xFFC7CCBE);
  final Color muted     = const Color(0xFF8A8F80);
  final Color faint     = const Color(0xFF6B6F62);
}

class _Border {
  const _Border();
  final Color hairline      = const Color(0xFF16190F);
  final Color normal        = const Color(0xFF23261F);
  final Color control       = const Color(0xFF2A2E22);
  final Color controlActive = const Color(0xFF2C3020);
  final Color loopCard      = const Color(0xFF23301A);
}

class _Radii {
  const _Radii();
  final double sm = 6, md = 8, card = 10, input = 12, railOrb = 16, pill = 9999;
}
