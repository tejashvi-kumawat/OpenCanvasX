import 'dart:typed_data';
import 'dart:io';

import 'package:opencanvasx/src/ai/ai.dart';
import 'package:document_model/document_model.dart';
import 'package:opencanvasx/src/library/design_library.dart';
import 'package:storage/storage.dart';

/// Deterministic text measurer: half an em per character, one line per
/// paragraph; wraps at [width] for auto-height text.
Point2D fakeMeasure(TextPayload text, {double? width}) {
  final lines = text.text.split('\n');
  final longest = lines.fold<int>(1, (m, l) => l.length > m ? l.length : m);
  final natural = longest * text.fontSize * 0.5;
  if (width == null || text.sizing == TextSizing.autoWidth) {
    return Point2D(natural, lines.length * text.fontSize * text.lineHeight);
  }
  final wraps = (natural / width).ceil().clamp(1, 1 << 20);
  return Point2D(width, lines.length * wraps * text.fontSize * text.lineHeight);
}

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
  Future<String> createFrom(
    String folder,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  }) async {
    final title = document.metadata.title;
    var path = '$folder/$title$projectFileExtension';
    for (var n = 2; files.containsKey(path); n++) {
      path = '$folder/$title $n$projectFileExtension';
    }
    files[path] = document;
    savedAssets[path] = assets;
    modified[path] = _tick();
    return path;
  }

  final Set<String> projects = {};

  @override
  Future<List<String>> listProjectFolders(String root) async => [
    for (final p in projects)
      if (p.startsWith('$root/')) p,
  ]..sort();

  @override
  Future<String> createProjectFolder(String root, String name) async {
    var path = '$root/$name';
    for (var n = 2; projects.contains(path); n++) {
      path = '$root/$name $n';
    }
    projects.add(path);
    return path;
  }

  @override
  Future<String> move(String path, String folder) async {
    final name = path.split('/').last;
    final target = '$folder/$name';
    files[target] = files.remove(path)!;
    modified[target] = modified.remove(path)!;
    return target;
  }

  @override
  Future<void> trash(String root, String path) async {
    files.remove(path);
    modified.remove(path);
  }

  @override
  Future<String> duplicate(String path) async {
    final doc = files[path]!;
    final title = '${doc.metadata.title} copy';
    final target = path.replaceFirst(
      RegExp(r'[^/]+$'),
      '$title$projectFileExtension',
    );
    files[target] = DesignDocument(
      id: DocumentId.generate(),
      metadata: DocumentMetadata(title: title),
      pages: doc.pages,
      objects: doc.objects,
    );
    modified[target] = _tick();
    return target;
  }

  @override
  Future<void> rename(String path, String title) async {
    final doc = files[path]!;
    files[path] = DesignDocument(
      id: doc.id,
      metadata: doc.metadata.copyWith(title: title),
      pages: doc.pages,
      objects: doc.objects,
    );
  }

  @override
  Future<OpenedProject> open(String path) async {
    final doc = files[path];
    if (doc == null) throw FileSystemException('No such design', path);
    return OpenedProject(
      contents: ProjectContents(
        document: doc,
        assets: savedAssets[path] ?? const {},
        missingAssets: const [],
        issues: const [],
      ),
      source: ProjectSource.saved,
      newerAutosaveAvailable: false,
    );
  }

  /// Saved versions by design path, newest first.
  final Map<String, List<(DesignVersion, DesignDocument)>> savedVersions = {};

  @override
  Future<List<DesignVersion>> versions(String path) async => [
    for (final (v, _)
        in savedVersions[path] ?? const <(DesignVersion, DesignDocument)>[])
      v,
  ];

  @override
  Future<DesignVersion> saveVersion(
    String path,
    DesignDocument document, {
    required String label,
    Map<String, Uint8List> assets = const {},
  }) async {
    final list = savedVersions.putIfAbsent(path, () => []);
    final version = (
      path: '$path#v${list.length}',
      label: label.trim().isEmpty ? 'Version' : label.trim(),
      createdAt: _tick(),
    );
    list.insert(0, (version, document));
    return version;
  }

  @override
  Future<ProjectContents> openVersion(DesignVersion version) async {
    for (final list in savedVersions.values) {
      for (final (v, doc) in list) {
        if (v.path == version.path) {
          return ProjectContents(
            document: doc,
            assets: const {},
            missingAssets: const [],
            issues: const [],
          );
        }
      }
    }
    throw StateError('no version ${version.path}');
  }

  @override
  Future<void> deleteVersion(DesignVersion version) async {
    for (final list in savedVersions.values) {
      list.removeWhere((e) => e.$1.path == version.path);
    }
  }

  /// Asset bytes from the last save of each path.
  final Map<String, Map<String, Uint8List>> savedAssets = {};

  @override
  Future<void> save(
    String path,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  }) async {
    savedAssets[path] = assets;
    files[path] = document;
    modified[path] = _tick();
    saves++;
  }
}

/// In-memory stand-in for the OS credential store.
class FakeSecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async => values[name] = value;

  @override
  Future<void> delete(String name) async => values.remove(name);
}
