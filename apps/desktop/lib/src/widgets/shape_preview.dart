import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';

/// Small drawing of a shape type for tiles and layer rows.
class ShapePreview extends StatelessWidget {
  const ShapePreview({
    required this.type,
    required this.color,
    this.size = 40,
    super.key,
  });

  final ObjectType type;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ShapePainter(type, color)),
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.type, this.color);

  final ObjectType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final box = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: s * 0.82,
      height: s * 0.82,
    );
    final fill = Paint()..color = color;
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(s / 16, 1.5)
          ..strokeCap = StrokeCap.round;
    switch (type) {
      case ObjectType.rect:
        canvas.drawRect(box, fill);
      case ObjectType.roundedRect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, Radius.circular(s * 0.16)),
          fill,
        );
      case ObjectType.ellipse:
        canvas.drawOval(box, fill);
      case ObjectType.line:
        canvas.drawLine(box.bottomLeft, box.topRight, stroke);
      case ObjectType.arrow:
        final start = box.bottomLeft;
        final end = box.topRight;
        canvas.drawLine(start, end - const Offset(2, -2), stroke);
        final head = s * 0.26;
        canvas.drawPath(
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(end.dx - head, end.dy + head * 0.15)
            ..lineTo(end.dx - head * 0.15, end.dy + head)
            ..close(),
          fill,
        );
      case ObjectType.text:
        final painter = TextPainter(
          text: TextSpan(
            text: 'T',
            style: TextStyle(
              color: color,
              fontSize: s * 0.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          size.center(Offset.zero) -
              Offset(painter.width / 2, painter.height / 2),
        );
      case ObjectType.image:
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, Radius.circular(s * 0.1)),
          stroke,
        );
        canvas.drawCircle(
          box.topLeft + Offset(box.width * 0.32, box.height * 0.32),
          s * 0.08,
          fill,
        );
      case ObjectType.path:
        canvas.drawPath(
          Path()
            ..moveTo(box.left, box.bottom)
            ..quadraticBezierTo(
              box.center.dx,
              box.top - s * 0.2,
              box.right,
              box.bottom,
            )
            ..close(),
          fill,
        );
      case ObjectType.polygon:
        canvas.drawPath(_regular(box, List.filled(6, 1)), fill);
      case ObjectType.star:
        canvas.drawPath(
          _regular(box, [
            for (var i = 0; i < 10; i++)
              if (i.isEven) 1.0 else 0.45,
          ]),
          fill,
        );
      case ObjectType.group:
        canvas
          ..drawRect(
            box.deflate(s * 0.08).shift(Offset(-s * 0.08, -s * 0.08)),
            stroke,
          )
          ..drawRect(
            box.deflate(s * 0.08).shift(Offset(s * 0.08, s * 0.08)),
            stroke,
          );
    }
  }

  static Path _regular(Rect box, List<double> radii) {
    final path = Path();
    for (var i = 0; i < radii.length; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / radii.length;
      final p = Offset(
        box.center.dx + math.cos(angle) * box.width / 2 * radii[i],
        box.center.dy + math.sin(angle) * box.height / 2 * radii[i],
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.type != type || old.color != color;
}
