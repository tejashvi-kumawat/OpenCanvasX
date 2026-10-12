import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ocx_app_index_');
  });

  tearDown(() => dir.delete(recursive: true));

  int userVersion(String path) {
    final db = sqlite3.open(path);
    try {
      return db.select('PRAGMA user_version').first.columnAt(0) as int;
    } finally {
      db.close();
    }
  }

  test('creates a fresh index at the current schema', () {
    final path = '${dir.path}/index.sqlite';
    AppIndex.open(path).close();
    expect(userVersion(path), AppIndex.schemaVersion);
  });

  test('upgrades a version 1 index and keeps recent documents', () {
    final path = '${dir.path}/index.sqlite';
    // A database exactly as P1.1.6 created it.
    sqlite3.open(path)
      ..execute('''
        CREATE TABLE recent (
          path TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          document_id TEXT,
          opened_at INTEGER NOT NULL
        );
        INSERT INTO recent VALUES ('/x.opencanvasx', 'Old', NULL, 1);
        PRAGMA user_version = 1;
      ''')
      ..close();

    final index = AppIndex.open(path);
    expect(index.recent.list().single.title, 'Old');
    index.settings.set('k', 'v');
    expect(index.settings.get('k'), 'v');
    index.close();
    expect(userVersion(path), 2);
  });

  test('settings get, set, overwrite and remove', () {
    final settings = AppIndex.inMemory().settings;
    expect(settings.get(AppSettings.projectsRootKey), isNull);
    settings
      ..set(AppSettings.projectsRootKey, r'C:\Projects')
      ..set(AppSettings.projectsRootKey, r'D:\Designs');
    expect(settings.get(AppSettings.projectsRootKey), r'D:\Designs');
    settings.remove(AppSettings.projectsRootKey);
    expect(settings.get(AppSettings.projectsRootKey), isNull);
  });
}
