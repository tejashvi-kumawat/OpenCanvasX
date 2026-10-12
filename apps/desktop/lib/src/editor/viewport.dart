import 'dart:math' as math;

import 'package:document_model/document_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vertical gap between stacked pages, in workspace pixels.
const double pageGap = 72;

/// Zoom limits (P1.2.1).
const double minZoom = 0.05;
const double maxZoom = 8;

/// Where one page sits in the workspace.
///
/// The workspace is a plane in "reference pixels" (96 per inch) where pages
/// are stacked top to bottom and centred on x = 0. Physical units therefore
/// show at their real size at 100 % zoom.
@immutable
class PageFrame {
  const PageFrame({
    required this.pageId,
    required this.index,
    required this.rect,
    required this.unitScale,
  });

  final PageId pageId;
  final int index;

  /// Page bounds in workspace pixels.
  final Rect rect;

  /// Workspace pixels per page unit.
  final double unitScale;

  Offset toWorkspace(Point2D p) =>
      rect.topLeft + Offset(p.x * unitScale, p.y * unitScale);

  Point2D toPage(Offset workspace) {
    final local = (workspace - rect.topLeft) / unitScale;
    return Point2D(local.dx, local.dy);
  }
}

/// Workspace pixels per unit of [page] at 100 % zoom.
double referencePixelsPerUnit(DesignPage page) =>
    convertLength(1, from: page.unit, to: LengthUnit.px);

/// Stacks [pages] vertically, centred on x = 0.
List<PageFrame> layoutPages(List<DesignPage> pages) {
  final frames = <PageFrame>[];
  var y = 0.0;
  for (final (index, page) in pages.indexed) {
    final scale = referencePixelsPerUnit(page);
    final width = page.width * scale;
    final height = page.height * scale;
    frames.add(
      PageFrame(
        pageId: page.id,
        index: index,
        rect: Rect.fromLTWH(-width / 2, y, width, height),
        unitScale: scale,
      ),
    );
    y += height + pageGap;
  }
  return frames;
}

/// Pan and zoom: `screen = workspace * zoom + pan`.
@immutable
class ViewportState {
  const ViewportState({
    this.zoom = 1,
    this.pan = Offset.zero,
    this.size = Size.zero,
    this.fitted = false,
  });

  final double zoom;
  final Offset pan;

  /// Size of the canvas area on screen.
  final Size size;

  /// Whether the view has been fitted once for the open design.
  final bool fitted;

  Offset toScreen(Offset workspace) => workspace * zoom + pan;
  Offset toWorkspace(Offset screen) => (screen - pan) / zoom;
  Rect rectToScreen(Rect workspace) => Rect.fromPoints(
    toScreen(workspace.topLeft),
    toScreen(workspace.bottomRight),
  );

  ViewportState copyWith({
    double? zoom,
    Offset? pan,
    Size? size,
    bool? fitted,
  }) => ViewportState(
    zoom: zoom ?? this.zoom,
    pan: pan ?? this.pan,
    size: size ?? this.size,
    fitted: fitted ?? this.fitted,
  );
}

final viewportProvider = NotifierProvider<ViewportController, ViewportState>(
  ViewportController.new,
);

class ViewportController extends Notifier<ViewportState> {
  @override
  ViewportState build() => const ViewportState();

  /// Forget the view so the next design is fitted again.
  void reset() => state = ViewportState(size: state.size);

  void setSize(Size size) {
    if (size == state.size) return;
    // Keep the centre of the view stable while the window resizes.
    final shift = Offset(
      (size.width - state.size.width) / 2,
      (size.height - state.size.height) / 2,
    );
    state = state.copyWith(
      size: size,
      pan: state.size == Size.zero ? state.pan : state.pan + shift,
    );
  }

  void panBy(Offset delta) => state = state.copyWith(pan: state.pan + delta);

  /// Zooms by [factor] keeping the workspace point under [focal] still.
  void zoomAt(Offset focal, double factor) {
    final zoom = (state.zoom * factor).clamp(minZoom, maxZoom);
    final anchor = state.toWorkspace(focal);
    state = state.copyWith(zoom: zoom, pan: focal - anchor * zoom);
  }

  /// Sets an absolute zoom around the centre of the view.
  void setZoom(double zoom) {
    final center = state.size.center(Offset.zero);
    zoomAt(center, zoom / state.zoom);
  }

  void zoomIn() => setZoom(_nextStep(up: true));
  void zoomOut() => setZoom(_nextStep(up: false));

  static const _steps = [
    0.1,
    0.25,
    0.33,
    0.5,
    0.67,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
    4.0,
    6.0,
    8.0, //
  ];

  double _nextStep({required bool up}) {
    final z = state.zoom;
    if (up) {
      return _steps.firstWhere((s) => s > z + 1e-6, orElse: () => maxZoom);
    }
    return _steps.lastWhere((s) => s < z - 1e-6, orElse: () => minZoom);
  }

  /// Fits [workspaceRect] in the view with [padding] around it.
  void fit(Rect workspaceRect, {double padding = 56}) {
    final size = state.size;
    if (size.isEmpty || workspaceRect.isEmpty) return;
    final zoom = math
        .min(
          (size.width - padding * 2) / workspaceRect.width,
          (size.height - padding * 2) / workspaceRect.height,
        )
        .clamp(minZoom, maxZoom);
    final pan = size.center(Offset.zero) - workspaceRect.center * zoom;
    state = state.copyWith(zoom: zoom, pan: pan, fitted: true);
  }

  /// Scrolls (without zooming) so [workspaceRect] is centred vertically.
  void reveal(Rect workspaceRect) {
    final target = state.size.center(Offset.zero);
    final current = state.toScreen(workspaceRect.center);
    state = state.copyWith(pan: state.pan + (target - current));
  }
}
