import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'viewport.dart';

/// Screen-pixel radius within which a handle is grabbed.
const double _handleGrab = 10;

/// Distance of the rotation handle below the selection, in screen pixels.
const double _rotateOffset = 30;

enum _Drag { none, move, resize, rotate, marquee, pan }

/// The editing surface: pages, selection, handles and pointer input
/// (P1.2.1, P1.3.3, P1.3.4).
class DesignCanvas extends ConsumerStatefulWidget {
  const DesignCanvas({required this.focusNode, super.key});

  /// Focus that keyboard shortcuts listen on; clicks on the canvas take it.
  final FocusNode focusNode;

  @override
  ConsumerState<DesignCanvas> createState() => _DesignCanvasState();
}

class _DesignCanvasState extends ConsumerState<DesignCanvas> {
  _Drag _drag = _Drag.none;
  ResizeHandle? _handle;
  Offset _downScreen = Offset.zero;
  Point2D _downPage = Point2D.zero;
  PageFrame? _dragFrame;
  Map<ObjectId, DesignObject> _dragStart = const {};
  bool _dragMoved = false;
  Rect? _marquee;
  ObjectId? _hovered;
  MouseCursor _cursor = SystemMouseCursors.basic;
  String? _fittedPath;
  double _lastPanZoomScale = 1;

  EditorController get _editor => ref.read(editorProvider.notifier);
  ViewportController get _view => ref.read(viewportProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final viewport = ref.watch(viewportProvider);
    final frames = layoutPages(session.document.pages);
    final colors = context.ocx;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _syncViewport(size, session, frames);
        return DragTarget<ObjectType>(
          onAcceptWithDetails: (details) => _drop(details, frames),
          builder:
              (context, candidates, _) => Stack(
                children: [
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: _cursor,
                      onHover: (e) => _hover(e.localPosition, frames),
                      onExit: (_) => setState(() => _hovered = null),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _pointerDown(e, frames),
                        onPointerMove: (e) => _pointerMove(e, frames),
                        onPointerUp: (e) => _pointerUp(e, frames),
                        onPointerCancel: (_) => _resetDrag(cancel: true),
                        onPointerSignal: _pointerSignal,
                        onPointerPanZoomStart: (_) => _lastPanZoomScale = 1,
                        onPointerPanZoomUpdate: _panZoom,
                        child: CustomPaint(
                          painter: _WorkspacePainter(
                            document: session.document,
                            frames: frames,
                            viewport: viewport,
                            activePageId: session.state.activePageId,
                            selection: session.selection,
                            hovered: _drag == _Drag.none ? _hovered : null,
                            marquee: _marquee,
                            dragLabel: _dragLabel(session),
                            colors: colors,
                            showActivePage: frames.length > 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final frame in frames)
                    _PageHeader(
                      frame: frame,
                      rect: viewport.rectToScreen(frame.rect),
                      page: session.document.pages[frame.index],
                      isActive: frame.pageId == session.state.activePageId,
                      pageCount: frames.length,
                    ),
                  if (candidates.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colors.selection.withValues(alpha: 0.6),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        );
      },
    );
  }

  // ------------------------------------------------------------- viewport

  void _syncViewport(Size size, EditorSession session, List<PageFrame> frames) {
    final viewport = ref.read(viewportProvider);
    final needsFit = _fittedPath != session.path || !viewport.fitted;
    if (size == viewport.size && !needsFit) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _view.setSize(size);
      if (_fittedPath != session.path || !ref.read(viewportProvider).fitted) {
        _fittedPath = session.path;
        final active = frames.firstWhere(
          (f) => f.pageId == session.state.activePageId,
          orElse: () => frames.first,
        );
        _view.fit(active.rect);
      }
    });
  }

  void _pointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) {
      _view.zoomAt(
        event.localPosition,
        math.exp(-event.scrollDelta.dy * 0.0016),
      );
    } else if (keys.isShiftPressed) {
      _view.panBy(Offset(-event.scrollDelta.dy, 0));
    } else {
      _view.panBy(-event.scrollDelta);
    }
  }

  void _panZoom(PointerPanZoomUpdateEvent event) {
    _view.panBy(event.panDelta);
    if (event.scale != _lastPanZoomScale) {
      _view.zoomAt(event.localPosition, event.scale / _lastPanZoomScale);
      _lastPanZoomScale = event.scale;
    }
  }

  // ----------------------------------------------------------- hit tests

  PageFrame? _frameAt(Offset screen, List<PageFrame> frames) {
    final w = ref.read(viewportProvider).toWorkspace(screen);
    for (final frame in frames) {
      final band = frame.rect.inflate(pageGap / 2);
      if (w.dy >= band.top && w.dy <= band.bottom) return frame;
    }
    return null;
  }

  Point2D _pagePoint(Offset screen, PageFrame frame) =>
      frame.toPage(ref.read(viewportProvider).toWorkspace(screen));

  /// Page units per screen pixel on [frame].
  double _unitsPerPixel(PageFrame frame) =>
      1 / (ref.read(viewportProvider).zoom * frame.unitScale);

  PageFrame _activeFrame(List<PageFrame> frames) {
    final active = ref.read(editorProvider)!.state.activePageId;
    return frames.firstWhere(
      (f) => f.pageId == active,
      orElse: () => frames.first,
    );
  }

  /// Handle under [screen] for a single selection, or `null`.
  ({ResizeHandle? resize, bool rotate})? _handleAt(
    Offset screen,
    List<PageFrame> frames,
  ) {
    final session = ref.read(editorProvider)!;
    if (session.selection.length != 1) return null;
    final id = session.selection.first;
    final object = session.document.objects[id];
    if (object == null || object.locked) return null;
    final geometry = _SelectionGeometry.of(
      session.document,
      id,
      _activeFrame(frames),
      ref.read(viewportProvider),
    );
    if (geometry == null) return null;
    if ((geometry.rotateHandle - screen).distance <= _handleGrab) {
      return (resize: null, rotate: true);
    }
    for (final (handle, position) in geometry.handles) {
      if ((position - screen).distance <= _handleGrab) {
        return (resize: handle, rotate: false);
      }
    }
    return null;
  }

  // --------------------------------------------------------------- input

  void _hover(Offset screen, List<PageFrame> frames) {
    if (_drag != _Drag.none) return;
    final session = ref.read(editorProvider);
    if (session == null) return;
    final handle = _handleAt(screen, frames);
    if (handle != null) {
      setState(() {
        _hovered = null;
        _cursor =
            handle.rotate
                ? SystemMouseCursors.grab
                : _resizeCursor(handle.resize!, session);
      });
      return;
    }
    final frame = _frameAt(screen, frames);
    ObjectId? hit;
    if (frame != null) {
      hit = hitTest(
        session.document,
        session.document.pages[frame.index],
        _pagePoint(screen, frame),
        tolerance: 6 * _unitsPerPixel(frame),
      );
    }
    final cursor =
        hit == null ? SystemMouseCursors.basic : SystemMouseCursors.move;
    if (hit != _hovered || cursor != _cursor) {
      setState(() {
        _hovered = hit;
        _cursor = cursor;
      });
    }
  }

  MouseCursor _resizeCursor(ResizeHandle handle, EditorSession session) {
    final id = session.selection.first;
    final rotation = session.document.objects[id]?.transform.rotation ?? 0;
    const base = {
      ResizeHandle.top: 90.0,
      ResizeHandle.bottom: 90.0,
      ResizeHandle.left: 0.0,
      ResizeHandle.right: 0.0,
      ResizeHandle.topLeft: 135.0,
      ResizeHandle.bottomRight: 135.0,
      ResizeHandle.topRight: 45.0,
      ResizeHandle.bottomLeft: 45.0,
    };
    final angle = ((base[handle]! - rotation) % 180 + 180) % 180;
    final bucket = ((angle + 22.5) ~/ 45) % 4;
    return const [
      SystemMouseCursors.resizeLeftRight,
      SystemMouseCursors.resizeUpRightDownLeft,
      SystemMouseCursors.resizeUpDown,
      SystemMouseCursors.resizeUpLeftDownRight,
    ][bucket];
  }

  void _pointerDown(PointerDownEvent event, List<PageFrame> frames) {
    widget.focusNode.requestFocus();
    final session = ref.read(editorProvider);
    if (session == null) return;
    _downScreen = event.localPosition;
    _dragMoved = false;

    final spaceHeld = HardwareKeyboard.instance.logicalKeysPressed.contains(
      LogicalKeyboardKey.space,
    );
    if (event.buttons == kMiddleMouseButton || spaceHeld) {
      _drag = _Drag.pan;
      setState(() => _cursor = SystemMouseCursors.grabbing);
      return;
    }
    if (event.buttons != kPrimaryMouseButton) return;

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final handle = _handleAt(event.localPosition, frames);
    if (handle != null) {
      _dragFrame = _activeFrame(frames);
      _startObjectDrag(handle.rotate ? _Drag.rotate : _Drag.resize);
      _handle = handle.resize;
      return;
    }

    final frame = _frameAt(event.localPosition, frames) ?? _activeFrame(frames);
    if (frame.pageId != session.state.activePageId) {
      _editor.setActivePage(frame.pageId);
    }
    _dragFrame = frame;
    _downPage = _pagePoint(event.localPosition, frame);
    final current = ref.read(editorProvider)!;
    final hit = hitTest(
      current.document,
      current.document.pages[frame.index],
      _downPage,
      tolerance: 6 * _unitsPerPixel(frame),
    );
    if (hit == null) {
      if (!shift) _editor.clearSelection();
      _drag = _Drag.marquee;
      setState(() => _marquee = Rect.fromPoints(_downScreen, _downScreen));
      return;
    }
    if (shift) {
      _editor.toggleSelected(hit);
      _drag = _Drag.none;
      return;
    }
    if (!current.selection.contains(hit)) _editor.select({hit});
    _startObjectDrag(_Drag.move);
  }

  void _startObjectDrag(_Drag kind) {
    final session = ref.read(editorProvider)!;
    _drag = kind;
    _dragStart = {
      for (final id in session.selection)
        if (session.document.objects[id] case final o? when !o.locked) id: o,
    };
    if (_dragStart.isEmpty) {
      _drag = _Drag.none;
      return;
    }
    _editor.beginGesture();
  }

  void _pointerMove(PointerMoveEvent event, List<PageFrame> frames) {
    if (_drag == _Drag.none) return;
    if ((event.localPosition - _downScreen).distance > 2) _dragMoved = true;
    if (_drag == _Drag.pan) {
      _view.panBy(event.delta);
      return;
    }
    if (_drag == _Drag.marquee) {
      setState(
        () => _marquee = Rect.fromPoints(_downScreen, event.localPosition),
      );
      return;
    }
    final frame = _dragFrame;
    if (frame == null || !_dragMoved) return;
    final p = _pagePoint(event.localPosition, frame);
    final shift = HardwareKeyboard.instance.isShiftPressed;

    switch (_drag) {
      case _Drag.move:
        var dx = p.x - _downPage.x;
        var dy = p.y - _downPage.y;
        if (shift) {
          // Constrain to the dominant axis.
          if (dx.abs() > dy.abs()) {
            dy = 0;
          } else {
            dx = 0;
          }
        }
        _editor.previewObjects([
          for (final o in _dragStart.values)
            o.copyWith(
              transform: o.transform.copyWith(
                x: o.transform.x + dx,
                y: o.transform.y + dy,
              ),
            ),
        ]);
      case _Drag.resize:
        final o = _dragStart.values.first;
        _editor.previewObjects([
          o.copyWith(
            transform: resizeTransform(
              o.transform,
              _handle!,
              p,
              keepAspectRatio: shift,
              minSize: 4 * _unitsPerPixel(frame),
            ),
          ),
        ]);
      case _Drag.rotate:
        final o = _dragStart.values.first;
        _editor.previewObjects([
          o.copyWith(
            transform: rotateTransform(
              o.transform,
              p,
              snapDegrees: shift ? 15 : 0,
            ),
          ),
        ]);
      case _Drag.none || _Drag.marquee || _Drag.pan:
        break;
    }
    setState(() {});
  }

  void _pointerUp(PointerUpEvent event, List<PageFrame> frames) {
    switch (_drag) {
      case _Drag.move:
        _editor.endGesture('Move');
      case _Drag.resize:
        _editor.endGesture('Resize');
      case _Drag.rotate:
        _editor.endGesture('Rotate');
      case _Drag.marquee:
        _finishMarquee(frames);
      case _Drag.pan || _Drag.none:
        break;
    }
    _resetDrag();
  }

  void _finishMarquee(List<PageFrame> frames) {
    final marquee = _marquee;
    final session = ref.read(editorProvider);
    if (marquee == null || session == null || !_dragMoved) return;
    final frame = _activeFrame(frames);
    final a = _pagePoint(marquee.topLeft, frame);
    final b = _pagePoint(marquee.bottomRight, frame);
    final ids = objectsInRect(
      session.document,
      session.activePage,
      Rect2D.fromPoints([a, b]),
    );
    if (HardwareKeyboard.instance.isShiftPressed) {
      _editor.select({...session.selection, ...ids});
    } else {
      _editor.select(ids);
    }
  }

  void _resetDrag({bool cancel = false}) {
    if (cancel && _editor.isGestureActive) _editor.endGesture('Move');
    setState(() {
      _drag = _Drag.none;
      _handle = null;
      _marquee = null;
      _dragStart = const {};
      if (_cursor == SystemMouseCursors.grabbing) {
        _cursor = SystemMouseCursors.basic;
      }
    });
  }

  String? _dragLabel(EditorSession session) {
    if (!_dragMoved || session.selection.length != 1) return null;
    final object = session.document.objects[session.selection.first];
    if (object == null) return null;
    final unit = session.activePage.unit.symbol;
    return switch (_drag) {
      _Drag.resize =>
        '${_fmt(object.transform.width)} × ${_fmt(object.transform.height)} $unit',
      _Drag.rotate => '${object.transform.rotation.round()}°',
      _ => null,
    };
  }

  void _drop(DragTargetDetails<ObjectType> details, List<PageFrame> frames) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final frame = _frameAt(local, frames) ?? _activeFrame(frames);
    final page = ref.read(editorProvider)!.document.pages[frame.index];
    final p = _pagePoint(local, frame);
    _editor.insertShape(
      details.data,
      pageId: frame.pageId,
      at: Point2D(
        p.x.clamp(0, page.width).toDouble(),
        p.y.clamp(0, page.height).toDouble(),
      ),
    );
    widget.focusNode.requestFocus();
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Screen-space geometry of a single selected object.
class _SelectionGeometry {
  _SelectionGeometry(
    this.corners,
    this.handles,
    this.rotateHandle,
    this.rotateAnchor,
  );

  final List<Offset> corners;
  final List<(ResizeHandle, Offset)> handles;
  final Offset rotateHandle;
  final Offset rotateAnchor;

  static _SelectionGeometry? of(
    DesignDocument document,
    ObjectId id,
    PageFrame frame,
    ViewportState viewport,
  ) {
    final object = document.objects[id];
    if (object == null) return null;
    final world = worldMatrix(document, id);
    final t = object.transform;
    Offset screen(Point2D local) =>
        viewport.toScreen(frame.toWorkspace(world.apply(local)));

    final corners = localCorners(t).map(screen).toList();
    final isLine = t.height == 0 || t.width == 0;
    final handles = [
      for (final h in ResizeHandle.values)
        if (!isLine ||
            (t.height == 0
                ? (h == ResizeHandle.left || h == ResizeHandle.right)
                : (h == ResizeHandle.top || h == ResizeHandle.bottom)))
          (h, screen(h.position(t.width, t.height))),
    ];
    // Rotation handle sits below the box along its local "down" direction.
    final bottom = screen(Point2D(t.width / 2, t.height));
    var down = world.applyToVector(const Point2D(0, 1));
    if (t.scaleY < 0) down = down * -1;
    final length = down.length == 0 ? 1.0 : down.length;
    final dir = Offset(down.x / length, down.y / length);
    return _SelectionGeometry(
      corners,
      handles,
      bottom + dir * _rotateOffset,
      bottom,
    );
  }
}

class _WorkspacePainter extends CustomPainter {
  _WorkspacePainter({
    required this.document,
    required this.frames,
    required this.viewport,
    required this.activePageId,
    required this.selection,
    required this.hovered,
    required this.marquee,
    required this.dragLabel,
    required this.colors,
    required this.showActivePage,
  });

  final DesignDocument document;
  final List<PageFrame> frames;
  final ViewportState viewport;
  final PageId activePageId;
  final Set<ObjectId> selection;
  final ObjectId? hovered;
  final Rect? marquee;
  final String? dragLabel;
  final OcxColors colors;
  final bool showActivePage;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRect(screen, Paint()..color = colors.workspace);

    PageFrame? active;
    for (final frame in frames) {
      final rect = viewport.rectToScreen(frame.rect);
      if (frame.pageId == activePageId) active = frame;
      if (!rect.inflate(24).overlaps(screen)) continue;
      final page = document.pages[frame.index];
      canvas.drawRect(
        rect.shift(const Offset(0, 3)),
        Paint()
          ..color = colors.pageShadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas
        ..save()
        ..clipRect(rect)
        ..translate(rect.left, rect.top)
        ..scale(viewport.zoom * frame.unitScale);
      paintPageBackground(canvas, page);
      paintPageContent(canvas, document, page);
      canvas.restore();
      if (showActivePage && frame.pageId == activePageId) {
        canvas.drawRect(
          rect.inflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colors.selection.withValues(alpha: 0.45),
        );
      }
    }
    if (active == null) return;

    final outline =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.selection;

    final hover = hovered;
    if (hover != null && !selection.contains(hover)) {
      _drawPolygon(canvas, _corners(hover, active), outline);
    }
    for (final id in selection) {
      _drawPolygon(canvas, _corners(id, active), outline);
    }
    if (selection.length > 1) {
      final bounds = selectionBounds(document, selection);
      if (bounds != null) {
        final rect = Rect.fromPoints(
          viewport.toScreen(active.toWorkspace(bounds.topLeft)),
          viewport.toScreen(
            active.toWorkspace(Point2D(bounds.right, bounds.bottom)),
          ),
        );
        canvas.drawRect(
          rect.inflate(4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = colors.selection.withValues(alpha: 0.6),
        );
      }
    }
    if (selection.length == 1) {
      final id = selection.first;
      final locked = document.objects[id]?.locked ?? false;
      final geometry = _SelectionGeometry.of(document, id, active, viewport);
      if (geometry != null && !locked) _drawHandles(canvas, geometry);
      if (geometry != null && dragLabel != null) {
        _drawLabel(
          canvas,
          geometry.rotateHandle + const Offset(0, 22),
          dragLabel!,
        );
      }
    }

    final m = marquee;
    if (m != null) {
      canvas
        ..drawRect(m, Paint()..color = colors.selection.withValues(alpha: 0.08))
        ..drawRect(
          m,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = colors.selection.withValues(alpha: 0.7),
        );
    }
  }

  List<Offset> _corners(ObjectId id, PageFrame frame) => [
    for (final p in worldCorners(document, id))
      viewport.toScreen(frame.toWorkspace(p)),
  ];

  void _drawPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    canvas.drawPath(Path()..addPolygon(points, true), paint);
  }

  void _drawHandles(Canvas canvas, _SelectionGeometry g) {
    final fill = Paint()..color = Colors.white;
    final border =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.selection;
    final shadow =
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawLine(
      g.rotateAnchor,
      g.rotateHandle,
      Paint()
        ..strokeWidth = 1
        ..color = colors.selection.withValues(alpha: 0.6),
    );
    for (final (handle, p) in g.handles) {
      final rect =
          handle.isCorner
              ? Rect.fromCenter(center: p, width: 10, height: 10)
              : Rect.fromCenter(center: p, width: 8, height: 8);
      final shape = RRect.fromRectAndRadius(
        rect,
        Radius.circular(handle.isCorner ? 2.5 : 4),
      );
      canvas
        ..drawRRect(shape.shift(const Offset(0, 0.5)), shadow)
        ..drawRRect(shape, fill)
        ..drawRRect(shape, border);
    }
    canvas
      ..drawCircle(g.rotateHandle, 9, shadow)
      ..drawCircle(g.rotateHandle, 9, fill)
      ..drawCircle(g.rotateHandle, 9, border);
    // Circular arrow glyph.
    final arc = Rect.fromCircle(center: g.rotateHandle, radius: 4.2);
    final glyph =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = colors.selection;
    canvas.drawArc(arc, -math.pi * 0.15, math.pi * 1.45, false, glyph);
    final tip =
        g.rotateHandle +
        Offset(
          4.2 * math.cos(-math.pi * 0.15),
          4.2 * math.sin(-math.pi * 0.15),
        );
    canvas
      ..drawLine(tip, tip + const Offset(-0.5, -3), glyph)
      ..drawLine(tip, tip + const Offset(-3, 0.6), glyph);
  }

  void _drawLabel(Canvas canvas, Offset center, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: center,
      width: painter.width + 14,
      height: painter.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(6)),
      Paint()..color = const Color(0xE61D2130),
    );
    painter.paint(canvas, box.topLeft + const Offset(7, 4));
  }

  @override
  bool shouldRepaint(_WorkspacePainter old) =>
      !identical(old.document, document) ||
      old.viewport != viewport ||
      old.activePageId != activePageId ||
      old.selection != selection ||
      old.hovered != hovered ||
      old.marquee != marquee ||
      old.dragLabel != dragLabel ||
      old.colors != colors;
}

/// Title and quick actions above each page, like a slide header.
class _PageHeader extends ConsumerWidget {
  const _PageHeader({
    required this.frame,
    required this.rect,
    required this.page,
    required this.isActive,
    required this.pageCount,
  });

  final PageFrame frame;
  final Rect rect;
  final DesignPage page;
  final bool isActive;
  final int pageCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rect.width < 80) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final editor = ref.read(editorProvider.notifier);
    final label =
        page.name.isEmpty
            ? 'Page ${frame.index + 1}'
            : 'Page ${frame.index + 1} – ${page.name}';
    final showActions = isActive && rect.width >= 220;
    return Positioned(
      left: rect.left,
      top: rect.top - 36,
      width: rect.width,
      height: 30,
      child: Row(
        children: [
          Flexible(
            child: GestureDetector(
              onTap: () => editor.setActivePage(page.id),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color:
                      isActive
                          ? theme.colorScheme.onSurface
                          : context.ocx.subtleText,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (showActions) ...[
            _HeaderButton(
              icon: Icons.copy_all_outlined,
              tooltip: 'Duplicate page',
              onPressed: () => editor.duplicatePage(page.id),
            ),
            _HeaderButton(
              icon: Icons.delete_outline,
              tooltip: 'Delete page',
              onPressed:
                  pageCount > 1 ? () => editor.deletePage(page.id) : null,
            ),
            _HeaderButton(
              icon: Icons.add_box_outlined,
              tooltip: 'Add page',
              onPressed: editor.addPage,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    color: context.ocx.subtleText,
  );
}
