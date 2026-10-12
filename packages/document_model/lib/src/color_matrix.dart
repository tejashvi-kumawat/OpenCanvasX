import 'dart:math' as math;

import 'payload.dart';

/// A 4 × 5 colour matrix (row-major, offsets in 0…255 units) applying
/// [adjust] — the same numbers drive the canvas (Flutter
/// `ColorFilter.matrix`) and SVG export (`feColorMatrix`, offsets / 255).
/// Order: exposure, brightness, contrast, temperature/tint, saturation and
/// greyscale, hue, sepia.
List<double> colorMatrixFor(ImageAdjustments adjust) {
  var m = _identity();
  void then(List<double> next) => m = _multiply(next, m);

  if (adjust.exposure != 0) {
    final k = math.pow(2, adjust.exposure / 50).toDouble();
    then(_scale(k, k, k));
  }
  if (adjust.brightness != 0) {
    final o = adjust.brightness / 100 * 0.4 * 255;
    then(_offset(o, o, o));
  }
  if (adjust.contrast != 0) {
    final k = 1 + adjust.contrast / 100;
    final o = (1 - k) * 127.5;
    then([k, 0, 0, 0, o, 0, k, 0, 0, o, 0, 0, k, 0, o, 0, 0, 0, 1, 0]);
  }
  if (adjust.temperature != 0 || adjust.tint != 0) {
    final t = adjust.temperature / 100 * 40;
    final g = -adjust.tint / 100 * 30;
    then(_offset(t, g, -t));
  }
  final saturation =
      (1 + adjust.saturation / 100) * (1 - adjust.grayscale / 100);
  if (saturation != 1) then(_saturation(saturation));
  if (adjust.hue != 0) then(_hue(adjust.hue * math.pi / 180));
  if (adjust.sepia != 0) {
    final a = adjust.sepia / 100;
    const sepia = [
      0.393, 0.769, 0.189, 0.0, 0.0, //
      0.349, 0.686, 0.168, 0.0, 0.0,
      0.272, 0.534, 0.131, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
    final id = _identity();
    then([for (var i = 0; i < 20; i++) id[i] * (1 - a) + sepia[i] * a]);
  }
  return m;
}

List<double> _identity() => [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _scale(double r, double g, double b) => [
  r, 0, 0, 0, 0, //
  0, g, 0, 0, 0,
  0, 0, b, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _offset(double r, double g, double b) => [
  1, 0, 0, 0, r, //
  0, 1, 0, 0, g,
  0, 0, 1, 0, b,
  0, 0, 0, 1, 0,
];

List<double> _saturation(double s) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final sr = (1 - s) * lr;
  final sg = (1 - s) * lg;
  final sb = (1 - s) * lb;
  return [
    sr + s, sg, sb, 0, 0, //
    sr, sg + s, sb, 0, 0,
    sr, sg, sb + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _hue(double radians) {
  final c = math.cos(radians);
  final s = math.sin(radians);
  const lr = 0.213;
  const lg = 0.715;
  const lb = 0.072;
  return [
    lr + c * (1 - lr) + s * -lr,
    lg + c * -lg + s * -lg,
    lb + c * -lb + s * (1 - lb),
    0,
    0,
    lr + c * -lr + s * 0.143,
    lg + c * (1 - lg) + s * 0.14,
    lb + c * -lb + s * -0.283,
    0,
    0,
    lr + c * -lr + s * -(1 - lr),
    lg + c * -lg + s * lg,
    lb + c * (1 - lb) + s * lb,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// [a] × [b] for 4 × 5 colour matrices (as 5 × 5 with an implicit last
/// row 0 0 0 0 1).
List<double> _multiply(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = col == 4 ? a[row * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[row * 5 + k] * b[k * 5 + col];
      }
      out[row * 5 + col] = v;
    }
  }
  return out;
}

/// Named looks offered as one-click filters (Canva-style).
const Map<String, Map<String, double>> imageFilterPresets = {
  'Original': {},
  'Mono': {'grayscale': 100, 'contrast': 10},
  'Noir': {'grayscale': 100, 'contrast': 45, 'brightness': -10},
  'Sepia': {'sepia': 80, 'contrast': 5},
  'Vivid': {'saturation': 45, 'contrast': 15},
  'Fade': {'contrast': -30, 'brightness': 12, 'saturation': -20},
  'Warm': {'temperature': 45, 'saturation': 10},
  'Cool': {'temperature': -45, 'tint': -10},
  'Dream': {'brightness': 10, 'saturation': 20, 'blur': 3, 'hue': -15},
};
