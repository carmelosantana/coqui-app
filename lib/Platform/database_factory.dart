/// Database factory resolution via conditional import.
///
/// On native: uses FFI factory for Linux/Windows, default sqflite for others.
/// On web: uses sqflite_common_ffi_web (SQLite WASM via OPFS).
library;

export 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_native.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';
