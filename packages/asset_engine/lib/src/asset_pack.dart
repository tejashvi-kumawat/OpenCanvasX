import 'package:meta/meta.dart';

/// What a pack offers in the asset panels (P2.1.3).
enum AssetKind {
  icon,
  sticker,
  illustration,
  photo,
  pattern,
  shape;

  static AssetKind parse(String value) => AssetKind.values.firstWhere(
    (k) => k.name == value,
    orElse: () => throw FormatException('unknown asset kind "$value"'),
  );
}

/// Licence facts every distributed asset must carry (asset-architecture.md,
/// legal-content-rules.md §63).
@immutable
final class AssetLicense {
  const AssetLicense({
    required this.spdx,
    required this.url,
    required this.author,
    required this.source,
    this.attributionRequired = false,
    this.attribution,
    this.redistribution = true,
    this.modification = true,
  });

  /// SPDX identifier, e.g. `MIT`, `CC-BY-4.0`.
  final String spdx;
  final String url;
  final String author;

  /// Where the pack came from (download URL).
  final String source;
  final bool attributionRequired;

  /// Credit line to show when [attributionRequired].
  final String? attribution;
  final bool redistribution;
  final bool modification;

  @override
  bool operator ==(Object other) =>
      other is AssetLicense &&
      other.spdx == spdx &&
      other.url == url &&
      other.author == author &&
      other.source == source &&
      other.attributionRequired == attributionRequired &&
      other.attribution == attribution &&
      other.redistribution == redistribution &&
      other.modification == modification;

  @override
  int get hashCode => Object.hash(
    spdx,
    url,
    author,
    source,
    attributionRequired,
    attribution,
    redistribution,
    modification,
  );
}

/// One file in a pack.
@immutable
final class AssetItem {
  const AssetItem({
    required this.id,
    required this.packId,
    required this.name,
    required this.file,
    required this.sha256,
    required this.mime,
    this.tags = const [],
    this.category = '',
    this.style,
  });

  /// `pack/stem`, unique across packs.
  final String id;
  final String packId;
  final String name;

  /// Path inside the pack folder, e.g. `svg/heart.svg`.
  final String file;
  final String sha256;
  final String mime;
  final List<String> tags;
  final String category;

  /// Variant within the pack (`outline`, `filled`, `duotone`, …).
  final String? style;

  bool get isSvg => mime == 'image/svg+xml';

  @override
  bool operator ==(Object other) => other is AssetItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AssetItem($id)';
}

/// A bundled or installed pack described by `pack.json`.
@immutable
final class AssetPack {
  const AssetPack({
    required this.id,
    required this.name,
    required this.kind,
    required this.version,
    required this.license,
    required this.items,
    this.recolorable = false,
  });

  /// Parses `pack.json`. Packs without complete licence metadata are
  /// rejected (P2.1.5) with a [FormatException].
  factory AssetPack.fromJson(Map<String, Object?> json) {
    String text(String key, {Map<String, Object?>? from}) {
      final value = (from ?? json)[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('pack.json: missing "$key"');
      }
      return value;
    }

    bool flag(String key, {bool fallback = false}) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! bool) throw FormatException('pack.json: "$key" not bool');
      return value;
    }

    final id = text('id');
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
      throw FormatException('pack.json: bad id "$id"');
    }
    final attributionRequired = flag('attribution_required');
    final attribution = json['attribution'];
    if (attributionRequired &&
        (attribution is! String || attribution.isEmpty)) {
      throw const FormatException('pack.json: attribution text required');
    }
    final license = AssetLicense(
      spdx: text('license'),
      url: text('license_url'),
      author: text('author'),
      source: text('source'),
      attributionRequired: attributionRequired,
      attribution: attribution is String ? attribution : null,
      redistribution: flag('redistribution', fallback: true),
      modification: flag('modification', fallback: true),
    );
    if (!license.redistribution) {
      throw const FormatException('pack.json: not redistributable');
    }
    final rawItems = json['items'];
    if (rawItems is! List) throw const FormatException('pack.json: no items');
    final items = <AssetItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, Object?>) {
        throw const FormatException('pack.json: item is not an object');
      }
      final file = text('file', from: raw);
      if (file.contains('..') || file.startsWith('/') || file.contains(r'\')) {
        throw FormatException('pack.json: unsafe path "$file"');
      }
      final tags = raw['tags'];
      final style = raw['style'];
      items.add(
        AssetItem(
          id: text('id', from: raw),
          packId: id,
          name: text('name', from: raw),
          file: file,
          sha256: text('sha256', from: raw),
          mime: text('mime', from: raw),
          tags: [
            if (tags is List)
              for (final t in tags)
                if (t is String) t.toLowerCase(),
          ],
          category: raw['category'] is String ? raw['category']! as String : '',
          style: style is String ? style : null,
        ),
      );
    }
    return AssetPack(
      id: id,
      name: text('name'),
      kind: AssetKind.parse(text('kind')),
      version: text('version'),
      license: license,
      items: List.unmodifiable(items),
      recolorable: flag('recolorable'),
    );
  }

  final String id;
  final String name;
  final AssetKind kind;
  final String version;
  final AssetLicense license;
  final List<AssetItem> items;

  /// Monochrome artwork drawn in `currentColor` that takes the object's
  /// colour.
  final bool recolorable;

  /// Reference stored in a document's asset index (`AssetInfo.licenseRef`).
  String get licenseRef => 'pack:$id@$version';

  /// Categories in first-seen order.
  List<String> get categories => [
    ...{for (final item in items) item.category},
  ];
}
