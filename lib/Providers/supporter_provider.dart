import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Services/purchase_service.dart';

/// Manages supporter status, selected theme, and selected app icon.
///
/// Perk unlocking is gated behind [isSupporter], which currently checks
/// for one-time donations. Future subscription purchases will also set
/// this flag.
class SupporterProvider extends ChangeNotifier {
  final PurchaseService _purchaseService;
  final _settingsBox = Hive.box('settings');

  SupporterProvider({required PurchaseService purchaseService})
      : _purchaseService = purchaseService {
    _purchaseService.onSupporterStatusChanged = () => notifyListeners();
    _purchaseService.onProductsLoaded = () => notifyListeners();
    _purchaseService.onPurchaseError = (msg) {
      _lastError = msg;
      notifyListeners();
    };
  }

  // ── Hive keys ──────────────────────────────────────────────────────────

  static const _selectedThemeKey = 'selected_theme';
  static const _selectedIconKey = 'selected_icon';

  // ── Error state ────────────────────────────────────────────────────────

  String? _lastError;
  String? get lastError => _lastError;
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ── Supporter status ───────────────────────────────────────────────────

  /// Whether the user has unlocked supporter perks.
  ///
  /// Currently only set by one-time IAP donations. Future subscription
  /// purchases will also grant supporter status.
  bool get isSupporter => _purchaseService.isSupporter;

  // ── Store products ─────────────────────────────────────────────────────

  bool get storeAvailable => _purchaseService.storeAvailable;
  List<ProductDetails> get products => _purchaseService.products;

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

  // ── Purchase actions ───────────────────────────────────────────────────

  Future<void> purchase(String productId) async {
    _lastError = null;
    await _purchaseService.purchase(productId);
  }

  Future<void> restorePurchases() async {
    _lastError = null;
    await _purchaseService.restorePurchases();
  }
}
