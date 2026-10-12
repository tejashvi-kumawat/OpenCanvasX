import 'dart:math' as math;

import 'package:document_model/document_model.dart';

import 'change.dart';
import 'scene.dart';

/// Creates ids for new objects; tests pass a deterministic one.
typedef ObjectIdFactory = ObjectId Function();

/// Creates ids for new pages.
typedef PageIdFactory = PageId Function();

ObjectId _newObjectId() => ObjectId.generate();
PageId _newPageId() => PageId.generate();

/// Default fill for new shapes.
final ArgbColor defaultShapeFill = ArgbColor(0xFF7B61FF);

/// Default colour for new lines and arrows.
final ArgbColor defaultLineColor = ArgbColor(0xFF1F2430);

/// Z-order moves for the Arrange menu.
enum ZOrderMove { forward, backward, toFront, toBack }

/// Alignment targets (P1.4.2).
enum AlignEdge { left, centerHorizontal, right, top, centerVertical, bottom }

// ----------------------------------------------------------------- objects

/// A new shape of [type] for [page] with sensible size and style, centred
/// on [center] (page centre by default).
DesignObject newShape(
  ObjectType type,
  DesignPage page, {
  required ObjectId id,
  Point2D? center,
}) {
  final base = math.min(page.width, page.height);
  final c = center ?? Point2D(page.width / 2, page.height / 2);
  final isLine = type == ObjectType.line || type == ObjectType.arrow;
  final width = _round(isLine ? base * 0.4 : base * 0.32);
  final height = isLine ? 0.0 : width;
  final style = switch (type) {
    ObjectType.line || ObjectType.arrow => ObjectStyle(
      stroke: Stroke(
        color: defaultLineColor,
        // About 1/200 of the page, never thinner than ~3 screen pixels.
        width: _round(math.max(base / 200, 3 / _pixelsPerUnit(page))),
      ),
    ),
    ObjectType.roundedRect => ObjectStyle(
      fill: SolidFill(defaultShapeFill),
      cornerRadius: _round(width * 0.12),
    ),
    _ => ObjectStyle(fill: SolidFill(defaultShapeFill)),
  };
  return DesignObject(
    id: id,
    type: type,
    pageId: page.id,
    transform: ObjectTransform(
      x: _round(c.x - width / 2),
      y: _round(c.y - height / 2),
      width: width,
      height: height,
    ),
    style: style,
  );
}

/// Adds root [objects] (with their [descendants]) on top of [pageId].
Change insertObjects(
  DesignDocument document,
  PageId pageId,
  List<DesignObject> objects, {
  List<DesignObject> descendants = const [],
  String label = 'Add element',
}) {
  final page = _page(document, pageId);
  return Change(
    label: label,
    objects: {
      for (final o in [...objects, ...descendants]) o.id: o,
    },
    pages: _replacePage(
      document,
      page.copyWith(
        objectIds: [...page.objectIds, ...objects.map((o) => o.id)],
      ),
    ),
  );
}

/// Replaces objects with edited versions (same ids).
Change updateObjects(
  DesignDocument document,
  Iterable<DesignObject> objects, {
  required String label,
}) => Change(
  label: label,
  objects: {
    for (final o in objects)
      if (document.objects[o.id] != o) o.id: o,
  },
);

/// Moves [ids] by `(dx, dy)` in their parents' units.
Change moveObjects(
  DesignDocument document,
  Iterable<ObjectId> ids,
  double dx,
  double dy, {
  String label = 'Move',
}) => updateObjects(document, [
  for (final id in ids)
    if (document.objects[id] case final o?)
      o.copyWith(
        transform: o.transform.copyWith(
          x: o.transform.x + dx,
          y: o.transform.y + dy,
        ),
      ),
], label: label);

/// Deletes [ids] and everything inside them, unlinking them from pages and
/// parent groups.
Change deleteObjects(
  DesignDocument document,
  Iterable<ObjectId> ids, {
  String label = 'Delete',
}) {
  final doomed = <ObjectId>{};
  for (final id in ids) {
    _collectSubtree(document, id, doomed);
  }
  if (doomed.isEmpty) return Change(label: label);

  final objects = <ObjectId, DesignObject?>{for (final id in doomed) id: null};
  for (final id in doomed) {
    final parentId = document.objects[id]?.parentId;
    if (parentId == null || doomed.contains(parentId)) continue;
    final parent = objects[parentId] ?? document.objects[parentId];
    if (parent != null) {
      objects[parentId] = parent.copyWith(
        childIds: parent.childIds.where((c) => !doomed.contains(c)),
      );
    }
  }
  final pages =
      document.pages
          .map(
            (page) =>
                page.objectIds.any(doomed.contains)
                    ? page.copyWith(
                      objectIds: page.objectIds.where(
                        (id) => !doomed.contains(id),
                      ),
                    )
                    : page,
          )
          .toList();
  return Change(label: label, objects: objects, pages: pages);
}

/// Every object in the subtrees of [ids], roots first, in z-order — what
/// the clipboard holds (P1.3.7).
List<DesignObject> copySubtrees(
  DesignDocument document,
  Iterable<ObjectId> ids,
) {
  final result = <DesignObject>[];
  final seen = <ObjectId>{};
  void visit(ObjectId id) {
    final object = document.objects[id];
    if (object == null || !seen.add(id)) return;
    result.add(object);
    object.childIds.forEach(visit);
  }

  ids.forEach(visit);
  return result;
}

/// Pastes [clipboard] (from [copySubtrees]) onto [pageId] with fresh ids,
/// shifted by [offset]. Returns the change and the new root ids.
(Change, List<ObjectId>) pasteObjects(
  DesignDocument document,
  PageId pageId,
  List<DesignObject> clipboard, {
  double offset = 0,
  ObjectIdFactory newId = _newObjectId,
  String label = 'Paste',
}) {
  final inClipboard = {for (final o in clipboard) o.id};
  final mapping = {for (final o in clipboard) o.id: newId()};
  final roots = <DesignObject>[];
  final descendants = <DesignObject>[];
  for (final o in clipboard) {
    final isRoot = o.parentId == null || !inClipboard.contains(o.parentId);
    final copy = DesignObject(
      id: mapping[o.id]!,
      type: o.type,
      transform:
          isRoot
              ? o.transform.copyWith(
                x: o.transform.x + offset,
                y: o.transform.y + offset,
              )
              : o.transform,
      pageId: isRoot ? pageId : null,
      parentId: isRoot ? null : mapping[o.parentId],
      childIds: [
        for (final c in o.childIds)
          if (mapping[c] case final mapped?) mapped,
      ],
      name: o.name,
      opacity: o.opacity,
      blendMode: o.blendMode,
      locked: o.locked,
      hidden: o.hidden,
      styleId: o.styleId,
      style: o.style,
      payload: o.payload,
    );
    (isRoot ? roots : descendants).add(copy);
  }
  final change = insertObjects(
    document,
    pageId,
    roots,
    descendants: descendants,
    label: label,
  );
  return (change, [for (final r in roots) r.id]);
}

/// Duplicates root [ids] on [pageId], offset so the copies are visible.
(Change, List<ObjectId>) duplicateObjects(
  DesignDocument document,
  PageId pageId,
  Iterable<ObjectId> ids, {
  required double offset,
  ObjectIdFactory newId = _newObjectId,
}) {
  final page = _page(document, pageId);
  final ordered = page.objectIds.where(ids.contains).toList();
  return pasteObjects(
    document,
    pageId,
    copySubtrees(document, ordered),
    offset: offset,
    newId: newId,
    label: 'Duplicate',
  );
}

/// Moves root [ids] on [pageId] in the stacking order.
Change reorderObjects(
  DesignDocument document,
  PageId pageId,
  Set<ObjectId> ids,
  ZOrderMove move,
) {
  final page = _page(document, pageId);
  final order = [...page.objectIds];
  switch (move) {
    case ZOrderMove.toFront:
      order
        ..removeWhere(ids.contains)
        ..addAll(page.objectIds.where(ids.contains));
    case ZOrderMove.toBack:
      order
        ..removeWhere(ids.contains)
        ..insertAll(0, page.objectIds.where(ids.contains));
    case ZOrderMove.forward:
      for (var i = order.length - 2; i >= 0; i--) {
        if (ids.contains(order[i]) && !ids.contains(order[i + 1])) {
          order.insert(i + 1, order.removeAt(i));
        }
      }
    case ZOrderMove.backward:
      for (var i = 1; i < order.length; i++) {
        if (ids.contains(order[i]) && !ids.contains(order[i - 1])) {
          order.insert(i - 1, order.removeAt(i));
        }
      }
  }
  return setLayerOrder(document, pageId, order, label: 'Arrange');
}

/// Sets the full back-to-front order of [pageId]'s roots (layers panel).
/// [order] must be a permutation of the page's current roots.
Change setLayerOrder(
  DesignDocument document,
  PageId pageId,
  List<ObjectId> order, {
  String label = 'Reorder layers',
}) {
  final page = _page(document, pageId);
  if (order.length != page.objectIds.length ||
      !order.toSet().containsAll(page.objectIds)) {
    throw ArgumentError.value(order, 'order', 'must permute the page roots');
  }
  if (_sameOrder(order, page.objectIds)) return Change(label: label);
  return Change(
    label: label,
    pages: _replacePage(document, page.copyWith(objectIds: order)),
  );
}

/// Aligns root [ids] to [edge] of [reference] (the page or the selection
/// bounds), using each object's rotated bounds.
Change alignObjects(
  DesignDocument document,
  Iterable<ObjectId> ids,
  AlignEdge edge,
  Rect2D reference,
) {
  final moved = <DesignObject>[];
  for (final id in ids) {
    final object = document.objects[id];
    final bounds = worldBounds(document, id);
    if (object == null || bounds == null) continue;
    final (dx, dy) = switch (edge) {
      AlignEdge.left => (reference.left - bounds.left, 0.0),
      AlignEdge.centerHorizontal => (reference.center.x - bounds.center.x, 0.0),
      AlignEdge.right => (reference.right - bounds.right, 0.0),
      AlignEdge.top => (0.0, reference.top - bounds.top),
      AlignEdge.centerVertical => (0.0, reference.center.y - bounds.center.y),
      AlignEdge.bottom => (0.0, reference.bottom - bounds.bottom),
    };
    moved.add(
      object.copyWith(
        transform: object.transform.copyWith(
          x: object.transform.x + dx,
          y: object.transform.y + dy,
        ),
      ),
    );
  }
  return updateObjects(document, moved, label: 'Align');
}

// ------------------------------------------------------------------- pages

/// Inserts [page] at [index] (end by default).
Change addPage(DesignDocument document, DesignPage page, {int? index}) {
  final pages = [...document.pages];
  pages.insert((index ?? pages.length).clamp(0, pages.length), page);
  return Change(label: 'Add page', pages: pages);
}

/// Removes [pageId] and its objects. The last page cannot be deleted.
Change deletePage(DesignDocument document, PageId pageId) {
  if (document.pages.length <= 1) {
    throw StateError('A design needs at least one page');
  }
  final page = _page(document, pageId);
  final doomed = <ObjectId>{};
  for (final id in page.objectIds) {
    _collectSubtree(document, id, doomed);
  }
  return Change(
    label: 'Delete page',
    objects: {for (final id in doomed) id: null},
    pages: [
      for (final p in document.pages)
        if (p.id != pageId) p,
    ],
  );
}

/// Copies [pageId] (settings and objects) right after itself.
(Change, PageId) duplicatePage(
  DesignDocument document,
  PageId pageId, {
  ObjectIdFactory newObjectId = _newObjectId,
  PageIdFactory newPageId = _newPageId,
}) {
  final page = _page(document, pageId);
  final copyId = newPageId();
  final clipboard = copySubtrees(document, page.objectIds);
  final (paste, newRoots) = pasteObjects(
    document,
    pageId,
    clipboard,
    newId: newObjectId,
  );
  // Re-home the pasted roots onto the new page.
  final objects = <ObjectId, DesignObject?>{
    for (final MapEntry(:key, :value) in paste.objects.entries)
      key:
          value != null && value.pageId != null
              ? value.copyWith(pageId: copyId)
              : value,
  };
  final copy = DesignPage(
    id: copyId,
    name: page.name.isEmpty ? '' : '${page.name} copy',
    width: page.width,
    height: page.height,
    unit: page.unit,
    dpi: page.dpi,
    background: page.background,
    bleed: page.bleed,
    margins: page.margins,
    guides: page.guides,
    objectIds: newRoots,
  );
  final index = document.pages.indexWhere((p) => p.id == pageId);
  final pages = [...document.pages]..insert(index + 1, copy);
  return (
    Change(label: 'Duplicate page', objects: objects, pages: pages),
    copyId,
  );
}

/// Moves the page at [from] to [to] (indexes in the page list).
Change movePage(DesignDocument document, int from, int to) {
  final pages = [...document.pages];
  if (from < 0 || from >= pages.length) {
    throw RangeError.index(from, pages, 'from');
  }
  final page = pages.removeAt(from);
  pages.insert(to.clamp(0, pages.length), page);
  return Change(label: 'Move page', pages: pages);
}

/// Replaces a page's settings (size, background, name, …).
Change updatePage(
  DesignDocument document,
  DesignPage page, {
  String label = 'Edit page',
}) {
  final current = _page(document, page.id);
  if (current == page) return Change(label: label);
  return Change(label: label, pages: _replacePage(document, page));
}

/// Renames the design.
Change renameDocument(DesignDocument document, String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty || trimmed == document.metadata.title) {
    return Change(label: 'Rename');
  }
  return Change(
    label: 'Rename',
    metadata: document.metadata.copyWith(title: trimmed),
  );
}

// ----------------------------------------------------------------- helpers

DesignPage _page(DesignDocument document, PageId id) =>
    document.pages.firstWhere(
      (p) => p.id == id,
      orElse: () => throw ArgumentError.value(id, 'pageId', 'unknown page'),
    );

List<DesignPage> _replacePage(DesignDocument document, DesignPage page) =>
    document.pages.map((p) => p.id == page.id ? page : p).toList();

void _collectSubtree(DesignDocument document, ObjectId id, Set<ObjectId> out) {
  final object = document.objects[id];
  if (object == null || !out.add(id)) return;
  for (final child in object.childIds) {
    _collectSubtree(document, child, out);
  }
}

bool _sameOrder(List<ObjectId> a, List<ObjectId> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

double _pixelsPerUnit(DesignPage page) =>
    convertLength(1, from: page.unit, to: LengthUnit.px, dpi: page.dpi);

double _round(double v) => (v * 10).roundToDouble() / 10;
