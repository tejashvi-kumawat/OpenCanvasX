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
    ObjectType.polygon => this is PolygonPayload,
    ObjectType.star => this is StarPayload,
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
/// How a text box takes its size (P1.5.1).
enum TextSizing {
  /// Width and height follow the text; no wrapping.
  autoWidth,

  /// Fixed width, wraps lines; height follows the text.
  autoHeight,

  /// Fixed box; text may overflow.
  fixed,
}

/// Horizontal alignment of text lines.
enum TextAlignment { left, center, right, justify }

/// Text content and its formatting (P1.5.1–P1.5.3). The text colour is the
/// object's fill. Character-level runs arrive with P1.5.4.
final class TextPayload extends ObjectPayload {
  factory TextPayload(
    String text, {
    String? fontFamily,
    double fontSize = 24,
    int fontWeight = 400,
    bool italic = false,
    TextAlignment align = TextAlignment.left,
    double lineHeight = 1.2,
    double letterSpacing = 0,
    TextSizing sizing = TextSizing.autoWidth,
  }) {
    checkPositive(fontSize, 'fontSize');
    if (fontWeight < 100 || fontWeight > 900 || fontWeight % 100 != 0) {
      throw ArgumentError.value(
        fontWeight,
        'fontWeight',
        'must be 100, 200, … 900',
      );
    }
    checkPositive(lineHeight, 'lineHeight');
    checkFinite(letterSpacing, 'letterSpacing');
    final family = fontFamily?.trim();
    return TextPayload._(
      text,
      family == null || family.isEmpty ? null : family,
      fontSize,
      fontWeight,
      italic,
      align,
      lineHeight,
      letterSpacing,
      sizing,
    );
  }

  const TextPayload._(
    this.text,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.italic,
    this.align,
    this.lineHeight,
    this.letterSpacing,
    this.sizing,
  );

  final String text;

  /// Family name; `null` uses the app's default font.
  final String? fontFamily;

  /// In the page's unit.
  final double fontSize;
  final int fontWeight;
  final bool italic;
  final TextAlignment align;

  /// Multiple of the font size.
  final double lineHeight;

  /// Extra space between characters, in the page's unit.
  final double letterSpacing;
  final TextSizing sizing;

  TextPayload copyWith({
    String? text,
    Object? fontFamily = _keep,
    double? fontSize,
    int? fontWeight,
    bool? italic,
    TextAlignment? align,
    double? lineHeight,
    double? letterSpacing,
    TextSizing? sizing,
  }) => TextPayload(
    text ?? this.text,
    fontFamily: fontFamily == _keep ? this.fontFamily : fontFamily as String?,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    italic: italic ?? this.italic,
    align: align ?? this.align,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    sizing: sizing ?? this.sizing,
  );

  @override
  bool operator ==(Object other) =>
      other is TextPayload &&
      other.text == text &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.fontWeight == fontWeight &&
      other.italic == italic &&
      other.align == align &&
      other.lineHeight == lineHeight &&
      other.letterSpacing == letterSpacing &&
      other.sizing == sizing;

  @override
  int get hashCode => Object.hash(
    text,
    fontFamily,
    fontSize,
    fontWeight,
    italic,
    align,
    lineHeight,
    letterSpacing,
    sizing,
  );

  @override
  String toString() => 'TextPayload(${text.length} chars, $fontSize)';
}

const Object _keep = Object();

/// Regular polygon inscribed in the object's box (P1.3.2).
final class PolygonPayload extends ObjectPayload {
  factory PolygonPayload({int sides = 6}) {
    RangeError.checkValueInInterval(sides, 3, 64, 'sides');
    return PolygonPayload._(sides);
  }

  const PolygonPayload._(this.sides);

  final int sides;

  @override
  bool operator ==(Object other) =>
      other is PolygonPayload && other.sides == sides;

  @override
  int get hashCode => Object.hash(PolygonPayload, sides);

  @override
  String toString() => 'PolygonPayload($sides)';
}

/// Star inscribed in the object's box (P1.3.2).
final class StarPayload extends ObjectPayload {
  factory StarPayload({int points = 5, double innerRatio = 0.5}) {
    RangeError.checkValueInInterval(points, 3, 64, 'points');
    checkUnitInterval(innerRatio, 'innerRatio');
    if (innerRatio == 0) {
      throw ArgumentError.value(innerRatio, 'innerRatio', 'must be > 0');
    }
    return StarPayload._(points, innerRatio);
  }

  const StarPayload._(this.points, this.innerRatio);

  final int points;

  /// Inner radius as a fraction of the outer radius.
  final double innerRatio;

  @override
  bool operator ==(Object other) =>
      other is StarPayload &&
      other.points == points &&
      other.innerRatio == innerRatio;

  @override
  int get hashCode => Object.hash(StarPayload, points, innerRatio);

  @override
  String toString() => 'StarPayload($points, $innerRatio)';
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
