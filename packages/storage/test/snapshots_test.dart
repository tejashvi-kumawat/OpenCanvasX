import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ocx_versions'));
  tearDown(() => root.deleteSync(recursive: true));

  DesignDocument doc(String title) => DesignDocument(
    id: const DocumentId('d'),
    metadata: DocumentMetadata(title: title),
    pages: [DesignPage(id: const PageId('p'), width: 10, height: 10)],
  );

  test('versions are saved, listed newest first, opened and deleted', () async {
    final path = newProjectPath(root.path, 'Poster');
    await saveProject(path, doc('Poster'));
    expect(await listDesignVersions(path), isEmpty);

    await saveDesignVersion(
      path,
      doc('First'),
      label: 'Before colours',
      now: DateTime(2026, 10, 1, 9),
    );
    final second = await saveDesignVersion(
      path,
      doc('Second'),
      label: '  ',
      now: DateTime(2026, 10, 2),
    );
    final versions = await listDesignVersions(path);
    expect(versions.map((v) => v.label), ['Version', 'Before colours']);
    expect(versions.first.createdAt, DateTime(2026, 10, 2));

    final opened = await openProject(versions.last.path);
    expect(opened.contents.document.metadata.title, 'First');

    // Versions live in a hidden folder and are not listed as designs.
    final designs = await findProjects(root.path);
    expect(designs, [path]);

    await deleteDesignVersion(second);
    expect((await listDesignVersions(path)).single.label, 'Before colours');
  });
}
