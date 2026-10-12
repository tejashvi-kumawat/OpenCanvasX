import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'template_info.dart';

/// Largest template file accepted from a repository.
const int maxTemplateBytes = 20 * 1024 * 1024;

/// Largest repository index accepted.
const int maxIndexBytes = 2 * 1024 * 1024;

/// A template and the repository it comes from.
typedef TemplateEntry = ({TemplateInfo info, TemplateRepository repository});

/// A source of templates (P6.2): a folder or a URL serving `index.json`
/// next to the template files (template-architecture.md "Sources").
@immutable
sealed class TemplateRepository {
  const TemplateRepository();

  /// Stable key, e.g. the folder path or the index URL.
  String get key;

  /// Short label for the UI.
  String get label;

  /// Templates listed by the repository (may use a cached index).
  Future<List<TemplateEntry>> list();

  @override
  bool operator ==(Object other) =>
      other is TemplateRepository &&
      other.runtimeType == runtimeType &&
      other.key == key;

  @override
  int get hashCode => Object.hash(runtimeType, key);

  /// The `.opencanvasx` bytes of [info], verified against the index's
  /// size and SHA-256 when given.
  Future<Uint8List> fetch(TemplateInfo info);
}

/// Templates in a local folder with an `index.json` (official templates
/// shipped next to the app, the user's own folders, Git checkouts).
final class FolderTemplateRepository extends TemplateRepository {
  const FolderTemplateRepository(this.path, {String? label}) : _label = label;

  final String path;
  final String? _label;

  @override
  String get key => path;

  @override
  String get label =>
      _label ??
      path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).lastOrNull ??
      path;

  @override
  Future<List<TemplateEntry>> list() async {
    final index = File('$path${Platform.pathSeparator}index.json');
    if (!index.existsSync()) return const [];
    if (index.lengthSync() > maxIndexBytes) {
      throw const FormatException('template index is too large');
    }
    final json = jsonDecode(await index.readAsString());
    if (json is! Map<String, Object?>) {
      throw const FormatException('template index is not an object');
    }
    return [
      for (final info in parseTemplateIndex(json))
        (info: info, repository: this),
    ];
  }

  @override
  Future<Uint8List> fetch(TemplateInfo info) async {
    final file = File('$path${Platform.pathSeparator}${info.file}');
    if (file.lengthSync() > maxTemplateBytes) {
      throw const FormatException('template file is too large');
    }
    return verifyTemplateBytes(info, await file.readAsBytes());
  }
}

/// A repository on the web (static HTTPS or a raw Git host). Nothing is
/// downloaded until the user asks: [refresh] fetches the index; [fetch]
/// downloads one template, which must match the index's SHA-256.
/// Downloads are cached in [cacheDir].
final class HttpTemplateRepository extends TemplateRepository {
  HttpTemplateRepository(this.indexUrl, {required this.cacheDir, this.name})
    : assert(indexUrl.endsWith('.json'), 'URL must point at index.json');

  /// URL of `index.json`; files are resolved relative to it.
  final String indexUrl;
  final String cacheDir;
  final String? name;

  @override
  String get key => indexUrl;

  @override
  String get label => name ?? Uri.parse(indexUrl).host;

  /// Folder for this repository's cache.
  String get _dir =>
      '$cacheDir${Platform.pathSeparator}'
      '${sha256.convert(utf8.encode(indexUrl)).toString().substring(0, 16)}';

  File get _cachedIndex => File('$_dir${Platform.pathSeparator}index.json');

  /// Whether an index has been downloaded before.
  bool get hasIndex => _cachedIndex.existsSync();

  /// Whether [info]'s file has been downloaded.
  bool isCached(TemplateInfo info) =>
      File('$_dir${Platform.pathSeparator}${info.file}').existsSync();

  @override
  Future<List<TemplateEntry>> list() async {
    if (!hasIndex) return const [];
    final json = jsonDecode(await _cachedIndex.readAsString());
    if (json is! Map<String, Object?>) return const [];
    return [
      for (final info in parseTemplateIndex(json))
        (info: info, repository: this),
    ];
  }

  /// Downloads the index (only https, or http to localhost).
  Future<List<TemplateEntry>> refresh() async {
    final bytes = await _get(Uri.parse(indexUrl), maxIndexBytes);
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, Object?>) {
      throw const FormatException('template index is not an object');
    }
    parseTemplateIndex(json); // validate before caching
    Directory(_dir).createSync(recursive: true);
    await _cachedIndex.writeAsBytes(bytes, flush: true);
    return list();
  }

  @override
  Future<Uint8List> fetch(TemplateInfo info) async {
    if (info.sha256 == null) {
      throw const FormatException(
        'remote templates must list a sha256 in the index',
      );
    }
    final cached = File('$_dir${Platform.pathSeparator}${info.file}');
    if (cached.existsSync()) {
      try {
        return verifyTemplateBytes(info, await cached.readAsBytes());
      } on FormatException {
        cached.deleteSync();
      }
    }
    final url = Uri.parse(indexUrl).resolve(info.file);
    final bytes = verifyTemplateBytes(info, await _get(url, maxTemplateBytes));
    Directory(_dir).createSync(recursive: true);
    await cached.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  static Future<Uint8List> _get(Uri url, int limit) async {
    final local = url.host == 'localhost' || url.host == '127.0.0.1';
    if (url.scheme != 'https' && !(url.scheme == 'http' && local)) {
      throw const FormatException('repositories must use https');
    }
    final client =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 15)
          ..userAgent = 'OpenCanvasX';
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      final out = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        out.add(chunk);
        if (out.length > limit) {
          throw const FormatException('download is too large');
        }
      }
      return out.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}

/// [bytes] if they match [info]'s declared size and SHA-256; otherwise a
/// [FormatException].
Uint8List verifyTemplateBytes(TemplateInfo info, Uint8List bytes) {
  if (bytes.length > maxTemplateBytes) {
    throw const FormatException('template file is too large');
  }
  if (info.bytes case final size? when size != bytes.length) {
    throw FormatException('${info.file}: size does not match the index');
  }
  if (info.sha256 case final hash?
      when sha256.convert(bytes).toString() != hash.toLowerCase()) {
    throw FormatException('${info.file}: checksum does not match the index');
  }
  return bytes;
}
