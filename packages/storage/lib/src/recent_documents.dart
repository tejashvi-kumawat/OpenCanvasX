import 'dart:io';

import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

/// One entry of the recent-documents list.
@immutable
final class RecentDocument {
  const RecentDocument({
    required this.path,
    required this.title,
    required this.openedAt,
    this.documentId,
  });

  /// Absolute path of the `.opencanvasx` file.
  final String path;
  final String title;

  /// `document_id` from the manifest, when known.
  final String? documentId;
  final DateTime openedAt;

  @override
  bool operator ==(Object other) =>
      other is RecentDocument &&
      other.path == path &&
      other.title == title &&
      other.documentId == documentId &&
      other.openedAt == openedAt;

  @override
  int get hashCode => Object.hash(path, title, documentId, openedAt);

  @override
  String toString() => 'RecentDocument($title, $path)';
}

/// Most-recently-opened projects, stored in the app-wide SQLite index
/// (storage-architecture.md, table `recent`).
///
/// The database is local only; nothing here leaves the device.
final class RecentDocuments {
  RecentDocuments._(this._db, this.limit) {
    _migrate();
  }

  /// Opens (or creates) the index at [databasePath].
  factory RecentDocuments.open(String databasePath, {int limit = 20}) {
    File(databasePath).parent.createSync(recursive: true);
    return _openChecked(sqlite3.open(databasePath), limit);
  }

  /// A throwaway index, for tests and previews.
  factory RecentDocuments.inMemory({int limit = 20}) =>
      _openChecked(sqlite3.openInMemory(), limit);

  /// Schema version stored in `PRAGMA user_version`.
  static const int schemaVersion = 1;

  final Database _db;

  /// Entries kept; older ones are dropped on [record].
  final int limit;

  void _migrate() {
    final version = _db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version > schemaVersion) {
      throw StateError(
        'Recent-documents index was created by a newer OpenCanvasX '
        '(schema $version, supported $schemaVersion)',
      );
    }
    if (version < 1) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS recent (
          path TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          document_id TEXT,
          opened_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS recent_opened_at ON recent (opened_at DESC);
        PRAGMA user_version = 1;
      ''');
    }
  }

  /// Records that [path] was opened (or saved) now, moving it to the top.
  void record({
    required String path,
    required String title,
    String? documentId,
    DateTime? at,
  }) {
    final absolute = File(path).absolute.path;
    final when = (at ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    _db
      ..execute(
        '''
        INSERT INTO recent (path, title, document_id, opened_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (path) DO UPDATE SET
          title = excluded.title,
          document_id = excluded.document_id,
          opened_at = excluded.opened_at
        ''',
        [absolute, title, documentId, when],
      )
      ..execute(
        '''
        DELETE FROM recent WHERE path NOT IN (
          SELECT path FROM recent ORDER BY opened_at DESC, path LIMIT ?
        )
        ''',
        [limit],
      );
  }

  /// Entries, most recent first.
  List<RecentDocument> list() => [
    for (final row in _db.select(
      'SELECT path, title, document_id, opened_at FROM recent '
      'ORDER BY opened_at DESC, path',
    ))
      RecentDocument(
        path: row['path'] as String,
        title: row['title'] as String,
        documentId: row['document_id'] as String?,
        openedAt: DateTime.fromMicrosecondsSinceEpoch(
          row['opened_at'] as int,
          isUtc: true,
        ),
      ),
  ];

  /// Removes one entry (e.g. "Remove from recent").
  void remove(String path) {
    _db.execute('DELETE FROM recent WHERE path = ?', [
      File(path).absolute.path,
    ]);
  }

  /// Drops entries whose file no longer exists; returns how many.
  int pruneMissing() {
    var removed = 0;
    for (final entry in list()) {
      if (!File(entry.path).existsSync()) {
        remove(entry.path);
        removed++;
      }
    }
    return removed;
  }

  /// Empties the list.
  void clear() => _db.execute('DELETE FROM recent');

  void close() => _db.close();
}

/// Wraps [db]; closes it if migration fails so the file is not left locked.
RecentDocuments _openChecked(Database db, int limit) {
  try {
    return RecentDocuments._(db, limit);
  } on Object {
    db.close();
    rethrow;
  }
}
