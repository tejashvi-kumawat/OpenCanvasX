import 'dart:math' as math;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

import '../editor/editor_controller.dart';

/// One screen of the player: a page, or a frame on a board.
@immutable
class _Screen {
  const _Screen(this.page, this.region, this.roots, {this.frame});

  final DesignPage page;
  final Rect2D region;
  final List<ObjectId> roots;

  /// The frame shown, for boards (prototype navigation targets it).
  final ObjectId? frame;
}

/// Opens present mode (P3.6.3, prototyping): a slideshow of the pages, or
/// — on a board — a clickable prototype of its frames.
Future<void> presentDesign(BuildContext context) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => const PresentPage(),
    transitionsBuilder:
        (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
  ),
);

/// Full-window player. Pages: click, →, Space or PageDown for next; ←
/// for previous. Boards: click linked objects to follow prototype links;
/// ← goes back. Escape leaves.
class PresentPage extends ConsumerStatefulWidget {
  const PresentPage({super.key});

  @override
  ConsumerState<PresentPage> createState() => _PresentPageState();
}

class _PresentPageState extends ConsumerState<PresentPage> {
  final FocusNode _focus = FocusNode(debugLabel: 'present');
  late final List<_Screen> _screens;
  late final bool _prototype;
  int _index = 0;
  final List<int> _history = [];
  PrototypeTransition _transition = PrototypeTransition.dissolve;
  bool _forward = true;
  bool _hoverLink = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(editorProvider)!;
    final document = session.document;
    final active = session.activePage;
    _prototype = active.isBoard;
    if (_prototype) {
      final frames = [
        for (final id in active.objectIds)
          if (document.objects[id] case final o?
              when o.type == ObjectType.frame && !o.hidden)
            o,
      ];
      // Reading order: rows top to bottom, then left to right.
      frames.sort((a, b) {
        final ta = a.transform;
        final tb = b.transform;
        final dy = ta.y - tb.y;
        if (dy.abs() > math.min(ta.height, tb.height) / 2) {
          return dy.sign.toInt();
        }
        return ta.x.compareTo(tb.x);
      });
      _screens = [
        for (final f in frames)
          if (worldBounds(document, f.id) case final b?)
            _Screen(active, b, [f.id], frame: f.id),
      ];
      // Start on the frame holding the selection, if any.
      final selected = session.selection.firstOrNull;
      if (selected != null) {
        final root = ancestorPath(document, selected).first;
        final i = _screens.indexWhere((s) => s.frame == root);
        if (i >= 0) _index = i;
      }
    } else {
      _screens = [
        for (final page in document.pages)
          if (!page.isBoard)
            _Screen(
              page,
              Rect2D.fromLTWH(0, 0, page.width, page.height),
              page.objectIds,
            ),
      ];
      _index = math.max(0, _screens.indexWhere((s) => s.page.id == active.id));
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _go(int index, {PrototypeTransition? transition, bool back = false}) {
    if (index < 0 || index >= _screens.length || index == _index) return;
    setState(() {
      if (!back) _history.add(_index);
      _transition =
          transition ??
          (_prototype
              ? PrototypeTransition.dissolve
              : PrototypeTransition.slideLeft);
      _forward = !back && index > _index || (!back && _prototype);
      _index = index;
    });
  }

  void _next() {
    if (!_prototype) _go(_index + 1);
  }

  void _previous() {
    if (_prototype) {
      if (_history.isEmpty) return;
      final to = _history.removeLast();
      setState(() {
        _transition = PrototypeTransition.dissolve;
        _forward = false;
        _index = to;
      });
    } else if (_index > 0) {
      setState(() {
        _transition = PrototypeTransition.slideRight;
        _forward = false;
        _index--;
      });
    }
  }

  /// The prototype link under page point [p] on the current screen.
  PrototypeLink? _linkAt(DesignDocument document, Point2D p) {
    final screen = _screens[_index];
    final hit = hitTestDeep(document, screen.page, p);
    if (hit == null) return null;
    for (final id in ancestorPath(document, hit).reversed) {
      for (final link in screen.page.links) {
        if (link.source == id) return link;
      }
    }
    return null;
  }

  Point2D? _pagePoint(Offset local, Size size) {
    final r = _screens[_index].region;
    final scale = math.min(size.width / r.width, size.height / r.height);
    final dx = (size.width - r.width * scale) / 2;
    final dy = (size.height - r.height * scale) / 2;
    final x = (local.dx - dx) / scale + r.left;
    final y = (local.dy - dy) / scale + r.top;
    if (x < r.left || y < r.top || x > r.right || y > r.bottom) return null;
    return Point2D(x, y);
  }

  void _tap(Offset local, Size size, DesignDocument document) {
    if (!_prototype) {
      _next();
      return;
    }
    final p = _pagePoint(local, size);
    if (p == null) return;
    final link = _linkAt(document, p);
    if (link == null) return;
    final target = _screens.indexWhere((s) => s.frame == link.target);
    if (target >= 0) _go(target, transition: link.transition);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorProvider);
    if (session == null || _screens.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _prototype
                  ? 'Add frames to this board to present it. Press Esc.'
                  : 'Nothing to present. Press Esc.',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }
    final document = session.document;
    final screen = _screens[_index];
    final media = ref.watch(mediaCacheProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape):
            () => Navigator.pop(context),
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.space): _next,
        const SingleActivator(LogicalKeyboardKey.pageDown): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
        const SingleActivator(LogicalKeyboardKey.pageUp): _previous,
        const SingleActivator(LogicalKeyboardKey.home): () => _go(0),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF0B0C0E),
          body: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return MouseRegion(
                      cursor:
                          _hoverLink || !_prototype
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                      onHover: (e) {
                        if (!_prototype) return;
                        final p = _pagePoint(e.localPosition, size);
                        final over = p != null && _linkAt(document, p) != null;
                        if (over != _hoverLink) {
                          setState(() => _hoverLink = over);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _tap(d.localPosition, size, document),
                        child: AnimatedSwitcher(
                          duration:
                              _transition == PrototypeTransition.instant
                                  ? Duration.zero
                                  : const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: _transitionBuilder,
                          child: CustomPaint(
                            key: ValueKey(_index),
                            size: size,
                            painter: _ScreenPainter(document, screen, media),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _Hud(
                  label:
                      _prototype
                          ? (document.objects[screen.frame]?.name ?? 'Frame')
                          : '${_index + 1} / ${_screens.length}',
                  onPrevious: _previous,
                  onNext: _prototype ? null : _next,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transitionBuilder(Widget child, Animation<double> animation) {
    final incoming = child.key == ValueKey(_index);
    Offset from() => switch (_transition) {
      PrototypeTransition.slideLeft => const Offset(1, 0),
      PrototypeTransition.slideRight => const Offset(-1, 0),
      PrototypeTransition.slideUp => const Offset(0, 1),
      PrototypeTransition.instant ||
      PrototypeTransition.dissolve => Offset.zero,
    };
    if (_transition == PrototypeTransition.dissolve ||
        _transition == PrototypeTransition.instant) {
      return FadeTransition(opacity: animation, child: child);
    }
    final begin = incoming ? from() : -from();
    return SlideTransition(
      position: Tween(
        begin: _forward ? begin : -begin,
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }
}

class _ScreenPainter extends CustomPainter {
  _ScreenPainter(this.document, this.screen, this.media)
    : super(repaint: media);

  final DesignDocument document;
  final _Screen screen;
  final MediaCache media;

  @override
  void paint(Canvas canvas, Size size) {
    final r = screen.region;
    if (r.width <= 0 || r.height <= 0) return;
    final scale = math.min(size.width / r.width, size.height / r.height);
    final dx = (size.width - r.width * scale) / 2;
    final dy = (size.height - r.height * scale) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale)
      ..translate(-r.left, -r.top)
      ..clipRect(Rect.fromLTWH(r.left, r.top, r.width, r.height));
    if (screen.frame == null) {
      paintPageBackground(
        canvas,
        screen.page,
        checkerboardForTransparent: false,
      );
    }
    for (final id in screen.roots) {
      final o = document.objects[id];
      if (o != null) paintObject(canvas, document, o, media: media);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScreenPainter old) =>
      !identical(old.document, document) || old.screen != screen;
}

/// Small translucent controls in the corner.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.label,
    required this.onPrevious,
    required this.onClose,
    this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xCC1F2128),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous  (←)',
            color: Colors.white70,
            iconSize: 18,
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          if (onNext != null)
            IconButton(
              tooltip: 'Next  (→)',
              color: Colors.white70,
              iconSize: 18,
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          IconButton(
            tooltip: 'Exit  (Esc)',
            color: Colors.white70,
            iconSize: 18,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
