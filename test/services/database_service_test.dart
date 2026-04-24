import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Platform/database_factory.dart' as db_factory;
import 'package:coqui_app/Services/database_service.dart';
import 'package:sqflite_common/sqlite_api.dart';

class _TestDatabaseService extends DatabaseService {
  final String databasePath;

  _TestDatabaseService(this.databasePath);

  @override
  Future<String> getDatabasesPathForPlatform() async => databasePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await db_factory.initDatabaseFactory();
  });

  test(
      'opens successfully when schema already has channel columns but user version is stale',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'coqui-app-db-migration-',
    );
    final databaseFile = 'coqui_app.db';
    final databasePath = path.join(tempDir.path, databaseFile);
    final factory = db_factory.getDatabaseFactory();

    Database? seededDatabase;
    final service = _TestDatabaseService(tempDir.path);

    try {
      seededDatabase = await factory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (Database db, int version) async {
            await db.execute('''CREATE TABLE sessions (
id TEXT PRIMARY KEY,
instance_id TEXT,
model_role TEXT NOT NULL,
model TEXT,
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
);''');

            await db.execute('''CREATE TABLE messages (
id TEXT PRIMARY KEY,
session_id TEXT NOT NULL,
content TEXT NOT NULL,
role TEXT NOT NULL,
tool_calls TEXT,
tool_call_id TEXT,
created_at INTEGER NOT NULL
);''');
          },
        ),
      );
      await seededDatabase.close();
      seededDatabase = null;

      await service.open(databaseFile);

      expect(await service.getSessions(), isEmpty);
    } finally {
      if (seededDatabase != null && seededDatabase.isOpen) {
        await seededDatabase.close();
      }
      await service.close().catchError((_) {});
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('clears cached sessions and messages together', () async {
    final tempDir = await Directory.systemTemp.createTemp('coqui-app-db-clear-');
    final service = _TestDatabaseService(tempDir.path);

    try {
      await service.open('coqui_app.db');

      final session = CoquiSession(
        id: 'session-1',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
      );

      await service.upsertSession(session);
      await service.upsertMessage(
        CoquiMessage(
          id: 'message-1',
          content: 'hello',
          role: CoquiMessageRole.user,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000002000),
        ),
        sessionId: session.id,
      );

      expect(await service.getSessions(), hasLength(1));
      expect(await service.getMessages(session.id), hasLength(1));

      await service.clearSessionCache();

      expect(await service.getSessions(), isEmpty);
      expect(await service.getMessages(session.id), isEmpty);
    } finally {
      await service.close().catchError((_) {});
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('deletes the backing database file for restart resets', () async {
    final tempDir = await Directory.systemTemp.createTemp('coqui-app-db-delete-');
    final service = _TestDatabaseService(tempDir.path);
    final databasePath = path.join(tempDir.path, 'coqui_app.db');

    try {
      await service.open('coqui_app.db');
      expect(await File(databasePath).exists(), isTrue);

      await service.deleteDatabaseFile();

      expect(await File(databasePath).exists(), isFalse);
    } finally {
      await service.close().catchError((_) {});
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
