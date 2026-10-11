import 'package:meta/meta.dart';

import 'validation.dart';

/// Placement of an object in its parent's coordinate space.
///
/// Render and export apply it as translate → rotate → scale around the
/// anchor (see document-model.md). Flips are negative scales. Skew is
/// post-MVP and not modelled yet.
@immutable
final class ObjectTransform {
  factory ObjectTransform({
    required double width,
    required double height,
    double x = 0,
    double y = 0,
    double rotation = 0,
    double scaleX = 1,
    double scaleY = 1,
    double anchorX = 0.5,
    double anchorY = 0.5,
  }) {
    checkFinite(x, 'x');
    checkFinite(y, 'y');
    // Zero is allowed: a horizontal line has no height.
    checkNonNegative(width, 'width');
    checkNonNegative(height, 'height');
    checkFinite(rotation, 'rotation');
    _checkScale(scaleX, 'scaleX');
    _checkScale(scaleY, 'scaleY');
    checkUnitInterval(anchorX, 'anchorX');
    checkUnitInterval(anchorY, 'anchorY');
    return ObjectTransform._(
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
      anchorX: anchorX,
      anchorY: anchorY,
    );
  }

  const ObjectTransform._({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.anchorX,
    required this.anchorY,
  });

  /// Position of the object's top-left corner in parent space.
  final double x;
  final double y;

  /// Unscaled size in document units.
  final double width;
  final double height;

  /// Clockwise rotation in degrees. Not normalised.
  final double rotation;

  /// Non-zero scale factors; negative values flip the object.
  final double scaleX;
  final double scaleY;

  /// Pivot for rotation and scale, in 0–1 local space (0.5 = centre).
  final double anchorX;
  final double anchorY;

  bool get isFlippedHorizontally => scaleX < 0;
  bool get isFlippedVertically => scaleY < 0;

  ObjectTransform copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? anchorX,
    double? anchorY,
  }) {
    return ObjectTransform(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
    );
  }

  static void _checkScale(double value, String name) {
    checkFinite(value, name);
    if (value == 0) {
      throw ArgumentError.value(value, name, 'must not be 0');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ObjectTransform &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.rotation == rotation &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.anchorX == anchorX &&
      other.anchorY == anchorY;

  @override
  int get hashCode => Object.hash(
    x,
    y,
    width,
    height,
    rotation,
    scaleX,
    scaleY,
    anchorX,
    anchorY,
  );

  @override
  String toString() =>
      'ObjectTransform(x: $x, y: $y, width: $width, '
      'height: $height, rotation: $rotation, scaleX: $scaleX, '
      'scaleY: $scaleY, anchorX: $anchorX, anchorY: $anchorY)';
}
