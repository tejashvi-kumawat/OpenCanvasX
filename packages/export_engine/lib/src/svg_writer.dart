import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';

import 'export_targets.dart';

/// Splits a text object into the lines it shows (the app supplies this
/// from its text layout so wrapping matches the canvas).
typedef TextLineBreaker = List<String> Function(DesignObject text);

/// Lines broken only at explicit newlines (no wrapping).
List<String> explicitLines(DesignObject text) => switch (text.payload) {
  TextPayload(:final text) => text.split('\n'),
  _ => const [],
};

/// Writes [target] as a standalone SVG 1.1 document (P1.9.3): shapes,
/// paths, lines and frames stay vectors; text stays text (fonts by family
/// name); images are embedded as data URIs. The canvas size is the
/// target's pixel size at [scale].
String exportSvg(
  DesignDocument document,
  ExportTarget target, {
  required Map<String, Uint8List> assets,
  TextLineBreaker lines = explicitLines,
  double scale = 1,
  bool transparent = false,
}) {
  final page = document.pages.firstWhere((p) => p.id == target.pageId);
  final size = exportPixelSize(page, target, scale: scale);
  final r = target.region;
  final w = _SvgWriter(document, assets, lines);
  final out =
      StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
        ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" '
          'xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" '
          'width="${size.width}" height="${size.height}" '
          'viewBox="${_n(r.left)} ${_n(r.top)} ${_n(r.width)} ${_n(r.height)}">',
        )
        ..writeln('<title>${_esc(target.name)}</title>');
  if (target.includeBackground && !transparent) {
    if (page.background case SolidBackground(:final color)) {
      out.writeln(
        '<rect x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
        'height="${_n(r.height)}"${_paint('fill', color)}/>',
      );
    }
  }
  for (final id in target.roots) {
    final object = document.objects[id];
    if (object == null) continue;
    final parent = parentToPage(document, id);
    if (parent == Affine2D.identity) {
      w.object(out, object);
    } else {
      out.writeln('<g transform="${_matrix(parent)}">');
      w.object(out, object);
      out.writeln('</g>');
    }
  }
  final defs = w.defs.toString();
  out.writeln('</svg>');
  final svg = out.toString();
  if (defs.isEmpty) return svg;
  // Clip paths are collected while writing; put them right after <title>.
  final at = svg.indexOf('</title>') + '</title>'.length;
  return '${svg.substring(0, at)}\n<defs>\n$defs</defs>${svg.substring(at)}';
}

class _SvgWriter {
  _SvgWriter(this.document, this.assets, this.lines);

  final DesignDocument document;
  final Map<String, Uint8List> assets;
  final TextLineBreaker lines;
  final StringBuffer defs = StringBuffer();
  int _clips = 0;

  void object(StringBuffer out, DesignObject o, [int depth = 0]) {
    if (o.hidden || depth > 64) return;
    final t = o.transform;
    final attrs = StringBuffer(' transform="${_matrix(localToParent(t))}"');
    if (o.opacity < 1) attrs.write(' opacity="${_n(o.opacity)}"');
    if (o.blendMode != ObjectBlendMode.normal) {
      attrs.write(' style="mix-blend-mode:${_blend(o.blendMode)}"');
    }
    final name = o.name;
    if (name != null && name.isNotEmpty) {
      attrs.write(' id="${_id(o.id.value)}"');
    }
    final style = effectiveStyleOf(o);
    out.writeln('<g$attrs>');
    switch (o.type) {
      case ObjectType.group:
        for (final id in o.childIds) {
          if (document.objects[id] case final child?) {
            object(out, child, depth + 1);
          }
        }
      case ObjectType.frame:
        final box = _roundedRect(t.width, t.height, style.cornerRadius);
        if (style.fill != null) out.writeln('<$box${_fill(style)}/>');
        final clip = switch (o.payload) {
          FramePayload(:final clipContent) => clipContent,
          _ => true,
        };
        if (clip) {
          final id = 'clip${_clips++}';
          defs.writeln('<clipPath id="$id"><$box/></clipPath>');
          out.writeln('<g clip-path="url(#$id)">');
        }
        for (final id in o.childIds) {
          if (document.objects[id] case final child?) {
            object(out, child, depth + 1);
          }
        }
        if (clip) out.writeln('</g>');
        if (style.stroke case final stroke? when stroke.width > 0) {
          out.writeln('<$box fill="none"${_stroke(stroke)}/>');
        }
      case ObjectType.rect || ObjectType.roundedRect:
        final radius =
            style.cornerRadius > 0
                ? style.cornerRadius
                : (o.type == ObjectType.roundedRect
                    ? math.min(t.width, t.height) * 0.12
                    : 0.0);
        out.writeln(
          '<${_roundedRect(t.width, t.height, radius)}'
          '${_fill(style)}${_strokeOf(style)}/>',
        );
      case ObjectType.ellipse:
        out.writeln(
          '<ellipse cx="${_n(t.width / 2)}" cy="${_n(t.height / 2)}" '
          'rx="${_n(t.width / 2)}" ry="${_n(t.height / 2)}"'
          '${_fill(style)}${_strokeOf(style)}/>',
        );
      case ObjectType.polygon:
        final sides = switch (o.payload) {
          PolygonPayload(:final sides) => sides,
          _ => 6,
        };
        out.writeln(
          '<polygon points="${_regular(t, [for (var i = 0; i < sides; i++) 1.0])}"'
          '${_fill(style)}${_strokeOf(style)}/>',
        );
      case ObjectType.star:
        final (points, inner) = switch (o.payload) {
          StarPayload(:final points, :final innerRatio) => (points, innerRatio),
          _ => (5, 0.5),
        };
        out.writeln(
          '<polygon points="${_regular(t, [for (var i = 0; i < points * 2; i++)
            if (i.isEven) 1.0 else inner])}"${_fill(style)}${_strokeOf(style)}/>',
        );
      case ObjectType.path:
        final scale = switch (o.payload) {
          PathPayload(:final viewWidth?, :final viewHeight?) =>
            ' transform="scale(${_n(t.width / viewWidth)} '
                '${_n(t.height / viewHeight)})" '
                'vector-effect="non-scaling-stroke"',
          _ => '',
        };
        out.writeln(
          '<path d="${_pathData(o.payload)}"$scale'
          '${_fill(style)}${_strokeOf(style)}/>',
        );
      case ObjectType.line:
        if (style.stroke case final stroke? when stroke.width > 0) {
          out.writeln(
            '<line x1="0" y1="0" x2="${_n(t.width)}" y2="${_n(t.height)}"'
            '${_stroke(stroke, roundCap: true)}/>',
          );
        }
      case ObjectType.arrow:
        if (style.stroke case final stroke? when stroke.width > 0) {
          _arrow(out, t, stroke);
        }
      case ObjectType.text:
        _text(out, o, style);
      case ObjectType.image:
        _image(out, o, style);
    }
    out.writeln('</g>');
  }

  /// Shared style with inline fields taking precedence (as the renderer).
  ObjectStyle effectiveStyleOf(DesignObject o) {
    final shared = o.styleId == null ? null : document.styles[o.styleId];
    final inline = o.style;
    if (shared == null) return inline ?? ObjectStyle.none;
    if (inline == null) return shared;
    return ObjectStyle(
      fill: inline.fill ?? shared.fill,
      stroke: inline.stroke ?? shared.stroke,
      cornerRadius:
          inline.cornerRadius > 0 ? inline.cornerRadius : shared.cornerRadius,
    );
  }

  void _arrow(StringBuffer out, ObjectTransform t, Stroke stroke) {
    final length = math.sqrt(t.width * t.width + t.height * t.height);
    if (length == 0) return;
    final head = math.min(math.max<double>(stroke.width * 4, 6), length);
    final dx = t.width / length;
    final dy = t.height / length;
    final shaftX = t.width - dx * head * 0.6;
    final shaftY = t.height - dy * head * 0.6;
    out.writeln(
      '<line x1="0" y1="0" x2="${_n(shaftX)}" y2="${_n(shaftY)}"'
      '${_stroke(stroke, roundCap: true)}/>',
    );
    final bx = t.width - dx * head;
    final by = t.height - dy * head;
    final nx = -dy * head * 0.5;
    final ny = dx * head * 0.5;
    out.writeln(
      '<polygon points="${_n(t.width)},${_n(t.height)} '
      '${_n(bx + nx)},${_n(by + ny)} ${_n(bx - nx)},${_n(by - ny)}"'
      '${_paint('fill', stroke.color)}/>',
    );
  }

  void _text(StringBuffer out, DesignObject o, ObjectStyle style) {
    final payload = o.payload;
    if (payload is! TextPayload) return;
    final t = o.transform;
    final (x, anchor) = switch (payload.align) {
      TextAlignment.center => (t.width / 2, 'middle'),
      TextAlignment.right => (t.width, 'end'),
      TextAlignment.left || TextAlignment.justify => (0.0, 'start'),
    };
    final family = payload.fontFamily;
    final attrs =
        StringBuffer()
          ..write(' font-size="${_n(payload.fontSize)}"')
          ..write(' font-weight="${payload.fontWeight}"')
          ..write(' text-anchor="$anchor"');
    attrs.write(
      ' font-family="${_esc(family == null ? '' : "'$family', ")}'
      'system-ui, sans-serif"',
    );
    if (payload.italic) attrs.write(' font-style="italic"');
    if (payload.letterSpacing != 0) {
      attrs.write(' letter-spacing="${_n(payload.letterSpacing)}"');
    }
    if (style.fill != null) attrs.write(_fill(style));
    final lineHeight = payload.fontSize * payload.lineHeight;
    // Baseline of the first line: half leading plus the ascent (~0.8 em).
    final first = (lineHeight - payload.fontSize) / 2 + payload.fontSize * 0.8;
    final shown = lines(o);
    out.writeln('<text$attrs xml:space="preserve">');
    for (final (i, line) in shown.indexed) {
      out.writeln(
        '<tspan x="${_n(x)}" y="${_n(first + i * lineHeight)}">'
        '${_esc(line)}</tspan>',
      );
    }
    out.writeln('</text>');
  }

  void _image(StringBuffer out, DesignObject o, ObjectStyle style) {
    final payload = o.payload;
    if (payload is! ImagePayload) return;
    final info = document.assets[payload.assetHash];
    var bytes = assets[payload.assetHash];
    if (info == null || bytes == null) return;
    final t = o.transform;
    if (info.mime == 'image/svg+xml') {
      // Bake the icon colour in: currentColor does not cross <image>.
      if (style.fill?.representative case final color?) {
        bytes = Uint8List.fromList(
          utf8.encode(
            utf8
                .decode(bytes, allowMalformed: true)
                .replaceAll('currentColor', _hex(color)),
          ),
        );
      }
    }
    final radius = math.min(
      style.cornerRadius,
      math.min(t.width, t.height) / 2,
    );
    var clipAttr = '';
    if (radius > 0) {
      final id = 'clip${_clips++}';
      defs.writeln(
        '<clipPath id="$id"><${_roundedRect(t.width, t.height, radius)}/></clipPath>',
      );
      clipAttr = ' clip-path="url(#$id)"';
    }
    out.writeln(
      '<image width="${_n(t.width)}" height="${_n(t.height)}" '
      'preserveAspectRatio="none"$clipAttr '
      'xlink:href="data:${info.mime};base64,${base64Encode(bytes)}"/>',
    );
    if (style.stroke case final stroke? when stroke.width > 0) {
      out.writeln(
        '<${_roundedRect(t.width, t.height, radius)} fill="none"'
        '${_stroke(stroke)}/>',
      );
    }
  }

  int _gradients = 0;

  /// Fill attribute; gradients are written to `<defs>` in bounding-box
  /// units and referenced by id (P1.7.3).
  String _fill(ObjectStyle style) {
    switch (style.fill) {
      case null:
        return ' fill="none"';
      case SolidFill(:final color):
        return _paint('fill', color);
      case LinearGradientFill(:final stops, :final angle):
        final id = 'grad${_gradients++}';
        final r = angle * math.pi / 180;
        final dx = math.cos(r);
        final dy = math.sin(r);
        final half = (dx.abs() + dy.abs()) / 2;
        defs
          ..writeln(
            '<linearGradient id="$id" x1="${_n(0.5 - dx * half)}" '
            'y1="${_n(0.5 - dy * half)}" x2="${_n(0.5 + dx * half)}" '
            'y2="${_n(0.5 + dy * half)}">',
          )
          ..write(_stops(stops))
          ..writeln('</linearGradient>');
        return ' fill="url(#$id)"';
      case RadialGradientFill(
        :final stops,
        :final centerX,
        :final centerY,
        :final radius,
      ):
        final id = 'grad${_gradients++}';
        defs
          ..writeln(
            '<radialGradient id="$id" cx="${_n(centerX)}" '
            'cy="${_n(centerY)}" r="${_n(radius)}">',
          )
          ..write(_stops(stops))
          ..writeln('</radialGradient>');
        return ' fill="url(#$id)"';
    }
  }

  static String _stops(List<GradientStop> stops) {
    final out = StringBuffer();
    for (final s in stops) {
      final alpha = s.color.alpha / 255;
      final opacity = alpha < 1 ? ' stop-opacity="${_n(alpha)}"' : '';
      out.writeln(
        '<stop offset="${_n(s.offset)}" stop-color="${_hex(s.color)}"$opacity/>',
      );
    }
    return out.toString();
  }

  String _strokeOf(ObjectStyle style) => switch (style.stroke) {
    final stroke? when stroke.width > 0 => _stroke(stroke),
    _ => '',
  };
}

String _roundedRect(double w, double h, double radius) {
  final r = math.min(radius, math.min(w, h) / 2);
  return 'rect x="0" y="0" width="${_n(w)}" height="${_n(h)}"'
      '${r > 0 ? ' rx="${_n(r)}" ry="${_n(r)}"' : ''}';
}

String _stroke(Stroke stroke, {bool roundCap = false}) {
  final w = stroke.width;
  final dash = switch (stroke.dash) {
    StrokeDash.solid => '',
    StrokeDash.dashed => ' stroke-dasharray="${_n(w * 4)} ${_n(w * 2.5)}"',
    StrokeDash.dotted => ' stroke-dasharray="0 ${_n(w * 2)}"',
  };
  final cap = stroke.dash == StrokeDash.dotted || roundCap ? 'round' : 'butt';
  return '${_paint('stroke', stroke.color)} stroke-width="${_n(w)}"'
      ' stroke-linejoin="round" stroke-linecap="$cap"$dash';
}

String _paint(String attr, ArgbColor color) {
  final alpha = color.alpha / 255;
  return ' $attr="${_hex(color)}"'
      '${alpha < 1 ? ' $attr-opacity="${_n(alpha)}"' : ''}';
}

String _hex(ArgbColor c) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${two(c.red)}${two(c.green)}${two(c.blue)}';
}

String _regular(ObjectTransform t, List<double> radii) {
  final cx = t.width / 2;
  final cy = t.height / 2;
  String vertex(int i) {
    final angle = -math.pi / 2 + 2 * math.pi * i / radii.length;
    final x = cx + math.cos(angle) * cx * radii[i];
    final y = cy + math.sin(angle) * cy * radii[i];
    return '${_n(x)},${_n(y)}';
  }

  return [for (var i = 0; i < radii.length; i++) vertex(i)].join(' ');
}

String _pathData(ObjectPayload payload) {
  if (payload is! PathPayload) return '';
  return [
    for (final s in payload.segments)
      switch (s) {
        MoveTo(:final x, :final y) => 'M${_n(x)} ${_n(y)}',
        LineTo(:final x, :final y) => 'L${_n(x)} ${_n(y)}',
        QuadTo(:final cx, :final cy, :final x, :final y) =>
          'Q${_n(cx)} ${_n(cy)} ${_n(x)} ${_n(y)}',
        CubicTo(
          :final c1x,
          :final c1y,
          :final c2x,
          :final c2y,
          :final x,
          :final y,
        ) =>
          'C${_n(c1x)} ${_n(c1y)} ${_n(c2x)} ${_n(c2y)} ${_n(x)} ${_n(y)}',
        ClosePath() => 'Z',
      },
  ].join(' ');
}

String _matrix(Affine2D m) =>
    'matrix(${_n(m.a)} ${_n(m.b)} ${_n(m.c)} ${_n(m.d)} ${_n(m.e)} ${_n(m.f)})';

String _blend(ObjectBlendMode mode) => mode.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '-${m[0]!.toLowerCase()}',
);

String _id(String raw) => 'o-${raw.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_')}';

/// Compact number: up to 3 decimals, no trailing zeros.
String _n(double v) {
  if (v.isNaN || v.isInfinite) return '0';
  final s = v.toStringAsFixed(3);
  if (!s.contains('.')) return s;
  final trimmed = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
