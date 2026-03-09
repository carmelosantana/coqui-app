/// No-op analytics for native platforms (iOS, Android, macOS, Windows, Linux).
class AnalyticsService {
  AnalyticsService._();

  /// Track a named event. No-op on native platforms.
  static void trackEvent(String name, [Map<String, Object>? data]) {}
}
