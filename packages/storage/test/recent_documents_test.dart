import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  String file(String name) =>
      '${dir.path}${Platform.pathSeparator}$name$projectFileExtension';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ocx_recent_');
  });

  tearDown(() => dir.delete(recursive: true));

  DateTime t(int minute) => DateTime.utc(2026, 10, 12, 12, minute);

  test('lists most recent first', () {
    final recent =
        RecentDocuments.inMemory()
          ..record(path: file('a'), title: 'A', at: t(1))
          ..record(path: file('b'), title: 'B', at: t(2))
          ..record(path: file('c'), title: 'C', at: t(3));
    expect(recent.list().map((r) => r.title), ['C', 'B', 'A']);
    recent.close();
  });

  test('re-opening moves an entry to the top and updates it', () {
    final recent =
        RecentDocuments.inMemory()
          ..record(path: file('a'), title: 'A', at: t(1))
          ..record(path: file('b'), title: 'B', at: t(2))
          ..record(
            path: file('a'),
            title: 'A renamed',
            documentId: 'd',
            at: t(3),
          );
    final list = recent.list();
    expect(list, hasLength(2));
    expect(list.first.title, 'A renamed');
    expect(list.first.documentId, 'd');
    expect(list.first.openedAt, t(3));
    recent.close();
  });

  test('keeps at most limit entries, dropping the oldest', () {
    final recent = RecentDocuments.inMemory(limit: 3);
    for (var i = 0; i < 5; i++) {
      recent.record(path: file('f$i'), title: 'F$i', at: t(i));
    }
    expect(recent.list().map((r) => r.title), ['F4', 'F3', 'F2']);
    recent.close();
  });

  test('stores absolute paths', () {
    final recent =
        RecentDocuments.inMemory()
          ..record(path: 'relative$projectFileExtension', title: 'R');
    expect(File(recent.list().single.path).isAbsolute, isTrue);
    recent.close();
  });

  test('remove, clear and pruneMissing', () {
    File(file('kept')).writeAsStringSync('x');
    final recent =
        RecentDocuments.inMemory()
          ..record(path: file('kept'), title: 'Kept', at: t(1))
          ..record(path: file('gone'), title: 'Gone', at: t(2))
          ..record(path: file('other'), title: 'Other', at: t(3));
    recent.remove(file('other'));
    expect(recent.list(), hasLength(2));
    expect(recent.pruneMissing(), 1);
    expect(recent.list().single.title, 'Kept');
    recent.clear();
    expect(recent.list(), isEmpty);
    recent.close();
  });

  test('persists across reopen and creates parent folders', () {
    final db = '${dir.path}/app/data/index.sqlite';
    RecentDocuments.open(db)
      ..record(path: file('a'), title: 'A', at: t(1))
      ..close();
    final reopened = RecentDocuments.open(db);
    expect(reopened.list().single.title, 'A');
    reopened.close();
  });

  test('refuses an index from a newer app version', () {
    final db = '${dir.path}/index.sqlite';
    sqlite3.open(db)
      ..execute('PRAGMA user_version = 99')
      ..close();
    expect(() => RecentDocuments.open(db), throwsStateError);
  });
}
