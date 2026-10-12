import 'package:meta/meta.dart';

import 'color.dart';
import 'validation.dart';

/// How an object's interior is painted.
///
/// Gradients arrive with the gradient editor (P1.7.3).
@immutable
sealed class Fill {
  const Fill();
}

final class SolidFill extends Fill {
  const SolidFill(this.color);

  final ArgbColor color;

  @override
  bool operator ==(Object other) => other is SolidFill && other.color == color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() => 'SolidFill($color)';
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
