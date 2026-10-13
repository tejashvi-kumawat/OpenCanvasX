import 'dart:io';

import 'package:document_model/document_model.dart';

import 'project_file.dart';
import 'projects_location.dart';

/// File that marks a folder inside the projects root as a project (a
/// workspace group of designs, P2.5.3). Hidden, so design scans skip it.
const String projectMarker = '.opencanvasx-project';

/// Folder (inside the projects root) where trashed designs go.
const String trashFolder = '.trash';

/// Project folders directly inside [root], sorted by name.
List<String> listWorkspaceProjects(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  final sep = Platform.pathSeparator;
  return [
    for (final d in dir.listSync(followLinks: false).whereType<Directory>())
      if (File('${d.path}$sep$projectMarker').existsSync()) d.path,
  ]..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
}

/// Creates a project folder named [name] in [root]; returns its path.
Future<String> createWorkspaceProject(String root, String name) async {
  final sep = Platform.pathSeparator;
  final base = safeFileName(name.trim().isEmpty ? 'Project' : name.trim());
  var path = '$root$sep$base';
  for (
    var n = 2;
    FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    n++
  ) {
    path = '$root$sep$base $n';
  }
  await Directory(path).create(recursive: true);
  await File(
    '$path$sep$projectMarker',
  ).writeAsString('{"name": ${_jsonString(name.trim())}}\n');
  return path;
}

/// The project folder holding [designPath], or `null` if it is directly
/// in the root.
String? projectOf(String designPath) {
  final designFolder = File(designPath).parent;
  final parent = designFolder.parent;
  return File(
        '${parent.path}${Platform.pathSeparator}$projectMarker',
      ).existsSync()
      ? parent.path
      : null;
}

/// Moves the design at [designPath] (its whole folder, with backups) into
/// [destination] (the root or a project folder). Returns the new file path.
Future<String> moveDesign(String designPath, String destination) async {
  final sep = Platform.pathSeparator;
  final folder = File(designPath).parent;
  final fileName = _name(designPath);
  if (folder.parent.path == Directory(destination).path) return designPath;
  final target = _unique('$destination$sep${_name(folder.path)}');
  await folder.rename(target);
  return '$target$sep$fileName';
}

/// Moves the design at [designPath] into `<root>/.trash` (recoverable;
/// nothing is deleted). Returns where it went.
Future<String> trashDesign(String root, String designPath) async {
  final sep = Platform.pathSeparator;
  final trash = Directory('$root$sep$trashFolder');
  await trash.create(recursive: true);
  final folder = File(designPath).parent;
  final target = _unique('${trash.path}$sep${_name(folder.path)}');
  await folder.rename(target);
  return target;
}

/// Copies the design at [designPath] next to it as a new design (new
/// document id, title "<title> copy"). Returns the new file path.
Future<String> duplicateDesign(String designPath) async {
  final contents = await readProjectFile(designPath);
  final doc = contents.document;
  final title = '${doc.metadata.title} copy';
  final now = DateTime.now();
  final copy = DesignDocument(
    id: DocumentId.generate(),
    metadata: DocumentMetadata(
      title: title,
      author: doc.metadata.author,
      createdAt: now,
      modifiedAt: now,
    ),
    pages: doc.pages,
    objects: doc.objects,
    styles: doc.styles,
    assets: doc.assets,
  );
  final path = newProjectPath(File(designPath).parent.parent.path, title);
  await saveProject(path, copy, assets: contents.assets);
  return path;
}

/// Changes the title stored in the design at [designPath].
Future<void> renameDesign(String designPath, String title) async {
  final contents = await readProjectFile(designPath);
  final doc = contents.document;
  await saveProject(
    designPath,
    DesignDocument(
      id: doc.id,
      metadata: doc.metadata.copyWith(
        title: title.trim().isEmpty ? doc.metadata.title : title.trim(),
        modifiedAt: DateTime.now(),
      ),
      pages: doc.pages,
      objects: doc.objects,
      styles: doc.styles,
      assets: doc.assets,
    ),
    assets: contents.assets,
  );
}

String _unique(String path) {
  var candidate = path;
  for (
    var n = 2;
    FileSystemEntity.typeSync(candidate) != FileSystemEntityType.notFound;
    n++
  ) {
    candidate = '$path $n';
  }
  return candidate;
}

String _name(String path) =>
    path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;

String _jsonString(String s) =>
    '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
