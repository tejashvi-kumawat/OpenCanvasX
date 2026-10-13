import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ocx_ws'));
  tearDown(() => root.deleteSync(recursive: true));

  Future<String> design(String folder, String title) async {
    final path = newProjectPath(folder, title);
    await saveProject(
      path,
      DesignDocument(
        id: DocumentId.generate(),
        metadata: DocumentMetadata(title: title),
        pages: [DesignPage(id: PageId.generate(), width: 10, height: 10)],
      ),
    );
    return path;
  }

  test('projects are marked folders; designs move between them', () async {
    final launch = await createWorkspaceProject(root.path, 'Launch');
    await createWorkspaceProject(root.path, 'Launch');
    expect(
      listWorkspaceProjects(
        root.path,
      ).map((p) => p.split(Platform.pathSeparator).last),
      ['Launch', 'Launch 2'],
    );
    final poster = await design(root.path, 'Poster');
    expect(projectOf(poster), isNull);
    final moved = await moveDesign(poster, launch);
    expect(File(moved).existsSync(), isTrue);
    expect(File(poster).existsSync(), isFalse);
    expect(projectOf(moved), launch);
    // findProjects still sees designs inside projects, not the marker.
    expect(await findProjects(root.path), [moved]);
    final back = await moveDesign(moved, root.path);
    expect(projectOf(back), isNull);
  });

  test('duplicate, rename and trash', () async {
    final poster = await design(root.path, 'Poster');
    final copy = await duplicateDesign(poster);
    final copied = (await readProjectFile(copy)).document;
    final original = (await readProjectFile(poster)).document;
    expect(copied.metadata.title, 'Poster copy');
    expect(copied.id, isNot(original.id));

    await renameDesign(poster, 'Summer poster');
    expect(
      (await readProjectFile(poster)).document.metadata.title,
      'Summer poster',
    );

    final trashed = await trashDesign(root.path, copy);
    expect(Directory(trashed).existsSync(), isTrue);
    expect(trashed, contains(trashFolder));
    expect(await findProjects(root.path), [poster]);
  });
}
