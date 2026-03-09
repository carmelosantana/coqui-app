import 'package:flutter/material.dart';

/// Brand color constants converted from the website's oklch CSS custom properties.
///
/// Light and dark palettes mirror the website's globals.css exactly.
/// Primary and accent swap between light/dark mode for optimal contrast.
abstract final class CoquiColors {
  // ── Light mode ──────────────────────────────────────────────────────────

  static const lightBackground = Color(0xFFFFFFFF); // oklch(1 0 0)
  static const lightForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const lightCard = Color(0xFFFFFFFF); // oklch(1 0 0)
  static const lightCardForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const lightPopover = Color(0xFFFFFFFF); // oklch(1 0 0)
  static const lightPopoverForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const lightPrimary = Color(0xFF278733); // oklch(0.55 0.15 145)
  static const lightPrimaryForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const lightSecondary = Color(0xFFF5F5F5); // oklch(0.97 0 0)
  static const lightSecondaryForeground = Color(0xFF171717); // oklch(0.205 0 0)
  static const lightMuted = Color(0xFFF5F5F5); // oklch(0.97 0 0)
  static const lightMutedForeground = Color(0xFF737373); // oklch(0.556 0 0)
  static const lightAccent = Color(0xFFCAE763); // oklch(0.88 0.16 120)
  static const lightAccentForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const lightDestructive =
      Color(0xFFE7000B); // oklch(0.577 0.245 27.325)
  static const lightBorder = Color(0xFFE5E5E5); // oklch(0.922 0 0)
  static const lightInput = Color(0xFFE5E5E5); // oklch(0.922 0 0)
  static const lightRing = Color(0xFF278733); // oklch(0.55 0.15 145)

  // Sidebar (light)
  static const lightSidebar = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const lightSidebarForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const lightSidebarPrimary = Color(0xFF278733); // oklch(0.55 0.15 145)
  static const lightSidebarPrimaryForeground =
      Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const lightSidebarAccent = Color(0xFFF5F5F5); // oklch(0.97 0 0)
  static const lightSidebarAccentForeground =
      Color(0xFF171717); // oklch(0.205 0 0)
  static const lightSidebarBorder = Color(0xFFE5E5E5); // oklch(0.922 0 0)

  // ── Dark mode ───────────────────────────────────────────────────────────

  static const darkBackground = Color(0xFF030403); // oklch(0.1 0.005 150)
  static const darkForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkCard = Color(0xFF080A08); // oklch(0.14 0.005 150)
  static const darkCardForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkPopover = Color(0xFF080A08); // oklch(0.14 0.005 150)
  static const darkPopoverForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkPrimary = Color(0xFFCAE763); // oklch(0.88 0.16 120)
  static const darkPrimaryForeground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const darkSecondary = Color(0xFF141715); // oklch(0.2 0.005 150)
  static const darkSecondaryForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkMuted = Color(0xFF141715); // oklch(0.2 0.005 150)
  static const darkMutedForeground = Color(0xFFA1A1A1); // oklch(0.708 0 0)
  static const darkAccent = Color(0xFF278733); // oklch(0.55 0.15 145)
  static const darkAccentForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkDestructive = Color(0xFF82181A); // oklch(0.396 0.141 25.723)
  static const darkDestructiveForeground =
      Color(0xFFFB2C36); // oklch(0.637 0.237 25.331)
  static const darkBorder = Color(0xFF191B19); // oklch(0.22 0.005 150)
  static const darkInput = Color(0xFF191B19); // oklch(0.22 0.005 150)
  static const darkRing = Color(0xFFCAE763); // oklch(0.88 0.16 120)

  // Sidebar (dark)
  static const darkSidebar = Color(0xFF080A08); // oklch(0.14 0.005 150)
  static const darkSidebarForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkSidebarPrimary = Color(0xFFCAE763); // oklch(0.88 0.16 120)
  static const darkSidebarPrimaryForeground =
      Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const darkSidebarAccent = Color(0xFF141715); // oklch(0.2 0.005 150)
  static const darkSidebarAccentForeground =
      Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const darkSidebarBorder = Color(0xFF191B19); // oklch(0.22 0.005 150)

  // ── Chart colors (shared) ──────────────────────────────────────────────

  static const chart1 = Color(0xFFCAE763); // oklch(0.88 0.16 120)
  static const chart2 = Color(0xFF74DA5C); // oklch(0.80 0.19 140)
  static const chart3 = Color(0xFF278733); // oklch(0.55 0.15 145)
  static const chart4 = Color(0xFF37B880); // oklch(0.70 0.14 160)
  static const chart5 = Color(0xFF7B9B59); // oklch(0.65 0.10 130)

  // ── Border radius (matches website --radius: 0.625rem = 10px) ─────────

  static const double radius = 10.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 10.0;
  static const double radiusXl = 14.0;
}
