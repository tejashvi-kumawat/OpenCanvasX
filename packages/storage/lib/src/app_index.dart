import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'app_settings.dart';
import 'recent_documents.dart';

/// The app-wide SQLite index in the per-user data folder
/// (storage-architecture.md "App-wide index"): recent documents and
/// settings. It is a cache of user choices, not the document store.
final class AppIndex {
  AppIndex._(this._db, {required int recentLimit})
    : recent = RecentDocuments.attach(_db, limit: recentLimit),
      settings = AppSettings.attach(_db);

  /// Opens (or creates) the index at [databasePath], migrating it.
  factory AppIndex.open(String databasePath, {int recentLimit = 20}) {
    File(databasePath).parent.createSync(recursive: true);
    return _openChecked(sqlite3.open(databasePath), recentLimit);
  }

  /// A throwaway index, for tests and previews.
  factory AppIndex.inMemory({int recentLimit = 20}) =>
      _openChecked(sqlite3.openInMemory(), recentLimit);

  /// Schema version stored in `PRAGMA user_version`.
  static const int schemaVersion = 2;

  final Database _db;
  final RecentDocuments recent;
  final AppSettings settings;

  void close() => _db.close();
}

/// Steps from version `n` to `n + 1`, mirroring the file-format migrators.
const _migrations = <int, String>{
  0: '''
    CREATE TABLE IF NOT EXISTS recent (
      path TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      document_id TEXT,
      opened_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS recent_opened_at ON recent (opened_at DESC);
  ''',
  1: '''
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );
  ''',
};

void _migrate(Database db) {
  var version = db.select('PRAGMA user_version').first.columnAt(0) as int;
  if (version > AppIndex.schemaVersion) {
    throw StateError(
      'App index was created by a newer OpenCanvasX '
      '(schema $version, supported ${AppIndex.schemaVersion})',
    );
  }
  while (version < AppIndex.schemaVersion) {
    db.execute('BEGIN');
    try {
      db
        ..execute(_migrations[version]!)
        ..execute('PRAGMA user_version = ${version + 1}')
        ..execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
    version++;
  }
}

/// Migrates [db]; closes it on failure so Windows does not keep the file
/// locked.
AppIndex _openChecked(Database db, int recentLimit) {
  try {
    _migrate(db);
    return AppIndex._(db, recentLimit: recentLimit);
  } on Object {
    db.close();
    rethrow;
  }
}
