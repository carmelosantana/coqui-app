import 'package:sqflite_common/sqlite_api.dart';

/// Stub database factory — fallback when neither dart:io nor dart:html is available.
Future<void> initDatabaseFactory() async {
  throw UnsupportedError('No database factory available for this platform');
}

DatabaseFactory getDatabaseFactory() {
  throw UnsupportedError('No database factory available for this platform');
}
