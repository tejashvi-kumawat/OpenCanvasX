import 'dart:io';

import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  String at(String relative) =>
      '${root.path}/$relative'.replaceAll('/', Platform.pathSeparator);

  void touch(String relative) =>
      File(at(relative))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ocx_projects_');
  });

  tearDown(() => root.delete(recursive: true));

  group('checkProjectsFolder', () {
    test('accepts a writable folder and leaves no probe file', () async {
      expect(await checkProjectsFolder(root.path), isNull);
      expect(root.listSync(), isEmpty);
    });

    test('reports a missing path', () async {
      expect(
        await checkProjectsFolder(at('missing')),
        ProjectsFolderProblem.notFound,
      );
    });

    test('reports a file instead of a folder', () async {
      touch('file.txt');
      expect(
        await checkProjectsFolder(at('file.txt')),
        ProjectsFolderProblem.notAFolder,
      );
    });
  });

  group('findProjects', () {
    test('finds projects at the root and one folder down', () async {
      touch('Loose$projectFileExtension');
      touch('Poster/Poster$projectFileExtension');
      touch('Deck/deck$projectFileExtension');
      final found = await findProjects(root.path);
      expect(found, [
        at('Deck/deck$projectFileExtension'),
        at('Loose$projectFileExtension'),
        at('Poster/Poster$projectFileExtension'),
      ]);
    });

    test(
      'skips hidden folders, autosaves, temp files and deep nesting',
      () async {
        touch('Card/.ocx/snapshots/old$projectFileExtension');
        touch('Card/Card$projectFileExtension.autosave');
        touch('Card/Card$projectFileExtension.tmp');
        touch('Card/notes.txt');
        touch('a/b/c/deep$projectFileExtension');
        expect(await findProjects(root.path), isEmpty);
      },
    );

    test('stops at the limit', () async {
      for (var i = 0; i < 5; i++) {
        touch('p$i$projectFileExtension');
      }
      expect(await findProjects(root.path, limit: 3), hasLength(3));
    });

    test('returns nothing for a missing root', () async {
      expect(await findProjects(at('missing')), isEmpty);
    });
  });

  group('safeFileName', () {
    test('keeps ordinary titles', () {
      expect(safeFileName('Spring Poster 2026'), 'Spring Poster 2026');
    });

    test('replaces reserved characters and collapses spaces', () {
      expect(safeFileName('A/B:C*D?  "E"<F>|G'), 'A B C D E F G');
    });

    test('drops trailing dots and spaces', () {
      expect(safeFileName('Report... '), 'Report');
    });

    test('avoids Windows device names and empty names', () {
      expect(safeFileName('con'), 'con design');
      expect(safeFileName('  ///  '), 'Untitled design');
    });

    test('limits the length', () {
      expect(safeFileName('x' * 200), hasLength(80));
    });
  });

  group('newProjectPath', () {
    test('uses one folder per project and numbers duplicates', () {
      final first = newProjectPath(root.path, 'Menu');
      expect(first, at('Menu/Menu$projectFileExtension'));
      Directory(at('Menu')).createSync();
      expect(
        newProjectPath(root.path, 'Menu'),
        at('Menu 2/Menu 2$projectFileExtension'),
      );
    });
  });
}
