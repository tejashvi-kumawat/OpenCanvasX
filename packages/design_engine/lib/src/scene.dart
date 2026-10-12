import 'dart:math' as math;

import 'package:document_model/document_model.dart';

/// Deepest nesting followed when walking parents; guards against cyclic
/// files that slipped past validation.
const _maxDepth = 64;

/// Matrix from [id]'s local box to page coordinates (its "world").
Affine2D worldMatrix(DesignDocument document, ObjectId id) {
  final chain = <DesignObject>[];
  var current = document.objects[id];
  while (current != null && chain.length < _maxDepth) {
    chain.add(current);
    final parentId = current.parentId;
    current = parentId == null ? null : document.objects[parentId];
  }
  var matrix = Affine2D.identity;
  for (final object in chain.reversed) {
    matrix = matrix * localToParent(object.transform);
  }
  return matrix;
}

/// Corners of [id]'s box in page coordinates, clockwise from top-left.
/// Rotated objects give a rotated quadrilateral.
List<Point2D> worldCorners(DesignDocument document, ObjectId id) {
  final object = document.objects[id];
  if (object == null) return const [];
  final matrix = worldMatrix(document, id);
  return localCorners(object.transform).map(matrix.apply).toList();
}

/// Axis-aligned page-space bounds of [id], or `null` if it does not exist.
Rect2D? worldBounds(DesignDocument document, ObjectId id) {
  final corners = worldCorners(document, id);
  return corners.isEmpty ? null : Rect2D.fromPoints(corners);
}

/// Union of the bounds of [ids]; `null` when none exist.
Rect2D? selectionBounds(DesignDocument document, Iterable<ObjectId> ids) {
  Rect2D? result;
  for (final id in ids) {
    final bounds = worldBounds(document, id);
    if (bounds == null) continue;
    result = result == null ? bounds : result.union(bounds);
  }
  return result;
}

/// Topmost visible, unlocked root object on [page] under [point]
/// (document-model.md "Selection and hit-testing"). Clicking inside a group
/// selects the whole group. [tolerance] widens thin targets such as lines,
/// in page units.
ObjectId? hitTest(
  DesignDocument document,
  DesignPage page,
  Point2D point, {
  double tolerance = 0,
}) {
  for (final id in page.objectIds.reversed) {
    final object = document.objects[id];
    if (object == null || object.hidden || object.locked) continue;
    if (_hits(document, object, Affine2D.identity, point, tolerance, 0)) {
      return id;
    }
  }
  return null;
}

/// Visible, unlocked roots on [page] whose bounds overlap [area]
/// (marquee selection).
List<ObjectId> objectsInRect(
  DesignDocument document,
  DesignPage page,
  Rect2D area,
) => [
  for (final id in page.objectIds)
    if (document.objects[id] case final object?
        when !object.hidden &&
            !object.locked &&
            (worldBounds(document, id)?.overlaps(area) ?? false))
      id,
];

bool _hits(
  DesignDocument document,
  DesignObject object,
  Affine2D parent,
  Point2D point,
  double tolerance,
  int depth,
) {
  if (object.hidden || depth > _maxDepth) return false;
  final matrix = parent * localToParent(object.transform);
  if (object.type.isContainer) {
    final clipped =
        clipsContent(object) && !insideBox(object, matrix, point, tolerance);
    if (!clipped) {
      for (final childId in object.childIds.reversed) {
        final child = document.objects[childId];
        if (child != null &&
            _hits(document, child, matrix, point, tolerance, depth + 1)) {
          return true;
        }
      }
    }
    return frameBodyHits(object) && insideBox(object, matrix, point, tolerance);
  }
  final inverse = matrix.inverse();
  if (inverse == null) return false;
  final local = inverse.apply(point);
  final scale = math.sqrt(matrix.determinant.abs());
  final slack = scale == 0 ? tolerance : tolerance / scale;
  final w = object.transform.width;
  final h = object.transform.height;

  switch (object.type) {
    case ObjectType.ellipse:
      final rx = w / 2 + slack;
      final ry = h / 2 + slack;
      if (rx <= 0 || ry <= 0) return false;
      final dx = (local.x - w / 2) / rx;
      final dy = (local.y - h / 2) / ry;
      return dx * dx + dy * dy <= 1;
    case ObjectType.line || ObjectType.arrow:
      final strokeHalf = (object.style?.stroke?.width ?? 1) / 2;
      return _distanceToSegment(local, Point2D.zero, Point2D(w, h)) <=
          strokeHalf + slack;
    case ObjectType.rect ||
        ObjectType.roundedRect ||
        ObjectType.text ||
        ObjectType.image ||
        ObjectType.path ||
        ObjectType.polygon ||
        ObjectType.star ||
        ObjectType.group ||
        ObjectType.frame:
      return local.x >= -slack &&
          local.x <= w + slack &&
          local.y >= -slack &&
          local.y <= h + slack;
  }
}

/// Whether [object] (a frame) hides children outside its box.
bool clipsContent(DesignObject object) => switch (object.payload) {
  FramePayload(:final clipContent) => clipContent,
  _ => false,
};

/// Whether clicking a frame's empty area selects it. Top-level frames that
/// hold content are picked by their title instead (so a drag inside them
/// starts a marquee), as in Figma; empty or nested frames are picked by
/// their body.
bool frameBodyHits(DesignObject object) =>
    object.type == ObjectType.frame &&
    (object.childIds.isEmpty || object.parentId != null);

/// Whether page point [point] lies in [object]'s box, given the matrix
/// [matrix] from its local space to the page.
bool insideBox(
  DesignObject object,
  Affine2D matrix,
  Point2D point,
  double tolerance,
) {
  final local = matrix.inverse()?.apply(point);
  if (local == null) return false;
  final scale = math.sqrt(matrix.determinant.abs());
  final slack = scale == 0 ? tolerance : tolerance / scale;
  return local.x >= -slack &&
      local.x <= object.transform.width + slack &&
      local.y >= -slack &&
      local.y <= object.transform.height + slack;
}

/// Whether [object] (drawn under [parent]) is under [point].
bool hitsObject(
  DesignDocument document,
  DesignObject object,
  Affine2D parent,
  Point2D point, {
  double tolerance = 0,
}) => _hits(document, object, parent, point, tolerance, 0);

double _distanceToSegment(Point2D p, Point2D a, Point2D b) {
  final ab = b - a;
  final lengthSquared = ab.x * ab.x + ab.y * ab.y;
  if (lengthSquared == 0) return (p - a).length;
  final t = (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).length;
}
