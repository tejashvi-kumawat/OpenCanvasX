import 'dart:math' as math;

import 'package:asset_engine/asset_engine.dart';
import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../theme/ocx_theme.dart';
import 'editor_controller.dart';
import 'panels/asset_tiles.dart';
import 'text_overlay.dart';
import 'rulers.dart';
import 'tools.dart';
import 'viewport.dart';

/// Screen-pixel radius within which a handle is grabbed.
const double _handleGrab = 8;

/// Distance of the rotation handle below the selection, in screen pixels.
const double _rotateOffset = 20;

/// Pointer travel (screen pixels) below which a press counts as a click.
const double _clickSlop = 3;

enum _Drag {
  none,
  move,
  resize,
  rotate,
  marquee,
  pan,
  draw,
  pen,
  pencil,
  node,
  guide,
}

/// Payload of drags from the Elements panel.
sealed class ElementDrag {
  const ElementDrag();
}

class ShapeDrag extends ElementDrag {
  const ShapeDrag(this.type);

  final ObjectType type;
}

class TextDrag extends ElementDrag {
  const TextDrag(this.role, {this.restyle});

  final TextRole role;
  final TextPayload Function(TextPayload payload)? restyle;
}

/// An empty image frame shape (Canva "Frames").
class ImageFrameDrag extends ElementDrag {
  const ImageFrameDrag(this.shape);

  final ImageFrameShape shape;
}

/// An icon or sticker from an asset pack.
class AssetDrag extends ElementDrag {
  const AssetDrag(this.item);

  final AssetItem item;
}

/// The editing surface: pages, selection, handles, tools and pointer input
/// (P1.2.1, P1.3.3, P1.3.4, P1.5.1).
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
  Offset _lastScreen = Offset.zero;
  Point2D _downPage = Point2D.zero;
  PageFrame? _dragFrame;
  Map<ObjectId, DesignObject> _dragStart = const {};
  late DesignDocument _dragDocument;

  /// Smart-guide targets for the current drag (P1.4.4) and what to show.
  SnapTargets? _snapTargets;
  Rect2D? _dragStartBounds;
  List<SnapGuide> _guides = const [];

  // Pen (P2.6.1): anchors placed so far, in page units of [_penPage].
  final List<PenAnchor> _pen = [];
  PageId? _penPage;
  Offset? _penHover;
  DateTime _lastPenClick = DateTime(0);

  // Pencil (P2.6.3): raw points of the stroke being drawn.
  final List<Point2D> _pencil = [];

  // Node editing (P2.6.2): the dragged anchor (part −1 in-handle, 0 point,
  // 1 out-handle) and the path as it was when the drag began.
  int _nodePart = 0;
  int? _nodeIndex;
  DesignObject? _nodeObject;
  List<PenAnchor> _nodeStart = const [];
  bool _nodeClosed = false;
  bool _dragMoved = false;
  Rect? _marquee;
  ObjectId? _hovered;
  MouseCursor _cursor = SystemMouseCursors.basic;
  String? _fittedPath;
  double _lastPanZoomScale = 1;
  DateTime _lastClick = DateTime(0);
  Offset _lastClickPosition = Offset.zero;

  EditorController get _editor => ref.read(editorProvider.notifier);
  ViewportController get _view => ref.read(viewportProvider.notifier);
  EditorTool get _tool => ref.read(toolProvider).active;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    if (session == null) return const SizedBox.shrink();
    final viewport = ref.watch(viewportProvider);
    final tool = ref.watch(toolProvider).active;
    final editingText = ref.watch(textEditingProvider);
    ref.listen(toolProvider, (previous, next) {
      if (previous?.active == EditorTool.pen && next.active != EditorTool.pen) {
        _finishPen(closed: false);
      }
    });
    final nodeEdit = ref.watch(nodeEditProvider);
    final frames = layoutPages(
      session.document.pages,
      active: session.state.activePageId,
    );
    final colors = context.ocx;
    final aids = ref.watch(canvasAidsProvider);
    final cursor =
        ref.watch(eyedropperProvider) != null
            ? SystemMouseCursors.precise
            : (_drag == _Drag.none ? _cursorFor(tool) ?? _cursor : _cursor);

    // While a text is edited inline the overlay draws it, not the painter.
    final document =
        editingText == null
            ? session.document
            : _withHidden(session.document, editingText);

    return LayoutBuilder(
      builder: (context, constraints) {
        _syncViewport(constraints.biggest, session, frames);
        return DragTarget<ElementDrag>(
          onAcceptWithDetails: (details) => _drop(details, frames),
          builder:
              (context, candidates, _) => Stack(
                children: [
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: cursor,
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
                            document: document,
                            frames: frames,
                            viewport: viewport,
                            activePageId: session.state.activePageId,
                            selection: session.selection,
                            hovered: _drag == _Drag.none ? _hovered : null,
                            marquee: _marquee,
                            drawPreview: _drawPreview(),
                            drawIsLine: tool.isLine,
                            dragLabel: _dragLabel(session),
                            showHandles:
                                editingText == null && nodeEdit == null,
                            vector: _vectorOverlay(
                              session,
                              frames,
                              viewport,
                              nodeEdit,
                            ),
                            colors: colors,
                            titles: _frameTitles(session, frames, viewport),
                            guides: _drag == _Drag.none ? const [] : _guides,
                            links: _linkArrows(session, frames, viewport),
                            media: ref.watch(mediaCacheProvider),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: CanvasAidsPainter(
                          document: session.document,
                          frames: frames,
                          viewport: viewport,
                          activePageId: session.state.activePageId,
                          aids: aids,
                          drag: ref.watch(guideDragProvider),
                          colors: colors,
                          labelStyle: OcxText.caption(context),
                        ),
                      ),
                    ),
                  ),
                  if (aids.rulers) const Positioned.fill(child: CanvasRulers()),
                  for (final frame in frames)
                    if (!frame.unbounded)
                      _PageTitle(
                        frame: frame,
                        rect: viewport.rectToScreen(frame.rect),
                        page: session.document.pages[frame.index],
                        isActive: frame.pageId == session.state.activePageId,
                      ),
                  if (editingText != null)
                    if (_screenMatrix(
                          session.document,
                          editingText,
                          frames,
                          viewport,
                        )
                        case final matrix?)
                      TextEditOverlay(
                        key: ValueKey(editingText),
                        object: session.document.objects[editingText]!,
                        matrix: matrix,
                        onChanged: _editor.updateEditedText,
                        onDone: () {
                          _editor.finishTextEdit();
                          widget.focusNode.requestFocus();
                        },
                      ),
                  if (candidates.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.accent, width: 2),
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

  static DesignDocument _withHidden(DesignDocument document, ObjectId id) {
    final object = document.objects[id];
    if (object == null) return document;
    return Change(
      label: 'hide',
      objects: {id: object.copyWith(hidden: true)},
    ).applyTo(document).$1;
  }

  MouseCursor? _cursorFor(EditorTool tool) => switch (tool) {
    EditorTool.move => null,
    EditorTool.hand => SystemMouseCursors.grab,
    EditorTool.text => SystemMouseCursors.text,
    _ => SystemMouseCursors.precise,
  };

  /// Screen transform of [id]'s local box, for the inline text editor.
  Matrix4? _screenMatrix(
    DesignDocument document,
    ObjectId id,
    List<PageFrame> frames,
    ViewportState viewport,
  ) {
    var pageId = document.objects[id]?.pageId;
    var current = document.objects[id];
    while (pageId == null && current?.parentId != null) {
      current = document.objects[current!.parentId];
      pageId = current?.pageId;
    }
    final frame = frames.where((f) => f.pageId == pageId).firstOrNull;
    if (frame == null) return null;
    final m =
        Affine2D.translation(viewport.pan.dx, viewport.pan.dy) *
        Affine2D.scale(viewport.zoom, viewport.zoom) *
        Affine2D.translation(frame.rect.left, frame.rect.top) *
        Affine2D.scale(frame.unitScale, frame.unitScale) *
        worldMatrix(document, id);
    return Matrix4.fromList(m.toMatrix4Storage());
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
        _view.fit(fitRectFor(session.document, active));
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

  /// Name labels above the active page's top-level frames (ADR-0007).
  List<_FrameTitle> _frameTitles(
    EditorSession session,
    List<PageFrame> frames,
    ViewportState viewport,
  ) {
    final frame =
        frames.where((f) => f.pageId == session.state.activePageId).firstOrNull;
    if (frame == null) return const [];
    final page = session.document.pages[frame.index];
    final titles = <_FrameTitle>[];
    for (final id in page.objectIds) {
      final object = session.document.objects[id];
      if (object == null || object.type != ObjectType.frame || object.hidden) {
        continue;
      }
      final corners = worldCorners(session.document, id);
      if (corners.isEmpty) continue;
      final topLeft = viewport.toScreen(frame.toWorkspace(corners.first));
      final topRight = viewport.toScreen(frame.toWorkspace(corners[1]));
      final width = (topRight - topLeft).distance;
      if (width < 24) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: layerName(session.document, page, object),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      titles.add(
        _FrameTitle(
          id: id,
          painter: painter,
          rect: Rect.fromLTWH(
            topLeft.dx,
            topLeft.dy - painter.height - 4,
            painter.width,
            painter.height,
          ),
        ),
      );
    }
    return titles;
  }

  ObjectId? _titleAt(Offset screen, PageFrame frame) {
    final session = ref.read(editorProvider)!;
    if (frame.pageId != session.state.activePageId) return null;
    for (final title
        in _frameTitles(session, [
          frame,
        ], ref.read(viewportProvider)).reversed) {
      if (title.rect.inflate(3).contains(screen)) {
        final object = session.document.objects[title.id];
        return object == null || object.locked ? null : title.id;
      }
    }
    return null;
  }

  PageFrame? _frameAt(Offset screen, List<PageFrame> frames) {
    final w = ref.read(viewportProvider).toWorkspace(screen);
    for (final frame in frames) {
      if (frame.unbounded) return frame;
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

  /// Snap targets on [page], with ruler guides and the grid when shown.
  SnapTargets _collectTargets(
    DesignDocument document,
    DesignPage page, {
    Set<ObjectId> exclude = const {},
  }) {
    final aids = ref.read(canvasAidsProvider);
    return SnapTargets.collect(
      document,
      page,
      exclude: exclude,
      guides: aids.guides,
      grid: aids.grid ? gridStep(page) : null,
    );
  }

  /// The ruler guide of the active page within a few pixels of [screen].
  (int, Guide)? _guideAt(Offset screen, List<PageFrame> frames) {
    if (!ref.read(canvasAidsProvider).guides) return null;
    final session = ref.read(editorProvider)!;
    final frame = _activeFrame(frames);
    final page = session.document.pages[frame.index];
    final viewport = ref.read(viewportProvider);
    for (final (i, g) in page.guides.indexed.toList().reversed) {
      final p = viewport.toScreen(
        frame.toWorkspace(
          g.axis == GuideAxis.vertical
              ? Point2D(g.position, 0)
              : Point2D(0, g.position),
        ),
      );
      final d =
          g.axis == GuideAxis.vertical
              ? (p.dx - screen.dx).abs()
              : (p.dy - screen.dy).abs();
      if (d <= 3) return (i, g);
    }
    return null;
  }

  void _moveGuide(Offset screen, List<PageFrame> frames) {
    final drag = ref.read(guideDragProvider);
    if (drag == null) return;
    final frame = _activeFrame(frames);
    final p = _pagePoint(screen, frame);
    final rulers = ref.read(canvasAidsProvider).rulers;
    final size = ref.read(viewportProvider).size;
    final vertical = drag.axis == GuideAxis.vertical;
    final along = vertical ? screen.dx : screen.dy;
    final extent = vertical ? size.width : size.height;
    final remove = along < (rulers ? rulerSize : 0) || along > extent;
    ref.read(guideDragProvider.notifier).value = (
      pageId: drag.pageId,
      axis: drag.axis,
      position: ((vertical ? p.x : p.y) * 100).round() / 100,
      index: drag.index,
      remove: remove,
    );
  }

  PageFrame _activeFrame(List<PageFrame> frames) {
    final active = ref.read(editorProvider)!.state.activePageId;
    return frames.firstWhere(
      (f) => f.pageId == active,
      orElse: () => frames.first,
    );
  }

  /// What a click at [screen] selects; inside an entered group this is a
  /// sibling of the selection, and [enter] goes one level deeper.
  ObjectId? _objectAt(Offset screen, PageFrame frame, {bool enter = false}) {
    final session = ref.read(editorProvider)!;
    return pickObject(
      session.document,
      session.document.pages[frame.index],
      _pagePoint(screen, frame),
      selection:
          frame.pageId == session.state.activePageId
              ? session.selection
              : const {},
      tolerance: 5 * _unitsPerPixel(frame),
      enter: enter,
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
    if (_tool == EditorTool.pen && _pen.isNotEmpty && _drag == _Drag.none) {
      setState(() => _penHover = screen);
      return;
    }
    if (_drag != _Drag.none || _tool != EditorTool.move) return;
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
    if (_guideAt(screen, frames) case (_, final g)) {
      setState(() {
        _hovered = null;
        _cursor =
            g.axis == GuideAxis.vertical
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow;
      });
      return;
    }
    final frame = _frameAt(screen, frames);
    final hit =
        frame == null
            ? null
            : (_titleAt(screen, frame) ?? _objectAt(screen, frame));
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
    if (ref.read(textEditingProvider) != null) _editor.finishTextEdit();
    widget.focusNode.requestFocus();
    final session = ref.read(editorProvider);
    if (session == null) return;
    _downScreen = event.localPosition;
    _lastScreen = event.localPosition;
    _dragMoved = false;

    if (event.buttons == kSecondaryMouseButton) {
      _contextMenu(event, frames);
      return;
    }
    final spaceHeld = HardwareKeyboard.instance.logicalKeysPressed.contains(
      LogicalKeyboardKey.space,
    );
    if (event.buttons == kMiddleMouseButton ||
        spaceHeld ||
        _tool == EditorTool.hand) {
      _drag = _Drag.pan;
      setState(() => _cursor = SystemMouseCursors.grabbing);
      return;
    }
    if (event.buttons != kPrimaryMouseButton) return;

    final frame = _frameAt(event.localPosition, frames) ?? _activeFrame(frames);
    _dragFrame = frame;
    _downPage = _pagePoint(event.localPosition, frame);

    if (ref.read(eyedropperProvider) case final pick?) {
      ref.read(eyedropperProvider.notifier).pick = null;
      _sampleColor(frame, _downPage).then((color) {
        if (color != null) pick(color);
      });
      return;
    }

    // Vector tools.
    if (_tool == EditorTool.pen) {
      if (frame.pageId != session.state.activePageId) {
        _editor.setActivePage(frame.pageId);
      }
      _penDown(event.localPosition, frame);
      return;
    }
    if (_tool == EditorTool.pencil) {
      if (frame.pageId != session.state.activePageId) {
        _editor.setActivePage(frame.pageId);
      }
      _pencil
        ..clear()
        ..add(_downPage);
      _drag = _Drag.pencil;
      setState(() {});
      return;
    }

    // Node editing: grab an anchor or handle, or leave node editing.
    if (ref.read(nodeEditProvider) case final nodes?) {
      if (_nodeAt(event.localPosition, nodes.id, frame) case (
        final index,
        final part,
      )) {
        final document = ref.read(editorProvider)!.document;
        final object = document.objects[nodes.id]!;
        final local = localAnchors(object);
        _nodeObject = object;
        _nodeStart = local.anchors;
        _nodeClosed = local.closed;
        _nodeIndex = index;
        _nodePart = part;
        _dragDocument = document;
        ref.read(nodeEditProvider.notifier).value = NodeEdit(
          nodes.id,
          anchor: index,
        );
        _editor.beginGesture();
        _drag = _Drag.node;
        return;
      }
      ref.read(nodeEditProvider.notifier).value = null;
    }

    // Drawing tools.
    if (_tool != EditorTool.move) {
      if (frame.pageId != session.state.activePageId) {
        _editor.setActivePage(frame.pageId);
      }
      _drag = _Drag.draw;
      setState(() {});
      return;
    }

    final shift = HardwareKeyboard.instance.isShiftPressed;
    final handle = _handleAt(event.localPosition, frames);
    if (handle != null) {
      _dragFrame = _activeFrame(frames);
      _startObjectDrag(handle.rotate ? _Drag.rotate : _Drag.resize);
      _handle = handle.resize;
      return;
    }

    if (_guideAt(event.localPosition, frames) case (final i, final g)) {
      ref.read(guideDragProvider.notifier).value = (
        pageId: session.state.activePageId,
        axis: g.axis,
        position: g.position,
        index: i,
        remove: false,
      );
      _drag = _Drag.guide;
      return;
    }

    if (frame.pageId != session.state.activePageId) {
      _editor.setActivePage(frame.pageId);
    }
    final title = _titleAt(event.localPosition, frame);
    if (title != null) {
      if (shift) {
        _editor.toggleSelected(title);
        _drag = _Drag.none;
      } else {
        if (!session.selection.contains(title)) _editor.select({title});
        _startObjectDrag(_Drag.move);
      }
      return;
    }
    final hit = _objectAt(event.localPosition, frame);

    // Double-click enters a group, or edits text inline.
    final now = DateTime.now();
    final isDouble =
        now.difference(_lastClick) < const Duration(milliseconds: 400) &&
        (event.localPosition - _lastClickPosition).distance < 6;
    _lastClick = now;
    _lastClickPosition = event.localPosition;
    if (isDouble && hit != null) {
      final document = ref.read(editorProvider)!.document;
      final entered = _objectAt(event.localPosition, frame, enter: true);
      if (entered != null && entered != hit) {
        _editor.select({entered});
        _drag = _Drag.none;
        return;
      }
      if (document.objects[hit] case final o?
          when o.type == ObjectType.path && !o.locked) {
        _editor.select({hit});
        ref.read(nodeEditProvider.notifier).value = NodeEdit(hit);
        _drag = _Drag.none;
        return;
      }
      if (document.objects[hit]?.payload is TextPayload) {
        _editor.startTextEdit(hit);
        _drag = _Drag.none;
        return;
      }
    }

    final current = ref.read(editorProvider)!;
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
    _dragDocument = session.document;
    _snapTargets = _collectTargets(
      session.document,
      session.activePage,
      exclude: _dragStart.keys.toSet(),
    );
    _dragStartBounds = selectionBounds(session.document, _dragStart.keys);
    _editor.beginGesture();
  }

  void _pointerMove(PointerMoveEvent event, List<PageFrame> frames) {
    if (_drag == _Drag.none) return;
    if ((event.localPosition - _downScreen).distance > _clickSlop) {
      _dragMoved = true;
    }
    _lastScreen = event.localPosition;
    switch (_drag) {
      case _Drag.pan:
        _view.panBy(event.delta);
        return;
      case _Drag.guide:
        _moveGuide(event.localPosition, frames);
        return;
      case _Drag.marquee:
        setState(
          () => _marquee = Rect.fromPoints(_downScreen, event.localPosition),
        );
        return;
      case _Drag.draw:
        setState(() {});
        return;
      case _Drag.pen:
        final frame = _dragFrame;
        if (_dragMoved && _pen.isNotEmpty && frame != null) {
          // Dragging after placing a point pulls out smooth handles.
          final p = _pagePoint(event.localPosition, frame);
          _pen[_pen.length - 1] = PenAnchor.smooth(_pen.last.point, p);
          setState(() {});
        }
        return;
      case _Drag.pencil:
        final frame = _dragFrame;
        if (frame != null) {
          final p = _pagePoint(event.localPosition, frame);
          if ((p - _pencil.last).length > _unitsPerPixel(frame)) {
            _pencil.add(p);
            setState(() {});
          }
        }
        return;
      case _Drag.none ||
          _Drag.move ||
          _Drag.resize ||
          _Drag.rotate ||
          _Drag.node:
        break;
    }
    final frame = _dragFrame;
    if (frame == null || !_dragMoved) return;
    final p = _pagePoint(event.localPosition, frame);
    final shift = HardwareKeyboard.instance.isShiftPressed;

    switch (_drag) {
      case _Drag.move:
        var dx = p.x - _downPage.x;
        var dy = p.y - _downPage.y;
        var lockX = false;
        var lockY = false;
        if (shift) {
          // Constrain to the dominant axis.
          if (dx.abs() > dy.abs()) {
            dy = 0;
            lockY = true;
          } else {
            dx = 0;
            lockX = true;
          }
        }
        final targets = _snapTargets;
        final start = _dragStartBounds;
        if (_snapping && targets != null && start != null) {
          final snap = targets.snapRect(
            Rect2D.fromLTWH(
              start.left + dx,
              start.top + dy,
              start.width,
              start.height,
            ),
            threshold: _snapDistance(frame),
          );
          if (!lockX) dx += snap.dx;
          if (!lockY) dy += snap.dy;
          _guides = [
            for (final g in snap.guides)
              if (g.vertical ? !lockX : !lockY) g,
          ];
        } else {
          _guides = const [];
        }
        _editor.previewObjects([
          for (final o in _dragStart.values)
            shiftedInPage(_dragDocument, o, dx, dy),
        ]);
      case _Drag.resize:
        final o = _dragStart.values.first;
        // Snap the dragged edge(s) to guides, then work in the object's
        // parent space (groups may be rotated or scaled).
        var point = p;
        final targets = _snapTargets;
        if (_snapping && targets != null) {
          final handle = _handle!;
          final snap = targets.snapPoint(
            p,
            threshold: _snapDistance(frame),
            snapX: handle.movesLeft || handle.movesRight,
            snapY: handle.movesTop || handle.movesBottom,
          );
          point = snap.point;
          _guides = snap.guides;
        }
        final local = pageToParent(_dragDocument, o.id, point);
        final transform = resizeTransform(
          o.transform,
          _handle!,
          local,
          keepAspectRatio: shift || o.type == ObjectType.group,
          minSize: 4 * _unitsPerPixel(frame),
        );
        if (o.type == ObjectType.group) {
          _editor.previewObjects(resizeGroup(_dragDocument, o, transform));
          break;
        }
        var resized = o.copyWith(transform: transform);
        // Dragging a side of an auto-width text fixes its width.
        final payload = o.payload;
        if (payload is TextPayload &&
            payload.sizing == TextSizing.autoWidth &&
            (_handle!.movesLeft || _handle!.movesRight)) {
          resized = resized.copyWith(
            payload: payload.copyWith(sizing: TextSizing.autoHeight),
          );
        }
        _editor.previewObjects([resized]);
      case _Drag.rotate:
        final o = _dragStart.values.first;
        _editor.previewObjects([
          o.copyWith(
            transform: rotateTransform(
              o.transform,
              pageToParent(_dragDocument, o.id, p),
              snapDegrees: shift ? 15 : 0,
            ),
          ),
        ]);
      case _Drag.node:
        _nodeMove(p);
      case _Drag.none ||
          _Drag.guide ||
          _Drag.marquee ||
          _Drag.pan ||
          _Drag.draw ||
          _Drag.pen ||
          _Drag.pencil:
        break;
    }
    setState(() {});
  }

  void _pointerUp(PointerUpEvent event, List<PageFrame> frames) {
    switch (_drag) {
      case _Drag.move:
        final frame = _dragFrame;
        if (frame == null) {
          _editor.endGesture('Move');
        } else {
          _editor.endMoveGesture(_pagePoint(event.localPosition, frame));
        }
      case _Drag.resize:
        _editor.endGesture('Resize');
      case _Drag.rotate:
        _editor.endGesture('Rotate');
      case _Drag.marquee:
        _finishMarquee(frames);
      case _Drag.draw:
        _finishDraw();
      case _Drag.pencil:
        _finishPencil();
      case _Drag.node:
        _editor.endGesture('Edit path');
        _nodeObject = null;
        _nodeIndex = null;
      case _Drag.guide:
        if (_dragMoved) {
          ref.read(guideDragProvider.notifier).finish();
        } else {
          ref.read(guideDragProvider.notifier).value = null;
        }
      case _Drag.pan || _Drag.none || _Drag.pen:
        break;
    }
    _resetDrag();
  }

  /// Screen-space preview of the shape being drawn, or `null`.
  (Offset, Offset)? _drawPreview() {
    if (_drag != _Drag.draw || !_dragMoved) return null;
    var end = _lastScreen;
    final tool = _tool;
    if (HardwareKeyboard.instance.isShiftPressed) {
      final d = end - _downScreen;
      if (tool.isLine) {
        // Snap lines to 45°.
        final angle =
            (math.atan2(d.dy, d.dx) / (math.pi / 4)).round() * math.pi / 4;
        end =
            _downScreen + Offset(math.cos(angle), math.sin(angle)) * d.distance;
      } else {
        final side = math.max(d.dx.abs(), d.dy.abs());
        end = _downScreen + Offset(side * d.dx.sign, side * d.dy.sign);
      }
    }
    return (_downScreen, end);
  }

  void _finishDraw() {
    final frame = _dragFrame;
    final tool = _tool;
    final type = tool.objectType;
    if (frame == null || type == null) return;
    final preview = _drawPreview();

    if (tool == EditorTool.frame) {
      if (preview == null) {
        // A click places a 400 px-equivalent frame at the pointer.
        final size = 400 / frame.unitScale;
        _editor.insertFrame(
          width: size,
          height: size,
          topLeft: _downPage,
          pageId: frame.pageId,
        );
      } else {
        final box = _boxTransform(
          _pagePoint(preview.$1, frame),
          _pagePoint(preview.$2, frame),
        );
        _editor.insertFrame(
          width: math.max(box.width, 1 / frame.unitScale),
          height: math.max(box.height, 1 / frame.unitScale),
          topLeft: Point2D(box.x, box.y),
          pageId: frame.pageId,
        );
      }
      ref.read(toolProvider.notifier).reset();
      return;
    }

    if (tool == EditorTool.text) {
      final id = _editor.insertText(
        TextRole.body,
        topLeft: _downPage,
        pageId: frame.pageId,
        text: '',
      );
      ref.read(toolProvider.notifier).reset();
      _editor.startTextEdit(id);
      return;
    }

    if (preview == null) {
      // A click places a default-sized shape centred on the pointer.
      _editor.insertShape(type, at: _downPage, pageId: frame.pageId);
    } else {
      var a = _pagePoint(preview.$1, frame);
      var b = _pagePoint(preview.$2, frame);
      if (_snapping) {
        final page = ref.read(editorProvider)!.document.pages[frame.index];
        final targets = _collectTargets(
          ref.read(editorProvider)!.document,
          page,
        );
        a = targets.snapPoint(a, threshold: _snapDistance(frame)).point;
        if (!tool.isLine) {
          b = targets.snapPoint(b, threshold: _snapDistance(frame)).point;
        }
      }
      final transform =
          tool.isLine ? _lineTransform(a, b) : _boxTransform(a, b);
      _editor.insertDrawnShape(type, transform, pageId: frame.pageId);
    }
    ref.read(toolProvider.notifier).reset();
  }

  static ObjectTransform _boxTransform(Point2D a, Point2D b) => ObjectTransform(
    x: math.min(a.x, b.x),
    y: math.min(a.y, b.y),
    width: (a.x - b.x).abs(),
    height: (a.y - b.y).abs(),
  );

  /// Lines are stored flat (height 0) and rotated about their centre.
  static ObjectTransform _lineTransform(Point2D a, Point2D b) {
    final d = b - a;
    final length = d.length;
    final center = a + d * 0.5;
    return ObjectTransform(
      x: center.x - length / 2,
      y: center.y,
      width: length,
      height: 0,
      rotation: math.atan2(d.y, d.x) * 180 / math.pi,
    );
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

  // ------------------------------------------------------------ vector

  void _penDown(Offset screen, PageFrame frame) {
    if (_pen.isNotEmpty && _penPage != frame.pageId) _finishPen(closed: false);
    _penPage = frame.pageId;
    final session = ref.read(editorProvider)!;
    var p = _pagePoint(screen, frame);
    if (_snapping) {
      p =
          _collectTargets(
            session.document,
            session.document.pages[frame.index],
          ).snapPoint(p, threshold: _snapDistance(frame)).point;
    }
    final now = DateTime.now();
    final isDouble =
        now.difference(_lastPenClick) < const Duration(milliseconds: 400) &&
        (screen - _lastClickPosition).distance < 6;
    _lastPenClick = now;
    _lastClickPosition = screen;
    if (_pen.length >= 2) {
      final first = ref
          .read(viewportProvider)
          .toScreen(frame.toWorkspace(_pen.first.point));
      if ((first - screen).distance <= 8) {
        _finishPen(closed: true);
        return;
      }
    }
    if (isDouble && _pen.length >= 2) {
      _finishPen(closed: false);
      return;
    }
    _pen.add(PenAnchor(p));
    _dragFrame = frame;
    _drag = _Drag.pen;
    setState(() {});
  }

  /// Commits the pen path (two or more points) and returns to Move.
  void _finishPen({required bool closed}) {
    final page = _penPage;
    if (_pen.length >= 2 && page != null) {
      _editor.insertPath(List.of(_pen), closed: closed, pageId: page);
    }
    _pen.clear();
    _penHover = null;
    _penPage = null;
    if (ref.read(toolProvider).active == EditorTool.pen) {
      ref.read(toolProvider.notifier).reset();
    }
    if (mounted) setState(() {});
  }

  void _finishPencil() {
    final frame = _dragFrame;
    if (_pencil.length >= 2 && frame != null) {
      _editor.insertPath(
        smoothStroke(_pencil, tolerance: 1.5 * _unitsPerPixel(frame)),
        closed: false,
        pageId: frame.pageId,
        freehand: true,
      );
    }
    _pencil.clear();
  }

  /// Screen positions of path [id]'s anchors and handles.
  List<({Offset point, Offset? handleIn, Offset? handleOut})> _nodeScreen(
    DesignDocument document,
    ObjectId id,
    PageFrame frame,
  ) {
    final object = document.objects[id];
    if (object == null) return const [];
    final world = worldMatrix(document, id);
    final viewport = ref.read(viewportProvider);
    Offset screen(Point2D p) =>
        viewport.toScreen(frame.toWorkspace(world.apply(p)));
    return [
      for (final a in localAnchors(object).anchors)
        (
          point: screen(a.point),
          handleIn: a.handleIn == null ? null : screen(a.handleIn!),
          handleOut: a.handleOut == null ? null : screen(a.handleOut!),
        ),
    ];
  }

  /// The anchor (part 0) or handle (−1 in, 1 out) under [screen].
  (int, int)? _nodeAt(Offset screen, ObjectId id, PageFrame frame) {
    final nodes = _nodeScreen(ref.read(editorProvider)!.document, id, frame);
    for (final (i, n) in nodes.indexed) {
      if ((n.point - screen).distance <= 7) return (i, 0);
    }
    for (final (i, n) in nodes.indexed) {
      if (n.handleOut case final h? when (h - screen).distance <= 6) {
        return (i, 1);
      }
      if (n.handleIn case final h? when (h - screen).distance <= 6) {
        return (i, -1);
      }
    }
    return null;
  }

  void _nodeMove(Point2D page) {
    final object = _nodeObject;
    final index = _nodeIndex;
    if (object == null || index == null) return;
    final inverse = worldMatrix(_dragDocument, object.id).inverse();
    if (inverse == null) return;
    final local = inverse.apply(page);
    final anchors = [..._nodeStart];
    final a = anchors[index];
    final alt = HardwareKeyboard.instance.isAltPressed;
    switch (_nodePart) {
      case 0:
        anchors[index] = a.translated(local.x - a.point.x, local.y - a.point.y);
      case 1:
        anchors[index] = a.copyWith(
          handleOut: local,
          handleIn:
              alt || a.handleIn == null
                  ? a.handleIn
                  : _mirror(a.point, local, a.handleIn!),
        );
      default:
        anchors[index] = a.copyWith(
          handleIn: local,
          handleOut:
              alt || a.handleOut == null
                  ? a.handleOut
                  : _mirror(a.point, local, a.handleOut!),
        );
    }
    _editor.previewObjects([withAnchors(object, anchors, closed: _nodeClosed)]);
  }

  /// The opposite handle of [anchor], pointing away from [moved] and
  /// keeping [other]'s length (smooth node).
  static Point2D _mirror(Point2D anchor, Point2D moved, Point2D other) {
    final dx = anchor.x - moved.x;
    final dy = anchor.y - moved.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return other;
    final keep = (other - anchor).length;
    return Point2D(
      anchor.x + dx / length * keep,
      anchor.y + dy / length * keep,
    );
  }

  /// Screen arrows for prototype links whose source (or its frame) is
  /// selected, from the source's right edge to the target frame's left.
  List<(Offset, Offset)> _linkArrows(
    EditorSession session,
    List<PageFrame> frames,
    ViewportState viewport,
  ) {
    final page = session.activePage;
    if (page.links.isEmpty || session.selection.isEmpty) return const [];
    final frame = frames.where((f) => f.pageId == page.id).firstOrNull;
    if (frame == null) return const [];
    final document = session.document;
    final arrows = <(Offset, Offset)>[];
    for (final link in page.links) {
      final path = ancestorPath(document, link.source);
      if (!path.any(session.selection.contains)) continue;
      final from = worldBounds(document, link.source);
      final to = worldBounds(document, link.target);
      if (from == null || to == null) continue;
      Offset screen(double x, double y) =>
          viewport.toScreen(frame.toWorkspace(Point2D(x, y)));
      arrows.add((
        screen(from.right, from.top + from.height / 2),
        screen(to.left, to.top + math.min(to.height / 2, 120)),
      ));
    }
    return arrows;
  }

  /// What the painter draws for the pen, pencil and node editing.
  _VectorOverlay? _vectorOverlay(
    EditorSession session,
    List<PageFrame> frames,
    ViewportState viewport,
    NodeEdit? nodeEdit,
  ) {
    PageFrame? frameOf(PageId? id) =>
        frames.where((f) => f.pageId == id).firstOrNull;
    if (_pen.isNotEmpty) {
      final frame = frameOf(_penPage);
      if (frame == null) return null;
      Offset screen(Point2D p) => viewport.toScreen(frame.toWorkspace(p));
      return _VectorOverlay(
        path: [
          for (final a in _pen)
            (
              point: screen(a.point),
              handleIn: a.handleIn == null ? null : screen(a.handleIn!),
              handleOut: a.handleOut == null ? null : screen(a.handleOut!),
            ),
        ],
        hover: _drag == _Drag.none ? _penHover : null,
      );
    }
    if (_pencil.length > 1) {
      final frame = _dragFrame;
      if (frame == null) return null;
      return _VectorOverlay(
        stroke: [
          for (final p in _pencil) viewport.toScreen(frame.toWorkspace(p)),
        ],
      );
    }
    if (nodeEdit != null && session.selection.contains(nodeEdit.id)) {
      final frame = frameOf(session.state.activePageId);
      if (frame == null) return null;
      return _VectorOverlay(
        nodes: _nodeScreen(session.document, nodeEdit.id, frame),
        selectedNode: nodeEdit.anchor,
      );
    }
    return null;
  }

  /// The colour drawn at [point] on [frame]'s page (eyedropper): renders
  /// one screen pixel of the page, background included.
  Future<ArgbColor?> _sampleColor(PageFrame frame, Point2D point) async {
    final session = ref.read(editorProvider);
    if (session == null) return null;
    final page = session.document.pages[frame.index];
    final size = _unitsPerPixel(frame);
    final image = await renderRegion(
      session.document,
      page,
      region: Rect2D.fromLTWH(point.x, point.y, size, size),
      roots: page.objectIds,
      background: true,
      width: 1,
      height: 1,
      media: ref.read(mediaCacheProvider),
    );
    final rgba = await imageRgba(image);
    image.dispose();
    if (rgba.length < 4) return null;
    // Transparent pixels fall back to white (what the page shows).
    final a = rgba[3];
    int over(int v) => (v * a + 255 * (255 - a)) ~/ 255;
    return ArgbColor(
      0xFF000000 | (over(rgba[0]) << 16) | (over(rgba[1]) << 8) | over(rgba[2]),
    );
  }

  /// Snapping is on unless Alt is held.
  bool get _snapping => !HardwareKeyboard.instance.isAltPressed;

  /// Snap distance: 6 screen pixels in page units.
  double _snapDistance(PageFrame frame) => 6 * _unitsPerPixel(frame);

  void _resetDrag({bool cancel = false}) {
    _snapTargets = null;
    _dragStartBounds = null;
    _guides = const [];
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

  Future<void> _contextMenu(
    PointerDownEvent event,
    List<PageFrame> frames,
  ) async {
    final frame = _frameAt(event.localPosition, frames) ?? _activeFrame(frames);
    final hit = _objectAt(event.localPosition, frame);
    final session = ref.read(editorProvider)!;
    if (hit != null && !session.selection.contains(hit)) _editor.select({hit});
    if (hit == null && frame.pageId != session.state.activePageId) {
      _editor.setActivePage(frame.pageId);
    }
    final hasSelection = ref.read(editorProvider)!.selection.isNotEmpty;
    final canPaste = ref.read(clipboardProvider).isNotEmpty;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      event.position & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    PopupMenuEntry<VoidCallback> item(
      String label,
      String shortcut,
      VoidCallback? action,
    ) => PopupMenuItem<VoidCallback>(
      value: action,
      enabled: action != null,
      height: 32,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(shortcut, style: OcxText.caption(context)),
        ],
      ),
    );
    final action = await showMenu<VoidCallback>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        item('Cut', 'Ctrl+X', hasSelection ? _editor.cutSelection : null),
        item('Copy', 'Ctrl+C', hasSelection ? _editor.copySelection : null),
        item('Paste', 'Ctrl+V', canPaste ? _editor.paste : null),
        item(
          'Duplicate',
          'Ctrl+D',
          hasSelection ? _editor.duplicateSelection : null,
        ),
        item('Delete', 'Del', hasSelection ? _editor.deleteSelection : null),
        const PopupMenuDivider(height: 9),
        item(
          'Group',
          'Ctrl+G',
          _editor.canGroup ? _editor.groupSelection : null,
        ),
        item(
          'Ungroup',
          'Ctrl+Shift+G',
          _editor.canUngroup ? _editor.ungroupSelection : null,
        ),
        item(
          'Use as mask',
          'Ctrl+Alt+M',
          hasSelection ? _editor.useSelectionAsMask : null,
        ),
        item(
          'Create component',
          'Ctrl+Alt+K',
          hasSelection ? _editor.createComponent : null,
        ),
        const PopupMenuDivider(height: 9),
        item(
          'Bring to front',
          'Ctrl+Shift+]',
          hasSelection ? () => _editor.arrange(ZOrderMove.toFront) : null,
        ),
        item(
          'Bring forward',
          'Ctrl+]',
          hasSelection ? () => _editor.arrange(ZOrderMove.forward) : null,
        ),
        item(
          'Send backward',
          'Ctrl+[',
          hasSelection ? () => _editor.arrange(ZOrderMove.backward) : null,
        ),
        item(
          'Send to back',
          'Ctrl+Shift+[',
          hasSelection ? () => _editor.arrange(ZOrderMove.toBack) : null,
        ),
        const PopupMenuDivider(height: 9),
        item('Select all', 'Ctrl+A', _editor.selectAll),
      ],
    );
    action?.call();
    widget.focusNode.requestFocus();
  }

  void _drop(DragTargetDetails<ElementDrag> details, List<PageFrame> frames) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final frame = _frameAt(local, frames) ?? _activeFrame(frames);
    final page = ref.read(editorProvider)!.document.pages[frame.index];
    final p = _pagePoint(local, frame);
    // Boards have no edges; on pages, drops land inside the page.
    final at =
        page.isBoard
            ? p
            : Point2D(
              p.x.clamp(0, page.width).toDouble(),
              p.y.clamp(0, page.height).toDouble(),
            );
    switch (details.data) {
      case ShapeDrag(:final type):
        _editor.insertShape(type, pageId: frame.pageId, at: at);
      case TextDrag(:final role, :final restyle):
        _editor.insertText(
          role,
          pageId: frame.pageId,
          center: at,
          restyle: restyle,
        );
      case AssetDrag(:final item):
        final document = ref.read(editorProvider)!.document;
        final hit = hitTest(document, page, p);
        insertAssetItem(
          context,
          ref,
          item,
          at: at,
          pageId: frame.pageId,
          intoFrame: isMaskGroup(document.objects[hit]) ? hit : null,
        );
      case ImageFrameDrag(:final shape):
        _editor.insertImageFrame(shape, at: at, pageId: frame.pageId);
    }
    widget.focusNode.requestFocus();
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Screen-space geometry of a single selected object.
class _SelectionGeometry {
  _SelectionGeometry(this.handles, this.rotateHandle, this.rotateAnchor);

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

    final flat = t.height == 0;
    final handles = [
      for (final h in ResizeHandle.values)
        if (!flat || h == ResizeHandle.left || h == ResizeHandle.right)
          (h, screen(h.position(t.width, t.height))),
    ];
    final bottom = screen(Point2D(t.width / 2, t.height));
    var down = world.applyToVector(const Point2D(0, 1));
    if (t.scaleY < 0) down = down * -1;
    final length = down.length == 0 ? 1.0 : down.length;
    final dir = Offset(down.x / length, down.y / length);
    return _SelectionGeometry(handles, bottom + dir * _rotateOffset, bottom);
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
    required this.drawPreview,
    required this.drawIsLine,
    required this.dragLabel,
    required this.showHandles,
    required this.colors,
    required this.titles,
    required this.media,
    this.guides = const [],
    this.vector,
    this.links = const [],
  }) : super(repaint: media);

  final List<_FrameTitle> titles;
  final List<SnapGuide> guides;
  final _VectorOverlay? vector;
  final List<(Offset, Offset)> links;
  final MediaCache media;
  final DesignDocument document;
  final List<PageFrame> frames;
  final ViewportState viewport;
  final PageId activePageId;
  final Set<ObjectId> selection;
  final ObjectId? hovered;
  final Rect? marquee;
  final (Offset, Offset)? drawPreview;
  final bool drawIsLine;
  final String? dragLabel;
  final bool showHandles;
  final OcxColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRect(screen, Paint()..color = colors.workspace);

    PageFrame? active;
    for (final frame in frames) {
      final rect = viewport.rectToScreen(frame.rect);
      if (frame.pageId == activePageId) active = frame;
      if (frame.unbounded) {
        _paintBoard(canvas, size, frame);
        continue;
      }
      if (!rect.inflate(24).overlaps(screen)) continue;
      final page = document.pages[frame.index];
      canvas
        ..drawRect(
          rect.shift(const Offset(0, 1)),
          Paint()
            ..color = colors.pageShadow
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..save()
        ..clipRect(rect)
        ..translate(rect.left, rect.top)
        ..scale(viewport.zoom * frame.unitScale);
      paintPageBackground(canvas, page);
      paintPageContent(canvas, document, page, media: media);
      canvas.restore();
    }
    if (active == null) return;

    for (final title in titles) {
      final selected = selection.contains(title.id);
      final isHovered = hovered == title.id;
      title.painter.text = TextSpan(
        text: (title.painter.text! as TextSpan).text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: selected || isHovered ? colors.accent : colors.textSecondary,
        ),
      );
      title.painter
        ..layout(maxWidth: math.max(title.rect.width, 1) + 0.5)
        ..paint(canvas, title.rect.topLeft);
    }

    final outline =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.accent;

    final hover = hovered;
    if (hover != null && !selection.contains(hover)) {
      _drawPolygon(
        canvas,
        _corners(hover, active),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.accent.withValues(alpha: 0.6),
      );
    }
    if (showHandles) {
      // The group being edited stays outlined while working inside it.
      final entered = {
        for (final id in selection)
          if (document.objects[id]?.parentId case final parentId?) parentId,
      };
      for (final id in entered) {
        _drawPolygon(
          canvas,
          _corners(id, active),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = colors.accent.withValues(alpha: 0.35),
        );
      }
      for (final id in selection) {
        _drawPolygon(canvas, _corners(id, active), outline);
      }
    }
    if (showHandles && selection.length > 1) {
      final bounds = selectionBounds(document, selection);
      if (bounds != null) {
        final rect = Rect.fromPoints(
          viewport.toScreen(active.toWorkspace(bounds.topLeft)),
          viewport.toScreen(
            active.toWorkspace(Point2D(bounds.right, bounds.bottom)),
          ),
        );
        canvas.drawRect(rect, outline);
      }
    }
    if (showHandles && selection.length == 1) {
      final id = selection.first;
      final locked = document.objects[id]?.locked ?? false;
      final geometry = _SelectionGeometry.of(document, id, active, viewport);
      if (geometry != null && !locked) _drawHandles(canvas, geometry);
      if (geometry != null && dragLabel != null) {
        _drawLabel(
          canvas,
          geometry.rotateHandle + const Offset(0, 20),
          dragLabel!,
        );
      }
    }

    if (vector case final v?) _paintVector(canvas, v);
    _paintLinks(canvas);

    // Smart guides (P1.4.4): 1 px accent lines with end ticks.
    if (guides.isNotEmpty) {
      final guide =
          Paint()
            ..strokeWidth = 1
            ..color = colors.accent;
      for (final g in guides) {
        final a = viewport.toScreen(
          active.toWorkspace(
            g.vertical
                ? Point2D(g.position, g.start)
                : Point2D(g.start, g.position),
          ),
        );
        final b = viewport.toScreen(
          active.toWorkspace(
            g.vertical
                ? Point2D(g.position, g.end)
                : Point2D(g.end, g.position),
          ),
        );
        canvas.drawLine(a, b, guide);
        for (final end in [a, b]) {
          canvas
            ..drawLine(
              end - const Offset(3, 3),
              end + const Offset(3, 3),
              guide,
            )
            ..drawLine(
              end - const Offset(3, -3),
              end + const Offset(3, -3),
              guide,
            );
        }
      }
    }

    final m = marquee;
    if (m != null) {
      canvas
        ..drawRect(m, Paint()..color = colors.accent.withValues(alpha: 0.08))
        ..drawRect(m, outline);
    }

    final preview = drawPreview;
    if (preview != null) {
      if (drawIsLine) {
        canvas.drawLine(preview.$1, preview.$2, outline..strokeWidth = 1.5);
      } else {
        canvas.drawRect(Rect.fromPoints(preview.$1, preview.$2), outline);
      }
    }
  }

  /// A board: its background over the whole view, a dot grid when zoomed
  /// in, and its content without page clipping.
  void _paintBoard(Canvas canvas, Size size, PageFrame frame) {
    final page = document.pages[frame.index];
    final background = switch (page.background) {
      SolidBackground(:final color) => Color(color.value),
      _ => colors.workspace,
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final step = 24 * viewport.zoom;
    if (step >= 10) {
      final dot =
          Paint()
            ..color = (background.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white)
                .withValues(alpha: 0.12);
      final origin = viewport.pan;
      final startX = origin.dx % step;
      final startY = origin.dy % step;
      for (var x = startX; x < size.width; x += step) {
        for (var y = startY; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 0.9, dot);
        }
      }
    }
    canvas
      ..save()
      ..translate(viewport.pan.dx, viewport.pan.dy)
      ..scale(viewport.zoom)
      ..translate(frame.rect.left, frame.rect.top)
      ..scale(frame.unitScale);
    paintPageContent(canvas, document, page, media: media);
    canvas.restore();
  }

  /// Prototype links as curved accent arrows from source to frame.
  void _paintLinks(Canvas canvas) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.accent;
    for (final (from, to) in links) {
      final bend = math.max(40, (to.dx - from.dx).abs() / 2).toDouble();
      final path =
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(
              from.dx + bend,
              from.dy,
              to.dx - bend,
              to.dy,
              to.dx,
              to.dy,
            );
      canvas
        ..drawPath(path, paint)
        ..drawCircle(from, 3.5, Paint()..color = colors.accent)
        ..drawPath(
          Path()
            ..moveTo(to.dx, to.dy)
            ..lineTo(to.dx - 8, to.dy - 5)
            ..lineTo(to.dx - 8, to.dy + 5)
            ..close(),
          Paint()..color = colors.accent,
        );
    }
  }

  /// Pen path in progress (with a rubber band to the pointer), pencil
  /// stroke, or the anchors and handles of a path being edited.
  void _paintVector(Canvas canvas, _VectorOverlay v) {
    final accent =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.accent;
    final faint =
        Paint()
          ..strokeWidth = 1
          ..color = colors.accent.withValues(alpha: 0.5);
    final white = Paint()..color = Colors.white;
    final filled = Paint()..color = colors.accent;

    final stroke = v.stroke;
    if (stroke != null && stroke.length > 1) {
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, accent..strokeCap = StrokeCap.round);
    }

    final nodes = v.path ?? v.nodes;
    if (nodes == null || nodes.isEmpty) return;
    if (v.path != null) {
      final path = Path()..moveTo(nodes.first.point.dx, nodes.first.point.dy);
      for (var i = 1; i < nodes.length; i++) {
        final a = nodes[i - 1];
        final b = nodes[i];
        final c1 = a.handleOut ?? a.point;
        final c2 = b.handleIn ?? b.point;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.point.dx, b.point.dy);
      }
      canvas.drawPath(path, accent);
      if (v.hover case final hover?) {
        canvas.drawLine(nodes.last.point, hover, faint);
      }
    }
    for (final (i, n) in nodes.indexed) {
      for (final h in [n.handleIn, n.handleOut]) {
        if (h == null) continue;
        canvas
          ..drawLine(n.point, h, faint)
          ..drawCircle(h, 3.5, white)
          ..drawCircle(h, 3.5, accent..strokeWidth = 1);
      }
      final square = Rect.fromCenter(center: n.point, width: 7, height: 7);
      canvas
        ..drawRect(square, i == v.selectedNode ? filled : white)
        ..drawRect(square, accent..strokeWidth = 1);
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
          ..strokeWidth = 1
          ..color = colors.accent;
    canvas.drawLine(
      g.rotateAnchor,
      g.rotateHandle,
      Paint()
        ..strokeWidth = 1
        ..color = colors.accent.withValues(alpha: 0.5),
    );
    for (final (_, p) in g.handles) {
      final rect = Rect.fromCenter(center: p, width: 7, height: 7);
      canvas
        ..drawRect(rect, fill)
        ..drawRect(rect, border);
    }
    canvas
      ..drawCircle(g.rotateHandle, 4, fill)
      ..drawCircle(g.rotateHandle, 4, border);
  }

  void _drawLabel(Canvas canvas, Offset center, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: center,
      width: painter.width + 12,
      height: painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(Radii.xs)),
      Paint()..color = const Color(0xFF1F2128),
    );
    painter.paint(canvas, box.topLeft + const Offset(6, 3));
  }

  @override
  bool shouldRepaint(_WorkspacePainter old) =>
      !identical(old.document, document) ||
      old.viewport != viewport ||
      old.activePageId != activePageId ||
      old.selection != selection ||
      old.hovered != hovered ||
      old.marquee != marquee ||
      old.drawPreview != drawPreview ||
      old.dragLabel != dragLabel ||
      old.showHandles != showHandles ||
      old.colors != colors;
}

/// Page title above each page (caption style, design-system.md §7).
class _PageTitle extends ConsumerWidget {
  const _PageTitle({
    required this.frame,
    required this.rect,
    required this.page,
    required this.isActive,
  });

  final PageFrame frame;
  final Rect rect;
  final DesignPage page;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rect.width < 60) return const SizedBox.shrink();
    final c = context.ocx;
    final label =
        page.name.isEmpty
            ? 'Page ${frame.index + 1}'
            : '${frame.index + 1}. ${page.name}';
    return Positioned(
      left: rect.left,
      top: rect.top - 22,
      width: rect.width,
      height: 18,
      child: GestureDetector(
        onTap: () => ref.read(editorProvider.notifier).setActivePage(page.id),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OcxText.caption(
            context,
          ).copyWith(color: isActive ? c.text : c.textSecondary),
        ),
      ),
    );
  }
}

/// A frame's name label on the canvas (click to select, drag to move).
class _FrameTitle {
  _FrameTitle({required this.id, required this.painter, required this.rect});

  final ObjectId id;
  final TextPainter painter;
  final Rect rect;
}

/// Screen-space vector editing state for the painter.
class _VectorOverlay {
  const _VectorOverlay({
    this.path,
    this.hover,
    this.stroke,
    this.nodes,
    this.selectedNode,
  });

  /// Pen anchors placed so far.
  final List<({Offset point, Offset? handleIn, Offset? handleOut})>? path;

  /// Pointer position for the pen's rubber band.
  final Offset? hover;

  /// Pencil stroke points.
  final List<Offset>? stroke;

  /// Anchors of the path being node-edited.
  final List<({Offset point, Offset? handleIn, Offset? handleOut})>? nodes;
  final int? selectedNode;
}
