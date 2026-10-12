import 'asset_pack.dart';

/// In-memory search over installed packs (P2.1.2). Ranking: exact name,
/// name prefix, exact tag, tag prefix, then substring matches.
final class AssetCatalog {
  AssetCatalog(Iterable<AssetPack> packs) : packs = List.unmodifiable(packs);

  final List<AssetPack> packs;

  AssetPack? pack(String id) => packs.where((p) => p.id == id).firstOrNull;

  /// Items matching every word of [query] (all items when blank), best
  /// first, optionally limited to a [kind], [packId], [category] or
  /// [style].
  List<AssetItem> search(
    String query, {
    AssetKind? kind,
    String? packId,
    String? category,
    String? style,
    int limit = 200,
  }) {
    final words =
        query
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();
    final scored = <(int, int, AssetItem)>[];
    var order = 0;
    for (final pack in packs) {
      if (kind != null && pack.kind != kind) continue;
      if (packId != null && pack.id != packId) continue;
      for (final item in pack.items) {
        if (category != null && item.category != category) continue;
        if (style != null && (item.style ?? '') != style) continue;
        final score = words.isEmpty ? 1 : _score(item, words);
        if (score > 0) scored.add((score, order++, item));
      }
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return [for (final (_, _, item) in scored.take(limit)) item];
  }

  static int _score(AssetItem item, List<String> words) {
    final name = item.name.toLowerCase();
    var total = 0;
    for (final word in words) {
      var best = 0;
      if (name == word) {
        best = 100;
      } else if (name.startsWith(word)) {
        best = 60;
      } else if (item.tags.contains(word)) {
        best = 50;
      } else if (item.tags.any((t) => t.startsWith(word))) {
        best = 30;
      } else if (name.contains(word) || item.category.contains(word)) {
        best = 10;
      }
      if (best == 0) return 0;
      total += best;
    }
    return total;
  }
}
