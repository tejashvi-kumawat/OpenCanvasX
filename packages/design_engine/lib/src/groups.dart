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
ObjectTransform composeTransform(
  ObjectTransform outer,
  ObjectTransform inner,
) => transformFromMatrix(inner, localToParent(outer) * localToParent(inner));

/// [inner]'s box placed by matrix [m] (local to target space), as a plain
/// transform. Shear cannot be represented and is dropped.
ObjectTransform transformFromMatrix(ObjectTransform inner, Affine2D m) {
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
  bool asFrame = false,
}) {
  final label = asFrame ? 'Frame selection' : 'Group';
  final members = [
    for (final id in ids)
      if (document.objects[id] case final o?) o,
  ];
  if (members.length < (asFrame ? 1 : 2)) return (Change(label: label), null);
  final parentId = members.first.parentId;
  final pageId = members.first.pageId;
  if (members.any((o) => o.parentId != parentId || o.pageId != pageId)) {
    return (Change(label: label), null);
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
    type: asFrame ? ObjectType.frame : ObjectType.group,
    pageId: pageId,
    parentId: parentId,
    childIds: ordered,
    style: asFrame ? ObjectStyle(fill: const SolidFill(ArgbColor.white)) : null,
    payload: asFrame ? const FramePayload() : const NoPayload(),
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
    _withSiblingOrder(document, members.first, newOrder, objects, label),
    groupId,
  );
}

/// Dissolves groups (or frames) [groupIds]; their children keep their place
/// on the page and in the stacking order. Returns the change and the released children.
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
    if (group == null || !group.type.isContainer) continue;
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

/// Topmost visible, unlocked object under [point], looking inside groups
/// and frames: a leaf, or a frame whose body was hit (see [frameBodyHits]).
ObjectId? hitTestDeep(
  DesignDocument document,
  DesignPage page,
  Point2D point, {
  double tolerance = 0,
}) {
  ObjectId? search(List<ObjectId> ids, Affine2D parent, int depth) {
    if (depth > 64) return null;
    for (final id in ids.reversed) {
      final object = document.objects[id];
      if (object == null || object.hidden || object.locked) continue;
      if (!object.type.isContainer) {
        if (hitsObject(document, object, parent, point, tolerance: tolerance)) {
          return id;
        }
        continue;
      }
      final matrix = parent * localToParent(object.transform);
      final inBox = insideBox(object, matrix, point, tolerance);
      if (!clipsContent(object) || inBox) {
        final inside = search(object.childIds, matrix, depth + 1);
        if (inside != null) return inside;
      }
      if (frameBodyHits(object) && inBox) return id;
    }
    return null;
  }

  return search(page.objectIds, Affine2D.identity, 0);
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
  // Frames are artboards, not selection units: clicks go straight through
  // them to their content (as in Figma).
  var depth = 0;
  while (depth < path.length - 1 &&
      document.objects[path[depth]]?.type == ObjectType.frame) {
    depth++;
  }
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

/// Deepest visible frame on [page] containing [point], ignoring [exclude]
/// and their descendants — where a drawn or dropped object should land.
ObjectId? frameAt(
  DesignDocument document,
  DesignPage page,
  Point2D point, {
  Set<ObjectId> exclude = const {},
}) {
  ObjectId? search(List<ObjectId> ids, Affine2D parent, int depth) {
    if (depth > 64) return null;
    for (final id in ids.reversed) {
      final object = document.objects[id];
      if (object == null || object.hidden || exclude.contains(id)) continue;
      if (object.type != ObjectType.frame) continue;
      final matrix = parent * localToParent(object.transform);
      if (!insideBox(object, matrix, point, 0)) continue;
      return search(object.childIds, matrix, depth + 1) ?? id;
    }
    return null;
  }

  return search(page.objectIds, Affine2D.identity, 0);
}

/// Moves [ids] into container [parentId] (or to the top of [pageId]'s roots
/// when `null`), keeping their place on the page. Objects already there,
/// or that would end up inside themselves, are left alone.
Change reparentObjects(
  DesignDocument document,
  Iterable<ObjectId> ids,
  ObjectId? parentId, {
  required PageId pageId,
  String label = 'Move into frame',
}) {
  final parent = parentId == null ? null : document.objects[parentId];
  if (parentId != null && (parent == null || !parent.type.isContainer)) {
    return Change(label: label);
  }
  final toPage =
      parentId == null
          ? Affine2D.identity
          : worldMatrix(document, parentId).inverse();
  if (toPage == null) return Change(label: label);
  final moving = [
    for (final id in ids)
      if (document.objects[id] case final o?
          when o.parentId != parentId &&
              (parentId == null ||
                  !ancestorPath(document, parentId).contains(id)))
        o,
  ];
  if (moving.isEmpty) return Change(label: label);

  final movingIds = {for (final o in moving) o.id};
  final objects = <ObjectId, DesignObject?>{};
  final page = document.pages.firstWhere((p) => p.id == pageId);
  var roots = [...page.objectIds];
  DesignObject current(ObjectId id) => objects[id] ?? document.objects[id]!;

  // Detach from old parents.
  for (final o in moving) {
    if (o.parentId case final oldParent?) {
      final p = current(oldParent);
      objects[oldParent] = p.copyWith(
        childIds: p.childIds.where((c) => !movingIds.contains(c)),
      );
    } else {
      roots = roots.where((r) => r != o.id).toList();
    }
  }
  // Attach in page stacking order, on top.
  final ordered = pageObjectsInOrder(document, page).where(movingIds.contains);
  final added = <ObjectId>[];
  for (final id in ordered) {
    final o = document.objects[id]!;
    final world = worldMatrix(document, id);
    final transform = transformFromMatrix(o.transform, toPage * world);
    objects[id] = DesignObject(
      id: o.id,
      type: o.type,
      transform: transform,
      pageId: parentId == null ? pageId : null,
      parentId: parentId,
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
    added.add(id);
  }
  if (parentId != null) {
    final p = current(parentId);
    objects[parentId] = p.copyWith(childIds: [...p.childIds, ...added]);
  } else {
    roots = [...roots, ...added];
  }
  return Change(
    label: label,
    objects: objects,
    pages: [
      for (final p in document.pages)
        if (p.id == pageId) p.copyWith(objectIds: roots) else p,
    ],
  );
}

/// A new white frame named [name] with its top-left at [at].
DesignObject newFrame({
  required ObjectId id,
  required PageId pageId,
  required double width,
  required double height,
  Point2D at = Point2D.zero,
  String? name,
}) => DesignObject(
  id: id,
  type: ObjectType.frame,
  pageId: pageId,
  name: name,
  transform: ObjectTransform(x: at.x, y: at.y, width: width, height: height),
  style: ObjectStyle(fill: const SolidFill(ArgbColor.white)),
  payload: const FramePayload(),
);
