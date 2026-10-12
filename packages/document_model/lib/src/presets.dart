import 'package:meta/meta.dart';

import 'ids.dart';
import 'page.dart';
import 'units.dart';

/// Groups presets in the "Create a design" picker.
enum PresetCategory {
  social('Social media'),
  presentation('Presentations'),
  video('Video'),
  print('Print');

  const PresetCategory(this.label);

  final String label;
}

/// A named page size (P1.2.3). Dimensions are publicly documented platform
/// or ISO sizes, not third-party templates.
@immutable
final class PagePreset {
  const PagePreset({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    required this.unit,
  });

  final String id;
  final String name;
  final PresetCategory category;
  final double width;
  final double height;
  final LengthUnit unit;

  /// e.g. `1080 × 1080 px`, `210 × 297 mm`.
  String get sizeLabel =>
      '${_format(width)} × ${_format(height)} ${unit.symbol}';

  /// A blank page of this size. Print sizes default to 300 DPI.
  DesignPage createPage(PageId id) => DesignPage(
    id: id,
    width: width,
    height: height,
    unit: unit,
    dpi: unit == LengthUnit.px ? defaultDpi : 300,
  );

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Built-in sizes offered when creating a design.
const List<PagePreset> pagePresets = [
  PagePreset(
    id: 'instagram_post',
    name: 'Instagram post',
    category: PresetCategory.social,
    width: 1080,
    height: 1080,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'instagram_story',
    name: 'Story',
    category: PresetCategory.social,
    width: 1080,
    height: 1920,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'facebook_post',
    name: 'Facebook post',
    category: PresetCategory.social,
    width: 1200,
    height: 630,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'linkedin_post',
    name: 'LinkedIn post',
    category: PresetCategory.social,
    width: 1200,
    height: 627,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'x_post',
    name: 'X post',
    category: PresetCategory.social,
    width: 1600,
    height: 900,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'presentation_16_9',
    name: 'Presentation 16:9',
    category: PresetCategory.presentation,
    width: 1920,
    height: 1080,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'presentation_4_3',
    name: 'Presentation 4:3',
    category: PresetCategory.presentation,
    width: 1024,
    height: 768,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'youtube_thumbnail',
    name: 'YouTube thumbnail',
    category: PresetCategory.video,
    width: 1280,
    height: 720,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'video_1080p',
    name: 'Video 1080p',
    category: PresetCategory.video,
    width: 1920,
    height: 1080,
    unit: LengthUnit.px,
  ),
  PagePreset(
    id: 'a4',
    name: 'A4 document',
    category: PresetCategory.print,
    width: 210,
    height: 297,
    unit: LengthUnit.mm,
  ),
  PagePreset(
    id: 'us_letter',
    name: 'US Letter',
    category: PresetCategory.print,
    width: 8.5,
    height: 11,
    unit: LengthUnit.inch,
  ),
  PagePreset(
    id: 'a3_poster',
    name: 'Poster (A3)',
    category: PresetCategory.print,
    width: 297,
    height: 420,
    unit: LengthUnit.mm,
  ),
  PagePreset(
    id: 'a5_flyer',
    name: 'Flyer (A5)',
    category: PresetCategory.print,
    width: 148,
    height: 210,
    unit: LengthUnit.mm,
  ),
  PagePreset(
    id: 'business_card',
    name: 'Business card',
    category: PresetCategory.print,
    width: 85,
    height: 55,
    unit: LengthUnit.mm,
  ),
];

/// Finds a preset by [id]; `null` if unknown.
PagePreset? presetById(String id) {
  for (final preset in pagePresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
