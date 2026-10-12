import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

/// The official templates in `templates/official` plus repository behaviour
/// (P2.2.5, P6.2).
void main() {
  const official = '../../templates/official';

  group('official templates folder', () {
    const repo = FolderTemplateRepository(official);

    test('lists every file with checksums', () async {
      final entries = await repo.list();
      expect(entries.length, greaterThanOrEqualTo(20));
      final files = [
        for (final f in Directory(official).listSync().whereType<File>())
          if (f.path.endsWith('.opencanvasx')) f.uri.pathSegments.last,
      ]..sort();
      expect([for (final e in entries) e.info.file]..sort(), files);
      expect(entries.every((e) => e.info.sha256 != null), isTrue);
    });

    test('every template decodes, validates and matches its entry', () async {
      for (final (:info, :repository) in await repo.list()) {
        final bytes = await repository.fetch(info);
        final contents = decodeProject(bytes);
        final doc = contents.document;
        expect(contents.missingAssets, isEmpty, reason: info.id);
        expect(validateTemplate(doc), isEmpty, reason: info.id);
        expect(doc.pages, hasLength(info.pages), reason: info.id);
        expect(templateCategories.containsKey(info.category), isTrue);
        for (final asset in doc.assets.values) {
          expect(asset.licenseRef, startsWith('pack:'), reason: info.id);
        }
      }
    });
  });

  group('folder repository', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ocx_repo'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a missing index lists nothing; tampered files are refused', () async {
      expect(await FolderTemplateRepository(dir.path).list(), isEmpty);
      File('${dir.path}/a.opencanvasx').writeAsBytesSync([1, 2, 3]);
      File('${dir.path}/index.json').writeAsStringSync(
        jsonEncode({
          'templates': [
            {
              'id': 'a',
              'name': 'A',
              'category': 'social',
              'file': 'a.opencanvasx',
              'width': 10,
              'height': 10,
              'unit': 'px',
              'pages': 1,
              'license': 'CC0-1.0',
              'license_url': 'https://example.org',
              'author': 'me',
              'sha256': sha256.convert([9, 9, 9]).toString(),
            },
          ],
        }),
      );
      final repo = FolderTemplateRepository(dir.path);
      final entry = (await repo.list()).single;
      expect(repo.label, isNotEmpty);
      expect(() => repo.fetch(entry.info), throwsFormatException);
    });
  });

  group('http repository', () {
    late HttpServer server;
    late Directory cache;
    final file = utf8.encode('template bytes');
    var served = file;

    setUp(() async {
      cache = Directory.systemTemp.createTempSync('ocx_cache');
      served = file;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        final path = request.uri.path;
        if (path == '/repo/index.json') {
          request.response.write(
            jsonEncode({
              'templates': [
                {
                  'id': 'remote',
                  'name': 'Remote',
                  'category': 'social',
                  'file': 'remote.opencanvasx',
                  'width': 10,
                  'height': 10,
                  'unit': 'px',
                  'pages': 1,
                  'license': 'CC0-1.0',
                  'license_url': 'https://example.org',
                  'author': 'me',
                  'sha256': sha256.convert(file).toString(),
                  'bytes': file.length,
                },
              ],
            }),
          );
        } else if (path == '/repo/remote.opencanvasx') {
          request.response.add(served);
        } else {
          request.response.statusCode = 404;
        }
        request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      cache.deleteSync(recursive: true);
    });

    String url() => 'http://localhost:${server.port}/repo/index.json';

    test('nothing is listed until refreshed; downloads are verified', () async {
      final repo = HttpTemplateRepository(url(), cacheDir: cache.path);
      expect(repo.hasIndex, isFalse);
      expect(await repo.list(), isEmpty);
      final entries = await repo.refresh();
      expect(entries.single.info.id, 'remote');
      expect(await repo.fetch(entries.single.info), file);
      // Cached: works even after the server's copy changes.
      served = utf8.encode('evil bytes!!!!');
      expect(await repo.fetch(entries.single.info), file);
    });

    test('a file not matching its checksum is refused', () async {
      served = utf8.encode('evil bytes!!!!');
      final repo = HttpTemplateRepository(url(), cacheDir: cache.path);
      final entries = await repo.refresh();
      expect(() => repo.fetch(entries.single.info), throwsFormatException);
    });

    test('plain http to other hosts is refused', () async {
      final repo = HttpTemplateRepository(
        'http://example.org/index.json',
        cacheDir: cache.path,
      );
      expect(repo.refresh, throwsFormatException);
    });
  });
}
