import 'dart:math' as math;

import 'package:document_model/document_model.dart';

import 'transform_tools.dart';

// Image cropping (P1.6.3). The object's box shows the `crop` part of the
// image; cropping changes the box and the crop together so the image
// stays where it is on the page, as in Canva and Figma.

/// The whole image of [image] in its local coordinates (may extend
/// beyond the box).
Rect2D fullImageRect(DesignObject image) {
  final payload = image.payload as ImagePayload;
  final t = image.transform;
  final c = payload.crop;
  final w = t.width / c.width;
  final h = t.height / c.height;
  return Rect2D.fromLTWH(-c.left * w, -c.top * h, w, h);
}

/// `start` with its box set to local rectangle [box] (of the box at
/// [start]), and the crop following it so the image does not move.
DesignObject _withBox(DesignObject start, Rect2D box) {
  final full = fullImageRect(start);
  final t = start.transform;
  final payload = start.payload as ImagePayload;
  final crop = Rect2D.fromLTWH(
    ((box.left - full.left) / full.width).clamp(0, 1),
    ((box.top - full.top) / full.height).clamp(0, 1),
    (box.width / full.width).clamp(1e-6, 1),
    (box.height / full.height).clamp(1e-6, 1),
  );
  final clamped = Rect2D.fromLTWH(
    crop.left,
    crop.top,
    math.min(crop.width, 1 - crop.left),
    math.min(crop.height, 1 - crop.top),
  );
  final transform = placeTransform(
    t.copyWith(width: box.width, height: box.height),
    local: Point2D.zero,
    lands: localToParent(t).apply(Point2D(box.left, box.top)),
  );
  return start.copyWith(
    transform: transform,
    payload: payload.copyWith(crop: clamped),
  );
}

/// Drags crop [handle] of [start] (the image when the drag began) to
/// [pointer] in parent coordinates. Edges stop at the image's edges and
/// keep at least [minSize] units of image.
DesignObject cropImage(
  DesignObject start,
  ResizeHandle handle,
  Point2D pointer, {
  double minSize = 1,
}) {
  if (start.payload is! ImagePayload) return start;
  final t = start.transform;
  final toLocal = localToParent(t).inverse();
  if (toLocal == null) return start;
  final p = toLocal.apply(pointer);
  final full = fullImageRect(start);
  var l = 0.0;
  var top = 0.0;
  var r = t.width;
  var b = t.height;
  if (handle.movesLeft) l = p.x.clamp(full.left, r - minSize);
  if (handle.movesRight) r = p.x.clamp(l + minSize, full.right);
  if (handle.movesTop) top = p.y.clamp(full.top, b - minSize);
  if (handle.movesBottom) b = p.y.clamp(top + minSize, full.bottom);
  return _withBox(start, Rect2D.fromLTRB(l, top, r, b));
}

/// Moves the image of [start] under its box by [delta] (parent
/// coordinates), never past its edges.
DesignObject panCrop(DesignObject start, Point2D delta) {
  if (start.payload case final ImagePayload payload) {
    final toLocal = localToParent(start.transform).inverse();
    if (toLocal == null) return start;
    final d = toLocal.applyToVector(delta);
    final full = fullImageRect(start);
    final c = payload.crop;
    final left = (c.left - d.x / full.width).clamp(0.0, 1 - c.width);
    final top = (c.top - d.y / full.height).clamp(0.0, 1 - c.height);
    return start.copyWith(
      payload: payload.copyWith(
        crop: Rect2D.fromLTWH(left, top, c.width, c.height),
      ),
    );
  }
  return start;
}

/// Crops [image] to the largest box with [aspect] (width / height) that
/// fits its current box, centred on it.
DesignObject cropToAspect(DesignObject image, double aspect) {
  if (image.payload is! ImagePayload || aspect <= 0) return image;
  final t = image.transform;
  var w = math.min(t.width, t.height * aspect);
  var h = w / aspect;
  if (h > t.height) {
    h = t.height;
    w = h * aspect;
  }
  return _withBox(
    image,
    Rect2D.fromLTWH((t.width - w) / 2, (t.height - h) / 2, w, h),
  );
}

/// Shows the whole image again at its current scale.
DesignObject resetCrop(DesignObject image) {
  if (image.payload is! ImagePayload) return image;
  return _withBox(image, fullImageRect(image));
}
