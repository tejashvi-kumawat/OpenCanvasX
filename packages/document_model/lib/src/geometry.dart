import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'transform.dart';

/// A point or vector in document units.
@immutable
final class Point2D {
  const Point2D(this.x, this.y);

  static const zero = Point2D(0, 0);

  final double x;
  final double y;

  Point2D operator +(Point2D other) => Point2D(x + other.x, y + other.y);
  Point2D operator -(Point2D other) => Point2D(x - other.x, y - other.y);
  Point2D operator *(double factor) => Point2D(x * factor, y * factor);

  double get length => math.sqrt(x * x + y * y);

  @override
  bool operator ==(Object other) =>
      other is Point2D && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point2D($x, $y)';
}

/// Axis-aligned rectangle in document units.
@immutable
final class Rect2D {
  const Rect2D.fromLTRB(this.left, this.top, this.right, this.bottom);

  factory Rect2D.fromLTWH(double left, double top, double width, double h) =>
      Rect2D.fromLTRB(left, top, left + width, top + h);

  /// Smallest rectangle containing all [points] (at least one).
  factory Rect2D.fromPoints(Iterable<Point2D> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) {
      throw ArgumentError.value(points, 'points', 'must not be empty');
    }
    var minX = iterator.current.x;
    var maxX = minX;
    var minY = iterator.current.y;
    var maxY = minY;
    while (iterator.moveNext()) {
      final p = iterator.current;
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return Rect2D.fromLTRB(minX, minY, maxX, maxY);
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  Point2D get center => Point2D((left + right) / 2, (top + bottom) / 2);
  Point2D get topLeft => Point2D(left, top);

  bool contains(Point2D p) =>
      p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  bool overlaps(Rect2D other) =>
      left <= other.right &&
      other.left <= right &&
      top <= other.bottom &&
      other.top <= bottom;

  Rect2D union(Rect2D other) => Rect2D.fromLTRB(
    math.min(left, other.left),
    math.min(top, other.top),
    math.max(right, other.right),
    math.max(bottom, other.bottom),
  );

  Rect2D inflate(double delta) =>
      Rect2D.fromLTRB(left - delta, top - delta, right + delta, bottom + delta);

  Rect2D translate(double dx, double dy) =>
      Rect2D.fromLTRB(left + dx, top + dy, right + dx, bottom + dy);

  @override
  bool operator ==(Object other) =>
      other is Rect2D &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'Rect2D.fromLTRB($left, $top, $right, $bottom)';
}

/// 2D affine matrix
///
/// ```text
/// | a c e |
/// | b d f |
/// | 0 0 1 |
/// ```
///
/// Shared by editing (`design_engine`) and drawing (`renderer`) so screen
/// and export geometry always agree (document-model.md "Transform").
@immutable
final class Affine2D {
  const Affine2D(this.a, this.b, this.c, this.d, this.e, this.f);

  factory Affine2D.translation(double dx, double dy) =>
      Affine2D(1, 0, 0, 1, dx, dy);

  factory Affine2D.scale(double sx, double sy) => Affine2D(sx, 0, 0, sy, 0, 0);

  /// Clockwise rotation in degrees (y axis points down).
  factory Affine2D.rotationDegrees(double degrees) {
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Affine2D(cos, sin, -sin, cos, 0, 0);
  }

  static const identity = Affine2D(1, 0, 0, 1, 0, 0);

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  /// `this * o`: applies [o] first, then this matrix.
  Affine2D operator *(Affine2D o) => Affine2D(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  Point2D apply(Point2D p) =>
      Point2D(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Applies only the linear part (no translation) — for direction vectors.
  Point2D applyToVector(Point2D v) =>
      Point2D(a * v.x + c * v.y, b * v.x + d * v.y);

  double get determinant => a * d - b * c;

  /// Inverse matrix, or `null` if the matrix is singular.
  Affine2D? inverse() {
    final det = determinant;
    if (det == 0 || !det.isFinite) return null;
    return Affine2D(
      d / det,
      -b / det,
      -c / det,
      a / det,
      (c * f - d * e) / det,
      (b * e - a * f) / det,
    );
  }

  /// Column-major 4×4 values, as used by Flutter's `Matrix4` (no import needed).
  List<double> toMatrix4Storage() => [
    a, b, 0, 0, //
    c, d, 0, 0,
    0, 0, 1, 0,
    e, f, 0, 1,
  ];

  @override
  bool operator ==(Object other) =>
      other is Affine2D &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  String toString() => 'Affine2D($a, $b, $c, $d, $e, $f)';
}

/// Maps an object's local box `(0, 0)–(width, height)` into its parent's
/// space: translate → rotate → scale around the anchor.
Affine2D localToParent(ObjectTransform t) {
  final ax = t.anchorX * t.width;
  final ay = t.anchorY * t.height;
  return Affine2D.translation(t.x + ax, t.y + ay) *
      Affine2D.rotationDegrees(t.rotation) *
      Affine2D.scale(t.scaleX, t.scaleY) *
      Affine2D.translation(-ax, -ay);
}

/// The four corners of the local box, in local coordinates, clockwise from
/// the top-left.
List<Point2D> localCorners(ObjectTransform t) => [
  Point2D.zero,
  Point2D(t.width, 0),
  Point2D(t.width, t.height),
  Point2D(0, t.height),
];

/// Axis-aligned bounds of the transformed box in parent space.
Rect2D boundsInParent(ObjectTransform t) {
  final m = localToParent(t);
  return Rect2D.fromPoints(localCorners(t).map(m.apply));
}
