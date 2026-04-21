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

  Future<void> open(String databaseFile) async {
    final factory = db_factory.getDatabaseFactory();
    final dbPath = PlatformInfo.isWeb
        ? databaseFile
        : path.join(await getDatabasesPathForPlatform(), databaseFile);
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (Database db, int version) async {
          await db.execute('''CREATE TABLE IF NOT EXISTS sessions (
id TEXT PRIMARY KEY,
instance_id TEXT,
model_role TEXT NOT NULL,
model TEXT,
profile TEXT,
active_project_id TEXT,
created_at INTEGER NOT NULL,
updated_at INTEGER NOT NULL,
token_count INTEGER DEFAULT 0,
is_closed INTEGER NOT NULL DEFAULT 0,
is_archived INTEGER NOT NULL DEFAULT 0,
closed_at INTEGER,
archived_at INTEGER,
closure_reason TEXT,
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
            await db.execute('ALTER TABLE sessions ADD COLUMN profile TEXT');
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN active_project_id TEXT',
            );
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN is_closed INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN closed_at INTEGER',
            );
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN archived_at INTEGER',
            );
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN closure_reason TEXT',
            );
          }
        },
      ),
    );
  }

  Future<void> close() async => _db.close();

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
