/// Bundled asset packs (P2.1.7). Packs live in `assets/packs/<id>/` with a
/// `pack.json` manifest and LICENSE; build them with
/// `scripts/asset_packs/build_packs.py`.
library;

import 'dart:convert';

import 'package:asset_engine/asset_engine.dart';
import 'package:flutter/services.dart';

/// Bundle key of a pack file.
String packAssetKey(String packId, String file) =>
    'packages/asset_packs/assets/packs/$packId/$file';

/// Loads every pack listed in `index.json`. Packs whose manifest fails
/// validation (e.g. missing licence metadata) are skipped and reported
/// through [onError].
Future<AssetCatalog> loadBundledCatalog(
  AssetBundle bundle, {
  void Function(String packId, Object error)? onError,
}) async {
  final index =
      jsonDecode(
            await bundle.loadString(
              'packages/asset_packs/assets/packs/index.json',
            ),
          )
          as Map<String, Object?>;
  final packs = <AssetPack>[];
  for (final entry in (index['packs']! as List).cast<Map<String, Object?>>()) {
    final id = entry['id']! as String;
    try {
      final json =
          jsonDecode(await bundle.loadString(packAssetKey(id, 'pack.json')))
              as Map<String, Object?>;
      packs.add(AssetPack.fromJson(json));
    } on Object catch (e) {
      onError?.call(id, e);
    }
  }
  return AssetCatalog(packs);
}

/// Bytes of [item].
Future<Uint8List> loadItemBytes(AssetBundle bundle, AssetItem item) async {
  final data = await bundle.load(packAssetKey(item.packId, item.file));
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
