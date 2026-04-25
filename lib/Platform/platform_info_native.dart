import 'dart:io' show Platform;

/// Native platform detection — delegates to `dart:io` Platform.
class PlatformInfo {
  PlatformInfo._();

  static bool get isWeb => false;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isWindows => Platform.isWindows;
  static bool get isFuchsia => Platform.isFuchsia;

  /// True on iOS or Android.
  static bool get isMobile => isAndroid || isIOS;

  /// True on macOS, Linux, or Windows.
  static bool get isDesktop => isMacOS || isLinux || isWindows;

  /// True when the app can install and manage a local Coqui server directly.
  static bool get isManagedLocalServerSupported => isMacOS || isLinux;
}
