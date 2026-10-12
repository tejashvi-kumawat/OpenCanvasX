import 'dart:math' as math;

import 'package:document_model/document_model.dart';

/// The eight selection handles around an object's box.
enum ResizeHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left;

  bool get movesLeft => this == topLeft || this == left || this == bottomLeft;
  bool get movesRight =>
      this == topRight || this == right || this == bottomRight;
  bool get movesTop => this == topLeft || this == top || this == topRight;
  bool get movesBottom =>
      this == bottomLeft || this == bottom || this == bottomRight;
  bool get isCorner =>
      this == topLeft ||
      this == topRight ||
      this == bottomRight ||
      this == bottomLeft;

  /// Handle position on a `width × height` local box.
  Point2D position(double width, double height) => Point2D(
    movesLeft ? 0 : (movesRight ? width : width / 2),
    movesTop ? 0 : (movesBottom ? height : height / 2),
  );
}

/// Resizes [t] by dragging [handle] to [pointer] (parent coordinates).
///
/// The opposite edge or corner stays fixed in parent space even when the
/// object is rotated or flipped. Corner handles keep the aspect ratio when
/// [keepAspectRatio] is set. Sizes never shrink below [minSize] along a
/// dragged axis (a zero-height line stays zero-height).
ObjectTransform resizeTransform(
  ObjectTransform t,
  ResizeHandle handle,
  Point2D pointer, {
  bool keepAspectRatio = false,
  double minSize = 1,
}) {
  final toParent = localToParent(t);
  final toLocal = toParent.inverse();
  if (toLocal == null) return t;
  final p = toLocal.apply(pointer);

  var width = t.width;
  var height = t.height;
  if (handle.movesLeft) width = t.width - p.x;
  if (handle.movesRight) width = p.x;
  if (handle.movesTop) height = t.height - p.y;
  if (handle.movesBottom) height = p.y;

  if (keepAspectRatio && handle.isCorner && t.width > 0 && t.height > 0) {
    final factor = math.max(width / t.width, height / t.height);
    width = t.width * factor;
    height = t.height * factor;
  }
  if (handle.movesLeft || handle.movesRight) {
    width = math.max(width, minSize);
  }
  if (handle.movesTop || handle.movesBottom) {
    height = math.max(height, minSize);
  }

  // Keep the point opposite the handle where it was.
  final fixedOld = Point2D(
    handle.movesLeft ? t.width : 0,
    handle.movesTop ? t.height : 0,
  );
  final fixedNew = Point2D(
    handle.movesLeft ? width : 0,
    handle.movesTop ? height : 0,
  );
  return placeTransform(
    t.copyWith(width: width, height: height),
    local: fixedNew,
    lands: toParent.apply(fixedOld),
  );
}

/// Rotates [t] so the rotation handle (above the box) points at [pointer].
/// With [snapDegrees] > 0 the angle snaps to multiples of it.
ObjectTransform rotateTransform(
  ObjectTransform t,
  Point2D pointer, {
  double snapDegrees = 0,
}) {
  final center = localToParent(
    t,
  ).apply(Point2D(t.anchorX * t.width, t.anchorY * t.height));
  final delta = pointer - center;
  if (delta.length == 0) return t;
  var degrees = math.atan2(delta.y, delta.x) * 180 / math.pi + 90;
  if (snapDegrees > 0) {
    degrees = (degrees / snapDegrees).roundToDouble() * snapDegrees;
  }
  return t.copyWith(rotation: normalizeDegrees(degrees));
}

/// Maps any angle into `(-180, 180]`.
double normalizeDegrees(double degrees) {
  var d = degrees % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d == 0 ? 0 : d;
}

/// Mirrors [t] horizontally or vertically in place (same bounds).
ObjectTransform flipTransform(ObjectTransform t, {required bool horizontal}) {
  final center = Point2D(t.anchorX * t.width, t.anchorY * t.height);
  final pinned = localToParent(t).apply(center);
  final flipped =
      horizontal
          ? t.copyWith(scaleX: -t.scaleX)
          : t.copyWith(scaleY: -t.scaleY);
  return placeTransform(flipped, local: center, lands: pinned);
}

/// Returns [t] with x/y chosen so local point [local] maps to [lands].
ObjectTransform placeTransform(
  ObjectTransform t, {
  required Point2D local,
  required Point2D lands,
}) {
  final anchor = Point2D(t.anchorX * t.width, t.anchorY * t.height);
  final linear =
      Affine2D.rotationDegrees(t.rotation) * Affine2D.scale(t.scaleX, t.scaleY);
  final offset = linear.applyToVector(local - anchor);
  return t.copyWith(
    x: lands.x - anchor.x - offset.x,
    y: lands.y - anchor.y - offset.y,
  );
}
