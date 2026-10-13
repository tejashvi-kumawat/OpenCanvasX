import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

/// File extension of OpenCanvasX projects (ADR-0004).
const String projectFileExtension = '.opencanvasx';

const _manifestName = 'manifest.json';
const _documentName = 'document.json';
const _fontsName = 'fonts.json';
const _assetPrefix = 'assets/sha256/';
const _thumbnailName = 'meta/thumbnails/cover.png';
const _maxThumbnailBytes = 2 << 20;

/// Bounds applied when opening a project file, which is untrusted input
/// (input-validation-policy.md: size limits, archive depth and file count).
@immutable
final class ArchiveLimits {
  const ArchiveLimits({
    this.maxArchiveBytes = 1 << 30,
    this.maxEntries = 20000,
    this.maxEntryBytes = 512 << 20,
    this.maxTotalBytes = 2 << 30,
    this.maxJsonBytes = 64 << 20,
    this.maxPathDepth = 8,
  });

  /// Size of the `.opencanvasx` file itself.
  final int maxArchiveBytes;

  /// Number of members in the ZIP.
  final int maxEntries;

  /// Declared uncompressed size of any single member.
  final int maxEntryBytes;

  /// Sum of declared uncompressed sizes of all members.
  final int maxTotalBytes;

  /// `manifest.json` / `document.json` size.
  final int maxJsonBytes;

  /// Path segments in a member name.
  final int maxPathDepth;
}

/// Result of opening a project file.
@immutable
final class ProjectContents {
  ProjectContents({
    required this.document,
    required Map<String, Uint8List> assets,
    required Iterable<String> missingAssets,
    required Iterable<ModelIssue> issues,
    this.thumbnail,
  }) : assets = Map.unmodifiable(assets),
       missingAssets = List.unmodifiable(missingAssets),
       issues = List.unmodifiable(issues);

  final DesignDocument document;

  /// A small PNG of the first page saved with the file (P1.6.5), if any.
  /// Only a cache: never trusted beyond being shown as an image.
  final Uint8List? thumbnail;

  /// Verified asset bytes by SHA-256 hex.
  final Map<String, Uint8List> assets;

  /// Indexed assets whose bytes are absent; the UI offers relink or
  /// placeholder and blocks export of objects using them (file-format.md).
  final List<String> missingAssets;

  /// Cross-reference problems from [DesignDocument.validate].
  final List<ModelIssue> issues;
}

/// Lowercase hex SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Packs [document] and its asset bytes into a `.opencanvasx` ZIP.
///
/// Only assets listed in the document's asset index are written. Throws
/// [ArgumentError] if any given bytes do not match their hash key.
Uint8List encodeProject(
  DesignDocument document, {
  Map<String, Uint8List> assets = const {},
  String? appVersion,
  Uint8List? thumbnail,
}) {
  for (final MapEntry(:key, :value) in assets.entries) {
    if (sha256Hex(value) != key) {
      throw ArgumentError.value(key, 'assets', 'bytes do not match hash');
    }
  }
  const json = JsonEncoder.withIndent('  ');
  final archive =
      Archive()
        ..add(
          ArchiveFile.string(
            _manifestName,
            json.convert(encodeManifest(document, appVersion: appVersion)),
          ),
        )
        ..add(
          ArchiveFile.string(
            _documentName,
            json.convert(encodeDocumentBody(document)),
          ),
        )
        // Families the text uses (P1.5.5), so another computer can tell
        // which fonts the design needs.
        ..add(
          ArchiveFile.string(
            _fontsName,
            json.convert({
              'families': [
                for (final family in usedFontFamilies(document))
                  {'family': family},
              ],
            }),
          ),
        );
  for (final hash in document.assets.keys) {
    final bytes = assets[hash];
    if (bytes != null) {
      archive.add(ArchiveFile.bytes('$_assetPrefix$hash', bytes));
    }
  }
  if (thumbnail != null && thumbnail.length <= _maxThumbnailBytes) {
    archive.add(ArchiveFile.bytes(_thumbnailName, thumbnail));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Opens a `.opencanvasx` ZIP produced by [encodeProject] or a compatible
/// writer.
///
/// Throws [FormatException] for anything that is not a well-formed project
/// within [limits], and `UnsupportedVersionException` for files from a
/// newer app. Missing assets and broken cross-references are reported in
/// the result rather than thrown, so the UI can offer repair.
ProjectContents decodeProject(
  Uint8List bytes, {
  ArchiveLimits limits = const ArchiveLimits(),
  bool readAssets = true,
}) {
  if (bytes.length > limits.maxArchiveBytes) {
    throw FormatException(
      'Project file is larger than ${limits.maxArchiveBytes} bytes',
    );
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('Not a valid $projectFileExtension file');
  }
  if (archive.isEmpty) {
    throw const FormatException('Not a valid $projectFileExtension file');
  }
  if (archive.length > limits.maxEntries) {
    throw FormatException('Project has more than ${limits.maxEntries} entries');
  }

  final members = <String, ArchiveFile>{};
  var total = 0;
  for (final entry in archive) {
    final name = entry.name;
    _checkEntryName(name, limits);
    if (entry.isSymbolicLink) {
      throw FormatException('Symbolic links are not allowed: $name');
    }
    if (!entry.isFile) continue;
    if (entry.size > limits.maxEntryBytes) {
      throw FormatException('Entry too large: $name');
    }
    total += entry.size;
    if (total > limits.maxTotalBytes) {
      throw const FormatException('Project expands beyond the size limit');
    }
    if (members.containsKey(name)) {
      throw FormatException('Duplicate entry: $name');
    }
    members[name] = entry;
  }

  final document = decodeDocument(
    manifest: _readJson(members, _manifestName, limits),
    body: _readJson(members, _documentName, limits),
  );

  final assets = <String, Uint8List>{};
  final missing = <String>[];
  for (final MapEntry(key: hash, value: info) in document.assets.entries) {
    if (!readAssets) break;
    final entry = members['$_assetPrefix$hash'];
    if (entry == null) {
      missing.add(hash);
      continue;
    }
    final data = _readBytes(entry);
    if (data.length != info.byteLength || sha256Hex(data) != hash) {
      throw FormatException('Asset is corrupt or was modified: $hash');
    }
    assets[hash] = data;
  }

  Uint8List? thumbnail;
  if (members[_thumbnailName] case final entry?
      when entry.size <= _maxThumbnailBytes) {
    final data = _readBytes(entry);
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    var isPng = data.length > png.length;
    for (var i = 0; isPng && i < png.length; i++) {
      isPng = data[i] == png[i];
    }
    if (isPng) thumbnail = data;
  }

  return ProjectContents(
    document: document,
    assets: assets,
    missingAssets: missing,
    issues: document.validate(),
    thumbnail: thumbnail,
  );
}

void _checkEntryName(String name, ArchiveLimits limits) {
  final segments = name.split('/');
  final unsafe =
      name.isEmpty ||
      name.startsWith('/') ||
      name.contains(r'\') ||
      name.contains(':') ||
      segments.any((s) => s == '..' || s == '.') ||
      segments.length > limits.maxPathDepth;
  if (unsafe) {
    throw FormatException('Unsafe entry name in project: $name');
  }
}

Uint8List _readBytes(ArchiveFile entry) {
  final data = entry.readBytes() ?? Uint8List(0);
  if (data.length != entry.size) {
    throw FormatException('Entry size mismatch: ${entry.name}');
  }
  return data;
}

Object? _readJson(
  Map<String, ArchiveFile> members,
  String name,
  ArchiveLimits limits,
) {
  final entry = members[name];
  if (entry == null) throw FormatException('Missing $name');
  if (entry.size > limits.maxJsonBytes) {
    throw FormatException('$name is too large');
  }
  try {
    return jsonDecode(utf8.decode(_readBytes(entry)));
  } on FormatException catch (e) {
    throw FormatException('$name is not valid JSON: ${e.message}');
  }
}

/// Font families used by text in [document], sorted.
List<String> usedFontFamilies(DesignDocument document) {
  final families = <String>{
    for (final o in document.objects.values)
      if (o.payload case TextPayload(:final fontFamily?)) fontFamily,
  };
  return families.toList()..sort();
}
