import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Something decoded that the painter can draw into an object's box.
sealed class MediaDrawable {
  const MediaDrawable();
}

/// A decoded raster image.
final class RasterMedia extends MediaDrawable {
  const RasterMedia(this.image);

  final ui.Image image;
}

/// A parsed SVG, recorded as a picture of [size] user units.
final class VectorMedia extends MediaDrawable {
  const VectorMedia(this.picture, this.size);

  final ui.Picture picture;
  final ui.Size size;
}

/// Decoded images and SVGs by asset hash (P1.6.5).
///
/// Bytes are [register]ed when a design opens or media is inserted;
/// decoding starts on first [resolve] and runs asynchronously, after which
/// listeners are notified so canvases repaint. SVGs that draw in
/// `currentColor` are cached once per colour.
class MediaCache extends ChangeNotifier {
  final Map<String, (Uint8List, String)> _bytes = {};
  final Map<String, ui.Image> _images = {};
  final Map<(String, int?), VectorMedia> _vectors = {};
  final Set<Object> _pending = {};
  final Set<Object> _failed = {};
  bool _disposed = false;

  /// Makes [bytes] (of type [mime]) available under [hash].
  void register(String hash, Uint8List bytes, String mime) {
    _bytes.putIfAbsent(hash, () => (bytes, mime));
  }

  bool contains(String hash) => _bytes.containsKey(hash);

  /// Registered bytes for [hash], e.g. for saving or export.
  Uint8List? bytesOf(String hash) => _bytes[hash]?.$1;

  /// Every registered hash with its bytes.
  Map<String, Uint8List> get allBytes => {
    for (final MapEntry(:key, :value) in _bytes.entries) key: value.$1,
  };

  /// The drawable for [hash], or `null` while it decodes (or if it cannot
  /// be decoded). [currentColor] (ARGB) recolours monochrome SVGs.
  MediaDrawable? resolve(String hash, {int? currentColor}) {
    final entry = _bytes[hash];
    if (entry == null) return null;
    final (bytes, mime) = entry;
    if (mime == 'image/svg+xml') {
      final key = (hash, currentColor);
      final cached = _vectors[key];
      if (cached != null) return cached;
      if (_pending.add(key) && !_failed.contains(key)) {
        _decodeSvg(key, bytes, currentColor);
      }
      return null;
    }
    final cached = _images[hash];
    if (cached != null) return RasterMedia(cached);
    if (_pending.add(hash) && !_failed.contains(hash)) {
      _decodeRaster(hash, bytes);
    }
    return null;
  }

  /// Decodes everything registered; completes when all decodes finish.
  /// Used before export so nothing is missing from the output.
  Future<void> preload(Iterable<(String, int?)> wanted) async {
    for (final (hash, color) in wanted) {
      resolve(hash, currentColor: color);
    }
    while (_pending.isNotEmpty && !_disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> _decodeRaster(String hash, Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (_disposed) {
        frame.image.dispose();
        return;
      }
      _images[hash] = frame.image;
    } on Object {
      _failed.add(hash);
    } finally {
      _pending.remove(hash);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _decodeSvg(
    (String, int?) key,
    Uint8List bytes,
    int? currentColor,
  ) async {
    try {
      final info = await vg.loadPicture(
        SvgBytesLoader(
          bytes,
          theme: SvgTheme(currentColor: ui.Color(currentColor ?? 0xFF000000)),
        ),
        null,
      );
      if (_disposed) {
        info.picture.dispose();
        return;
      }
      _vectors[key] = VectorMedia(info.picture, info.size);
    } on Object {
      _failed.add(key);
    } finally {
      _pending.remove(key);
    }
    if (!_disposed) notifyListeners();
  }

  /// Forgets all media (e.g. when a design closes).
  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    for (final vector in _vectors.values) {
      vector.picture.dispose();
    }
    _images.clear();
    _vectors.clear();
    _bytes.clear();
    _failed.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}
