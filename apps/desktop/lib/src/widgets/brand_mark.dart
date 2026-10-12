import 'package:flutter/material.dart';

import '../theme/ocx_theme.dart';

/// The OpenCanvasX mark: a solid accent tile with a canvas corner and an X.
/// No gradient (design-system.md §2).
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.ocx.accent,
      borderRadius: BorderRadius.circular(size * 0.25),
    ),
    child: CustomPaint(painter: _MarkPainter(context.ocx.onAccent)),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.11;
    canvas
      // Canvas corner.
      ..drawLine(Offset(s * 0.25, s * 0.47), Offset(s * 0.25, s * 0.25), stroke)
      ..drawLine(Offset(s * 0.25, s * 0.25), Offset(s * 0.47, s * 0.25), stroke)
      // The X.
      ..drawLine(Offset(s * 0.45, s * 0.45), Offset(s * 0.75, s * 0.75), stroke)
      ..drawLine(
        Offset(s * 0.75, s * 0.45),
        Offset(s * 0.45, s * 0.75),
        stroke,
      );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// Mark plus the product name.
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: size),
      const SizedBox(width: Space.sm),
      Flexible(
        child: Text(
          'OpenCanvasX',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OcxText.title(context),
        ),
      ),
    ],
  );
}
