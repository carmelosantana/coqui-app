import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'platform_info_native.dart';

DatabaseFactory _databaseFactory = sqflite.databaseFactory;

/// Initialize the database factory for native platforms.
///
/// Desktop platforms (macOS, Linux, Windows) use FFI to bundle SQLite
/// and avoid system-SQLite authorization issues (SQLITE_AUTH on macOS).
/// iOS/Android use the default sqflite plugin.
Future<void> initDatabaseFactory() async {
  if (PlatformInfo.isWindows || PlatformInfo.isLinux || PlatformInfo.isMacOS) {
    sqfliteFfiInit();
    _databaseFactory = databaseFactoryFfi;
  }
}

/// Get the current database factory (native).
DatabaseFactory getDatabaseFactory() {
  return _databaseFactory;
}
