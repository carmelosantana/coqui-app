import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'platform_info_native.dart';

/// Initialize the database factory for native platforms.
///
/// Linux and Windows use FFI; macOS/iOS/Android use the default sqflite plugin.
Future<void> initDatabaseFactory() async {
  if (PlatformInfo.isWindows || PlatformInfo.isLinux) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }
}

/// Get the current database factory (native).
DatabaseFactory getDatabaseFactory() {
  return sqflite.databaseFactory;
}
