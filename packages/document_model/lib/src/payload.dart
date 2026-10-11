import 'package:meta/meta.dart';

import 'object_type.dart';
import 'validation.dart';

/// Type-specific data carried by an object.
@immutable
sealed class ObjectPayload {
  const ObjectPayload();

  /// Whether this payload is the one [type] requires.
  bool fits(ObjectType type) => switch (type) {
    ObjectType.text => this is TextPayload,
    ObjectType.image => this is ImagePayload,
    ObjectType.path => this is PathPayload,
    ObjectType.rect ||
    ObjectType.roundedRect ||
    ObjectType.ellipse ||
    ObjectType.line ||
    ObjectType.arrow ||
    ObjectType.group => this is NoPayload,
  };
}

/// For objects fully described by their transform and style.
final class NoPayload extends ObjectPayload {
  const NoPayload();

  @override
  bool operator ==(Object other) => other is NoPayload;

  @override
  int get hashCode => (NoPayload).hashCode;

  @override
  String toString() => 'NoPayload()';
}

/// Plain text content. Rich text (paragraphs, spans) replaces this in P1.5.
final class TextPayload extends ObjectPayload {
  const TextPayload(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is TextPayload && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextPayload(${text.length} chars)';
}

/// Reference to image bytes stored under `assets/sha256/<assetHash>`.
final class ImagePayload extends ObjectPayload {
  factory ImagePayload(String assetHash) {
    checkSha256Hex(assetHash, 'assetHash');
    return ImagePayload._(assetHash);
  }

  const ImagePayload._(this.assetHash);

  final String assetHash;

  @override
  bool operator ==(Object other) =>
      other is ImagePayload && other.assetHash == assetHash;

  @override
  int get hashCode => assetHash.hashCode;

  @override
  String toString() => 'ImagePayload($assetHash)';
}

/// Vector path as SVG-compatible segments in the object's local space.
final class PathPayload extends ObjectPayload {
  PathPayload(Iterable<PathSegment> segments)
    : segments = List.unmodifiable(segments);

  final List<PathSegment> segments;

  @override
  bool operator ==(Object other) =>
      other is PathPayload && listEquals(other.segments, segments);

  @override
  int get hashCode => Object.hashAll(segments);

  @override
  String toString() => 'PathPayload(${segments.length} segments)';
}

/// One SVG path command (`M`, `L`, `Q`, `C`, `Z`) in absolute coordinates.
@immutable
sealed class PathSegment {
  const PathSegment();
}

final class MoveTo extends PathSegment {
  factory MoveTo(double x, double y) {
    checkFinite(x, 'x');
    checkFinite(y, 'y');
    return MoveTo._(x, y);
  }

  const MoveTo._(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is MoveTo && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(MoveTo, x, y);

  @override
  String toString() => 'M $x $y';
}

final class LineTo extends PathSegment {
  factory LineTo(double x, double y) {
    checkFinite(x, 'x');
    checkFinite(y, 'y');
    return LineTo._(x, y);
  }

  const LineTo._(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is LineTo && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(LineTo, x, y);

  @override
  String toString() => 'L $x $y';
}

final class QuadTo extends PathSegment {
  factory QuadTo(double cx, double cy, double x, double y) {
    for (final (name, v) in [('cx', cx), ('cy', cy), ('x', x), ('y', y)]) {
      checkFinite(v, name);
    }
    return QuadTo._(cx, cy, x, y);
  }

  const QuadTo._(this.cx, this.cy, this.x, this.y);

  final double cx;
  final double cy;
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is QuadTo &&
      other.cx == cx &&
      other.cy == cy &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(QuadTo, cx, cy, x, y);

  @override
  String toString() => 'Q $cx $cy $x $y';
}

final class CubicTo extends PathSegment {
  factory CubicTo(
    double c1x,
    double c1y,
    double c2x,
    double c2y,
    double x,
    double y,
  ) {
    for (final (name, v) in [
      ('c1x', c1x),
      ('c1y', c1y),
      ('c2x', c2x),
      ('c2y', c2y),
      ('x', x),
      ('y', y),
    ]) {
      checkFinite(v, name);
    }
    return CubicTo._(c1x, c1y, c2x, c2y, x, y);
  }

  const CubicTo._(this.c1x, this.c1y, this.c2x, this.c2y, this.x, this.y);

  final double c1x;
  final double c1y;
  final double c2x;
  final double c2y;
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is CubicTo &&
      other.c1x == c1x &&
      other.c1y == c1y &&
      other.c2x == c2x &&
      other.c2y == c2y &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(CubicTo, c1x, c1y, c2x, c2y, x, y);

  @override
  String toString() => 'C $c1x $c1y $c2x $c2y $x $y';
}

final class ClosePath extends PathSegment {
  const ClosePath();

  @override
  bool operator ==(Object other) => other is ClosePath;

  @override
  int get hashCode => (ClosePath).hashCode;

  @override
  String toString() => 'Z';
}
