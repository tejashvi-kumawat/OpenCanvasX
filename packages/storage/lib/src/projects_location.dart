import 'dart:io';

import 'package:document_model/document_model.dart';

import 'project_archive.dart';

/// Why a folder cannot be used as the projects folder.
enum ProjectsFolderProblem {
  /// Nothing exists at the path.
  notFound,

  /// The path is a file, not a folder.
  notAFolder,

  /// OpenCanvasX cannot create files there.
  notWritable,
}

/// Checks that [path] can hold projects: it must be an existing folder we
/// can write to. Probes with a temporary file that is removed again.
/// Returns `null` when the folder is usable.
Future<ProjectsFolderProblem?> checkProjectsFolder(String path) async {
  final type = FileSystemEntity.typeSync(path);
  if (type == FileSystemEntityType.notFound) {
    return ProjectsFolderProblem.notFound;
  }
  if (type != FileSystemEntityType.directory) {
    return ProjectsFolderProblem.notAFolder;
  }
  final probe = File(
    '$path${Platform.pathSeparator}.ocx-write-test-${generateUuidV4()}',
  );
  try {
    await probe.writeAsString('', flush: true);
    return null;
  } on FileSystemException {
    return ProjectsFolderProblem.notWritable;
  } finally {
    if (probe.existsSync()) await probe.delete();
  }
}

/// Finds `.opencanvasx` files in [root] and its sub-folders, up to
/// [maxDepth] levels (storage-architecture.md: one folder per project).
///
/// Skips hidden folders (including `.ocx/`), autosave and temp copies, and
/// stops after [limit] results. Unreadable folders are skipped silently.
Future<List<String>> findProjects(
  String root, {
  int maxDepth = 2,
  int limit = 500,
}) async {
  final found = <String>[];
  Future<void> walk(Directory dir, int depth) async {
    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      if (found.length >= limit) return;
      final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (name.startsWith('.')) continue;
      if (entry is File && name.endsWith(projectFileExtension)) {
        found.add(entry.path);
      } else if (entry is Directory && depth < maxDepth) {
        await walk(entry, depth + 1);
      }
    }
  }

  final dir = Directory(root);
  if (dir.existsSync()) await walk(dir, 1);
  return found;
}

final _illegalChars = RegExp(r'[<>:"/\|?*\x00-\x1F]');
final _whitespace = RegExp(r'\s+');
final _trailingDotsOrSpaces = RegExp(r'[. ]+$');
const _reservedWindowsNames = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// Turns a design title into a file/folder name valid on Windows, macOS and
/// Linux: drops reserved characters, trailing dots/spaces and reserved
/// device names, and limits the length.
String safeFileName(String title, {int maxLength = 80}) {
  var name = title
      .replaceAll(_illegalChars, ' ')
      .replaceAll(_whitespace, ' ')
      .trim()
      .replaceAll(_trailingDotsOrSpaces, '');
  if (name.length > maxLength) {
    name = name
        .substring(0, maxLength)
        .trim()
        .replaceAll(_trailingDotsOrSpaces, '');
  }
  if (name.isEmpty) return 'Untitled design';
  if (_reservedWindowsNames.contains(name.toUpperCase())) return '$name design';
  return name;
}

/// Path for a new project titled [title] in [folder], following the
/// one-folder-per-project layout: `<folder>/<Name>/<Name>.opencanvasx`.
/// Adds " 2", " 3", … when the name is taken.
String newProjectPath(String folder, String title) {
  final sep = Platform.pathSeparator;
  final base = safeFileName(title);
  for (var n = 1; ; n++) {
    final name = n == 1 ? base : '$base $n';
    final dir = '$folder$sep$name';
    if (FileSystemEntity.typeSync(dir) == FileSystemEntityType.notFound) {
      return '$dir$sep$name$projectFileExtension';
    }
  }
}
