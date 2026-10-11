import 'package:meta/meta.dart';

/// 32-bit color packed as `0xAARRGGBB` (non-premultiplied sRGB).
///
/// Kept independent of `dart:ui` so the model stays pure Dart.
@immutable
final class ArgbColor {
  /// Creates a color from a packed `0xAARRGGBB` value.
  factory ArgbColor(int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw ArgumentError.value(value, 'value', 'must fit in 32 bits');
    }
    return ArgbColor._(value);
  }

  /// Creates a color from 0–255 channel values.
  factory ArgbColor.fromArgb(int alpha, int red, int green, int blue) {
    for (final (name, channel) in [
      ('alpha', alpha),
      ('red', red),
      ('green', green),
      ('blue', blue),
    ]) {
      RangeError.checkValueInInterval(channel, 0, 255, name);
    }
    return ArgbColor._((alpha << 24) | (red << 16) | (green << 8) | blue);
  }

  const ArgbColor._(this.value);

  static const transparent = ArgbColor._(0x00000000);
  static const black = ArgbColor._(0xFF000000);
  static const white = ArgbColor._(0xFFFFFFFF);

  final int value;

  int get alpha => (value >> 24) & 0xFF;
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;

  @override
  bool operator ==(Object other) => other is ArgbColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'ArgbColor(0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}
