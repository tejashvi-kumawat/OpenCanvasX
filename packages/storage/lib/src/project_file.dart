import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

import 'project_archive.dart';

/// Autosave copy kept next to a project file until the next explicit save.
String autosavePathFor(String projectPath) => '$projectPath.autosave';

/// Writes a project to [path] atomically (storage-architecture.md):
/// the ZIP is written to `<path>.tmp`, flushed, read back and verified, then
/// renamed over [path]. A crash at any point leaves the previous file intact.
Future<void> writeProjectFile(
  String path,
  DesignDocument document, {
  Map<String, Uint8List> assets = const {},
  String? appVersion,
  Uint8List? thumbnail,
}) async {
  final bytes = encodeProject(
    document,
    assets: assets,
    appVersion: appVersion,
    thumbnail: thumbnail,
  );
  final temp = File('$path.tmp');
  await temp.parent.create(recursive: true);
  await temp.writeAsBytes(bytes, flush: true);
  try {
    // Never replace a good file with one we cannot read back.
    decodeProject(await temp.readAsBytes());
    await temp.rename(path);
  } on Object {
    if (temp.existsSync()) await temp.delete();
    rethrow;
  }
}

/// Reads and decodes a project file. See [decodeProject] for errors.
Future<ProjectContents> readProjectFile(
  String path, {
  ArchiveLimits limits = const ArchiveLimits(),
  bool readAssets = true,
}) async {
  final file = File(path);
  final length = await file.length();
  if (length > limits.maxArchiveBytes) {
    throw FormatException(
      'Project file is larger than ${limits.maxArchiveBytes} bytes',
    );
  }
  return decodeProject(
    await file.readAsBytes(),
    limits: limits,
    readAssets: readAssets,
  );
}

/// Saves explicitly: writes [path] atomically, then removes the autosave
/// copy because it is no longer ahead of the saved file.
Future<void> saveProject(
  String path,
  DesignDocument document, {
  Map<String, Uint8List> assets = const {},
  String? appVersion,
  Uint8List? thumbnail,
}) async {
  await writeProjectFile(
    path,
    document,
    assets: assets,
    appVersion: appVersion,
    thumbnail: thumbnail,
  );
  final autosave = File(autosavePathFor(path));
  if (autosave.existsSync()) await autosave.delete();
}

/// Which copy [openProject] loaded.
enum ProjectSource {
  /// The project file itself.
  saved,

  /// The autosave copy, because the project file could not be read.
  autosave,
}

/// Result of [openProject].
@immutable
final class OpenedProject {
  const OpenedProject({
    required this.contents,
    required this.source,
    required this.newerAutosaveAvailable,
  });

  final ProjectContents contents;
  final ProjectSource source;

  /// The saved file was opened, but a readable autosave copy is newer.
  /// The UI must ask whether to restore it; neither copy is discarded.
  final bool newerAutosaveAvailable;
}

/// Opens [path], falling back to its autosave copy when the project file is
/// missing, truncated or corrupt (crash recovery).
///
/// When both are readable and the autosave is newer, the saved file is
/// returned with [OpenedProject.newerAutosaveAvailable] set, so the user
/// chooses; this never silently picks a winner.
Future<OpenedProject> openProject(
  String path, {
  ArchiveLimits limits = const ArchiveLimits(),
}) async {
  final autosavePath = autosavePathFor(path);
  final hasAutosave = File(autosavePath).existsSync();

  final ProjectContents saved;
  try {
    saved = await readProjectFile(path, limits: limits);
  } on Object {
    if (!hasAutosave) rethrow;
    final recovered = await _tryRead(autosavePath, limits);
    if (recovered == null) rethrow;
    return OpenedProject(
      contents: recovered,
      source: ProjectSource.autosave,
      newerAutosaveAvailable: false,
    );
  }

  var newer = false;
  if (hasAutosave) {
    final autosaveTime = File(autosavePath).lastModifiedSync();
    final savedTime = File(path).lastModifiedSync();
    newer =
        autosaveTime.isAfter(savedTime) &&
        await _tryRead(autosavePath, limits) != null;
  }
  return OpenedProject(
    contents: saved,
    source: ProjectSource.saved,
    newerAutosaveAvailable: newer,
  );
}

Future<ProjectContents?> _tryRead(String path, ArchiveLimits limits) async {
  try {
    return await readProjectFile(path, limits: limits);
  } on Object {
    return null;
  }
}

/// Schedules a timer; replaceable in tests.
typedef TimerFactory = Timer Function(Duration delay, void Function() run);

/// Debounced autosave: after edits stop for [delay], runs [save] once.
///
/// Saves never overlap; edits made during a save schedule another one.
/// Failures go to [onError] and leave the autosaver dirty so the next
/// edit or [flush] retries.
final class Autosaver {
  Autosaver({
    required this.save,
    this.delay = const Duration(seconds: 2),
    this.onError,
    TimerFactory? timer,
  }) : _timer = timer ?? Timer.new;

  /// Writes the current document, usually to [autosavePathFor].
  final Future<void> Function() save;

  /// Quiet period after the last edit (configurable per settings).
  final Duration delay;

  final void Function(Object error, StackTrace stack)? onError;

  final TimerFactory _timer;
  Timer? _pending;
  Future<void>? _running;
  bool _dirty = false;
  bool _disposed = false;

  /// Whether edits exist that have not been autosaved yet.
  bool get isDirty => _dirty;

  /// Records an edit and restarts the quiet period.
  void markDirty() {
    if (_disposed) return;
    _dirty = true;
    _pending?.cancel();
    _pending = _timer(delay, () => unawaited(_run()));
  }

  /// Saves now if dirty and waits for any save in progress.
  Future<void> flush() async {
    _pending?.cancel();
    _pending = null;
    await _running;
    if (_dirty) await _run();
  }

  /// Stops scheduling. Call [flush] first to keep pending edits.
  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _pending = null;
  }

  Future<void> _run() async {
    while (_running != null) {
      await _running;
    }
    if (!_dirty) return;
    _dirty = false;
    final run = _guardedSave();
    _running = run;
    await run;
    _running = null;
  }

  Future<void> _guardedSave() async {
    try {
      await save();
    } on Object catch (error, stack) {
      _dirty = true;
      onError?.call(error, stack);
    }
  }
}
