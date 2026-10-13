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

/// A bundled open-licence font family (OFL, from Google Fonts).
typedef BundledFont = ({String family, String category});

Future<List<BundledFont>>? _fonts;

/// Registers the bundled fonts in `assets/fonts/` with the engine and
/// returns their families. Runs once; later calls return the same result.
/// Families whose files fail to load are left out.
Future<List<BundledFont>> loadBundledFonts(AssetBundle bundle) =>
    _fonts ??= _loadFonts(bundle);

Future<List<BundledFont>> _loadFonts(AssetBundle bundle) async {
  const base = 'packages/asset_packs/assets/fonts';
  final Map<String, Object?> index;
  try {
    index =
        jsonDecode(await bundle.loadString('$base/index.json'))
            as Map<String, Object?>;
  } on Object {
    return const [];
  }
  final fonts = <BundledFont>[];
  for (final entry
      in (index['families']! as List).cast<Map<String, Object?>>()) {
    final dir = entry['dir']! as String;
    final family = entry['family']! as String;
    try {
      final meta =
          jsonDecode(await bundle.loadString('$base/$dir/font.json'))
              as Map<String, Object?>;
      final loader = FontLoader(family);
      for (final file
          in (meta['files']! as List).cast<Map<String, Object?>>()) {
        loader.addFont(bundle.load('$base/$dir/${file['file']}'));
      }
      await loader.load();
      fonts.add((family: family, category: entry['category']! as String));
    } on Object {
      // Skipped; the family falls back to the default font.
    }
  }
  return fonts;
}

/// The font file of bundled family [family] (case-insensitive), for
/// embedding in PDFs; `null` if it is not bundled.
Future<Uint8List?> loadBundledFontFile(
  AssetBundle bundle,
  String family,
) async {
  const base = 'packages/asset_packs/assets/fonts';
  try {
    final index =
        jsonDecode(await bundle.loadString('$base/index.json'))
            as Map<String, Object?>;
    for (final entry
        in (index['families']! as List).cast<Map<String, Object?>>()) {
      if ((entry['family']! as String).toLowerCase() != family.toLowerCase()) {
        continue;
      }
      final dir = entry['dir']! as String;
      final meta =
          jsonDecode(await bundle.loadString('$base/$dir/font.json'))
              as Map<String, Object?>;
      final file =
          (meta['files']! as List).cast<Map<String, Object?>>().first['file'];
      final data = await bundle.load('$base/$dir/$file');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
  } on Object {
    return null;
  }
  return null;
}
