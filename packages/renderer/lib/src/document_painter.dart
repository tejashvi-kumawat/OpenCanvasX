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
    for (final childId in object.childIds) {
      final child = document.objects[childId];
      if (child != null) {
        paintObject(canvas, document, child, depth: depth + 1);
      }
    }
  } else {
    _paintShape(canvas, object, effectiveStyle(object, document.styles));
  }

  if (needsLayer) canvas.restore();
  canvas.restore();
}

void _paintShape(ui.Canvas canvas, DesignObject object, ObjectStyle style) {
  final t = object.transform;
  final box = ui.Rect.fromLTWH(0, 0, t.width, t.height);
  final fill = switch (style.fill) {
    SolidFill(:final color) => ui.Paint()..color = toUiColor(color),
    null => null,
  };
  final stroke = switch (style.stroke) {
    final s? when s.width > 0 =>
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = s.width
        ..color = toUiColor(s.color)
        ..strokeJoin = ui.StrokeJoin.round,
    _ => null,
  };

  switch (object.type) {
    case ObjectType.rect || ObjectType.roundedRect:
      final radius = cornerRadiusOf(object, style);
      final shape = ui.RRect.fromRectAndRadius(box, ui.Radius.circular(radius));
      if (fill != null) canvas.drawRRect(shape, fill);
      if (stroke != null) canvas.drawRRect(shape, stroke);
    case ObjectType.ellipse:
      if (fill != null) canvas.drawOval(box, fill);
      if (stroke != null) canvas.drawOval(box, stroke);
    case ObjectType.line:
      if (stroke != null) {
        canvas.drawLine(
          ui.Offset.zero,
          ui.Offset(t.width, t.height),
          stroke..strokeCap = ui.StrokeCap.round,
        );
      }
    case ObjectType.arrow:
      if (stroke != null) _paintArrow(canvas, t, stroke);
    case ObjectType.path:
      final path = _pathOf(object.payload);
      if (path != null) {
        if (fill != null) canvas.drawPath(path, fill);
        if (stroke != null) canvas.drawPath(path, stroke);
      }
    case ObjectType.text:
      _paintText(canvas, object, style);
    case ObjectType.image:
      _paintImagePlaceholder(canvas, box);
    case ObjectType.group:
      break;
  }
}

void _paintArrow(ui.Canvas canvas, ObjectTransform t, ui.Paint stroke) {
  final end = ui.Offset(t.width, t.height);
  final length = end.distance;
  if (length == 0) return;
  final headLength = math.min(math.max<double>(stroke.strokeWidth * 4, 6), length);
  final direction = end / length;
  final shaftEnd = end - direction * (headLength * 0.6);
  canvas.drawLine(
    ui.Offset.zero,
    shaftEnd,
    stroke..strokeCap = ui.StrokeCap.round,
  );
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
      ..color = stroke.color
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

/// Plain-text placeholder rendering until typography lands (P1.5).
void _paintText(ui.Canvas canvas, DesignObject object, ObjectStyle style) {
  final payload = object.payload;
  if (payload is! TextPayload || payload.text.isEmpty) return;
  final t = object.transform;
  final color = switch (style.fill) {
    SolidFill(:final color) => toUiColor(color),
    null => const ui.Color(0xFF1F2430),
  };
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(fontSize: math.max(t.height * 0.7, 1)),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(payload.text);
  final paragraph =
      builder.build()
        ..layout(ui.ParagraphConstraints(width: math.max(t.width, 1)));
  canvas.drawParagraph(paragraph, ui.Offset.zero);
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
