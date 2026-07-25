import 'package:flutter/material.dart';

/// Typography matching the website's design system.
/// Uses bundled Geist Sans (body) and Geist Mono (code/labels).
/// Fonts are shipped as assets — no network dependency.
abstract final class CoquiTypography {
  static const String fontFamily = 'Geist';
  static const String monoFontFamily = 'GeistMono';

  /// Body/display text theme using Geist Sans.
  static TextTheme textTheme(TextTheme base) {
    return base.apply(fontFamily: fontFamily);
  }

  /// Monospace text style using Geist Mono — for code, role labels, etc.
  static TextStyle monoStyle([TextStyle? base]) {
    return (base ?? const TextStyle()).copyWith(fontFamily: monoFontFamily);
  }

  /// Compact monospace label style built from scratch — for mono chips,
  /// status labels, and metadata rendered in Geist Mono.
  static TextStyle mono({
    double size = 10.5,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
