import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:meta/meta.dart';

import 'groups.dart';
import 'scene.dart';

/// A smart guide to draw while snapping (P1.4.4), in page units: a
/// vertical line at x = [position] (or horizontal at y) from [start] to
/// [end].
@immutable
final class SnapGuide {
  const SnapGuide({
    required this.vertical,
    required this.position,
    required this.start,
    required this.end,
  });

  final bool vertical;
  final double position;
  final double start;
  final double end;

  @override
  bool operator ==(Object other) =>
      other is SnapGuide &&
      other.vertical == vertical &&
      other.position == position &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(vertical, position, start, end);
}

/// Lines objects can snap to: x positions (with the vertical extent of
/// what defines them) and y positions.
@immutable
final class SnapTargets {
  const SnapTargets(this.xs, this.ys);

  /// Edges and centres of [page] (fixed pages), of every visible object
  /// not in [exclude] (nor inside it), and of the frames containing the
  /// excluded objects.
  factory SnapTargets.collect(
    DesignDocument document,
    DesignPage page, {
    Set<ObjectId> exclude = const {},
  }) {
    final xs = <(double, double, double)>[];
    final ys = <(double, double, double)>[];
    void addRect(Rect2D r) {
      for (final x in [r.left, r.left + r.width / 2, r.right]) {
        xs.add((x, r.top, r.bottom));
      }
      for (final y in [r.top, r.top + r.height / 2, r.bottom]) {
        ys.add((y, r.left, r.right));
      }
    }

    if (!page.isBoard) addRect(Rect2D.fromLTWH(0, 0, page.width, page.height));
    final excludedTrees = <ObjectId>{};
    for (final id in exclude) {
      excludedTrees.add(id);
      void visit(ObjectId child) {
        excludedTrees.add(child);
        document.objects[child]?.childIds.forEach(visit);
      }

      document.objects[id]?.childIds.forEach(visit);
    }
    for (final id in pageObjectsInOrder(document, page)) {
      if (excludedTrees.contains(id)) continue;
      final o = document.objects[id];
      if (o == null || o.hidden || _hiddenAncestor(document, o)) continue;
      // Groups snap as a whole; their members are only targets when the
      // group is being edited (they share the moving objects' parent).
      final parent = o.parentId == null ? null : document.objects[o.parentId];
      if (parent != null &&
          parent.type == ObjectType.group &&
          !exclude.any((e) => document.objects[e]?.parentId == o.parentId)) {
        continue;
      }
      if (worldBounds(document, id) case final b?) addRect(b);
    }
    return SnapTargets(xs, ys);
  }

  /// (x, top, bottom) of vertical snap lines.
  final List<(double, double, double)> xs;

  /// (y, left, right) of horizontal snap lines.
  final List<(double, double, double)> ys;

  static bool _hiddenAncestor(DesignDocument document, DesignObject o) {
    var parent = o.parentId;
    while (parent != null) {
      final p = document.objects[parent];
      if (p == null) return false;
      if (p.hidden) return true;
      parent = p.parentId;
    }
    return false;
  }

  /// Snaps a box moved to [moved]: the closest of its left/centre/right to
  /// a vertical line within [threshold], and likewise for y. Returns the
  /// correction to add and the guides to show.
  ({double dx, double dy, List<SnapGuide> guides}) snapRect(
    Rect2D moved, {
    required double threshold,
  }) {
    final mx = [moved.left, moved.left + moved.width / 2, moved.right];
    final my = [moved.top, moved.top + moved.height / 2, moved.bottom];
    final x = _best(xs, mx, threshold);
    final y = _best(ys, my, threshold);
    final dx = x?.$1 ?? 0;
    final dy = y?.$1 ?? 0;
    final snapped = Rect2D.fromLTWH(
      moved.left + dx,
      moved.top + dy,
      moved.width,
      moved.height,
    );
    return (
      dx: dx,
      dy: dy,
      guides: [
        if (x != null) ..._verticalGuides(x.$2, snapped),
        if (y != null) ..._horizontalGuides(y.$2, snapped),
      ],
    );
  }

  /// Snaps a single point (a resize handle or a drawing corner).
  ({Point2D point, List<SnapGuide> guides}) snapPoint(
    Point2D p, {
    required double threshold,
    bool snapX = true,
    bool snapY = true,
  }) {
    final x = snapX ? _best(xs, [p.x], threshold) : null;
    final y = snapY ? _best(ys, [p.y], threshold) : null;
    final snapped = Point2D(p.x + (x?.$1 ?? 0), p.y + (y?.$1 ?? 0));
    final dot = Rect2D.fromLTWH(snapped.x, snapped.y, 0, 0);
    return (
      point: snapped,
      guides: [
        if (x != null) ..._verticalGuides(x.$2, dot),
        if (y != null) ..._horizontalGuides(y.$2, dot),
      ],
    );
  }

  /// The smallest correction within [threshold] and the line value it
  /// snaps to.
  static (double, double)? _best(
    List<(double, double, double)> lines,
    List<double> values,
    double threshold,
  ) {
    (double, double)? best;
    for (final (line, _, _) in lines) {
      for (final v in values) {
        final d = line - v;
        if (d.abs() <= threshold && (best == null || d.abs() < best.$1.abs())) {
          best = (d, line);
        }
      }
    }
    return best;
  }

  List<SnapGuide> _verticalGuides(double x, Rect2D box) {
    var top = box.top;
    var bottom = box.bottom;
    for (final (lx, t, b) in xs) {
      if ((lx - x).abs() < 1e-6) {
        top = math.min(top, t);
        bottom = math.max(bottom, b);
      }
    }
    return [SnapGuide(vertical: true, position: x, start: top, end: bottom)];
  }

  List<SnapGuide> _horizontalGuides(double y, Rect2D box) {
    var left = box.left;
    var right = box.right;
    for (final (ly, l, r) in ys) {
      if ((ly - y).abs() < 1e-6) {
        left = math.min(left, l);
        right = math.max(right, r);
      }
    }
    return [SnapGuide(vertical: false, position: y, start: left, end: right)];
  }
}
