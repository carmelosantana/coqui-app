import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Initialize the database factory for web.
///
/// Uses SQLite compiled to WASM via Origin Private File System (OPFS).
/// Data persists across browser sessions.
Future<void> initDatabaseFactory() async {
  // No additional init needed — the web factory handles WASM loading internally.
}

/// Get the database factory for web (SQLite WASM).
DatabaseFactory getDatabaseFactory() {
  return databaseFactoryFfiWeb;
}
