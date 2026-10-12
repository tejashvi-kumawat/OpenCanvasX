import 'dart:math' as math;

import 'package:document_model/document_model.dart';

import 'change.dart';
import 'edits.dart';
import 'scene.dart';
import 'transform_tools.dart';

/// Topmost ancestor of [id] (itself for a root); `null` if unknown.
DesignObject? rootOf(DesignDocument document, ObjectId id) {
  var current = document.objects[id];
  var guard = 0;
  while (current != null && current.parentId != null && guard++ < 64) {
    current = document.objects[current.parentId];
  }
  return current;
}

/// Matrix from [id]'s parent space to the page (identity for roots).
Affine2D parentToPage(DesignDocument document, ObjectId id) {
  final parentId = document.objects[id]?.parentId;
  return parentId == null ? Affine2D.identity : worldMatrix(document, parentId);
}

/// Converts a page-space point into [id]'s parent space.
Point2D pageToParent(DesignDocument document, ObjectId id, Point2D page) =>
    parentToPage(document, id).inverse()?.apply(page) ?? page;

/// [object] moved by a page-space delta, converted into its parent's space
/// so objects inside rotated or scaled groups follow the pointer.
DesignObject shiftedInPage(
  DesignDocument document,
  DesignObject object,
  double dx,
  double dy,
) {
  final inverse = parentToPage(document, object.id).inverse();
  final local =
      inverse == null
          ? Point2D(dx, dy)
          : inverse.applyToVector(Point2D(dx, dy));
  final t = object.transform;
  return object.copyWith(
    transform: t.copyWith(x: t.x + local.x, y: t.y + local.y),
  );
}

/// [inner] (in [outer]'s local space) expressed in [outer]'s parent space.
///
/// Rotation and scale are recombined; shear from non-uniform scale under
/// rotation cannot be represented and is dropped.
ObjectTransform composeTransform(ObjectTransform outer, ObjectTransform inner) {
  final m = localToParent(outer) * localToParent(inner);
  final sx = math.sqrt(m.a * m.a + m.b * m.b);
  final rotation = math.atan2(m.b, m.a) * 180 / math.pi;
  final sy = sx == 0 ? inner.scaleY : (m.a * m.d - m.b * m.c) / sx;
  final anchor = Point2D(
    inner.anchorX * inner.width,
    inner.anchorY * inner.height,
  );
  return placeTransform(
    inner.copyWith(
      rotation: rotation,
      scaleX: sx == 0 ? inner.scaleX : sx,
      scaleY: sy == 0 ? inner.scaleY : sy,
    ),
    local: anchor,
    lands: m.apply(anchor),
  );
}

/// [id]'s transform as if it were a root on the page.
ObjectTransform worldTransform(DesignDocument document, ObjectId id) {
  final object = document.objects[id]!;
  final parentId = object.parentId;
  if (parentId == null) return object.transform;
  return composeTransform(worldTransform(document, parentId), object.transform);
}

/// Groups [ids] (P1.3.6). They must share one parent (the page or a group);
/// returns an empty change otherwise. The group sits where the topmost
/// member was and its box fits the members' bounds.
(Change, ObjectId?) groupObjects(
  DesignDocument document,
  Iterable<ObjectId> ids, {
  ObjectIdFactory newId = _newId,
}) {
  final members = [
    for (final id in ids)
      if (document.objects[id] case final o?) o,
  ];
  if (members.length < 2) return (Change(label: 'Group'), null);
  final parentId = members.first.parentId;
  final pageId = members.first.pageId;
  if (members.any((o) => o.parentId != parentId || o.pageId != pageId)) {
    return (Change(label: 'Group'), null);
  }

  final siblings = _siblings(document, members.first);
  final memberIds = {for (final m in members) m.id};
  final ordered = siblings.where(memberIds.contains).toList();
  var bounds = boundsInParent(document.objects[ordered.first]!.transform);
  for (final id in ordered.skip(1)) {
    bounds = bounds.union(boundsInParent(document.objects[id]!.transform));
  }

  final groupId = newId();
  final group = DesignObject(
    id: groupId,
    type: ObjectType.group,
    pageId: pageId,
    parentId: parentId,
    childIds: ordered,
    transform: ObjectTransform(
      x: bounds.left,
      y: bounds.top,
      width: bounds.width,
      height: bounds.height,
    ),
  );
  final objects = <ObjectId, DesignObject?>{groupId: group};
  for (final id in ordered) {
    final o = document.objects[id]!;
    objects[id] = DesignObject(
      id: o.id,
      type: o.type,
      transform: o.transform.copyWith(
        x: o.transform.x - bounds.left,
        y: o.transform.y - bounds.top,
      ),
      parentId: groupId,
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
  }
  final topIndex = siblings.indexOf(ordered.last);
  final newOrder = [
    for (final (i, id) in siblings.indexed)
      if (i == topIndex) groupId else if (!memberIds.contains(id)) id,
  ];
  return (
    _withSiblingOrder(document, members.first, newOrder, objects, 'Group'),
    groupId,
  );
}

/// Dissolves [groupIds]; their children keep their place on the page and in
/// the stacking order. Returns the change and the released children.
(Change, List<ObjectId>) ungroupObjects(
  DesignDocument document,
  Iterable<ObjectId> groupIds,
) {
  var current = document;
  final released = <ObjectId>[];
  final objects = <ObjectId, DesignObject?>{};
  List<DesignPage>? pages;
  for (final id in groupIds) {
    final group = current.objects[id];
    if (group == null || group.type != ObjectType.group) continue;
    final children = [
      for (final c in group.childIds)
        if (current.objects[c] case final o?) o,
    ];
    final step = <ObjectId, DesignObject?>{id: null};
    for (final child in children) {
      step[child.id] = DesignObject(
        id: child.id,
        type: child.type,
        transform: composeTransform(group.transform, child.transform),
        pageId: group.pageId,
        parentId: group.parentId,
        childIds: child.childIds,
        name: child.name,
        opacity: child.opacity * group.opacity,
        blendMode: child.blendMode,
        locked: child.locked,
        hidden: child.hidden || group.hidden,
        styleId: child.styleId,
        style: child.style,
        payload: child.payload,
      );
    }
    final siblings = _siblings(current, group);
    final newOrder = [
      for (final s in siblings)
        if (s == id) ...group.childIds else s,
    ];
    final change = _withSiblingOrder(current, group, newOrder, step, 'Ungroup');
    current = change.applyTo(current).$1;
    objects.addAll(change.objects);
    if (change.pages != null) pages = change.pages;
    released.addAll(group.childIds);
  }
  return (Change(label: 'Ungroup', objects: objects, pages: pages), released);
}

/// Objects to preview when [group] is resized to [resized]: the group plus
/// every descendant scaled to fit, so content follows the handles. Text
/// sizes scale with the smaller factor.
List<DesignObject> resizeGroup(
  DesignDocument document,
  DesignObject group,
  ObjectTransform resized,
) {
  final old = group.transform;
  final sx = old.width == 0 ? 1.0 : resized.width / old.width;
  final sy = old.height == 0 ? 1.0 : resized.height / old.height;
  final result = <DesignObject>[group.copyWith(transform: resized)];
  void scaleChildren(DesignObject parent) {
    for (final id in parent.childIds) {
      final child = document.objects[id];
      if (child == null) continue;
      final t = child.transform;
      final payload = child.payload;
      result.add(
        child.copyWith(
          transform: t.copyWith(
            x: t.x * sx,
            y: t.y * sy,
            width: t.width * sx,
            height: t.height * sy,
          ),
          payload:
              payload is TextPayload
                  ? payload.copyWith(
                    fontSize: payload.fontSize * math.min(sx, sy),
                  )
                  : null,
        ),
      );
      if (child.type == ObjectType.group) scaleChildren(child);
    }
  }

  scaleChildren(group);
  return result;
}

/// Topmost visible, unlocked leaf (not a group) under [point], looking
/// inside groups — used for double-click "enter group" selection.
ObjectId? hitTestDeep(
  DesignDocument document,
  DesignPage page,
  Point2D point, {
  double tolerance = 0,
}) {
  ObjectId? search(List<ObjectId> ids) {
    for (final id in ids.reversed) {
      final object = document.objects[id];
      if (object == null || object.hidden || object.locked) continue;
      if (object.type == ObjectType.group) {
        final inside = search(object.childIds);
        if (inside != null) return inside;
        continue;
      }
      final local = worldMatrix(document, id).inverse()?.apply(point);
      if (local == null) continue;
      final probe = DesignObject(
        id: object.id,
        type: object.type,
        transform: ObjectTransform(
          width: object.transform.width,
          height: object.transform.height,
          anchorX: 0,
          anchorY: 0,
        ),
        pageId: page.id,
        style: object.style,
        payload: object.payload,
      );
      final probeDoc = DesignDocument(
        id: document.id,
        metadata: document.metadata,
        pages: [
          page.copyWith(objectIds: [object.id]),
        ],
        objects: {object.id: probe},
      );
      final scale = math.sqrt(worldMatrix(document, id).determinant.abs());
      if (hitTest(
            probeDoc,
            probeDoc.pages.single,
            local,
            tolerance: scale == 0 ? tolerance : tolerance / scale,
          ) !=
          null) {
        return id;
      }
    }
    return null;
  }

  return search(page.objectIds);
}

/// All objects of [page] in drawing order (depth first, back to front).
List<ObjectId> pageObjectsInOrder(DesignDocument document, DesignPage page) {
  final result = <ObjectId>[];
  void visit(ObjectId id) {
    final object = document.objects[id];
    if (object == null) return;
    result.add(id);
    object.childIds.forEach(visit);
  }

  page.objectIds.forEach(visit);
  return result;
}

ObjectId _newId() => ObjectId.generate();

List<ObjectId> _siblings(DesignDocument document, DesignObject object) {
  final parentId = object.parentId;
  if (parentId != null) return document.objects[parentId]!.childIds;
  return document.pages.firstWhere((p) => p.id == object.pageId).objectIds;
}

/// A change that puts [objects] and gives [member]'s parent the sibling
/// order [order].
Change _withSiblingOrder(
  DesignDocument document,
  DesignObject member,
  List<ObjectId> order,
  Map<ObjectId, DesignObject?> objects,
  String label,
) {
  final parentId = member.parentId;
  if (parentId != null) {
    final parent = objects[parentId] ?? document.objects[parentId]!;
    return Change(
      label: label,
      objects: {...objects, parentId: parent.copyWith(childIds: order)},
    );
  }
  return Change(
    label: label,
    objects: objects,
    pages: [
      for (final p in document.pages)
        if (p.id == member.pageId) p.copyWith(objectIds: order) else p,
    ],
  );
}

/// [id] and its ancestors, outermost first.
List<ObjectId> ancestorPath(DesignDocument document, ObjectId id) {
  final path = <ObjectId>[];
  ObjectId? current = id;
  while (current != null && path.length < 64) {
    path.insert(0, current);
    current = document.objects[current]?.parentId;
  }
  return path;
}

/// What a click at [point] selects (P1.3.6): the root under the pointer,
/// or — once [selection] is inside a group — the object at the same depth,
/// so siblings inside an entered group are picked directly. With [enter]
/// (double-click) it goes one level deeper than a selected group.
ObjectId? pickObject(
  DesignDocument document,
  DesignPage page,
  Point2D point, {
  Set<ObjectId> selection = const {},
  double tolerance = 0,
  bool enter = false,
}) {
  final leaf = hitTestDeep(document, page, point, tolerance: tolerance);
  if (leaf == null) {
    return hitTest(document, page, point, tolerance: tolerance);
  }
  final path = ancestorPath(document, leaf);
  var depth = 0;
  for (final id in selection) {
    final parentId = document.objects[id]?.parentId;
    final i = parentId == null ? -1 : path.indexOf(parentId);
    if (i >= 0) depth = math.max(depth, i + 1);
    if (enter) {
      final j = path.indexOf(id);
      if (j >= 0) depth = math.max(depth, j + 1);
    }
  }
  return path[math.min(depth, path.length - 1)];
}
