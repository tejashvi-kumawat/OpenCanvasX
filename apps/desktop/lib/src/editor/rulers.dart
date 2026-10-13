import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'viewport.dart';

/// Thickness of the rulers along the top and left of the canvas.
const double rulerSize = 20;

/// What the canvas shows besides the design (P1.2.4): rulers, ruler
/// guides and the grid. Remembered between sessions.
typedef CanvasAids = ({bool rulers, bool guides, bool grid});

final canvasAidsProvider = NotifierProvider<CanvasAidsController, CanvasAids>(
  CanvasAidsController.new,
);

class CanvasAidsController extends Notifier<CanvasAids> {
  static const _key = 'canvas.aids';

  @override
  CanvasAids build() {
    final raw = ref.watch(appIndexProvider).settings.get(_key);
    if (raw == null) return (rulers: false, guides: true, grid: false);
    final on = raw.split(',').toSet();
    return (
      rulers: on.contains('rulers'),
      guides: on.contains('guides'),
      grid: on.contains('grid'),
    );
  }

  void _save(CanvasAids aids) {
    state = aids;
    ref
        .read(appIndexProvider)
        .settings
        .set(
          _key,
          [
            if (aids.rulers) 'rulers',
            if (aids.guides) 'guides',
            if (aids.grid) 'grid',
          ].join(','),
        );
  }

  void toggleRulers() =>
      _save((rulers: !state.rulers, guides: state.guides, grid: state.grid));

  void toggleGuides() =>
      _save((rulers: state.rulers, guides: !state.guides, grid: state.grid));

  void toggleGrid() =>
      _save((rulers: state.rulers, guides: state.guides, grid: !state.grid));
}

/// Grid spacing for [page] in its own unit.
double gridStep(DesignPage page) => switch (page.unit) {
  LengthUnit.px => 8,
  LengthUnit.pt => 6,
  LengthUnit.mm => 5,
  LengthUnit.cm => 0.5,
  LengthUnit.inch => 0.25,
};

/// A guide being dragged out of a ruler or along the canvas. `index` is
/// the guide being moved, or `null` for a new one.
typedef GuideDrag =
    ({PageId pageId, GuideAxis axis, double position, int? index, bool remove});

final guideDragProvider = NotifierProvider<GuideDragController, GuideDrag?>(
  GuideDragController.new,
);

class GuideDragController extends Notifier<GuideDrag?> {
  @override
  GuideDrag? build() => null;

  GuideDrag? get value => state;
  set value(GuideDrag? drag) => state = drag;

  /// Commits the drag: adds, moves or (when dropped back on a ruler)
  /// removes the guide.
  void finish() {
    final drag = state;
    state = null;
    if (drag == null) return;
    final editor = ref.read(editorProvider.notifier);
    final session = ref.read(editorProvider);
    if (session == null) return;
    final page = session.document.pages.firstWhere(
      (p) => p.id == drag.pageId,
      orElse: () => session.activePage,
    );
    final guides = [...page.guides];
    if (drag.index case final i? when i < guides.length) guides.removeAt(i);
    if (!drag.remove) guides.add(Guide(drag.axis, drag.position));
    editor.setGuides(
      page.id,
      guides,
      label:
          drag.remove
              ? 'Remove guide'
              : (drag.index == null ? 'Add guide' : 'Move guide'),
    );
  }
}

/// A "nice" ruler step (1, 2, 5 × 10ⁿ page units) so labels are at least
/// [minPixels] apart at [pixelsPerUnit].
double rulerStep(double pixelsPerUnit, {double minPixels = 60}) {
  final raw = minPixels / pixelsPerUnit;
  final magnitude =
      math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1, 2, 5, 10]) {
    if (m * magnitude >= raw) return m * magnitude;
  }
  return 10 * magnitude;
}

String _label(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

/// Rulers along the top and left of the canvas, in the active page's
/// units, with the selection's extent highlighted. Dragging from a ruler
/// places a guide (P1.2.4). Fills the canvas area; only the strips take
/// pointer events.
class CanvasRulers extends ConsumerStatefulWidget {
  const CanvasRulers({super.key});

  @override
  ConsumerState<CanvasRulers> createState() => _CanvasRulersState();
}

class _CanvasRulersState extends ConsumerState<CanvasRulers> {
  PageFrame? _activeFrame(EditorSession session) {
    final frames = layoutPages(
      session.document.pages,
      active: session.state.activePageId,
    );
    for (final f in frames) {
      if (f.pageId == session.state.activePageId) return f;
    }
    return frames.firstOrNull;
  }

  void _start(GuideAxis axis, Offset local) {
    final session = ref.read(editorProvider);
    if (session == null) return;
    _update(axis, local, session.state.activePageId);
  }

  void _update(GuideAxis axis, Offset local, PageId pageId) {
    final session = ref.read(editorProvider);
    if (session == null) return;
    final frame = _activeFrame(session);
    if (frame == null) return;
    final page = frame.toPage(ref.read(viewportProvider).toWorkspace(local));
    final remove =
        axis == GuideAxis.vertical
            ? local.dx < rulerSize
            : local.dy < rulerSize;
    ref.read(guideDragProvider.notifier).value = (
      pageId: pageId,
      axis: axis,
      position: _rounded(axis == GuideAxis.vertical ? page.x : page.y),
      index: null,
      remove: remove,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    final viewport = ref.watch(viewportProvider);
    if (session == null) return const SizedBox.shrink();
    final frame = _activeFrame(session);
    if (frame == null) return const SizedBox.shrink();
    final c = context.ocx;
    final bounds = selectionBounds(session.document, session.selection);
    final painter = _RulerPainter(
      frame: frame,
      viewport: viewport,
      selection: bounds,
      colors: c,
      textStyle: OcxText.caption(context).copyWith(
        fontSize: 9,
        color: c.textTertiary,
        fontWeight: FontWeight.w500,
      ),
    );

    Widget strip(GuideAxis axis) => Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _start(axis, _toCanvas(context, e.position)),
      onPointerMove:
          (e) => _update(
            axis,
            _toCanvas(context, e.position),
            session.state.activePageId,
          ),
      onPointerUp: (_) => ref.read(guideDragProvider.notifier).finish(),
      onPointerCancel: (_) => ref.read(guideDragProvider.notifier).value = null,
      child: MouseRegion(
        cursor:
            axis == GuideAxis.horizontal
                ? SystemMouseCursors.resizeRow
                : SystemMouseCursors.resizeColumn,
        child: Tooltip(
          message: 'Drag to add a guide',
          waitDuration: const Duration(seconds: 1),
          child: CustomPaint(
            painter: painter.forAxis(
              axis == GuideAxis.horizontal ? Axis.horizontal : Axis.vertical,
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned(
          left: rulerSize,
          right: 0,
          top: 0,
          height: rulerSize,
          child: strip(GuideAxis.horizontal),
        ),
        Positioned(
          left: 0,
          top: rulerSize,
          bottom: 0,
          width: rulerSize,
          child: strip(GuideAxis.vertical),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: rulerSize,
          height: rulerSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                right: BorderSide(color: c.border),
                bottom: BorderSide(color: c.border),
              ),
            ),
            child: Center(
              child: Text(
                session.activePage.unit.symbol,
                style: OcxText.caption(
                  context,
                ).copyWith(fontSize: 8, color: c.textTertiary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Offset _toCanvas(BuildContext context, Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);
}

double _rounded(double v) => (v * 100).round() / 100;

class _RulerPainter {
  _RulerPainter({
    required this.frame,
    required this.viewport,
    required this.selection,
    required this.colors,
    required this.textStyle,
  });

  final PageFrame frame;
  final ViewportState viewport;
  final Rect2D? selection;
  final OcxColors colors;
  final TextStyle textStyle;

  CustomPainter forAxis(Axis axis) => _AxisPainter(this, axis);
}

class _AxisPainter extends CustomPainter {
  _AxisPainter(this.p, this.axis);

  final _RulerPainter p;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final c = p.colors;
    final horizontal = axis == Axis.horizontal;
    canvas.drawRect(Offset.zero & size, Paint()..color = c.surface);
    final pixelsPerUnit = p.viewport.zoom * p.frame.unitScale;
    // Screen position of page coordinate 0 along this axis, relative to
    // the strip (which starts [rulerSize] in from the canvas edge).
    final origin = p.viewport.toScreen(p.frame.toWorkspace(Point2D.zero));
    final zero = (horizontal ? origin.dx : origin.dy) - rulerSize;
    final length = horizontal ? size.width : size.height;

    if (p.selection case final s?) {
      final a = zero + (horizontal ? s.left : s.top) * pixelsPerUnit;
      final b = zero + (horizontal ? s.right : s.bottom) * pixelsPerUnit;
      final band = Paint()..color = c.accentSubtle;
      canvas.drawRect(
        horizontal
            ? Rect.fromLTRB(a, 0, b, size.height)
            : Rect.fromLTRB(0, a, size.width, b),
        band,
      );
    }

    final step = rulerStep(pixelsPerUnit);
    final minor = step / 5;
    final tick =
        Paint()
          ..color = c.textTertiary.withValues(alpha: 0.6)
          ..strokeWidth = 1;
    final first = ((0 - zero) / pixelsPerUnit / minor).floor();
    final last = ((length - zero) / pixelsPerUnit / minor).ceil();
    for (var i = first; i <= last; i++) {
      final value = i * minor;
      final pos = (zero + value * pixelsPerUnit).roundToDouble() + 0.5;
      final major = i % 5 == 0;
      final t = major ? size.shortestSide * 0.6 : size.shortestSide * 0.25;
      if (horizontal) {
        canvas.drawLine(
          Offset(pos, size.height - t),
          Offset(pos, size.height),
          tick,
        );
      } else {
        canvas.drawLine(
          Offset(size.width - t, pos),
          Offset(size.width, pos),
          tick,
        );
      }
      if (major) {
        final text = TextPainter(
          text: TextSpan(text: _label(value), style: p.textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        if (horizontal) {
          text.paint(canvas, Offset(pos + 3, 1));
        } else {
          canvas
            ..save()
            ..translate(1, pos - 3)
            ..rotate(-math.pi / 2);
          text.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }
    final edge = Paint()..color = c.border;
    if (horizontal) {
      canvas.drawLine(
        Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5),
        edge,
      );
    } else {
      canvas.drawLine(
        Offset(size.width - 0.5, 0),
        Offset(size.width - 0.5, size.height),
        edge,
      );
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.p.viewport != p.viewport ||
      old.p.frame.rect != p.frame.rect ||
      old.p.selection != p.selection ||
      old.p.colors != p.colors;
}

/// Grid and ruler guides over the canvas (no pointer events).
class CanvasAidsPainter extends CustomPainter {
  CanvasAidsPainter({
    required this.document,
    required this.frames,
    required this.viewport,
    required this.activePageId,
    required this.aids,
    required this.drag,
    required this.colors,
    required this.labelStyle,
  });

  final DesignDocument document;
  final List<PageFrame> frames;
  final ViewportState viewport;
  final PageId activePageId;
  final CanvasAids aids;
  final GuideDrag? drag;
  final OcxColors colors;
  final TextStyle labelStyle;

  static const guideColor = Color(0xFFE5484D);

  @override
  void paint(Canvas canvas, Size size) {
    if (aids.grid) {
      final line =
          Paint()
            ..color = colors.accent.withValues(alpha: 0.12)
            ..strokeWidth = 1;
      for (final frame in frames) {
        if (frame.unbounded) continue;
        final page = document.pages[frame.index];
        final step = gridStep(page);
        final px = step * frame.unitScale * viewport.zoom;
        if (px < 6) continue;
        final rect = viewport.rectToScreen(frame.rect);
        final visible = rect.intersect(Offset.zero & size);
        if (visible.isEmpty) continue;
        canvas
          ..save()
          ..clipRect(visible);
        final startX =
            rect.left + ((visible.left - rect.left) / px).floor() * px;
        for (var x = startX; x <= visible.right; x += px) {
          final xx = x.roundToDouble() + 0.5;
          canvas.drawLine(
            Offset(xx, visible.top),
            Offset(xx, visible.bottom),
            line,
          );
        }
        final startY = rect.top + ((visible.top - rect.top) / px).floor() * px;
        for (var y = startY; y <= visible.bottom; y += px) {
          final yy = y.roundToDouble() + 0.5;
          canvas.drawLine(
            Offset(visible.left, yy),
            Offset(visible.right, yy),
            line,
          );
        }
        canvas.restore();
      }
    }

    PageFrame? frameOf(PageId id) {
      for (final f in frames) {
        if (f.pageId == id) return f;
      }
      return null;
    }

    final paint =
        Paint()
          ..color = guideColor
          ..strokeWidth = 1;
    void drawGuide(PageFrame frame, GuideAxis axis, double position) {
      final p = viewport.toScreen(
        frame.toWorkspace(
          axis == GuideAxis.vertical
              ? Point2D(position, 0)
              : Point2D(0, position),
        ),
      );
      if (axis == GuideAxis.vertical) {
        final x = p.dx.roundToDouble() + 0.5;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      } else {
        final y = p.dy.roundToDouble() + 0.5;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (aids.guides) {
      if (frameOf(activePageId) case final frame?) {
        final page = document.pages[frame.index];
        for (final (i, g) in page.guides.indexed) {
          if (drag != null && drag!.pageId == page.id && drag!.index == i) {
            continue;
          }
          drawGuide(frame, g.axis, g.position);
        }
      }
    }
    if (drag case final d? when !d.remove) {
      if (frameOf(d.pageId) case final frame?) {
        drawGuide(frame, d.axis, d.position);
        final p = viewport.toScreen(
          frame.toWorkspace(
            d.axis == GuideAxis.vertical
                ? Point2D(d.position, 0)
                : Point2D(0, d.position),
          ),
        );
        final text = TextPainter(
          text: TextSpan(
            text: _label(d.position),
            style: labelStyle.copyWith(color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final at =
            d.axis == GuideAxis.vertical
                ? Offset(p.dx + 6, rulerSize + 6)
                : Offset(rulerSize + 6, p.dy + 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            (at - const Offset(4, 2)) & Size(text.width + 8, text.height + 4),
            const Radius.circular(3),
          ),
          Paint()..color = guideColor,
        );
        text.paint(canvas, at);
      }
    }
  }

  @override
  bool shouldRepaint(CanvasAidsPainter old) =>
      old.document != document ||
      old.viewport != viewport ||
      old.aids != aids ||
      old.drag != drag ||
      old.activePageId != activePageId ||
      old.colors != colors;
}
