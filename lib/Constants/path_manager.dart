import 'package:coqui_app/Platform/platform_info.dart';
import 'package:path_provider/path_provider.dart';

/// Manages platform-specific document paths.
///
/// On web, paths are unused (storage is handled by IndexedDB/OPFS).
/// On native, resolves to the appropriate application directory.
class PathManager {
  static final PathManager _instance = PathManager._internal();
  String _documentsPath = '';

  PathManager._internal();

  static Future<void> initialize() async {
    if (PlatformInfo.isWeb) {
      // Web has no filesystem paths — storage uses browser APIs directly.
      return;
    }

    if (PlatformInfo.isLinux) {
      final directory = await getApplicationSupportDirectory();
      _instance._documentsPath = directory.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      _instance._documentsPath = directory.path;
    }
  }

  /// The documents directory path. Empty string on web.
  String get documentsPath => _documentsPath;

  static PathManager get instance => _instance;
}
