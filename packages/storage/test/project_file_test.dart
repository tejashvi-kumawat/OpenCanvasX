import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:document_model/document_model.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

DesignDocument _doc(String title) => DesignDocument(
  id: const DocumentId('doc'),
  metadata: DocumentMetadata(title: title),
  pages: [DesignPage(id: const PageId('p'), width: 100, height: 100)],
);

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ocx_project_file_');
    path = '${dir.path}${Platform.pathSeparator}card$projectFileExtension';
  });

  tearDown(() => dir.delete(recursive: true));

  String titleOf(OpenedProject p) => p.contents.document.metadata.title;

  group('writeProjectFile / readProjectFile', () {
    test('writes and reads back', () async {
      await writeProjectFile(path, _doc('One'));
      final read = await readProjectFile(path);
      expect(read.document, _doc('One'));
    });

    test('replaces an existing file and leaves no temp file', () async {
      await writeProjectFile(path, _doc('One'));
      await writeProjectFile(path, _doc('Two'));
      expect((await readProjectFile(path)).document.metadata.title, 'Two');
      expect(File('$path.tmp').existsSync(), isFalse);
    });

    test('creates missing parent folders', () async {
      final nested = '${dir.path}/a/b/c$projectFileExtension';
      await writeProjectFile(nested, _doc('Nested'));
      expect(File(nested).existsSync(), isTrue);
    });

    test('a failed write keeps the previous file', () async {
      await writeProjectFile(path, _doc('Good'));
      // Asset bytes that do not match their hash make encoding fail.
      await expectLater(
        writeProjectFile(
          path,
          _doc('Bad'),
          assets: {
            '0' * 64: Uint8List.fromList([1]),
          },
        ),
        throwsArgumentError,
      );
      expect((await readProjectFile(path)).document.metadata.title, 'Good');
    });
  });

  group('saveProject', () {
    test('removes the autosave copy after an explicit save', () async {
      await writeProjectFile(autosavePathFor(path), _doc('Draft'));
      await saveProject(path, _doc('Saved'));
      expect(File(autosavePathFor(path)).existsSync(), isFalse);
      expect(File(path).existsSync(), isTrue);
    });
  });

  group('openProject', () {
    test('opens the saved file when there is no autosave', () async {
      await saveProject(path, _doc('Saved'));
      final opened = await openProject(path);
      expect(opened.source, ProjectSource.saved);
      expect(opened.newerAutosaveAvailable, isFalse);
      expect(titleOf(opened), 'Saved');
    });

    test('recovers from autosave when the saved file is truncated', () async {
      await saveProject(path, _doc('Saved'));
      await writeProjectFile(autosavePathFor(path), _doc('Draft'));
      final bytes = await File(path).readAsBytes();
      await File(path).writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

      final opened = await openProject(path);
      expect(opened.source, ProjectSource.autosave);
      expect(titleOf(opened), 'Draft');
    });

    test('recovers from autosave when the saved file is missing', () async {
      await writeProjectFile(autosavePathFor(path), _doc('Draft'));
      final opened = await openProject(path);
      expect(opened.source, ProjectSource.autosave);
    });

    test('flags a newer autosave without choosing it', () async {
      await saveProject(path, _doc('Saved'));
      await writeProjectFile(autosavePathFor(path), _doc('Draft'));
      final now = DateTime.now();
      File(path).setLastModifiedSync(now.subtract(const Duration(minutes: 5)));
      File(autosavePathFor(path)).setLastModifiedSync(now);

      final opened = await openProject(path);
      expect(opened.source, ProjectSource.saved);
      expect(titleOf(opened), 'Saved');
      expect(opened.newerAutosaveAvailable, isTrue);
    });

    test('ignores an older or unreadable autosave', () async {
      await saveProject(path, _doc('Saved'));
      await File(autosavePathFor(path)).writeAsString('garbage');
      final opened = await openProject(path);
      expect(opened.newerAutosaveAvailable, isFalse);
    });

    test('throws the original error when nothing is readable', () async {
      await File(path).writeAsString('not a zip');
      await File(autosavePathFor(path)).writeAsString('also not');
      await expectLater(openProject(path), throwsFormatException);
    });
  });

  group('Autosaver', () {
    late List<void Function()> timers;
    late int saves;

    Autosaver make({Future<void> Function()? save, void Function()? onError}) {
      timers = [];
      saves = 0;
      return Autosaver(
        save: save ?? () async => saves++,
        onError: onError == null ? null : (_, _) => onError(),
        timer: (delay, run) {
          timers.add(run);
          return _FakeTimer();
        },
      );
    }

    test('saves once after edits stop', () async {
      final autosaver =
          make()
            ..markDirty()
            ..markDirty()
            ..markDirty();
      expect(timers, hasLength(3)); // each edit restarts the quiet period
      expect(saves, 0);
      timers.last();
      await pumpEventQueue();
      expect(saves, 1);
      expect(autosaver.isDirty, isFalse);
    });

    test('flush saves pending edits immediately', () async {
      final autosaver = make()..markDirty();
      await autosaver.flush();
      expect(saves, 1);
      await autosaver.flush();
      expect(saves, 1, reason: 'nothing new to save');
    });

    test('saves never overlap and edits during a save are kept', () async {
      final gate = Completer<void>();
      var running = 0;
      var maxRunning = 0;
      final autosaver = make(
        save: () async {
          running++;
          maxRunning = running > maxRunning ? running : maxRunning;
          saves++;
          if (saves == 1) await gate.future;
          running--;
        },
      )..markDirty();
      timers.last();
      await pumpEventQueue();
      autosaver.markDirty(); // edit while the first save is in flight
      timers.last();
      final flushed = autosaver.flush();
      gate.complete();
      await flushed;
      await pumpEventQueue();
      expect(saves, 2);
      expect(maxRunning, 1);
      expect(autosaver.isDirty, isFalse);
    });

    test('a failed save stays dirty and reports the error', () async {
      var errors = 0;
      final autosaver = make(
        save: () async => throw const FileSystemException('disk full'),
        onError: () => errors++,
      )..markDirty();
      await autosaver.flush();
      expect(errors, 1);
      expect(autosaver.isDirty, isTrue);
    });

    test('dispose stops scheduling', () {
      final autosaver = make()..dispose();
      autosaver.markDirty();
      expect(timers, isEmpty);
    });

    test('works end to end with the real timer', () async {
      var count = 0;
      final autosaver = Autosaver(
        delay: const Duration(milliseconds: 10),
        save: () async {
          count++;
          await writeProjectFile(autosavePathFor(path), _doc('Auto'));
        },
      )..markDirty();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(count, 1);
      expect(File(autosavePathFor(path)).existsSync(), isTrue);
      autosaver.dispose();
    });
  });
}

final class _FakeTimer implements Timer {
  @override
  bool get isActive => false;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}
