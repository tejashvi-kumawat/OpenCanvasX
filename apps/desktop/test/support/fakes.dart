import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:opencanvasx/src/library/design_library.dart';
import 'package:storage/storage.dart';

/// [DesignLibrary] kept in memory so tests never touch the disk.
class InMemoryDesignLibrary implements DesignLibrary {
  final Map<String, DesignDocument> files = {};
  final Map<String, DateTime> modified = {};
  int saves = 0;
  DateTime _clock = DateTime(2026, 10, 12, 9);

  DateTime _tick() => _clock = _clock.add(const Duration(minutes: 1));

  /// Adds a ready-made design at `<folder>/<title>.opencanvasx`.
  String seed(String folder, String title, {DesignPage? page}) {
    final path = '$folder/$title$projectFileExtension';
    files[path] = DesignDocument(
      id: DocumentId.generate(),
      metadata: DocumentMetadata(title: title),
      pages: [
        page ?? DesignPage(id: PageId.generate(), width: 1080, height: 1080),
      ],
    );
    modified[path] = _tick();
    return path;
  }

  @override
  Future<List<DesignSummary>> list(String folder) async => [
    for (final MapEntry(key: path, value: doc) in files.entries)
      if (path.startsWith(folder))
        DesignSummary(
          path: path,
          title: doc.metadata.title,
          modified: modified[path]!,
          document: doc,
        ),
  ]..sort((a, b) => b.modified.compareTo(a.modified));

  @override
  Future<String> create(
    String folder, {
    required String title,
    required DesignPage page,
  }) async {
    var path = '$folder/$title$projectFileExtension';
    for (var n = 2; files.containsKey(path); n++) {
      path = '$folder/$title $n$projectFileExtension';
    }
    files[path] = DesignDocument(
      id: DocumentId.generate(),
      metadata: DocumentMetadata(title: title),
      pages: [page],
    );
    modified[path] = _tick();
    return path;
  }

  @override
  Future<OpenedProject> open(String path) async {
    final doc = files[path];
    if (doc == null) throw FileSystemException('No such design', path);
    return OpenedProject(
      contents: ProjectContents(
        document: doc,
        assets: const {},
        missingAssets: const [],
        issues: const [],
      ),
      source: ProjectSource.saved,
      newerAutosaveAvailable: false,
    );
  }

  @override
  Future<void> save(String path, DesignDocument document) async {
    files[path] = document;
    modified[path] = _tick();
    saves++;
  }
}
