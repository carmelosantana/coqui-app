import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:coqui_app/Platform/platform_info.dart';

/// Manages supporter status, selected theme, and selected app icon.
///
/// Supporter state is currently local-only and keyed off the persisted
/// `is_supporter` flag while purchase flows are disabled.
class SupporterProvider extends ChangeNotifier {
  final _settingsBox = Hive.box('settings');

  SupporterProvider();

  // ── Hive keys ──────────────────────────────────────────────────────────

  static const _selectedThemeKey = 'selected_theme';
  static const _selectedIconKey = 'selected_icon';
  static const _isSupporterKey = 'is_supporter';

  // ── Error state ────────────────────────────────────────────────────────

  String? _lastError;
  String? get lastError => _lastError;
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ── Supporter status ───────────────────────────────────────────────────

  /// Whether the user has unlocked supporter perks.
  bool get isSupporter =>
      _settingsBox.get(_isSupporterKey, defaultValue: false) == true;

  // ── Theme selection ────────────────────────────────────────────────────

  /// The currently selected supporter theme name, or `null` for default.
  String? get selectedTheme {
    if (!isSupporter) return null;
    return _settingsBox.get(_selectedThemeKey) as String?;
  }

  void setTheme(String? themeName) {
    if (!isSupporter) return;
    if (themeName == null) {
      _settingsBox.delete(_selectedThemeKey);
    } else {
      _settingsBox.put(_selectedThemeKey, themeName);
    }
    notifyListeners();
  }

  // ── Icon selection (iOS only) ──────────────────────────────────────────

  static const _iconChannel = MethodChannel('ai.coquibot.app/icon');

  /// The currently selected alternate icon name, or `null` for default.
  String? get selectedIcon {
    if (!isSupporter) return null;
    return _settingsBox.get(_selectedIconKey) as String?;
  }

  Future<void> setIcon(String? iconName) async {
    if (!isSupporter || !PlatformInfo.isIOS) return;
    try {
      await _iconChannel.invokeMethod('setAlternateIcon', iconName);
      if (iconName == null) {
        _settingsBox.delete(_selectedIconKey);
      } else {
        _settingsBox.put(_selectedIconKey, iconName);
      }
      notifyListeners();
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Failed to change app icon.';
      notifyListeners();
    }
  }
}
