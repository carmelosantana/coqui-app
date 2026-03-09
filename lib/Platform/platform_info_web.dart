/// Web platform detection — no native platform is true.
class PlatformInfo {
  PlatformInfo._();

  static bool get isWeb => true;
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isFuchsia => false;

  /// True on iOS or Android.
  static bool get isMobile => false;

  /// True on macOS, Linux, or Windows.
  static bool get isDesktop => false;
}
