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

/// Outline paint. Dash patterns arrive with P1.3.5.
@immutable
final class Stroke {
  factory Stroke({required ArgbColor color, double width = 1}) {
    checkNonNegative(width, 'width');
    return Stroke._(color, width);
  }

  const Stroke._(this.color, this.width);

  final ArgbColor color;
  final double width;

  @override
  bool operator ==(Object other) =>
      other is Stroke && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);

  @override
  String toString() => 'Stroke(color: $color, width: $width)';
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
