import 'package:flutter/material.dart';

import 'coqui_colors.dart';

/// Builds Material [ColorScheme] instances from the Coqui brand palette.
///
/// Maps the website's semantic tokens (primary, accent, muted, surface, etc.)
/// to Material's [ColorScheme] roles as closely as possible.
abstract final class CoquiColorScheme {
  static ColorScheme light() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: CoquiColors.lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: CoquiColors.lightAccent,
      onPrimaryContainer: CoquiColors.lightAccentForeground,
      secondary: CoquiColors.lightSecondary,
      onSecondary: CoquiColors.lightSecondaryForeground,
      secondaryContainer: CoquiColors.lightMuted,
      onSecondaryContainer: CoquiColors.lightMutedForeground,
      tertiary: CoquiColors.lightAccent,
      onTertiary: CoquiColors.lightAccentForeground,
      surface: CoquiColors.lightBackground,
      onSurface: CoquiColors.lightForeground,
      surfaceContainerLowest: CoquiColors.lightBackground,
      surfaceContainerLow: CoquiColors.lightSidebar,
      surfaceContainer: CoquiColors.lightSecondary,
      surfaceContainerHigh: CoquiColors.lightMuted,
      surfaceContainerHighest: CoquiColors.lightBorder,
      onSurfaceVariant: CoquiColors.lightMutedForeground,
      outline: CoquiColors.lightBorder,
      outlineVariant: CoquiColors.lightInput,
      error: CoquiColors.lightDestructive,
      onError: Colors.white,
      shadow: Colors.black,
      inverseSurface: CoquiColors.lightForeground,
      onInverseSurface: CoquiColors.lightBackground,
    );
  }

  static ColorScheme dark() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: CoquiColors.darkPrimary,
      onPrimary: CoquiColors.darkPrimaryForeground,
      primaryContainer: CoquiColors.darkAccent,
      onPrimaryContainer: CoquiColors.darkAccentForeground,
      secondary: CoquiColors.darkSecondary,
      onSecondary: CoquiColors.darkSecondaryForeground,
      secondaryContainer: CoquiColors.darkMuted,
      onSecondaryContainer: CoquiColors.darkMutedForeground,
      tertiary: CoquiColors.darkAccent,
      onTertiary: CoquiColors.darkAccentForeground,
      surface: CoquiColors.darkBackground,
      onSurface: CoquiColors.darkForeground,
      surfaceContainerLowest: CoquiColors.darkBackground,
      surfaceContainerLow: CoquiColors.darkCard,
      surfaceContainer: CoquiColors.darkSecondary,
      surfaceContainerHigh: CoquiColors.darkMuted,
      surfaceContainerHighest: CoquiColors.darkBorder,
      onSurfaceVariant: CoquiColors.darkMutedForeground,
      outline: CoquiColors.darkBorder,
      outlineVariant: CoquiColors.darkInput,
      error: CoquiColors.darkDestructiveForeground,
      onError: CoquiColors.darkDestructive,
      shadow: Colors.black,
      inverseSurface: CoquiColors.darkForeground,
      onInverseSurface: CoquiColors.darkBackground,
    );
  }
}

/// ThemeExtension carrying brand-specific tokens that don't map to Material semantics.
@immutable
class CoquiBrandColors extends ThemeExtension<CoquiBrandColors> {
  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarBorder;
  final Color ring;
  final Color card;
  final Color cardForeground;

  const CoquiBrandColors({
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarBorder,
    required this.ring,
    required this.card,
    required this.cardForeground,
  });

  static const lightInstance = CoquiBrandColors(
    sidebar: CoquiColors.lightSidebar,
    sidebarForeground: CoquiColors.lightSidebarForeground,
    sidebarPrimary: CoquiColors.lightSidebarPrimary,
    sidebarPrimaryForeground: CoquiColors.lightSidebarPrimaryForeground,
    sidebarAccent: CoquiColors.lightSidebarAccent,
    sidebarAccentForeground: CoquiColors.lightSidebarAccentForeground,
    sidebarBorder: CoquiColors.lightSidebarBorder,
    ring: CoquiColors.lightRing,
    card: CoquiColors.lightCard,
    cardForeground: CoquiColors.lightCardForeground,
  );

  static const darkInstance = CoquiBrandColors(
    sidebar: CoquiColors.darkSidebar,
    sidebarForeground: CoquiColors.darkSidebarForeground,
    sidebarPrimary: CoquiColors.darkSidebarPrimary,
    sidebarPrimaryForeground: CoquiColors.darkSidebarPrimaryForeground,
    sidebarAccent: CoquiColors.darkSidebarAccent,
    sidebarAccentForeground: CoquiColors.darkSidebarAccentForeground,
    sidebarBorder: CoquiColors.darkSidebarBorder,
    ring: CoquiColors.darkRing,
    card: CoquiColors.darkCard,
    cardForeground: CoquiColors.darkCardForeground,
  );

  @override
  CoquiBrandColors copyWith({
    Color? sidebar,
    Color? sidebarForeground,
    Color? sidebarPrimary,
    Color? sidebarPrimaryForeground,
    Color? sidebarAccent,
    Color? sidebarAccentForeground,
    Color? sidebarBorder,
    Color? ring,
    Color? card,
    Color? cardForeground,
  }) {
    return CoquiBrandColors(
      sidebar: sidebar ?? this.sidebar,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarPrimaryForeground:
          sidebarPrimaryForeground ?? this.sidebarPrimaryForeground,
      sidebarAccent: sidebarAccent ?? this.sidebarAccent,
      sidebarAccentForeground:
          sidebarAccentForeground ?? this.sidebarAccentForeground,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      ring: ring ?? this.ring,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
    );
  }

  @override
  CoquiBrandColors lerp(CoquiBrandColors? other, double t) {
    if (other == null) return this;
    return CoquiBrandColors(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarForeground:
          Color.lerp(sidebarForeground, other.sidebarForeground, t)!,
      sidebarPrimary: Color.lerp(sidebarPrimary, other.sidebarPrimary, t)!,
      sidebarPrimaryForeground: Color.lerp(
          sidebarPrimaryForeground, other.sidebarPrimaryForeground, t)!,
      sidebarAccent: Color.lerp(sidebarAccent, other.sidebarAccent, t)!,
      sidebarAccentForeground: Color.lerp(
          sidebarAccentForeground, other.sidebarAccentForeground, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
    );
  }
}
