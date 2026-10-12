import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:document_model/document_model.dart';

/// Deepest group nesting drawn; protects against cyclic files.
const _maxDepth = 64;

/// Converts a model colour to a `dart:ui` colour.
ui.Color toUiColor(ArgbColor color) => ui.Color(color.value);

/// The `dart:ui` blend mode for [mode].
ui.BlendMode toUiBlendMode(ObjectBlendMode mode) => switch (mode) {
  ObjectBlendMode.normal => ui.BlendMode.srcOver,
  ObjectBlendMode.multiply => ui.BlendMode.multiply,
  ObjectBlendMode.screen => ui.BlendMode.screen,
  ObjectBlendMode.overlay => ui.BlendMode.overlay,
  ObjectBlendMode.darken => ui.BlendMode.darken,
  ObjectBlendMode.lighten => ui.BlendMode.lighten,
  ObjectBlendMode.colorDodge => ui.BlendMode.colorDodge,
  ObjectBlendMode.colorBurn => ui.BlendMode.colorBurn,
  ObjectBlendMode.hardLight => ui.BlendMode.hardLight,
  ObjectBlendMode.softLight => ui.BlendMode.softLight,
  ObjectBlendMode.difference => ui.BlendMode.difference,
  ObjectBlendMode.exclusion => ui.BlendMode.exclusion,
  ObjectBlendMode.hue => ui.BlendMode.hue,
  ObjectBlendMode.saturation => ui.BlendMode.saturation,
  ObjectBlendMode.color => ui.BlendMode.color,
  ObjectBlendMode.luminosity => ui.BlendMode.luminosity,
};

/// Converts a model matrix for `Canvas.transform`.
Float64List toUiMatrix(Affine2D m) =>
    Float64List.fromList(m.toMatrix4Storage());

/// The style [object] is drawn with: its shared style (`styleId`) with the
/// inline style's fields taking precedence (document-model.md "Styles").
ObjectStyle effectiveStyle(
  DesignObject object,
  Map<String, ObjectStyle> styles,
) {
  final shared = object.styleId == null ? null : styles[object.styleId];
  final inline = object.style;
  if (shared == null) return inline ?? ObjectStyle.none;
  if (inline == null) return shared;
  return ObjectStyle(
    fill: inline.fill ?? shared.fill,
    stroke: inline.stroke ?? shared.stroke,
    cornerRadius:
        inline.cornerRadius > 0 ? inline.cornerRadius : shared.cornerRadius,
  );
}

/// Corner radius used for [object]'s box.
double cornerRadiusOf(DesignObject object, ObjectStyle style) {
  final t = object.transform;
  final maxRadius = math.min(t.width, t.height) / 2;
  final radius =
      style.cornerRadius > 0
          ? style.cornerRadius
          : (object.type == ObjectType.roundedRect
              ? math.min(t.width, t.height) * 0.12
              : 0.0);
  return math.min(radius, maxRadius);
}

/// Fills [page]'s own area (`0, 0 – width, height` in page units) with its
/// background. Transparent pages draw a light checkerboard when
/// [checkerboardForTransparent] is set (editor), nothing otherwise (export).
void paintPageBackground(
  ui.Canvas canvas,
  DesignPage page, {
  bool checkerboardForTransparent = true,
}) {
  final bounds = ui.Rect.fromLTWH(0, 0, page.width, page.height);
  switch (page.background) {
    case SolidBackground(:final color):
      canvas.drawRect(bounds, ui.Paint()..color = toUiColor(color));
    case TransparentBackground():
      if (checkerboardForTransparent) _paintCheckerboard(canvas, bounds);
    case ImageBackground():
      // Image assets arrive with P1.6; show a neutral fill meanwhile.
      canvas.drawRect(bounds, ui.Paint()..color = const ui.Color(0xFFE9EBF0));
  }
}

/// Draws all objects of [page] in page units, back to front. Hidden objects
/// are skipped.
void paintPageContent(
  ui.Canvas canvas,
  DesignDocument document,
  DesignPage page,
) {
  for (final id in page.objectIds) {
    final object = document.objects[id];
    if (object != null) paintObject(canvas, document, object);
  }
}

/// Draws [object] (and, for groups, its children) in its parent's space.
void paintObject(
  ui.Canvas canvas,
  DesignDocument document,
  DesignObject object, {
  int depth = 0,
}) {
  if (object.hidden || depth > _maxDepth) return;
  final t = object.transform;
  canvas
    ..save()
    ..transform(toUiMatrix(localToParent(t)));

  final needsLayer =
      object.opacity < 1 || object.blendMode != ObjectBlendMode.normal;
  if (needsLayer) {
    canvas.saveLayer(
      null,
      ui.Paint()
        ..color = ui.Color.fromRGBO(0, 0, 0, object.opacity)
        ..blendMode = toUiBlendMode(object.blendMode),
    );
  }

  if (object.type == ObjectType.group) {
    _paintChildren(canvas, document, object, depth);
  } else if (object.type == ObjectType.frame) {
    _paintFrame(canvas, document, object, depth);
  } else {
    _paintShape(canvas, object, effectiveStyle(object, document.styles));
  }

  if (needsLayer) canvas.restore();
  canvas.restore();
}

void _paintChildren(
  ui.Canvas canvas,
  DesignDocument document,
  DesignObject object,
  int depth,
) {
  for (final childId in object.childIds) {
    final child = document.objects[childId];
    if (child != null) paintObject(canvas, document, child, depth: depth + 1);
  }
}

/// Frames draw their fill, their (optionally clipped) children, then their
/// stroke on top (ADR-0007).
void _paintFrame(
  ui.Canvas canvas,
  DesignDocument document,
  DesignObject object,
  int depth,
) {
  final style = effectiveStyle(object, document.styles);
  final outline = shapePath(object, style)!;
  if (style.fill case SolidFill(:final color)) {
    canvas.drawPath(outline, ui.Paint()..color = toUiColor(color));
  }
  final clip = switch (object.payload) {
    FramePayload(:final clipContent) => clipContent,
    _ => true,
  };
  if (clip) {
    canvas
      ..save()
      ..clipPath(outline);
  }
  _paintChildren(canvas, document, object, depth);
  if (clip) canvas.restore();
  final stroke = style.stroke;
  if (stroke != null && stroke.width > 0) {
    canvas.drawPath(
      _dashed(outline, stroke),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..color = toUiColor(stroke.color),
    );
  }
}

void _paintShape(ui.Canvas canvas, DesignObject object, ObjectStyle style) {
  final t = object.transform;
  final box = ui.Rect.fromLTWH(0, 0, t.width, t.height);
  final fill = switch (style.fill) {
    SolidFill(:final color) => ui.Paint()..color = toUiColor(color),
    null => null,
  };
  final stroke = style.stroke;
  final strokePaint =
      stroke != null && stroke.width > 0
          ? (ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = stroke.width
            ..color = toUiColor(stroke.color)
            ..strokeJoin = ui.StrokeJoin.round
            ..strokeCap =
                stroke.dash == StrokeDash.dotted
                    ? ui.StrokeCap.round
                    : ui.StrokeCap.butt)
          : null;

  switch (object.type) {
    case ObjectType.text:
      _paintText(canvas, object, style);
    case ObjectType.image:
      _paintImagePlaceholder(canvas, box);
    case ObjectType.arrow:
      if (strokePaint != null) _paintArrow(canvas, t, strokePaint, stroke!);
    case ObjectType.group || ObjectType.frame:
      break;
    case ObjectType.line:
      if (strokePaint != null) {
        final line =
            ui.Path()
              ..moveTo(0, 0)
              ..lineTo(t.width, t.height);
        if (stroke!.dash == StrokeDash.solid) {
          strokePaint.strokeCap = ui.StrokeCap.round;
        }
        canvas.drawPath(_dashed(line, stroke), strokePaint);
      }
    case ObjectType.rect ||
        ObjectType.roundedRect ||
        ObjectType.ellipse ||
        ObjectType.path ||
        ObjectType.polygon ||
        ObjectType.star:
      final path = shapePath(object, style);
      if (path == null) return;
      if (fill != null) canvas.drawPath(path, fill);
      if (strokePaint != null) {
        canvas.drawPath(_dashed(path, stroke!), strokePaint);
      }
  }
}

/// Outline of a closed shape in its local box, or `null` for types that are
/// not closed shapes. Shared by drawing and (later) export.
ui.Path? shapePath(DesignObject object, ObjectStyle style) {
  final t = object.transform;
  final box = ui.Rect.fromLTWH(0, 0, t.width, t.height);
  switch (object.type) {
    case ObjectType.rect || ObjectType.roundedRect || ObjectType.frame:
      final radius = cornerRadiusOf(object, style);
      return ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(box, ui.Radius.circular(radius)));
    case ObjectType.ellipse:
      return ui.Path()..addOval(box);
    case ObjectType.path:
      return _pathOf(object.payload);
    case ObjectType.polygon:
      final sides = switch (object.payload) {
        PolygonPayload(:final sides) => sides,
        _ => 6,
      };
      return _regularPath(box, [for (var i = 0; i < sides; i++) 1.0]);
    case ObjectType.star:
      final (points, inner) = switch (object.payload) {
        StarPayload(:final points, :final innerRatio) => (points, innerRatio),
        _ => (5, 0.5),
      };
      return _regularPath(box, [
        for (var i = 0; i < points * 2; i++)
          if (i.isEven) 1.0 else inner,
      ]);
    case ObjectType.text ||
        ObjectType.image ||
        ObjectType.line ||
        ObjectType.arrow ||
        ObjectType.group:
      return null;
  }
}

/// Polygon whose vertices sit at [radii] (fractions of the box's half size)
/// around the centre, starting straight up.
ui.Path _regularPath(ui.Rect box, List<double> radii) {
  final path = ui.Path();
  final c = box.center;
  for (var i = 0; i < radii.length; i++) {
    final angle = -math.pi / 2 + 2 * math.pi * i / radii.length;
    final p = ui.Offset(
      c.dx + math.cos(angle) * box.width / 2 * radii[i],
      c.dy + math.sin(angle) * box.height / 2 * radii[i],
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// [path] split into dashes for [stroke]'s pattern; solid strokes return
/// [path] unchanged. Dash lengths scale with the stroke width.
ui.Path _dashed(ui.Path path, Stroke stroke) {
  final w = math.max(stroke.width, 0.0001);
  final (on, off) = switch (stroke.dash) {
    StrokeDash.solid => (0.0, 0.0),
    StrokeDash.dashed => (w * 4, w * 2.5),
    // Near-zero dashes with round caps draw as dots.
    StrokeDash.dotted => (w * 0.001, w * 2),
  };
  if (on == 0) return path;
  final result = ui.Path();
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      result.addPath(
        metric.extractPath(distance, math.min(distance + on, metric.length)),
        ui.Offset.zero,
      );
      distance += on + off;
    }
  }
  return result;
}

void _paintArrow(
  ui.Canvas canvas,
  ObjectTransform t,
  ui.Paint paint,
  Stroke stroke,
) {
  final end = ui.Offset(t.width, t.height);
  final length = end.distance;
  if (length == 0) return;
  final headLength = math.min(math.max<double>(stroke.width * 4, 6), length);
  final direction = end / length;
  final shaftEnd = end - direction * (headLength * 0.6);
  final shaft =
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(shaftEnd.dx, shaftEnd.dy);
  if (stroke.dash == StrokeDash.solid) paint.strokeCap = ui.StrokeCap.round;
  canvas.drawPath(_dashed(shaft, stroke), paint);
  final normal = ui.Offset(-direction.dy, direction.dx);
  final base = end - direction * headLength;
  final head =
      ui.Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          base.dx + normal.dx * headLength * 0.5,
          base.dy + normal.dy * headLength * 0.5,
        )
        ..lineTo(
          base.dx - normal.dx * headLength * 0.5,
          base.dy - normal.dy * headLength * 0.5,
        )
        ..close();
  canvas.drawPath(
    head,
    ui.Paint()
      ..color = paint.color
      ..style = ui.PaintingStyle.fill,
  );
}

ui.Path? _pathOf(ObjectPayload payload) {
  if (payload is! PathPayload) return null;
  final path = ui.Path();
  for (final segment in payload.segments) {
    switch (segment) {
      case MoveTo(:final x, :final y):
        path.moveTo(x, y);
      case LineTo(:final x, :final y):
        path.lineTo(x, y);
      case QuadTo(:final cx, :final cy, :final x, :final y):
        path.quadraticBezierTo(cx, cy, x, y);
      case CubicTo(
        :final c1x,
        :final c1y,
        :final c2x,
        :final c2y,
        :final x,
        :final y,
      ):
        path.cubicTo(c1x, c1y, c2x, c2y, x, y);
      case ClosePath():
        path.close();
    }
  }
  return path;
}

/// Font used when a text has no family or the family is not installed.
const String defaultFontFamily = 'Segoe UI';

/// Builds a laid-out paragraph for [text]. [width] constrains wrapping;
/// `null` lays out on one line per paragraph (auto width).
ui.Paragraph layoutText(TextPayload text, {double? width, ui.Color? color}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: switch (text.align) {
              TextAlignment.left => ui.TextAlign.left,
              TextAlignment.center => ui.TextAlign.center,
              TextAlignment.right => ui.TextAlign.right,
              TextAlignment.justify => ui.TextAlign.justify,
            },
            fontFamily: text.fontFamily ?? defaultFontFamily,
            fontSize: text.fontSize,
            height: text.lineHeight,
            fontWeight: ui.FontWeight.values[(text.fontWeight ~/ 100) - 1],
            fontStyle: text.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: color ?? const ui.Color(0xFF16181D),
            fontFamily: text.fontFamily ?? defaultFontFamily,
            fontSize: text.fontSize,
            height: text.lineHeight,
            letterSpacing: text.letterSpacing,
            fontWeight: ui.FontWeight.values[(text.fontWeight ~/ 100) - 1],
            fontStyle: text.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
          ),
        )
        // An empty paragraph still has the height of one line.
        ..addText(text.text.isEmpty ? ' ' : text.text);
  return builder.build()
    ..layout(ui.ParagraphConstraints(width: width ?? double.infinity));
}

/// Box size of [text] in its own units: natural size for auto width, the
/// wrapped height at [width] otherwise (P1.5.1).
Point2D measureText(TextPayload text, {double? width}) {
  if (text.sizing == TextSizing.autoWidth || width == null) {
    final paragraph = layoutText(text);
    final w = paragraph.maxIntrinsicWidth.ceilToDouble();
    final h = paragraph.height.ceilToDouble();
    paragraph.dispose();
    return Point2D(math.max(w, 1), math.max(h, 1));
  }
  final paragraph = layoutText(text, width: width);
  final h = paragraph.height.ceilToDouble();
  paragraph.dispose();
  return Point2D(width, math.max(h, 1));
}

void _paintText(ui.Canvas canvas, DesignObject object, ObjectStyle style) {
  final payload = object.payload;
  if (payload is! TextPayload) return;
  final t = object.transform;
  final color = switch (style.fill) {
    SolidFill(:final color) => toUiColor(color),
    null => const ui.Color(0x00000000),
  };
  final paragraph = layoutText(
    payload,
    // Auto-width boxes are kept at the text's natural width by the editor;
    // laying out unconstrained keeps lines unwrapped even if they lag.
    width: payload.sizing == TextSizing.autoWidth ? null : math.max(t.width, 1),
    color: color,
  );
  if (payload.sizing == TextSizing.fixed) {
    canvas
      ..save()
      ..clipRect(ui.Rect.fromLTWH(0, 0, t.width, t.height));
  }
  canvas.drawParagraph(paragraph, ui.Offset.zero);
  if (payload.sizing == TextSizing.fixed) canvas.restore();
  paragraph.dispose();
}

/// Neutral box with a cross until image decoding lands (P1.6).
void _paintImagePlaceholder(ui.Canvas canvas, ui.Rect box) {
  canvas.drawRect(box, ui.Paint()..color = const ui.Color(0xFFE3E6EC));
  final lines =
      ui.Paint()
        ..color = const ui.Color(0xFFB8BEC9)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = math.max(math.min(box.width, box.height) / 100, 0.5);
  canvas
    ..drawLine(box.topLeft, box.bottomRight, lines)
    ..drawLine(box.topRight, box.bottomLeft, lines);
}

void _paintCheckerboard(ui.Canvas canvas, ui.Rect bounds) {
  canvas.drawRect(bounds, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  final cell = math.max<double>(math.max(bounds.width, bounds.height) / 48, 1);
  final dark = ui.Paint()..color = const ui.Color(0xFFE8EAEE);
  canvas
    ..save()
    ..clipRect(bounds);
  for (var y = 0; y * cell < bounds.height; y++) {
    for (var x = y.isEven ? 0 : 1; x * cell < bounds.width; x += 2) {
      canvas.drawRect(ui.Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
    }
  }
  canvas.restore();
}
