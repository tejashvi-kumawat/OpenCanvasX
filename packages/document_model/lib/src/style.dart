import 'package:meta/meta.dart';

import 'color.dart';
import 'validation.dart';

/// How an object's interior is painted.
///
/// Gradients arrive with the gradient editor (P1.7.3).
@immutable
sealed class Fill {
  const Fill();

  /// The colour of a solid fill, `null` for gradients.
  ArgbColor? get solidColor => null;

  /// One colour standing for this fill (the solid colour or the first
  /// gradient stop) — for swatches and places that cannot show gradients.
  ArgbColor get representative;
}

final class SolidFill extends Fill {
  const SolidFill(this.color);

  final ArgbColor color;

  @override
  ArgbColor? get solidColor => color;

  @override
  ArgbColor get representative => color;

  @override
  bool operator ==(Object other) => other is SolidFill && other.color == color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() => 'SolidFill($color)';
}

/// A colour at a position (0–1) along a gradient (P1.7.3).
@immutable
final class GradientStop {
  factory GradientStop(double offset, ArgbColor color) {
    checkUnitInterval(offset, 'offset');
    return GradientStop._(offset, color);
  }

  const GradientStop._(this.offset, this.color);

  final double offset;
  final ArgbColor color;

  GradientStop copyWith({double? offset, ArgbColor? color}) =>
      GradientStop(offset ?? this.offset, color ?? this.color);

  @override
  bool operator ==(Object other) =>
      other is GradientStop && other.offset == offset && other.color == color;

  @override
  int get hashCode => Object.hash(offset, color);

  @override
  String toString() => 'GradientStop($offset, $color)';
}

List<GradientStop> _checkStops(Iterable<GradientStop> stops) {
  final sorted = [...stops]..sort((a, b) => a.offset.compareTo(b.offset));
  if (sorted.length < 2) {
    throw ArgumentError.value(sorted, 'stops', 'needs at least two stops');
  }
  return List.unmodifiable(sorted);
}

/// Linear gradient across the object's box (P1.7.3). [angle] is in
/// degrees: 0 runs left → right, 90 top → bottom.
final class LinearGradientFill extends Fill {
  factory LinearGradientFill(
    Iterable<GradientStop> stops, {
    double angle = 90,
  }) {
    if (!angle.isFinite) throw ArgumentError.value(angle, 'angle');
    return LinearGradientFill._(_checkStops(stops), angle % 360);
  }

  const LinearGradientFill._(this.stops, this.angle);

  final List<GradientStop> stops;
  final double angle;

  @override
  ArgbColor get representative => stops.first.color;

  LinearGradientFill copyWith({List<GradientStop>? stops, double? angle}) =>
      LinearGradientFill(stops ?? this.stops, angle: angle ?? this.angle);

  @override
  bool operator ==(Object other) =>
      other is LinearGradientFill &&
      other.angle == angle &&
      listEquals(other.stops, stops);

  @override
  int get hashCode => Object.hash(angle, Object.hashAll(stops));
}

/// Radial gradient (P1.7.3) centred at ([centerX], [centerY]) and reaching
/// [radius], all as fractions of the object's box (an ellipse in
/// non-square boxes).
final class RadialGradientFill extends Fill {
  factory RadialGradientFill(
    Iterable<GradientStop> stops, {
    double centerX = 0.5,
    double centerY = 0.5,
    double radius = 0.5,
  }) {
    checkUnitInterval(centerX, 'centerX');
    checkUnitInterval(centerY, 'centerY');
    if (!(radius > 0 && radius.isFinite)) {
      throw ArgumentError.value(radius, 'radius', 'must be positive');
    }
    return RadialGradientFill._(_checkStops(stops), centerX, centerY, radius);
  }

  const RadialGradientFill._(
    this.stops,
    this.centerX,
    this.centerY,
    this.radius,
  );

  final List<GradientStop> stops;
  final double centerX;
  final double centerY;
  final double radius;

  @override
  ArgbColor get representative => stops.first.color;

  RadialGradientFill copyWith({List<GradientStop>? stops}) =>
      RadialGradientFill(
        stops ?? this.stops,
        centerX: centerX,
        centerY: centerY,
        radius: radius,
      );

  @override
  bool operator ==(Object other) =>
      other is RadialGradientFill &&
      other.centerX == centerX &&
      other.centerY == centerY &&
      other.radius == radius &&
      listEquals(other.stops, stops);

  @override
  int get hashCode =>
      Object.hash(centerX, centerY, radius, Object.hashAll(stops));
}

/// Line pattern of a stroke (P1.3.5). Dash lengths scale with the width.
enum StrokeDash { solid, dashed, dotted }

/// Outline paint.
@immutable
final class Stroke {
  factory Stroke({
    required ArgbColor color,
    double width = 1,
    StrokeDash dash = StrokeDash.solid,
  }) {
    checkNonNegative(width, 'width');
    return Stroke._(color, width, dash);
  }

  const Stroke._(this.color, this.width, this.dash);

  final ArgbColor color;
  final double width;
  final StrokeDash dash;

  Stroke copyWith({ArgbColor? color, double? width, StrokeDash? dash}) =>
      Stroke(
        color: color ?? this.color,
        width: width ?? this.width,
        dash: dash ?? this.dash,
      );

  @override
  bool operator ==(Object other) =>
      other is Stroke &&
      other.color == color &&
      other.width == width &&
      other.dash == dash;

  @override
  int get hashCode => Object.hash(color, width, dash);

  @override
  String toString() => 'Stroke(color: $color, width: $width, ${dash.name})';
}

/// Visual appearance of an object, used inline or as a named shared style.
///
/// Shadows and text defaults are added with their features (P1.5, P3).
@immutable
final class ObjectStyle {
  factory ObjectStyle({Fill? fill, Stroke? stroke, double cornerRadius = 0}) {
    checkNonNegative(cornerRadius, 'cornerRadius');
    return ObjectStyle._(fill, stroke, cornerRadius);
  }

  const ObjectStyle._(this.fill, this.stroke, this.cornerRadius);

  /// No fill, no stroke, square corners.
  static const none = ObjectStyle._(null, null, 0);

  final Fill? fill;
  final Stroke? stroke;
  final double cornerRadius;

  @override
  bool operator ==(Object other) =>
      other is ObjectStyle &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(fill, stroke, cornerRadius);

  @override
  String toString() =>
      'ObjectStyle(fill: $fill, stroke: $stroke, cornerRadius: $cornerRadius)';
}
