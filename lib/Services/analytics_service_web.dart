import 'dart:js_interop';

/// JS binding for `window.umami.track()`.
@JS('umami.track')
external void _umamiTrack(JSString name);

@JS('umami.track')
external void _umamiTrackWithData(JSString name, JSAny data);

/// Check whether `window.umami` exists.
@JS('umami')
external JSObject? get _umami;

/// Web analytics via Umami tracker (loaded in index.html).
///
/// All calls are fire-and-forget — failures are silently ignored
/// so analytics never interfere with app functionality.
class AnalyticsService {
  AnalyticsService._();

  /// Track a named event, optionally with key-value data.
  ///
  /// Calls `window.umami.track(name)` or `window.umami.track(name, data)`.
  /// No-ops silently if Umami hasn't loaded yet or is blocked.
  static void trackEvent(String name, [Map<String, Object>? data]) {
    try {
      if (_umami == null) return;

      if (data != null && data.isNotEmpty) {
        _umamiTrackWithData(name.toJS, data.jsify()!);
      } else {
        _umamiTrack(name.toJS);
      }
    } catch (_) {
      // Silently ignore — analytics must never break the app.
    }
  }
}
