import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Platform/database_factory.dart' as db_factory;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart' as path;

/// SQLite-backed local cache for Coqui API data.
///
/// Caches sessions, messages, and turns fetched from the API server
/// for offline viewing and fast UI rendering.
///
/// On web, uses SQLite compiled to WASM via OPFS for persistent storage.
/// On native, uses sqflite (mobile) or FFI (desktop).
class DatabaseService {
  late Database _db;
  bool _isOpen = false;
  String? _databaseFile;

  Future<String> getDatabasesPathForPlatform() async {
    if (PlatformInfo.isWeb) {
      // Web SQLite WASM manages its own storage path.
      return '';
    }
    if (PlatformInfo.isLinux) {
      return PathManager.instance.documentsPath;
    }
    return await db_factory.getDatabaseFactory().getDatabasesPath();
  }

  Future<String> resolveDatabasePath(String databaseFile) async {
    if (PlatformInfo.isWeb) {
      return databaseFile;
    }

    return path.join(await getDatabasesPathForPlatform(), databaseFile);
  }

  Future<void> open(String databaseFile) async {
    final factory = db_factory.getDatabaseFactory();
    final dbPath = await resolveDatabasePath(databaseFile);
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (Database db, int version) async {
          await db.execute('''CREATE TABLE IF NOT EXISTS sessions (
id TEXT PRIMARY KEY,
instance_id TEXT,
model_role TEXT NOT NULL,
model TEXT,
session_origin TEXT NOT NULL DEFAULT 'user',
profile TEXT,
group_enabled INTEGER NOT NULL DEFAULT 0,
group_max_rounds INTEGER NOT NULL DEFAULT 3,
group_composition_key TEXT,
group_members_json TEXT,
active_project_id TEXT,
created_at INTEGER NOT NULL,
updated_at INTEGER NOT NULL,
token_count INTEGER DEFAULT 0,
is_closed INTEGER NOT NULL DEFAULT 0,
is_archived INTEGER NOT NULL DEFAULT 0,
closed_at INTEGER,
archived_at INTEGER,
closure_reason TEXT,
channel_bound INTEGER NOT NULL DEFAULT 0,
channel_json TEXT,
title TEXT
) WITHOUT ROWID;''');

          await db.execute('''CREATE TABLE IF NOT EXISTS messages (
id TEXT PRIMARY KEY,
session_id TEXT NOT NULL,
content TEXT NOT NULL,
role TEXT CHECK(role IN ('user', 'assistant', 'tool')) NOT NULL,
tool_calls TEXT,
tool_call_id TEXT,
created_at INTEGER NOT NULL,
FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
) WITHOUT ROWID;''');
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) {
            await _addColumnIfMissing(db, 'sessions', 'profile', 'TEXT');
          }
          if (oldVersion < 3) {
            await _addColumnIfMissing(
              db,
              'sessions',
              'active_project_id',
              'TEXT',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'is_closed',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'is_archived',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'closed_at',
              'INTEGER',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'archived_at',
              'INTEGER',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'closure_reason',
              'TEXT',
            );
          }
          if (oldVersion < 4) {
            await _addColumnIfMissing(
              db,
              'sessions',
              'group_enabled',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'group_max_rounds',
              'INTEGER NOT NULL DEFAULT 3',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'group_composition_key',
              'TEXT',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'group_members_json',
              'TEXT',
            );
          }
          if (oldVersion < 5) {
            await _addColumnIfMissing(
              db,
              'sessions',
              'channel_bound',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _addColumnIfMissing(
              db,
              'sessions',
              'channel_json',
              'TEXT',
            );
          }
          if (oldVersion < 6) {
            await _addColumnIfMissing(
              db,
              'sessions',
              'session_origin',
              "TEXT NOT NULL DEFAULT 'user'",
            );
          }
        },
        onOpen: (Database db) async {
          await _ensureSessionSchema(db);
        },
      ),
    );
    _databaseFile = databaseFile;
    _isOpen = true;
  }

  Future<void> _ensureSessionSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      'sessions',
      'session_origin',
      "TEXT NOT NULL DEFAULT 'user'",
    );
    await _addColumnIfMissing(db, 'sessions', 'profile', 'TEXT');
    await _addColumnIfMissing(db, 'sessions', 'active_project_id', 'TEXT');
    await _addColumnIfMissing(
      db,
      'sessions',
      'is_closed',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'sessions',
      'is_archived',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'sessions', 'closed_at', 'INTEGER');
    await _addColumnIfMissing(db, 'sessions', 'archived_at', 'INTEGER');
    await _addColumnIfMissing(db, 'sessions', 'closure_reason', 'TEXT');
    await _addColumnIfMissing(
      db,
      'sessions',
      'group_enabled',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'sessions',
      'group_max_rounds',
      'INTEGER NOT NULL DEFAULT 3',
    );
    await _addColumnIfMissing(db, 'sessions', 'group_composition_key', 'TEXT');
    await _addColumnIfMissing(db, 'sessions', 'group_members_json', 'TEXT');
    await _addColumnIfMissing(
      db,
      'sessions',
      'channel_bound',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'sessions', 'channel_json', 'TEXT');
    await _addColumnIfMissing(db, 'sessions', 'title', 'TEXT');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    if (await _tableHasColumn(db, table, column)) {
      return;
    }

    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<bool> _tableHasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');

    return rows.any((row) => row['name'] == column);
  }

  Future<void> close() async {
    if (!_isOpen) {
      return;
    }

    if (_db.isOpen) {
      await _db.close();
    }

    _isOpen = false;
  }

  Future<void> deleteDatabaseFile({String? databaseFile}) async {
    final targetFile = databaseFile ?? _databaseFile;
    if (targetFile == null || targetFile.isEmpty) {
      return;
    }

    final dbPath = await resolveDatabasePath(targetFile);
    await close();
    await db_factory.getDatabaseFactory().deleteDatabase(dbPath);
  }

  // ── Session Operations ──────────────────────────────────────────────

  /// Upsert a session into the local cache.
  Future<void> upsertSession(CoquiSession session, {String? instanceId}) async {
    await _db.insert(
      'sessions',
      {
        ...session.toDatabaseMap(),
        'instance_id': instanceId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a cached session by ID.
  Future<CoquiSession?> getSession(String sessionId) async {
    final maps = await _db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    if (maps.isEmpty) return null;
    return CoquiSession.fromDatabase(maps.first);
  }

  /// Get all cached sessions for an instance, ordered by most recent.
  Future<List<CoquiSession>> getSessions({String? instanceId}) async {
    final maps = await _db.query(
      'sessions',
      where: instanceId != null ? 'instance_id = ?' : null,
      whereArgs: instanceId != null ? [instanceId] : null,
      orderBy: 'updated_at DESC',
    );

    return maps.map((m) => CoquiSession.fromDatabase(m)).toList();
  }

  /// Update the local title for a session.
  Future<void> updateSessionTitle(String sessionId, String title) async {
    await _db.update(
      'sessions',
      {'title': title},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Delete a session and its messages from the local cache.
  Future<void> deleteSession(String sessionId) async {
    await _db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    await _db
        .delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  /// Clear all sessions for an instance (used when switching instances).
  Future<void> clearSessionsForInstance(String instanceId) async {
    final sessions = await getSessions(instanceId: instanceId);
    for (final session in sessions) {
      await deleteSession(session.id);
    }
  }

  /// Clear the entire local conversation cache.
  Future<void> clearSessionCache() async {
    await _db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('sessions');
    });
  }

  // ── Message Operations ──────────────────────────────────────────────

  /// Upsert a message into the local cache.
  Future<void> upsertMessage(CoquiMessage message,
      {required String sessionId}) async {
    await _db.insert(
      'messages',
      {
        ...message.toDatabaseMap(),
        'session_id': sessionId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Bulk upsert messages (used when syncing from server).
  Future<void> upsertMessages(
    List<CoquiMessage> messages, {
    required String sessionId,
  }) async {
    await _db.transaction((txn) async {
      for (final message in messages) {
        await txn.insert(
          'messages',
          {
            ...message.toDatabaseMap(),
            'session_id': sessionId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Get all cached messages for a session, ordered chronologically.
  Future<List<CoquiMessage>> getMessages(String sessionId) async {
    final maps = await _db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );

    return maps.map((m) => CoquiMessage.fromDatabase(m)).toList();
  }

  /// Delete all messages for a session (used before re-syncing).
  Future<void> deleteMessages(String sessionId) async {
    await _db.delete(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
