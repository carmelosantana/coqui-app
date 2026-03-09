import 'package:flutter/material.dart';

import 'coqui_colors.dart';
import 'coqui_color_scheme.dart';
import 'coqui_typography.dart';

/// Central theme factory for the Coqui app.
///
/// Composes brand colors, Geist typography, and component-level overrides
/// to produce a shadcn-inspired flat/bordered Material 3 theme.
abstract final class CoquiTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme =
        isLight ? CoquiColorScheme.light() : CoquiColorScheme.dark();
    final brandColors = isLight
        ? CoquiBrandColors.lightInstance
        : CoquiBrandColors.darkInstance;

    final borderColor =
        isLight ? CoquiColors.lightBorder : CoquiColors.darkBorder;
    final cardColor = isLight ? CoquiColors.lightCard : CoquiColors.darkCard;
    final surfaceColor =
        isLight ? CoquiColors.lightBackground : CoquiColors.darkBackground;

    final base = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
    );

    final textTheme = CoquiTypography.textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: surfaceColor,

      // ── Extensions ──────────────────────────────────────────────────────
      extensions: [brandColors],

      // ── AppBar: transparent + border-bottom, no elevation ─────────────
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        shape: Border(
          bottom: BorderSide(
            color: borderColor.withValues(alpha: 0.4),
          ),
        ),
      ),

      // ── Card: flat with border, no shadow ────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
          side: BorderSide(color: borderColor),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input: flat outlined style ───────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),

      // ── Filled button: flat primary ──────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
          ),
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // ── Elevated button: also flat ───────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
          ),
          foregroundColor: colorScheme.onSecondary,
          backgroundColor: colorScheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // ── Outlined button: brand border ────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
          ),
          side: BorderSide(color: borderColor),
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // ── Text button ──────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
          ),
        ),
      ),

      // ── Chip: muted brand colors ─────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.secondary,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusSm),
        ),
        labelStyle: textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Drawer: sidebar colors + border ──────────────────────────────
      drawerTheme: DrawerThemeData(
        elevation: 0,
        backgroundColor: brandColors.sidebar,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: brandColors.sidebarBorder),
        ),
      ),

      // ── Navigation drawer ────────────────────────────────────────────
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: brandColors.sidebar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: brandColors.sidebarAccent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
        ),
      ),

      // ── Dialog: flat bordered ────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
          side: BorderSide(color: borderColor),
        ),
      ),

      // ── Bottom sheet: flat bordered ──────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(CoquiColors.radiusLg),
          ),
          side: BorderSide(color: borderColor),
        ),
      ),

      // ── Popup menu: flat bordered popover ────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
          side: BorderSide(color: borderColor),
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: borderColor.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ─────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
        ),
      ),

      // ── SnackBar ─────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
        ),
      ),

      // ── Icon ─────────────────────────────────────────────────────────
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
      ),

      // ── Progress indicator ──────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
    );
  }
}
