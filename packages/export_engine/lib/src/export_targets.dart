import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

/// What to export (P1.9).
enum ExportScope {
  /// The active page; on a board, each of its top-level frames.
  currentPage,

  /// Every page; boards contribute their frames.
  allPages,

  /// The selected objects, cropped to their bounds.
  selection,
}

/// One output image/page: a region of a page and the objects drawn in it.
@immutable
final class ExportTarget {
  const ExportTarget({
    required this.pageId,
    required this.name,
    required this.region,
    required this.roots,
    required this.includeBackground,
  });

  final PageId pageId;

  /// File-name friendly label ("Page 2", "Phone — Home").
  final String name;

  /// Area to export, in page units.
  final Rect2D region;

  /// Objects to draw (with their descendants), back to front. They may be
  /// nested: they are drawn with their parents' transforms.
  final List<ObjectId> roots;

  /// Whether the page background is drawn under the objects.
  final bool includeBackground;

  @override
  String toString() => 'ExportTarget($name, $region)';
}

/// The targets for [scope]. Fixed pages export whole; boards export each
/// visible top-level frame (or all content when they have none).
List<ExportTarget> exportTargets(
  DesignDocument document, {
  required ExportScope scope,
  required PageId activePage,
  Set<ObjectId> selection = const {},
}) {
  switch (scope) {
    case ExportScope.selection:
      final page = document.pages.firstWhere((p) => p.id == activePage);
      final ordered = [
        for (final id in pageObjectsInOrder(document, page))
          if (selection.contains(id) &&
              !_hasSelectedAncestor(document, id, selection))
            id,
      ];
      final bounds = selectionBounds(document, ordered);
      if (bounds == null || ordered.isEmpty) return const [];
      final single =
          ordered.length == 1 ? document.objects[ordered.first] : null;
      return [
        ExportTarget(
          pageId: page.id,
          name: single == null ? 'Selection' : (single.name ?? 'Selection'),
          region: bounds,
          roots: ordered,
          includeBackground: false,
        ),
      ];
    case ExportScope.currentPage:
      final index = document.pages.indexWhere((p) => p.id == activePage);
      return _pageTargets(document, document.pages[index], index);
    case ExportScope.allPages:
      return [
        for (final (i, page) in document.pages.indexed)
          ..._pageTargets(document, page, i),
      ];
  }
}

List<ExportTarget> _pageTargets(
  DesignDocument document,
  DesignPage page,
  int index,
) {
  final label = page.name.isEmpty ? 'Page ${index + 1}' : page.name;
  if (!page.isBoard) {
    return [
      ExportTarget(
        pageId: page.id,
        name: label,
        region: Rect2D.fromLTWH(0, 0, page.width, page.height),
        roots: page.objectIds,
        includeBackground: true,
      ),
    ];
  }
  final frames = [
    for (final id in page.objectIds)
      if (document.objects[id] case final o?
          when o.type == ObjectType.frame && !o.hidden)
        o,
  ];
  if (frames.isEmpty) {
    final bounds = selectionBounds(document, page.objectIds);
    if (bounds == null) return const [];
    return [
      ExportTarget(
        pageId: page.id,
        name: label,
        region: bounds,
        roots: page.objectIds,
        includeBackground: true,
      ),
    ];
  }
  var n = 0;
  return [
    for (final frame in frames)
      if (worldBounds(document, frame.id) case final bounds?)
        ExportTarget(
          pageId: page.id,
          name: frame.name ?? 'Frame ${++n}',
          region: bounds,
          roots: [frame.id],
          includeBackground: false,
        ),
  ];
}

bool _hasSelectedAncestor(
  DesignDocument document,
  ObjectId id,
  Set<ObjectId> selection,
) {
  var parent = document.objects[id]?.parentId;
  while (parent != null) {
    if (selection.contains(parent)) return true;
    parent = document.objects[parent]?.parentId;
  }
  return false;
}

/// Output pixel size of [target] at [scale] × the page's pixel size
/// (physical pages use their DPI).
({int width, int height}) exportPixelSize(
  DesignPage page,
  ExportTarget target, {
  double scale = 1,
}) {
  final perUnit = convertLength(
    1,
    from: page.unit,
    to: LengthUnit.px,
    dpi: page.unit == LengthUnit.px ? defaultDpi : page.dpi,
  );
  return (
    width: math.max(1, (target.region.width * perUnit * scale).round()),
    height: math.max(1, (target.region.height * perUnit * scale).round()),
  );
}

/// Size of [target] in PDF points (1/72 in).
({double width, double height}) exportPointSize(
  DesignPage page,
  ExportTarget target,
) => (
  width: convertLength(
    target.region.width,
    from: page.unit,
    to: LengthUnit.pt,
    dpi: page.dpi,
  ),
  height: convertLength(
    target.region.height,
    from: page.unit,
    to: LengthUnit.pt,
    dpi: page.dpi,
  ),
);

/// A safe file name from [name] ("Phone — Home" → "Phone - Home").
String exportFileName(String name, String extension) {
  final cleaned =
      name
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F—–]'), '-')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  final base = cleaned.isEmpty ? 'Export' : cleaned;
  return '${base.length > 80 ? base.substring(0, 80) : base}.$extension';
}
