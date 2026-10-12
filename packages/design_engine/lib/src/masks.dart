import 'dart:math' as math;

import 'package:document_model/document_model.dart';

import 'change.dart';
import 'groups.dart';

/// Whether [object] is a mask group (its first child masks the rest).
bool isMaskGroup(DesignObject? object) =>
    object != null &&
    object.type == ObjectType.group &&
    object.payload is MaskPayload;

/// Masks the selection with its bottom-most object (Figma "Use as mask",
/// P3.1.4): the selected siblings are grouped and the group becomes a
/// mask group. Needs two or more siblings.
(Change, ObjectId?) useAsMask(
  DesignDocument document,
  Iterable<ObjectId> ids, {
  ObjectId Function()? newId,
}) {
  final (change, id) = groupObjects(
    document,
    ids,
    newId: newId ?? ObjectId.generate,
  );
  if (id == null) return (Change(label: 'Use as mask'), null);
  final group = change.objects[id]!;
  return (
    Change(
      label: 'Use as mask',
      objects: {
        ...change.objects,
        id: group.copyWith(name: 'Mask group', payload: const MaskPayload()),
      },
      pages: change.pages,
    ),
    id,
  );
}

/// Shapes offered as image frames (Canva "Frames").
enum ImageFrameShape {
  square,
  rounded,
  circle,
  arch,
  blob,
  heart,
  star,
  hexagon,
}

/// A new, empty image frame (a mask group holding only its [shape]) of
/// [size] centred on [center]. Returns the group and its mask child.
List<DesignObject> newImageFrame({
  required ObjectId id,
  required ObjectId maskId,
  required PageId pageId,
  required ImageFrameShape shape,
  required Point2D center,
  required double size,
}) {
  final w = shape == ImageFrameShape.arch ? size * 0.8 : size;
  final h = size;
  const placeholder = ArgbColor.boardGray;
  final (type, payload, radius) = switch (shape) {
    ImageFrameShape.square => (ObjectType.rect, const NoPayload(), 0.0),
    ImageFrameShape.rounded => (
      ObjectType.rect,
      const NoPayload(),
      size * 0.12,
    ),
    ImageFrameShape.circle => (ObjectType.ellipse, const NoPayload(), 0.0),
    ImageFrameShape.star => (
      ObjectType.star,
      StarPayload(innerRatio: 0.55) as ObjectPayload,
      0.0,
    ),
    ImageFrameShape.hexagon => (
      ObjectType.polygon,
      PolygonPayload() as ObjectPayload,
      0.0,
    ),
    ImageFrameShape.arch => (ObjectType.path, _arch(w, h), 0.0),
    ImageFrameShape.blob => (ObjectType.path, _blob(w, h), 0.0),
    ImageFrameShape.heart => (ObjectType.path, _heart(w, h), 0.0),
  };
  final mask = DesignObject(
    id: maskId,
    type: type,
    parentId: id,
    name: 'Frame shape',
    transform: ObjectTransform(width: w, height: h),
    style: ObjectStyle(
      fill: const SolidFill(placeholder),
      cornerRadius: radius,
    ),
    payload: payload,
  );
  final group = DesignObject(
    id: id,
    type: ObjectType.group,
    pageId: pageId,
    name: 'Image frame',
    childIds: [maskId],
    transform: ObjectTransform(
      x: center.x - w / 2,
      y: center.y - h / 2,
      width: w,
      height: h,
    ),
    payload: const MaskPayload(),
  );
  return [group, mask];
}

/// Puts [image] (an image object, any size) into image frame / mask group
/// [frameId], replacing images already in it, scaled to cover the mask
/// shape and centred (P1.6.4). [image]'s width and height give its aspect.
Change placeImageInFrame(
  DesignDocument document,
  ObjectId frameId,
  DesignObject image, {
  Map<String, AssetInfo?> assets = const {},
}) {
  final frame = document.objects[frameId];
  if (!isMaskGroup(frame) || frame!.childIds.isEmpty) {
    return Change(label: 'Add image');
  }
  final mask = document.objects[frame.childIds.first]!;
  final box = boundsInParent(mask.transform);
  final aspect =
      image.transform.height == 0
          ? 1.0
          : image.transform.width / image.transform.height;
  // Cover: fill the mask box, cropping the longer side.
  var w = box.width;
  var h = w / aspect;
  if (h < box.height) {
    h = box.height;
    w = h * aspect;
  }
  final placed = DesignObject(
    id: image.id,
    type: image.type,
    parentId: frameId,
    name: image.name,
    transform: ObjectTransform(
      x: box.left + (box.width - w) / 2,
      y: box.top + (box.height - h) / 2,
      width: w,
      height: h,
    ),
    style: image.style,
    payload: image.payload,
  );
  final replaced = [
    for (final c in frame.childIds.skip(1))
      if (document.objects[c]?.type == ObjectType.image) c,
  ];
  return Change(
    label: 'Add image',
    objects: {
      for (final c in replaced) c: null,
      placed.id: placed,
      frameId: frame.copyWith(
        childIds: [
          for (final c in frame.childIds)
            if (!replaced.contains(c)) c,
          placed.id,
        ],
      ),
    },
    assets: assets,
  );
}

PathPayload _arch(double w, double h) {
  final r = w / 2;
  return PathPayload(
    [
      MoveTo(0, h),
      LineTo(0, r),
      CubicTo(0, r * 0.45, r * 0.45, 0, r, 0),
      CubicTo(r * 1.55, 0, w, r * 0.45, w, r),
      LineTo(w, h),
      const ClosePath(),
    ],
    viewWidth: w,
    viewHeight: h,
  );
}

PathPayload _blob(double w, double h) {
  // A soft organic shape from a smoothed polygon.
  const radii = [1.0, 0.86, 0.97, 0.8, 0.95, 0.88, 1.0, 0.83];
  final points = [
    for (var i = 0; i < radii.length; i++)
      Point2D(
        w / 2 + math.cos(2 * math.pi * i / radii.length) * w / 2 * radii[i],
        h / 2 + math.sin(2 * math.pi * i / radii.length) * h / 2 * radii[i],
      ),
  ];
  final segments = <PathSegment>[MoveTo(points.first.x, points.first.y)];
  for (var i = 0; i < points.length; i++) {
    final p0 = points[(i - 1 + points.length) % points.length];
    final p1 = points[i];
    final p2 = points[(i + 1) % points.length];
    final p3 = points[(i + 2) % points.length];
    segments.add(
      CubicTo(
        p1.x + (p2.x - p0.x) / 6,
        p1.y + (p2.y - p0.y) / 6,
        p2.x - (p3.x - p1.x) / 6,
        p2.y - (p3.y - p1.y) / 6,
        p2.x,
        p2.y,
      ),
    );
  }
  segments.add(const ClosePath());
  return PathPayload(segments, viewWidth: w, viewHeight: h);
}

PathPayload _heart(double w, double h) => PathPayload(
  [
    MoveTo(w / 2, h * 0.28),
    CubicTo(w * 0.3, -h * 0.05, -w * 0.12, h * 0.25, w * 0.08, h * 0.55),
    CubicTo(w * 0.2, h * 0.72, w * 0.38, h * 0.84, w / 2, h),
    CubicTo(w * 0.62, h * 0.84, w * 0.8, h * 0.72, w * 0.92, h * 0.55),
    CubicTo(w * 1.12, h * 0.25, w * 0.7, -h * 0.05, w / 2, h * 0.28),
    const ClosePath(),
  ],
  viewWidth: w,
  viewHeight: h,
);
