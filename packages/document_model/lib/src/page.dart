import 'dart:math';

import 'package:meta/meta.dart';

import 'color.dart';
import 'ids.dart';
import 'units.dart';
import 'validation.dart';

/// One fixed-size page (slide, artboard) of a document.
///
/// All lengths are in [unit]. [objectIds] lists the page's root objects
/// back-to-front (index 0 drawn first); nested objects hang off groups
/// (ADR-0003).
@immutable
final class DesignPage {
  factory DesignPage({
    required PageId id,
    required double width,
    required double height,
    String name = '',
    LengthUnit unit = LengthUnit.px,
    double dpi = defaultDpi,
    PageBackground background = const SolidBackground(ArgbColor.white),
    PageInsets bleed = PageInsets.zero,
    PageInsets margins = PageInsets.zero,
    Iterable<Guide> guides = const [],
    Iterable<ObjectId> objectIds = const [],
  }) {
    checkPositive(width, 'width');
    checkPositive(height, 'height');
    checkPositive(dpi, 'dpi');
    if (margins.left + margins.right > width ||
        margins.top + margins.bottom > height) {
      throw ArgumentError.value(margins, 'margins', 'exceed the page size');
    }
    final roots = List<ObjectId>.unmodifiable(objectIds);
    if (roots.toSet().length != roots.length) {
      throw ArgumentError.value(roots, 'objectIds', 'contains duplicates');
    }
    return DesignPage._(
      id: id,
      name: name,
      width: width,
      height: height,
      unit: unit,
      dpi: dpi,
      background: background,
      bleed: bleed,
      margins: margins,
      guides: List.unmodifiable(guides),
      objectIds: roots,
    );
  }

  const DesignPage._({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.unit,
    required this.dpi,
    required this.background,
    required this.bleed,
    required this.margins,
    required this.guides,
    required this.objectIds,
  });

  final PageId id;

  /// User label, e.g. "Slide 3". Empty means the UI shows its position.
  final String name;

  final double width;
  final double height;
  final LengthUnit unit;

  /// Pixels per inch used when converting to and from physical units.
  final double dpi;

  final PageBackground background;

  /// Extra area outside the trim edge for print.
  final PageInsets bleed;

  /// Safe content area inside the trim edge.
  final PageInsets margins;

  final List<Guide> guides;

  /// Root objects on this page, back-to-front.
  final List<ObjectId> objectIds;

  /// Page size expressed in [target] units, using this page's [dpi].
  ({double width, double height}) sizeIn(LengthUnit target) => (
    width: convertLength(width, from: unit, to: target, dpi: dpi),
    height: convertLength(height, from: unit, to: target, dpi: dpi),
  );

  /// Raster size in whole pixels when rendered at [exportDpi]
  /// (e.g. PNG export at 300 DPI). Never smaller than 1×1.
  ({int width, int height}) pixelSizeAt(double exportDpi) {
    checkPositive(exportDpi, 'exportDpi');
    final inches = sizeIn(LengthUnit.inch);
    return (
      width: max(1, (inches.width * exportDpi).round()),
      height: max(1, (inches.height * exportDpi).round()),
    );
  }

  DesignPage copyWith({
    String? name,
    double? width,
    double? height,
    LengthUnit? unit,
    double? dpi,
    PageBackground? background,
    PageInsets? bleed,
    PageInsets? margins,
    Iterable<Guide>? guides,
    Iterable<ObjectId>? objectIds,
  }) {
    return DesignPage(
      id: id,
      name: name ?? this.name,
      width: width ?? this.width,
      height: height ?? this.height,
      unit: unit ?? this.unit,
      dpi: dpi ?? this.dpi,
      background: background ?? this.background,
      bleed: bleed ?? this.bleed,
      margins: margins ?? this.margins,
      guides: guides ?? this.guides,
      objectIds: objectIds ?? this.objectIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DesignPage &&
      other.id == id &&
      other.name == name &&
      other.width == width &&
      other.height == height &&
      other.unit == unit &&
      other.dpi == dpi &&
      other.background == background &&
      other.bleed == bleed &&
      other.margins == margins &&
      listEquals(other.guides, guides) &&
      listEquals(other.objectIds, objectIds);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    width,
    height,
    unit,
    dpi,
    background,
    bleed,
    margins,
    Object.hashAll(guides),
    Object.hashAll(objectIds),
  );

  @override
  String toString() =>
      'DesignPage(${id.value}, ${width}x$height ${unit.symbol})';
}

/// Distances from each page edge, in the page's unit.
@immutable
final class PageInsets {
  factory PageInsets({
    double top = 0,
    double right = 0,
    double bottom = 0,
    double left = 0,
  }) {
    checkNonNegative(top, 'top');
    checkNonNegative(right, 'right');
    checkNonNegative(bottom, 'bottom');
    checkNonNegative(left, 'left');
    return PageInsets._(top, right, bottom, left);
  }

  factory PageInsets.all(double value) =>
      PageInsets(top: value, right: value, bottom: value, left: value);

  const PageInsets._(this.top, this.right, this.bottom, this.left);

  static const zero = PageInsets._(0, 0, 0, 0);

  final double top;
  final double right;
  final double bottom;
  final double left;

  @override
  bool operator ==(Object other) =>
      other is PageInsets &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() => 'PageInsets($top, $right, $bottom, $left)';
}

enum GuideAxis {
  /// A vertical line at a fixed x position.
  vertical,

  /// A horizontal line at a fixed y position.
  horizontal,
}

/// A user-placed ruler guide. [position] may lie outside the page.
@immutable
final class Guide {
  factory Guide(GuideAxis axis, double position) {
    checkFinite(position, 'position');
    return Guide._(axis, position);
  }

  const Guide._(this.axis, this.position);

  final GuideAxis axis;
  final double position;

  @override
  bool operator ==(Object other) =>
      other is Guide && other.axis == axis && other.position == position;

  @override
  int get hashCode => Object.hash(axis, position);

  @override
  String toString() => 'Guide(${axis.name}, $position)';
}

/// What is drawn behind a page's objects.
///
/// Gradient backgrounds arrive with the gradient editor (P1.7.3).
@immutable
sealed class PageBackground {
  const PageBackground();
}

final class TransparentBackground extends PageBackground {
  const TransparentBackground();

  @override
  bool operator ==(Object other) => other is TransparentBackground;

  @override
  int get hashCode => (TransparentBackground).hashCode;

  @override
  String toString() => 'TransparentBackground()';
}

final class SolidBackground extends PageBackground {
  const SolidBackground(this.color);

  final ArgbColor color;

  @override
  bool operator ==(Object other) =>
      other is SolidBackground && other.color == color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() => 'SolidBackground($color)';
}

/// Background image stored under `assets/sha256/<assetHash>`.
final class ImageBackground extends PageBackground {
  factory ImageBackground(String assetHash) {
    checkSha256Hex(assetHash, 'assetHash');
    return ImageBackground._(assetHash);
  }

  const ImageBackground._(this.assetHash);

  final String assetHash;

  @override
  bool operator ==(Object other) =>
      other is ImageBackground && other.assetHash == assetHash;

  @override
  int get hashCode => assetHash.hashCode;

  @override
  String toString() => 'ImageBackground($assetHash)';
}
