import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';

/// Limits for templates (P2.2.5): templates come from repositories the
/// user adds, so they are treated as untrusted input.
const int maxTemplatePages = 100;
const int maxTemplateObjects = 5000;
const int maxTemplateTextLength = 20000;

/// Problems that make [template] unusable; empty when it is valid.
/// Checks object graph integrity, size limits and asset references.
List<String> validateTemplate(DesignDocument template) {
  final issues = <String>[
    for (final issue in validatePages(template.pages, template.objects))
      issue.toString(),
  ];
  if (template.pages.isEmpty) issues.add('template has no pages');
  if (template.pages.length > maxTemplatePages) {
    issues.add('more than $maxTemplatePages pages');
  }
  if (template.objects.length > maxTemplateObjects) {
    issues.add('more than $maxTemplateObjects objects');
  }
  for (final o in template.objects.values) {
    final payload = o.payload;
    if (payload is TextPayload && payload.text.length > maxTemplateTextLength) {
      issues.add('${o.id.value}: text too long');
    }
    if (payload is ImagePayload &&
        !template.assets.containsKey(payload.assetHash)) {
      issues.add('${o.id.value}: missing asset ${payload.assetHash}');
    }
  }
  return issues;
}

/// A new design from [template] (P2.2.4): fresh document, page and object
/// ids, so designs made from the same template never collide.
DesignDocument instantiateTemplate(
  DesignDocument template, {
  required String title,
  DateTime? now,
  ObjectId Function()? newObjectId,
  PageId Function()? newPageId,
}) {
  final clone = _clone(
    template,
    template.pages,
    newObjectId ?? ObjectId.generate,
    newPageId ?? PageId.generate,
  );
  final time = now ?? DateTime.now();
  return DesignDocument(
    id: DocumentId.generate(),
    metadata: DocumentMetadata(title: title, createdAt: time, modifiedAt: time),
    pages: clone.pages,
    objects: clone.objects,
    styles: template.styles,
    assets: template.assets,
  );
}

/// Adds [template]'s pages to [document] after page [after] — or, when
/// [asFramesOn] names a board, adds each template page as a frame on it,
/// laid out to the right of the board's content. One undoable change,
/// with the ids of the new pages or frames.
TemplateInsertion insertTemplate(
  DesignDocument document,
  DesignDocument template, {
  required PageId after,
  PageId? asFramesOn,
  ObjectId Function()? newObjectId,
  PageId Function()? newPageId,
}) {
  final objectId = newObjectId ?? ObjectId.generate;
  final pageId = newPageId ?? PageId.generate;
  final assets = {
    for (final MapEntry(:key, :value) in template.assets.entries)
      if (!document.assets.containsKey(key)) key: value,
  };

  if (asFramesOn != null) {
    final board = document.pages.firstWhere((p) => p.id == asFramesOn);
    final bounds = selectionBounds(document, board.objectIds);
    var x = bounds == null ? 0.0 : bounds.right + 120;
    final y = bounds?.top ?? 0.0;
    final objects = <ObjectId, DesignObject?>{};
    final frames = <ObjectId>[];
    for (final page in template.pages) {
      final clone = _clone(template, [page], objectId, pageId);
      final frameId = objectId();
      final scale = convertLength(
        1,
        from: page.unit,
        to: board.unit,
        dpi: page.dpi,
      );
      final background = switch (page.background) {
        SolidBackground(:final color) => SolidFill(color),
        _ => null,
      };
      final roots = clone.pages.single.objectIds;
      for (final o in clone.objects.values) {
        objects[o.id] = o.pageId == null ? o : _reparent(o, frameId);
      }
      objects[frameId] = DesignObject(
        id: frameId,
        type: ObjectType.frame,
        pageId: board.id,
        name: page.name.isEmpty ? null : page.name,
        childIds: roots,
        transform: ObjectTransform(
          x: x,
          y: y,
          width: page.width,
          height: page.height,
          scaleX: scale,
          scaleY: scale,
          anchorX: 0,
          anchorY: 0,
        ),
        style: background == null ? null : ObjectStyle(fill: background),
        payload: const FramePayload(),
      );
      frames.add(frameId);
      x += page.width * scale + 80;
    }
    return (
      change: Change(
        label: 'Add template',
        objects: objects,
        pages: [
          for (final p in document.pages)
            if (p.id == board.id)
              p.copyWith(objectIds: [...p.objectIds, ...frames])
            else
              p,
        ],
        assets: assets,
      ),
      frames: frames,
      pages: const <PageId>[],
    );
  }

  final clone = _clone(template, template.pages, objectId, pageId);
  final index = document.pages.indexWhere((p) => p.id == after);
  final pages = [...document.pages]..insertAll(index + 1, clone.pages);
  return (
    change: Change(
      label: 'Add template',
      objects: {for (final o in clone.objects.values) o.id: o},
      pages: pages,
      assets: assets,
    ),
    frames: const <ObjectId>[],
    pages: [for (final p in clone.pages) p.id],
  );
}

/// Result of [insertTemplate].
typedef TemplateInsertion =
    ({Change change, List<ObjectId> frames, List<PageId> pages});

DesignObject _reparent(DesignObject o, ObjectId parent) => DesignObject(
  id: o.id,
  type: o.type,
  transform: o.transform,
  parentId: parent,
  childIds: o.childIds,
  name: o.name,
  opacity: o.opacity,
  blendMode: o.blendMode,
  locked: o.locked,
  hidden: o.hidden,
  styleId: o.styleId,
  style: o.style,
  payload: o.payload,
);

/// [pages] of [source] and their objects with fresh ids.
({List<DesignPage> pages, Map<ObjectId, DesignObject> objects}) _clone(
  DesignDocument source,
  List<DesignPage> pages,
  ObjectId Function() objectId,
  PageId Function() pageId,
) {
  final ids = <ObjectId, ObjectId>{};
  ObjectId map(ObjectId id) => ids.putIfAbsent(id, objectId);
  final objects = <ObjectId, DesignObject>{};
  final newPages = <DesignPage>[];
  for (final page in pages) {
    final newPage = pageId();
    void visit(ObjectId id, ObjectId? parent, int depth) {
      final o = source.objects[id];
      if (o == null || depth > 64) return;
      final copy = DesignObject(
        id: map(id),
        type: o.type,
        transform: o.transform,
        pageId: parent == null ? newPage : null,
        parentId: parent,
        childIds: [
          for (final c in o.childIds)
            if (source.objects.containsKey(c)) map(c),
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
      objects[copy.id] = copy;
      for (final c in o.childIds) {
        visit(c, copy.id, depth + 1);
      }
    }

    for (final id in page.objectIds) {
      visit(id, null, 0);
    }
    newPages.add(
      DesignPage(
        id: newPage,
        width: page.width,
        height: page.height,
        name: page.name,
        unit: page.unit,
        dpi: page.dpi,
        background: page.background,
        bleed: page.bleed,
        margins: page.margins,
        guides: page.guides,
        kind: page.kind,
        objectIds: [
          for (final id in page.objectIds)
            if (source.objects.containsKey(id)) map(id),
        ],
      ),
    );
  }
  return (pages: newPages, objects: objects);
}

/// Scale that fits a template page of [width] × [height] into a box.
double fitScale(double width, double height, double boxW, double boxH) =>
    math.min(boxW / width, boxH / height);
