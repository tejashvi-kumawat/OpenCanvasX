import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

/// Small key/value preferences in the app-wide index (table `settings`).
///
/// Values are plain strings; secrets (API keys, tokens) never go here —
/// they belong in OS secure storage (ai-architecture.md).
final class AppSettings {
  /// Used by `AppIndex`, which owns [_db] and its schema.
  @internal
  AppSettings.attach(this._db);

  /// Folder the user chose for projects (P1.1.7).
  static const String projectsRootKey = 'projects_root';

  final Database _db;

  String? get(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void set(String key, String value) => _db.execute(
    'INSERT INTO settings (key, value) VALUES (?, ?) '
    'ON CONFLICT (key) DO UPDATE SET value = excluded.value',
    [key, value],
  );

  void remove(String key) =>
      _db.execute('DELETE FROM settings WHERE key = ?', [key]);
}
