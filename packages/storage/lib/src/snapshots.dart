import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:document_model/document_model.dart';

import 'project_archive.dart';
import 'project_file.dart';

String get _sep => Platform.pathSeparator;

int _lastSeparator(String path) =>
    path.lastIndexOf('/') > path.lastIndexOf(r'\')
        ? path.lastIndexOf('/')
        : path.lastIndexOf(r'\');

String _dirname(String path) {
  final i = _lastSeparator(path);
  return i < 0 ? '.' : path.substring(0, i);
}

String _stemOf(String path) {
  final i = _lastSeparator(path);
  final name = path.substring(i + 1);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// A named version of a design (P1.8.3): a full copy of the design file
/// in `<design folder>/.ocx/snapshots/<design name>/`, next to a small
/// JSON file with its label. Hidden folders are skipped when listing
/// designs, so versions never show up as designs.
typedef DesignVersion = ({String path, String label, DateTime createdAt});

/// Folder holding the versions of [designPath].
String versionsDirFor(String designPath) =>
    '${_dirname(designPath)}$_sep.ocx${_sep}snapshots$_sep${_stemOf(designPath)}';

/// Saves [document] (with its [assets]) as a version called [label].
Future<DesignVersion> saveDesignVersion(
  String designPath,
  DesignDocument document, {
  required String label,
  Map<String, Uint8List> assets = const {},
  DateTime? now,
}) async {
  final created = now ?? DateTime.now();
  final dir = Directory(versionsDirFor(designPath));
  await dir.create(recursive: true);
  final base = created.millisecondsSinceEpoch;
  var n = 0;
  String stemFor(int n) => n == 0 ? '$base' : '${base}_$n';
  while (File(
    '${dir.path}$_sep${stemFor(n)}$projectFileExtension',
  ).existsSync()) {
    n++;
  }
  final stem = stemFor(n);
  final path = '${dir.path}$_sep$stem$projectFileExtension';
  await writeProjectFile(path, document, assets: assets);
  final name = label.trim().isEmpty ? 'Version' : label.trim();
  await File('${dir.path}$_sep$stem.json').writeAsString(
    jsonEncode({'label': name, 'created_at': created.toIso8601String()}),
  );
  return (path: path, label: name, createdAt: created);
}

/// Versions of [designPath], newest first. Unreadable labels fall back to
/// the file's time.
Future<List<DesignVersion>> listDesignVersions(String designPath) async {
  final dir = Directory(versionsDirFor(designPath));
  if (!dir.existsSync()) return const [];
  final versions = <DesignVersion>[];
  await for (final entity in dir.list()) {
    if (entity is! File || !entity.path.endsWith(projectFileExtension)) {
      continue;
    }
    final stem = _stemOf(entity.path);
    var label = 'Version';
    var created = entity.lastModifiedSync();
    try {
      final meta =
          jsonDecode(File('${dir.path}$_sep$stem.json').readAsStringSync())
              as Map<String, Object?>;
      if (meta['label'] case final String l) label = l;
      if (meta['created_at'] case final String c) {
        created = DateTime.tryParse(c) ?? created;
      }
    } on Object {
      // Label file missing or damaged: keep the defaults.
    }
    versions.add((path: entity.path, label: label, createdAt: created));
  }
  versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return versions;
}

/// Deletes [version] and its label file.
Future<void> deleteDesignVersion(DesignVersion version) async {
  final file = File(version.path);
  if (file.existsSync()) await file.delete();
  final meta = File(
    '${version.path.substring(0, version.path.length - projectFileExtension.length)}.json',
  );
  if (meta.existsSync()) await meta.delete();
}
