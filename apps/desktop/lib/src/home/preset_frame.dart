import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';

/// Accent gradient per preset category.
List<Color> categoryColors(PresetCategory? category) => switch (category) {
  PresetCategory.social => const [Color(0xFFFF7AB6), Color(0xFF8B5CF6)],
  PresetCategory.presentation => const [Color(0xFFFFB547), Color(0xFFFF6A3D)],
  PresetCategory.video => const [Color(0xFFFF6B6B), Color(0xFFD9264D)],
  PresetCategory.print => const [Color(0xFF34D3BE), Color(0xFF0EA5E9)],
  null => const [Color(0xFFA3AAB8), Color(0xFF6B7280)],
};

IconData categoryIcon(PresetCategory? category) => switch (category) {
  PresetCategory.social => Icons.favorite_rounded,
  PresetCategory.presentation => Icons.slideshow_rounded,
  PresetCategory.video => Icons.play_arrow_rounded,
  PresetCategory.print => Icons.description_rounded,
  null => Icons.crop_free_rounded,
};

/// A miniature page drawn at the preset's aspect ratio inside a square.
class PresetFrame extends StatelessWidget {
  const PresetFrame({
    required this.width,
    required this.height,
    required this.category,
    this.box = 64,
    super.key,
  });

  final double width;
  final double height;
  final PresetCategory? category;
  final double box;

  @override
  Widget build(BuildContext context) {
    final ratio = width / height;
    final w = ratio >= 1 ? box : box * math.max(ratio, 0.3);
    final h = ratio >= 1 ? box / math.min(ratio, 3.3) : box;
    final colors = categoryColors(category);
    return SizedBox.square(
      dimension: box,
      child: Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(box * 0.09),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            categoryIcon(category),
            color: Colors.white.withValues(alpha: 0.95),
            size: math.min(w, h) * 0.42,
          ),
        ),
      ),
    );
  }
}
