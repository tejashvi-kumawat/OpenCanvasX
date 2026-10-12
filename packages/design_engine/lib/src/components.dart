import 'dart:math' as math;

import 'package:document_model/document_model.dart';

import 'change.dart';
import 'edits.dart';
import 'groups.dart';

/// Whether [object] is a main component (a frame flagged as component).
bool isComponent(DesignObject? object) =>
    object != null &&
    object.type == ObjectType.frame &&
    object.payload is FramePayload &&
    (object.payload as FramePayload).component;

/// Every main component in [document], in page and drawing order.
List<DesignObject> componentsIn(DesignDocument document) => [
  for (final page in document.pages)
    for (final id in pageObjectsInOrder(document, page))
      if (document.objects[id] case final o? when isComponent(o)) o,
];

/// Makes a main component from [ids]: a single frame is flagged in place;
/// anything else is wrapped in a new, unfilled frame first (like
/// Ctrl+Alt+K in Figma). Returns the change and the component id.
(Change, ObjectId?) makeComponent(
  DesignDocument document,
  Iterable<ObjectId> ids, {
  ObjectId Function()? newId,
}) {
  final list = ids.toList();
  if (list.length == 1) {
    final o = document.objects[list.single];
    if (o != null && o.type == ObjectType.frame) {
      final payload = o.payload as FramePayload;
      return (
        updateObjects(document, [
          o.copyWith(payload: payload.copyWith(component: true)),
        ], label: 'Create component'),
        o.id,
      );
    }
  }
  final (change, id) = groupObjects(
    document,
    list,
    asFrame: true,
    newId: newId ?? ObjectId.generate,
  );
  if (id == null) return (Change(label: 'Create component'), null);
  final frame = change.objects[id]!;
  return (
    Change(
      label: 'Create component',
      objects: {
        ...change.objects,
        id: frame.copyWith(
          name: frame.name ?? 'Component',
          style: ObjectStyle.none,
          payload: const FramePayload(clipContent: false, component: true),
        ),
      },
      pages: change.pages,
    ),
    id,
  );
}

/// A new instance of [component] centred on [center].
DesignObject newInstance({
  required ObjectId id,
  required PageId pageId,
  required DesignObject component,
  required Point2D center,
}) {
  final t = component.transform;
  return DesignObject(
    id: id,
    type: ObjectType.instance,
    pageId: pageId,
    name: component.name,
    transform: ObjectTransform(
      x: center.x - t.width / 2,
      y: center.y - t.height / 2,
      width: t.width,
      height: t.height,
    ),
    payload: InstancePayload(component.id),
  );
}

/// Replaces instance [id] with an editable copy of its component, scaled
/// to the instance's box (Figma's "Detach instance"). Returns the change
/// and the new frame's id; an empty change if the component is missing.
(Change, ObjectId?) detachInstance(
  DesignDocument document,
  ObjectId id, {
  ObjectId Function()? newId,
}) {
  final instance = document.objects[id];
  final payload = instance?.payload;
  if (instance == null || payload is! InstancePayload) {
    return (Change(label: 'Detach instance'), null);
  }
  final component = document.objects[payload.componentId];
  if (!isComponent(component)) return (Change(label: 'Detach instance'), null);
  final makeId = newId ?? ObjectId.generate;
  final ct = component!.transform;
  final sx = ct.width == 0 ? 1.0 : instance.transform.width / ct.width;
  final sy = ct.height == 0 ? 1.0 : instance.transform.height / ct.height;
  final fontScale = math.min(sx, sy);

  final ids = <ObjectId, ObjectId>{};
  ObjectId map(ObjectId old) => ids.putIfAbsent(old, makeId);
  final objects = <ObjectId, DesignObject?>{id: null};

  DesignObject scaled(DesignObject o) {
    final t = o.transform;
    final p = o.payload;
    return o.copyWith(
      transform: t.copyWith(
        x: t.x * sx,
        y: t.y * sy,
        width: t.width * sx,
        height: t.height * sy,
      ),
      payload:
          p is TextPayload ? p.copyWith(fontSize: p.fontSize * fontScale) : p,
    );
  }

  void visit(ObjectId childId, ObjectId parent, int depth) {
    final o = document.objects[childId];
    if (o == null || depth > 64) return;
    final copy = scaled(o);
    objects[map(childId)] = DesignObject(
      id: map(childId),
      type: copy.type,
      transform: copy.transform,
      parentId: parent,
      childIds: [
        for (final c in o.childIds)
          if (document.objects.containsKey(c)) map(c),
      ],
      name: copy.name,
      opacity: copy.opacity,
      blendMode: copy.blendMode,
      locked: copy.locked,
      hidden: copy.hidden,
      styleId: copy.styleId,
      style: copy.style,
      payload: copy.payload,
    );
    for (final c in o.childIds) {
      visit(c, map(childId), depth + 1);
    }
  }

  final rootId = makeId();
  for (final c in component.childIds) {
    visit(c, rootId, 1);
  }
  final framePayload = component.payload as FramePayload;
  objects[rootId] = DesignObject(
    id: rootId,
    type: ObjectType.frame,
    transform: instance.transform,
    pageId: instance.pageId,
    parentId: instance.parentId,
    childIds: [
      for (final c in component.childIds)
        if (document.objects.containsKey(c)) map(c),
    ],
    name: instance.name ?? component.name,
    opacity: instance.opacity,
    blendMode: instance.blendMode,
    hidden: instance.hidden,
    style: component.style,
    payload: framePayload.copyWith(component: false),
  );

  // Put the copy where the instance was in the stacking order.
  final parentId = instance.parentId;
  if (parentId != null) {
    final parent = document.objects[parentId]!;
    objects[parentId] = parent.copyWith(
      childIds: [
        for (final c in parent.childIds)
          if (c == id) rootId else c,
      ],
    );
    return (Change(label: 'Detach instance', objects: objects), rootId);
  }
  return (
    Change(
      label: 'Detach instance',
      objects: objects,
      pages: [
        for (final p in document.pages)
          if (p.id == instance.pageId)
            p.copyWith(
              objectIds: [
                for (final r in p.objectIds)
                  if (r == id) rootId else r,
              ],
              links: [
                for (final l in p.links)
                  if (l.source == id)
                    PrototypeLink(
                      source: rootId,
                      target: l.target,
                      transition: l.transition,
                    )
                  else
                    l,
              ],
            )
          else
            p,
      ],
    ),
    rootId,
  );
}
