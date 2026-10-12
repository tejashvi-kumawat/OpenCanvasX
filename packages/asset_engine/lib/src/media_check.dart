import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Largest file accepted for import (asset-architecture.md "size caps").
const int maxImportBytes = 50 * 1024 * 1024;

/// Largest SVG accepted; SVG is text and big ones are usually hostile.
const int maxSvgBytes = 5 * 1024 * 1024;

/// Largest raster side accepted, in pixels.
const int maxImageSide = 16384;

/// Result of checking an imported file: its type and pixel size, or why it
/// was refused.
@immutable
final class MediaCheck {
  const MediaCheck.ok(this.mime, this.width, this.height) : error = null;
  const MediaCheck.rejected(String this.error)
    : mime = null,
      width = null,
      height = null;

  final String? mime;
  final int? width;
  final int? height;
  final String? error;

  bool get isOk => error == null;
  bool get isSvg => mime == 'image/svg+xml';
}

/// Identifies PNG, JPEG, GIF, WebP, BMP and SVG from their bytes (never the
/// file name) and reads the pixel size from headers only (P1.6.1, P1.6.2).
MediaCheck checkMedia(Uint8List bytes) {
  if (bytes.isEmpty) return const MediaCheck.rejected('The file is empty.');
  if (bytes.length > maxImportBytes) {
    return const MediaCheck.rejected('The file is larger than 50 MB.');
  }
  final raster = _rasterSize(bytes);
  if (raster != null) {
    final (mime, w, h) = raster;
    if (w <= 0 || h <= 0) {
      return const MediaCheck.rejected('The image has no size.');
    }
    if (w > maxImageSide || h > maxImageSide) {
      return const MediaCheck.rejected(
        'The image is larger than 16384 pixels on a side.',
      );
    }
    return MediaCheck.ok(mime, w, h);
  }
  return checkSvg(bytes);
}

/// Validates SVG text: refuses scripts, event handlers, external
/// references, entities and foreign content; reads the size from
/// `width`/`height` or `viewBox`.
MediaCheck checkSvg(Uint8List bytes) {
  if (bytes.length > maxSvgBytes) {
    return const MediaCheck.rejected('The SVG is larger than 5 MB.');
  }
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return const MediaCheck.rejected('This file type is not supported.');
  }
  final root = RegExp(r'<svg\b[^>]*>', caseSensitive: false).firstMatch(text);
  if (root == null) {
    return const MediaCheck.rejected('This file type is not supported.');
  }
  if (_unsafeSvg.hasMatch(text)) {
    return const MediaCheck.rejected(
      'The SVG contains scripts or external content and was not imported.',
    );
  }
  final tag = root.group(0)!;
  double? attr(String name) {
    final m = RegExp(
      '\\s$name\\s*=\\s*["\']\\s*([0-9.]+)\\s*(px)?\\s*["\']',
    ).firstMatch(tag);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  var w = attr('width');
  var h = attr('height');
  final viewBox = RegExp(
    r'viewBox\s*=\s*["'
    "'"
    r']([^"'
    "'"
    r']+)',
  ).firstMatch(tag);
  if ((w == null || h == null) && viewBox != null) {
    final parts =
        viewBox
            .group(1)!
            .trim()
            .split(RegExp(r'[\s,]+'))
            .map(double.tryParse)
            .toList();
    if (parts.length == 4 && parts[2] != null && parts[3] != null) {
      w ??= parts[2];
      h ??= parts[3];
    }
  }
  return MediaCheck.ok(
    'image/svg+xml',
    (w ?? 300).round().clamp(1, maxImageSide),
    (h ?? 150).round().clamp(1, maxImageSide),
  );
}

final _unsafeSvg = RegExp(
  r'<script|<foreignObject|<!ENTITY|<!DOCTYPE|<iframe|<embed|<object|'
  r'\son[a-z]+\s*=|javascript:|data:text/html|'
  r'''(?:xlink:)?href\s*=\s*["'](?!#|data:image/)|'''
  r'''url\(\s*["']?(?!#|data:image/)''',
  caseSensitive: false,
);

(String, int, int)? _rasterSize(Uint8List b) {
  int u16be(int o) => (b[o] << 8) | b[o + 1];
  int u16le(int o) => b[o] | (b[o + 1] << 8);
  int u32be(int o) => (u16be(o) << 16) | u16be(o + 2);
  int u32le(int o) => u16le(o) | (u16le(o + 2) << 16);
  int s32le(int o) => u32le(o).toSigned(32);
  bool starts(List<int> sig, [int at = 0]) {
    if (b.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[at + i] != sig[i]) return false;
    }
    return true;
  }

  // PNG: IHDR right after the signature.
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    if (b.length < 24) return ('image/png', 0, 0);
    return ('image/png', u32be(16), u32be(20));
  }
  // GIF87a / GIF89a.
  if (starts(const [0x47, 0x49, 0x46, 0x38])) {
    if (b.length < 10) return ('image/gif', 0, 0);
    return ('image/gif', u16le(6), u16le(8));
  }
  // BMP: BITMAPINFOHEADER width/height (height may be negative).
  if (starts(const [0x42, 0x4D])) {
    if (b.length < 26) return ('image/bmp', 0, 0);
    return ('image/bmp', s32le(18).abs(), s32le(22).abs());
  }
  // WebP: RIFF....WEBP with VP8 / VP8L / VP8X chunks.
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    if (b.length < 30) return ('image/webp', 0, 0);
    if (starts(const [0x56, 0x50, 0x38, 0x20], 12)) {
      return ('image/webp', u16le(26) & 0x3FFF, u16le(28) & 0x3FFF);
    }
    if (starts(const [0x56, 0x50, 0x38, 0x4C], 12)) {
      final bits = u32le(21);
      return ('image/webp', (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    }
    if (starts(const [0x56, 0x50, 0x38, 0x58], 12)) {
      final w = (b[24] | (b[25] << 8) | (b[26] << 16)) + 1;
      final h = (b[27] | (b[28] << 8) | (b[29] << 16)) + 1;
      return ('image/webp', w, h);
    }
    return ('image/webp', 0, 0);
  }
  // JPEG: walk markers to the first start-of-frame.
  if (starts(const [0xFF, 0xD8])) {
    var o = 2;
    while (o + 9 < b.length) {
      if (b[o] != 0xFF) {
        o++;
        continue;
      }
      final marker = b[o + 1];
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        o += 2;
        continue;
      }
      final isFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isFrame) return ('image/jpeg', u16be(o + 7), u16be(o + 5));
      o += 2 + u16be(o + 2);
    }
    return ('image/jpeg', 0, 0);
  }
  return null;
}
