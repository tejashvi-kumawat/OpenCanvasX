import 'package:meta/meta.dart';

import 'ids.dart';
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
    ObjectType.frame => this is FramePayload,
    ObjectType.instance => this is InstancePayload,
    ObjectType.rect ||
    ObjectType.roundedRect ||
    ObjectType.ellipse ||
    ObjectType.line ||
    ObjectType.arrow ||
    ObjectType.group => this is NoPayload || this is MaskPayload,
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

/// Frame options (ADR-0007).
final class FramePayload extends ObjectPayload {
  const FramePayload({this.clipContent = true, this.component = false});

  /// Whether children outside the frame's box are hidden.
  final bool clipContent;

  /// Whether this frame is a main component that instances draw from.
  final bool component;

  FramePayload copyWith({bool? clipContent, bool? component}) => FramePayload(
    clipContent: clipContent ?? this.clipContent,
    component: component ?? this.component,
  );

  @override
  bool operator ==(Object other) =>
      other is FramePayload &&
      other.clipContent == clipContent &&
      other.component == component;

  @override
  int get hashCode => Object.hash(FramePayload, clipContent, component);

  @override
  String toString() =>
      'FramePayload(clip: $clipContent${component ? ', component' : ''})';
}

/// An instance of the component frame [componentId].
final class InstancePayload extends ObjectPayload {
  const InstancePayload(this.componentId);

  final ObjectId componentId;

  @override
  bool operator ==(Object other) =>
      other is InstancePayload && other.componentId == componentId;

  @override
  int get hashCode => Object.hash(InstancePayload, componentId);

  @override
  String toString() => 'InstancePayload(${componentId.value})';
}

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
  factory ImagePayload(
    String assetHash, {
    ImageAdjustments adjust = ImageAdjustments.none,
  }) {
    checkSha256Hex(assetHash, 'assetHash');
    return ImagePayload._(assetHash, adjust);
  }

  const ImagePayload._(this.assetHash, this.adjust);

  final String assetHash;

  /// Non-destructive colour adjustments and blur (P3.3.1, P3.3.2).
  final ImageAdjustments adjust;

  ImagePayload copyWith({ImageAdjustments? adjust}) =>
      ImagePayload._(assetHash, adjust ?? this.adjust);

  @override
  bool operator ==(Object other) =>
      other is ImagePayload &&
      other.assetHash == assetHash &&
      other.adjust == adjust;

  @override
  int get hashCode => Object.hash(assetHash, adjust);

  @override
  String toString() => 'ImagePayload($assetHash)';
}

/// Image adjustments (P3.3.1, P3.3.2). Each slider is −100…100 (0 = none)
/// except [hue] (−180…180 degrees) and [blur] (0…100, % of the shorter
/// side / 20) and [grayscale] (0…100).
@immutable
final class ImageAdjustments {
  factory ImageAdjustments({
    double brightness = 0,
    double contrast = 0,
    double saturation = 0,
    double exposure = 0,
    double temperature = 0,
    double tint = 0,
    double hue = 0,
    double grayscale = 0,
    double sepia = 0,
    double blur = 0,
  }) {
    void range(double v, double min, double max, String name) {
      if (!v.isFinite || v < min || v > max) {
        throw ArgumentError.value(v, name, 'must be within $min…$max');
      }
    }

    for (final (v, n) in [
      (brightness, 'brightness'),
      (contrast, 'contrast'),
      (saturation, 'saturation'),
      (exposure, 'exposure'),
      (temperature, 'temperature'),
      (tint, 'tint'),
    ]) {
      range(v, -100, 100, n);
    }
    range(hue, -180, 180, 'hue');
    range(grayscale, 0, 100, 'grayscale');
    range(sepia, 0, 100, 'sepia');
    range(blur, 0, 100, 'blur');
    return ImageAdjustments._(
      brightness,
      contrast,
      saturation,
      exposure,
      temperature,
      tint,
      hue,
      grayscale,
      sepia,
      blur,
    );
  }

  const ImageAdjustments._(
    this.brightness,
    this.contrast,
    this.saturation,
    this.exposure,
    this.temperature,
    this.tint,
    this.hue,
    this.grayscale,
    this.sepia,
    this.blur,
  );

  /// From [values] (missing keys are 0).
  factory ImageAdjustments.fromMap(Map<String, double> values) =>
      ImageAdjustments(
        brightness: values['brightness'] ?? 0,
        contrast: values['contrast'] ?? 0,
        saturation: values['saturation'] ?? 0,
        exposure: values['exposure'] ?? 0,
        temperature: values['temperature'] ?? 0,
        tint: values['tint'] ?? 0,
        hue: values['hue'] ?? 0,
        grayscale: values['grayscale'] ?? 0,
        sepia: values['sepia'] ?? 0,
        blur: values['blur'] ?? 0,
      );

  static const none = ImageAdjustments._(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double temperature;
  final double tint;
  final double hue;
  final double grayscale;
  final double sepia;
  final double blur;

  bool get isNone => this == none;

  /// Every value by name (for JSON and the inspector).
  Map<String, double> toMap() => {
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'exposure': exposure,
    'temperature': temperature,
    'tint': tint,
    'hue': hue,
    'grayscale': grayscale,
    'sepia': sepia,
    'blur': blur,
  };

  /// A copy with [name] set to [value].
  ImageAdjustments withValue(String name, double value) =>
      ImageAdjustments.fromMap({...toMap(), name: value});

  @override
  bool operator ==(Object other) =>
      other is ImageAdjustments &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.exposure == exposure &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.hue == hue &&
      other.grayscale == grayscale &&
      other.sepia == sepia &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(
    brightness,
    contrast,
    saturation,
    exposure,
    temperature,
    tint,
    hue,
    grayscale,
    sepia,
    blur,
  );
}

/// A mask group (P3.1.4): its first child is the mask shape; the other
/// children show only inside it. Also the basis of image frames.
final class MaskPayload extends ObjectPayload {
  const MaskPayload();

  @override
  bool operator ==(Object other) => other is MaskPayload;

  @override
  int get hashCode => (MaskPayload).hashCode;

  @override
  String toString() => 'MaskPayload()';
}

/// Vector path as SVG-compatible segments in the object's local space.
final class PathPayload extends ObjectPayload {
  /// [viewWidth] × [viewHeight] is the box the segments were drawn in
  /// (like an SVG viewBox): the path is scaled from it to the object's
  /// box, so resizing scales the curves. Without it the segments are drawn
  /// as they are.
  PathPayload(Iterable<PathSegment> segments, {this.viewWidth, this.viewHeight})
    : segments = List.unmodifiable(segments) {
    for (final v in [viewWidth, viewHeight]) {
      if (v != null && !(v > 0 && v.isFinite)) {
        throw ArgumentError.value(v, 'view size', 'must be positive');
      }
    }
  }

  final List<PathSegment> segments;
  final double? viewWidth;
  final double? viewHeight;

  @override
  bool operator ==(Object other) =>
      other is PathPayload &&
      other.viewWidth == viewWidth &&
      other.viewHeight == viewHeight &&
      listEquals(other.segments, segments);

  @override
  int get hashCode =>
      Object.hash(viewWidth, viewHeight, Object.hashAll(segments));

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
