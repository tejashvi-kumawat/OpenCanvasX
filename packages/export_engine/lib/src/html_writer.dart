import 'dart:typed_data';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';

import 'export_targets.dart';
import 'svg_writer.dart';

/// A static website from [document] (P3.9.2): one HTML file per target —
/// the frames of a board (prototype links become real links between the
/// pages) or the design's pages (with previous/next links). Each page
/// embeds its design as inline SVG that scales to the window, so text stays
/// sharp and selectable. Returns file name → contents; the first file is
/// `index.html`.
Map<String, String> exportHtmlSite(
  DesignDocument document,
  List<ExportTarget> targets, {
  required Map<String, Uint8List> assets,
  TextLineBreaker lines = explicitLines,
  TextSegmenter? segments,
}) {
  if (targets.isEmpty) return const {};
  // Stable, unique file names: index.html, then slugs of target names.
  final names = <String>[];
  final used = <String>{'index'};
  for (final (i, target) in targets.indexed) {
    if (i == 0) {
      names.add('index.html');
      continue;
    }
    var slug = _slug(target.name);
    if (slug.isEmpty) slug = 'page-${i + 1}';
    var unique = slug;
    for (var n = 2; used.contains(unique); n++) {
      unique = '$slug-$n';
    }
    used.add(unique);
    names.add('$unique.html');
  }
  final fileOfFrame = <ObjectId, String>{
    for (final (i, t) in targets.indexed)
      if (t.roots.length == 1) t.roots.single: names[i],
  };

  final files = <String, String>{};
  for (final (i, target) in targets.indexed) {
    final page = document.pages.firstWhere((p) => p.id == target.pageId);
    final r = target.region;
    final svg = exportSvg(
      document,
      target,
      assets: assets,
      lines: lines,
      segments: segments,
    ).replaceFirst(RegExp(r'^<\?xml[^>]*\?>\s*'), '');
    final background = switch (page.background) {
      SolidBackground(:final color) when page.isBoard => _css(color),
      _ => '#f1f2f4',
    };

    // Hotspots for prototype links on this target.
    final hotspots = StringBuffer();
    for (final link in page.links) {
      final href = fileOfFrame[link.target];
      if (href == null) continue;
      if (!_insideTarget(document, link.source, target)) continue;
      final b = worldBounds(document, link.source);
      if (b == null) continue;
      String pct(double v, double of) =>
          '${(v / of * 100).toStringAsFixed(4)}%';
      final style = [
        'left:${pct(b.left - r.left, r.width)}',
        'top:${pct(b.top - r.top, r.height)}',
        'width:${pct(b.width, r.width)}',
        'height:${pct(b.height, r.height)}',
      ].join(';');
      final label = _attr(_nameOf(document, link.target));
      hotspots.writeln(
        '<a class="hotspot" href="$href" aria-label="Go to $label" '
        'style="$style"></a>',
      );
    }
    final pager =
        page.isBoard
            ? ''
            : '<nav class="pager">'
                '${i > 0 ? '<a href="${names[i - 1]}">← Previous</a>' : '<span></span>'}'
                '<span>${i + 1} / ${targets.length}</span>'
                '${i < targets.length - 1 ? '<a href="${names[i + 1]}">Next →</a>' : '<span></span>'}'
                '</nav>';
    final width = exportPixelSize(page, target).width;
    files[names[i]] = '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="generator" content="OpenCanvasX">
<title>${_text(target.name)} · ${_text(document.metadata.title)}</title>
<style>
  html, body { margin: 0; background: $background; }
  body { font-family: system-ui, sans-serif; }
  .frame { position: relative; max-width: ${width}px; margin: 0 auto; }
  .frame > svg { display: block; width: 100%; height: auto; }
  .hotspot { position: absolute; display: block; border-radius: 4px; }
  .hotspot:focus-visible { outline: 3px solid #3256f0; outline-offset: 2px; }
  .pager { display: flex; justify-content: space-between; max-width: ${width}px;
    margin: 12px auto; padding: 0 12px; box-sizing: border-box; color: #5b616e; font-size: 14px; }
  .pager a { color: #3256f0; text-decoration: none; }
</style>
</head>
<body>
<main class="frame">
$svg$hotspots</main>
$pager
</body>
</html>
''';
  }
  return files;
}

bool _insideTarget(DesignDocument document, ObjectId id, ExportTarget target) =>
    ancestorPath(document, id).any(target.roots.contains);

String _nameOf(DesignDocument document, ObjectId id) =>
    document.objects[id]?.name ?? 'next page';

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _css(ArgbColor c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _text(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _attr(String s) => _text(s).replaceAll('"', '&quot;');
