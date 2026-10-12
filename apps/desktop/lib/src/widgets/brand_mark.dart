import 'package:flutter/material.dart';

import '../theme/ocx_theme.dart';

/// The OpenCanvasX mark: a gradient tile with a canvas corner and an X.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 36, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: Brand.heroGradient,
      borderRadius: BorderRadius.circular(size * 0.28),
      boxShadow: [
        BoxShadow(
          color: Brand.violet.withValues(alpha: 0.35),
          blurRadius: size * 0.3,
          offset: Offset(0, size * 0.08),
        ),
      ],
    ),
    child: CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final white =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.11;
    // Canvas corner (top-left frame).
    canvas
      ..drawLine(Offset(s * 0.24, s * 0.46), Offset(s * 0.24, s * 0.24), white)
      ..drawLine(Offset(s * 0.24, s * 0.24), Offset(s * 0.46, s * 0.24), white);
    // The X.
    final x =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.12;
    canvas
      ..drawLine(Offset(s * 0.44, s * 0.44), Offset(s * 0.76, s * 0.76), x)
      ..drawLine(Offset(s * 0.76, s * 0.44), Offset(s * 0.44, s * 0.76), x);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// Mark plus the product name.
class BrandLockup extends StatelessWidget {
  const BrandLockup({this.color, super.key});

  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BrandMark(size: 34),
      const SizedBox(width: Space.md),
      Flexible(
        child: Text(
          'OpenCanvasX',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: color, letterSpacing: -0.3),
        ),
      ),
    ],
  );
}
