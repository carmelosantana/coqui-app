import 'package:flutter/material.dart';

/// A named color palette defining the 4 core theme colors for both
/// light and dark brightness modes.
class SupporterThemePalette {
  final String name;
  final String label;

  // Light mode
  final Color lightPrimary;
  final Color lightAccent;
  final Color lightSurface;
  final Color lightMuted;

  // Dark mode
  final Color darkPrimary;
  final Color darkAccent;
  final Color darkSurface;
  final Color darkMuted;

  const SupporterThemePalette({
    required this.name,
    required this.label,
    required this.lightPrimary,
    required this.lightAccent,
    required this.lightSurface,
    required this.lightMuted,
    required this.darkPrimary,
    required this.darkAccent,
    required this.darkSurface,
    required this.darkMuted,
  });
}

/// Available supporter themes.
///
/// Each theme provides the 4 core colors (primary, accent, surface, muted)
/// for both light and dark modes. All other ColorScheme roles are
/// derived automatically via [CoquiColorScheme.lightFromPalette] /
/// [CoquiColorScheme.darkFromPalette].
abstract final class SupporterThemes {
  static const cyberpunk = SupporterThemePalette(
    name: 'cyberpunk',
    label: 'Cyberpunk',
    lightPrimary: Color(0xFFE91E8C), // Hot pink
    lightAccent: Color(0xFF00E5FF), // Neon cyan
    lightSurface: Color(0xFFFAFAFA),
    lightMuted: Color(0xFFF0F0F0),
    darkPrimary: Color(0xFFFF2D95), // Neon pink
    darkAccent: Color(0xFF00E5FF), // Neon cyan
    darkSurface: Color(0xFF0D0D1A), // Deep navy-black
    darkMuted: Color(0xFF1A1A2E),
  );

  static const vaporwave = SupporterThemePalette(
    name: 'vaporwave',
    label: 'Vaporwave',
    lightPrimary: Color(0xFF9B59B6), // Purple
    lightAccent: Color(0xFFFF6B9D), // Pink
    lightSurface: Color(0xFFFDF6FF),
    lightMuted: Color(0xFFF3EAF6),
    darkPrimary: Color(0xFFE879F9), // Light purple
    darkAccent: Color(0xFFFF6B9D), // Pink
    darkSurface: Color(0xFF120B18), // Deep purple-black
    darkMuted: Color(0xFF1E1228),
  );

  static const solarized = SupporterThemePalette(
    name: 'solarized',
    label: 'Solarized',
    lightPrimary: Color(0xFF268BD2), // Solarized blue
    lightAccent: Color(0xFFB58900), // Solarized yellow
    lightSurface: Color(0xFFFDF6E3), // Solarized base3
    lightMuted: Color(0xFFEEE8D5), // Solarized base2
    darkPrimary: Color(0xFF268BD2), // Solarized blue
    darkAccent: Color(0xFFB58900), // Solarized yellow
    darkSurface: Color(0xFF002B36), // Solarized base03
    darkMuted: Color(0xFF073642), // Solarized base02
  );

  static const dracula = SupporterThemePalette(
    name: 'dracula',
    label: 'Dracula',
    lightPrimary: Color(0xFF7C3AED), // Dracula purple
    lightAccent: Color(0xFFFF79C6), // Dracula pink
    lightSurface: Color(0xFFFAF9FC),
    lightMuted: Color(0xFFF0EDF5),
    darkPrimary: Color(0xFFBD93F9), // Dracula purple
    darkAccent: Color(0xFFFF79C6), // Dracula pink
    darkSurface: Color(0xFF282A36), // Dracula background
    darkMuted: Color(0xFF343746), // Dracula current line
  );

  static const panda = SupporterThemePalette(
    name: 'panda',
    label: 'Panda',
    lightPrimary: Color(0xFF19B9A0), // Panda teal
    lightAccent: Color(0xFFFF75B5), // Panda pink
    lightSurface: Color(0xFFFAFAFA),
    lightMuted: Color(0xFFF0F0F0),
    darkPrimary: Color(0xFF19B9A0), // Panda teal
    darkAccent: Color(0xFFFFB86C), // Panda orange
    darkSurface: Color(0xFF292A2B), // Panda background
    darkMuted: Color(0xFF3B3C3D),
  );

  /// All available supporter themes, keyed by name.
  static const Map<String, SupporterThemePalette> all = {
    'cyberpunk': cyberpunk,
    'vaporwave': vaporwave,
    'solarized': solarized,
    'dracula': dracula,
    'panda': panda,
  };

  /// Look up a theme by name. Returns `null` for unknown names.
  static SupporterThemePalette? byName(String? name) => all[name];
}
