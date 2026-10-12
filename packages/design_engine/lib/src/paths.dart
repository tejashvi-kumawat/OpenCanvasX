import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

import 'transform_tools.dart';

/// One point of a pen path (P2.6.1): the anchor and its optional Bézier
/// handles (absolute positions, in the same space as [point]).
@immutable
final class PenAnchor {
  const PenAnchor(this.point, {this.handleIn, this.handleOut});

  /// A smooth anchor whose out-handle is at [out] and in-handle mirrors it.
  factory PenAnchor.smooth(Point2D point, Point2D out) => PenAnchor(
    point,
    handleOut: out,
    handleIn: Point2D(2 * point.x - out.x, 2 * point.y - out.y),
  );

  final Point2D point;

  /// Control point on the side of the previous anchor.
  final Point2D? handleIn;

  /// Control point on the side of the next anchor.
  final Point2D? handleOut;

  PenAnchor translated(double dx, double dy) => PenAnchor(
    Point2D(point.x + dx, point.y + dy),
    handleIn: _shift(handleIn, dx, dy),
    handleOut: _shift(handleOut, dx, dy),
  );

  PenAnchor mapped(Point2D Function(Point2D) f) => PenAnchor(
    f(point),
    handleIn: handleIn == null ? null : f(handleIn!),
    handleOut: handleOut == null ? null : f(handleOut!),
  );

  PenAnchor copyWith({
    Point2D? point,
    Object? handleIn = _keep,
    Object? handleOut = _keep,
  }) => PenAnchor(
    point ?? this.point,
    handleIn: identical(handleIn, _keep) ? this.handleIn : handleIn as Point2D?,
    handleOut:
        identical(handleOut, _keep) ? this.handleOut : handleOut as Point2D?,
  );

  static Point2D? _shift(Point2D? p, double dx, double dy) =>
      p == null ? null : Point2D(p.x + dx, p.y + dy);

  @override
  bool operator ==(Object other) =>
      other is PenAnchor &&
      other.point == point &&
      other.handleIn == handleIn &&
      other.handleOut == handleOut;

  @override
  int get hashCode => Object.hash(point, handleIn, handleOut);

  @override
  String toString() => 'PenAnchor($point, in: $handleIn, out: $handleOut)';
}

const Object _keep = Object();

/// Segments joining [anchors] (lines where both sides lack handles,
/// cubics otherwise), optionally closed back to the first anchor.
List<PathSegment> segmentsFor(List<PenAnchor> anchors, {bool closed = false}) {
  if (anchors.isEmpty) return const [];
  PathSegment join(PenAnchor a, PenAnchor b) =>
      a.handleOut == null && b.handleIn == null
          ? LineTo(b.point.x, b.point.y)
          : CubicTo(
            (a.handleOut ?? a.point).x,
            (a.handleOut ?? a.point).y,
            (b.handleIn ?? b.point).x,
            (b.handleIn ?? b.point).y,
            b.point.x,
            b.point.y,
          );
  return [
    MoveTo(anchors.first.point.x, anchors.first.point.y),
    for (var i = 1; i < anchors.length; i++) join(anchors[i - 1], anchors[i]),
    if (closed && anchors.length > 2) ...[
      join(anchors.last, anchors.first),
      const ClosePath(),
    ],
  ];
}

/// The anchors of [payload] in view-box coordinates and whether it is
/// closed. Quadratic segments become cubics; only the first sub-path is
/// read.
({List<PenAnchor> anchors, bool closed}) anchorsOf(PathPayload payload) {
  final anchors = <PenAnchor>[];
  var closed = false;
  for (final s in payload.segments) {
    switch (s) {
      case MoveTo(:final x, :final y):
        if (anchors.isNotEmpty) return (anchors: anchors, closed: closed);
        anchors.add(PenAnchor(Point2D(x, y)));
      case LineTo(:final x, :final y):
        anchors.add(PenAnchor(Point2D(x, y)));
      case QuadTo(:final cx, :final cy, :final x, :final y):
        final from = anchors.last.point;
        final c1 = Point2D(
          from.x + (cx - from.x) * 2 / 3,
          from.y + (cy - from.y) * 2 / 3,
        );
        final c2 = Point2D(x + (cx - x) * 2 / 3, y + (cy - y) * 2 / 3);
        anchors
          ..[anchors.length - 1] = anchors.last.copyWith(handleOut: c1)
          ..add(PenAnchor(Point2D(x, y), handleIn: c2));
      case CubicTo(
        :final c1x,
        :final c1y,
        :final c2x,
        :final c2y,
        :final x,
        :final y,
      ):
        anchors[anchors.length - 1] = anchors.last.copyWith(
          handleOut: Point2D(c1x, c1y),
        );
        anchors.add(PenAnchor(Point2D(x, y), handleIn: Point2D(c2x, c2y)));
      case ClosePath():
        closed = true;
    }
  }
  // A closing segment that returns to the start duplicates it: fold the
  // duplicate's in-handle into the first anchor.
  if (closed && anchors.length > 1) {
    final last = anchors.last;
    final first = anchors.first;
    if ((last.point.x - first.point.x).abs() < 1e-9 &&
        (last.point.y - first.point.y).abs() < 1e-9) {
      anchors
        ..removeLast()
        ..[0] = first.copyWith(handleIn: last.handleIn);
    }
  }
  return (anchors: anchors, closed: closed);
}

/// A path object through [anchors] given in its parent's coordinates
/// (P2.6.1). The box fits the anchors and handles; the segments are
/// stored relative to it with a matching view box so resizing scales
/// them.
DesignObject newPathObject({
  required ObjectId id,
  required PageId pageId,
  required List<PenAnchor> anchors,
  bool closed = false,
  ObjectStyle? style,
  String? name,
}) {
  final box = _bounds(anchors);
  final local = [for (final a in anchors) a.translated(-box.left, -box.top)];
  return DesignObject(
    id: id,
    type: ObjectType.path,
    pageId: pageId,
    name: name,
    transform: ObjectTransform(
      x: box.left,
      y: box.top,
      width: box.width,
      height: box.height,
    ),
    style: style,
    payload: PathPayload(
      segmentsFor(local, closed: closed),
      viewWidth: box.width,
      viewHeight: box.height,
    ),
  );
}

/// [object]'s anchors in its local box coordinates (0…width, 0…height),
/// for node editing (P2.6.2).
({List<PenAnchor> anchors, bool closed}) localAnchors(DesignObject object) {
  final payload = object.payload;
  if (payload is! PathPayload) return (anchors: const [], closed: false);
  final read = anchorsOf(payload);
  final t = object.transform;
  final sx = payload.viewWidth == null ? 1.0 : t.width / payload.viewWidth!;
  final sy = payload.viewHeight == null ? 1.0 : t.height / payload.viewHeight!;
  return (
    anchors: [
      for (final a in read.anchors)
        a.mapped((p) => Point2D(p.x * sx, p.y * sy)),
    ],
    closed: read.closed,
  );
}

/// [object] with new [anchors] (in its current local box coordinates):
/// the box is refitted and moved so nothing shifts on the page.
DesignObject withAnchors(
  DesignObject object,
  List<PenAnchor> anchors, {
  required bool closed,
}) {
  final box = _bounds(anchors);
  final t = object.transform;
  final local = [for (final a in anchors) a.translated(-box.left, -box.top)];
  final resized = placeTransform(
    t.copyWith(width: box.width, height: box.height),
    local: Point2D.zero,
    lands: localToParent(t).apply(Point2D(box.left, box.top)),
  );
  return object.copyWith(
    transform: resized,
    payload: PathPayload(
      segmentsFor(local, closed: closed),
      viewWidth: box.width,
      viewHeight: box.height,
    ),
  );
}

/// Freehand stroke (P2.6.3): [points] simplified within [tolerance]
/// (Ramer–Douglas–Peucker) and smoothed into Bézier anchors
/// (Catmull–Rom).
List<PenAnchor> smoothStroke(List<Point2D> points, {double tolerance = 1}) {
  if (points.length < 3) return [for (final p in points) PenAnchor(p)];
  final kept = _simplify(points, tolerance);
  if (kept.length < 3) return [for (final p in kept) PenAnchor(p)];
  final anchors = <PenAnchor>[];
  for (var i = 0; i < kept.length; i++) {
    final prev = kept[math.max(i - 1, 0)];
    final next = kept[math.min(i + 1, kept.length - 1)];
    final p = kept[i];
    final tx = (next.x - prev.x) / 6;
    final ty = (next.y - prev.y) / 6;
    anchors.add(
      PenAnchor(
        p,
        handleIn: i == 0 ? null : Point2D(p.x - tx, p.y - ty),
        handleOut: i == kept.length - 1 ? null : Point2D(p.x + tx, p.y + ty),
      ),
    );
  }
  return anchors;
}

List<Point2D> _simplify(List<Point2D> points, double tolerance) {
  if (points.length < 3) return points;
  final keep =
      List<bool>.filled(points.length, false)
        ..[0] = true
        ..[points.length - 1] = true;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    var maxDistance = 0.0;
    var index = -1;
    for (var i = start + 1; i < end; i++) {
      final d = _distanceToLine(points[i], points[start], points[end]);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }
    if (index >= 0 && maxDistance > tolerance) {
      keep[index] = true;
      stack
        ..add((start, index))
        ..add((index, end));
    }
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

double _distanceToLine(Point2D p, Point2D a, Point2D b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length == 0) {
    return math.sqrt(math.pow(p.x - a.x, 2) + math.pow(p.y - a.y, 2));
  }
  return ((dy * p.x - dx * p.y + b.x * a.y - b.y * a.x).abs()) / length;
}

/// Box around anchors and handles; never thinner than a hair so the view
/// box stays valid for straight lines.
Rect2D _bounds(List<PenAnchor> anchors) {
  final points = [
    for (final a in anchors) ...[
      a.point,
      if (a.handleIn case final h?) h,
      if (a.handleOut case final h?) h,
    ],
  ];
  if (points.isEmpty) return Rect2D.fromLTWH(0, 0, 1, 1);
  var r = Rect2D.fromPoints(points);
  const minSize = 0.001;
  if (r.width < minSize || r.height < minSize) {
    r = Rect2D.fromLTWH(
      r.left,
      r.top,
      math.max(r.width, minSize),
      math.max(r.height, minSize),
    );
  }
  return r;
}
