import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';

import '../theme/ocx_theme.dart';

IconData categoryIcon(PresetCategory? category) => switch (category) {
  PresetCategory.board => Icons.dashboard_outlined,
  PresetCategory.device => Icons.devices_outlined,
  PresetCategory.social => Icons.tag,
  PresetCategory.presentation => Icons.slideshow_outlined,
  PresetCategory.video => Icons.smart_display_outlined,
  PresetCategory.print => Icons.print_outlined,
  null => Icons.crop_free,
};

/// A neutral miniature page at the preset's aspect ratio
/// (design-system.md §2: colour is reserved for meaning).
class PresetFrame extends StatelessWidget {
  const PresetFrame({
    required this.width,
    required this.height,
    required this.category,
    this.box = 56,
    this.selected = false,
    super.key,
  });

  final double width;
  final double height;
  final PresetCategory? category;
  final double box;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.ocx;
    final ratio = width / height;
    final w = ratio >= 1 ? box : box * math.max(ratio, 0.3);
    final h = ratio >= 1 ? box / math.min(ratio, 3.3) : box;
    return SizedBox.square(
      dimension: box,
      child: Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selected ? c.accent : c.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Icon(
            categoryIcon(category),
            size: math.min(14, math.min(w, h) * 0.5),
            color: selected ? c.accent : c.textTertiary,
          ),
        ),
      ),
    );
  }
}
