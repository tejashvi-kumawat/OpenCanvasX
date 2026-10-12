import 'dart:async';
import 'dart:math' as math;

import 'package:asset_engine/asset_engine.dart';
import 'package:design_engine/design_engine.dart'
    hide
        addPage,
        deletePage,
        duplicatePage,
        movePage,
        setLayerOrder,
        updatePage;
import 'package:design_engine/design_engine.dart'
    as engine
    show
        addPage,
        deletePage,
        duplicatePage,
        movePage,
        setLayerOrder,
        updatePage;
import 'package:document_model/document_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugins_sdk/plugins_sdk.dart' show PluginEffect;
import 'package:storage/storage.dart';
import 'package:template_engine/template_engine.dart' as tpl;

import 'package:renderer/renderer.dart' as renderer;

import '../providers.dart';
import 'viewport.dart';

/// Decoded images and SVGs of the open design (and bundled assets shown in
/// panels), keyed by content hash.
final mediaCacheProvider = Provider<renderer.MediaCache>((ref) {
  final cache = renderer.MediaCache();
  ref.onDispose(cache.dispose);
  return cache;
});

/// The path whose nodes are being edited (P2.6.2) and its selected anchor.
@immutable
class NodeEdit {
  const NodeEdit(this.id, {this.anchor});

  final ObjectId id;
  final int? anchor;
}

/// While set, the next canvas click samples a colour and passes it here
/// (eyedropper, P1.7.1).
final eyedropperProvider =
    NotifierProvider<EyedropperController, ValueChanged<ArgbColor>?>(
      EyedropperController.new,
    );

class EyedropperController extends Notifier<ValueChanged<ArgbColor>?> {
  @override
  ValueChanged<ArgbColor>? build() => null;

  ValueChanged<ArgbColor>? get pick => state;
  set pick(ValueChanged<ArgbColor>? value) => state = value;
}

final nodeEditProvider = NotifierProvider<NodeEditController, NodeEdit?>(
  NodeEditController.new,
);

class NodeEditController extends Notifier<NodeEdit?> {
  @override
  NodeEdit? build() => null;

  NodeEdit? get value => state;
  set value(NodeEdit? next) => state = next;
}

/// Where the open design stands relative to its file.
enum SaveStatus {
  /// Everything is on disk.
  saved,

  /// Edits are waiting for the autosave quiet period.
  pending,

  /// A save is running.
  saving,

  /// The last save failed; edits are kept and retried.
  failed,
}

/// The design being edited and everything the editor chrome shows about it.
@immutable
class EditorSession {
  const EditorSession({
    required this.path,
    required this.state,
    this.saveStatus = SaveStatus.saved,
    this.undoLabel,
    this.redoLabel,
  });

  final String path;
  final EditorState state;
  final SaveStatus saveStatus;
  final String? undoLabel;
  final String? redoLabel;

  DesignDocument get document => state.document;
  DesignPage get activePage => state.activePage;
  Set<ObjectId> get selection => state.selection;
  bool get canUndo => undoLabel != null;
  bool get canRedo => redoLabel != null;

  EditorSession copyWith({
    EditorState? state,
    SaveStatus? saveStatus,
    String? undoLabel,
    String? redoLabel,
    bool clearUndo = false,
    bool clearRedo = false,
  }) => EditorSession(
    path: path,
    state: state ?? this.state,
    saveStatus: saveStatus ?? this.saveStatus,
    undoLabel: clearUndo ? null : (undoLabel ?? this.undoLabel),
    redoLabel: clearRedo ? null : (redoLabel ?? this.redoLabel),
  );
}

/// Measures text boxes in page units; tests may replace it.
typedef TextMeasurer = Point2D Function(TextPayload text, {double? width});

final textMeasurerProvider = Provider<TextMeasurer>(
  (ref) => renderer.measureText,
);

/// The text object being edited inline on the canvas, if any.
final textEditingProvider = NotifierProvider<TextEditingTarget, ObjectId?>(
  TextEditingTarget.new,
);

class TextEditingTarget extends Notifier<ObjectId?> {
  @override
  ObjectId? build() => null;

  ObjectId? get id => state;
  set id(ObjectId? value) => state = value;
}

/// Quiet period before autosave writes the design file.
final autosaveDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 800),
);

/// Objects copied with Ctrl+C, shared across designs (P1.3.7).
final clipboardProvider =
    NotifierProvider<ClipboardController, List<DesignObject>>(
      ClipboardController.new,
    );

class ClipboardController extends Notifier<List<DesignObject>> {
  @override
  List<DesignObject> build() => const [];

  void set(List<DesignObject> objects) => state = List.unmodifiable(objects);
}

/// The open design, or `null` on the home screen.
final editorProvider = NotifierProvider<EditorController, EditorSession?>(
  EditorController.new,
);

/// Result of opening a design, for the UI to explain recovery.
enum OpenNotice { none, recoveredFromAutosave, newerAutosaveAvailable }

class EditorController extends Notifier<EditorSession?> {
  final History _history = History();
  Autosaver? _autosaver;

  /// Document before a drag started, and the live objects of that drag.
  DesignDocument? _gestureBase;
  final Map<ObjectId, DesignObject> _gestureObjects = {};

  @override
  EditorSession? build() {
    ref.onDispose(() => _autosaver?.dispose());
    return null;
  }

  EditorSession get _session {
    final session = state;
    if (session == null) throw StateError('No design is open');
    return session;
  }

  EditorState get _editor => _session.state;

  // ------------------------------------------------------------ lifecycle

  /// Opens the design at [path].
  Future<OpenNotice> open(String path) async {
    final opened = await ref.read(designLibraryProvider).open(path);
    _start(path, opened.contents.document, assets: opened.contents.assets);
    if (opened.source == ProjectSource.autosave) {
      return OpenNotice.recoveredFromAutosave;
    }
    return opened.newerAutosaveAvailable
        ? OpenNotice.newerAutosaveAvailable
        : OpenNotice.none;
  }

  /// Starts editing an already loaded [document] saved at [path]. With
  /// [unsaved] (e.g. a restored backup) it is written back promptly.
  void start(
    String path,
    DesignDocument document, {
    bool unsaved = false,
    Map<String, Uint8List> assets = const {},
  }) {
    _start(path, document, assets: assets);
    if (unsaved) {
      _setStatus(SaveStatus.pending);
      _autosaver?.markDirty();
    }
  }

  void _start(
    String path,
    DesignDocument document, {
    Map<String, Uint8List> assets = const {},
  }) {
    final media = ref.read(mediaCacheProvider)..clear();
    for (final MapEntry(key: hash, value: info) in document.assets.entries) {
      if (assets[hash] case final bytes?) {
        media.register(hash, bytes, info.mime);
      }
    }
    _autosaver?.dispose();
    _history.clear();
    _gestureBase = null;
    _gestureObjects.clear();
    ref.read(textEditingProvider.notifier).id = null;
    _autosaver = Autosaver(
      delay: ref.read(autosaveDelayProvider),
      save: _save,
      onError: (_, _) => _setStatus(SaveStatus.failed),
    );
    state = EditorSession(path: path, state: EditorState.initial(document));
    ref
        .read(appIndexProvider)
        .recent
        .record(
          path: path,
          title: document.metadata.title,
          documentId: document.id.value,
        );
  }

  /// Saves pending edits and leaves the editor.
  Future<void> close() async {
    final autosaver = _autosaver;
    if (autosaver != null) {
      await autosaver.flush();
      autosaver.dispose();
    }
    _autosaver = null;
    _history.clear();
    state = null;
    ref.invalidate(designsProvider);
  }

  /// Writes the design now (Ctrl+S).
  Future<void> saveNow() async => _autosaver?.flush();

  Future<void> _save() async {
    final session = state;
    if (session == null) return;
    _setStatus(SaveStatus.saving);
    final document = session.document;
    final stamped = DesignDocument(
      id: document.id,
      metadata: document.metadata.copyWith(modifiedAt: DateTime.now()),
      pages: document.pages,
      objects: document.objects,
      styles: document.styles,
      assets: document.assets,
    );
    final media = ref.read(mediaCacheProvider);
    await ref
        .read(designLibraryProvider)
        .save(
          session.path,
          stamped,
          assets: {
            for (final hash in stamped.assets.keys)
              if (media.bytesOf(hash) case final bytes?) hash: bytes,
          },
        );
    _setStatus(
      (_autosaver?.isDirty ?? false) ? SaveStatus.pending : SaveStatus.saved,
    );
  }

  void _setStatus(SaveStatus status) {
    final session = state;
    if (session != null) state = session.copyWith(saveStatus: status);
  }

  // ------------------------------------------------------- state plumbing

  void _commit(Change change, {Set<ObjectId>? select, PageId? activePage}) {
    final document = _history.apply(_editor.document, change);
    _publish(
      _editor.copyWith(
        document: document,
        selection: select,
        activePageId: activePage,
      ),
      edited: !change.isEmpty,
    );
  }

  void _publish(EditorState next, {required bool edited}) {
    state = _session.copyWith(
      state: next,
      undoLabel: _history.undoLabel,
      redoLabel: _history.redoLabel,
      clearUndo: !_history.canUndo,
      clearRedo: !_history.canRedo,
      saveStatus: edited ? SaveStatus.pending : null,
    );
    if (edited) _autosaver?.markDirty();
  }

  // ------------------------------------------------------------- history

  void undo() {
    if (!_history.canUndo) return;
    _cancelGesture();
    _publish(
      _editor.copyWith(document: _history.undo(_editor.document)),
      edited: true,
    );
  }

  void redo() {
    if (!_history.canRedo) return;
    _cancelGesture();
    _publish(
      _editor.copyWith(document: _history.redo(_editor.document)),
      edited: true,
    );
  }

  // ----------------------------------------------------------- selection

  void select(Iterable<ObjectId> ids) =>
      _publish(_editor.copyWith(selection: ids.toSet()), edited: false);

  void toggleSelected(ObjectId id) {
    final next = {..._editor.selection};
    if (!next.remove(id)) next.add(id);
    select(next);
  }

  void clearSelection() => select(const {});

  /// Selects every visible, unlocked object on the active page.
  void selectAll() => select([
    for (final id in _editor.activePage.objectIds)
      if (_editor.document.objects[id] case final o?
          when !o.hidden && !o.locked)
        id,
  ]);

  void setActivePage(PageId id) {
    if (id == _editor.activePageId) return;
    final next = _editor.document.pages.where((p) => p.id == id).firstOrNull;
    // Boards and stacked pages lay the workspace out differently: refit.
    if ((next?.isBoard ?? false) || _editor.activePage.isBoard) {
      ref.read(viewportProvider.notifier).reset();
    }
    _publish(
      _editor.copyWith(activePageId: id, selection: const {}),
      edited: false,
    );
  }

  // ------------------------------------------------------------- objects

  /// Adds a default [type] shape to the active page, centred on [at]
  /// (page units) or the page centre, and selects it.
  void insertShape(ObjectType type, {Point2D? at, PageId? pageId}) {
    final document = _editor.document;
    final page =
        pageId == null
            ? _editor.activePage
            : document.pages.firstWhere((p) => p.id == pageId);
    final center = at ?? _boardCenter(page);
    final shape = newShape(type, page, id: ObjectId.generate(), center: center);
    _commit(
      _intoFrame(
        insertObjects(document, page.id, [
          shape,
        ], label: 'Add ${typeLabel(type)}'),
        [shape.id],
        page.id,
        center ?? _centerOf(shape.transform),
      ),
      activePage: page.id,
      select: {shape.id},
    );
  }

  /// Places an image or SVG (P1.6.1, P1.6.2): validates [bytes], stores
  /// them by content hash and adds an image object sized to fit, centred
  /// on [at] (the view or page centre by default). Returns the new id, or
  /// throws [FormatException] with a user-facing message.
  ///
  /// [tint] recolours monochrome SVG icons; [licenseRef] records where a
  /// bundled asset came from; [size] is the longer side in page units
  /// (default: up to half the page).
  ObjectId insertImage(
    Uint8List bytes, {
    String? name,
    String? licenseRef,
    ArgbColor? tint,
    Point2D? at,
    double? size,
    double? sizePx,
    PageId? pageId,
  }) {
    final check = checkMedia(bytes);
    if (!check.isOk) throw FormatException(check.error!);
    final document = _editor.document;
    final page =
        pageId == null
            ? _editor.activePage
            : document.pages.firstWhere((p) => p.id == pageId);
    final hash = sha256Hex(bytes);
    ref.read(mediaCacheProvider).register(hash, bytes, check.mime!);

    final w = check.width!.toDouble();
    final h = check.height!.toDouble();
    final pxToUnit = convertLength(
      1,
      from: LengthUnit.px,
      to: page.unit,
      dpi: page.dpi,
    );
    final longest =
        size ??
        (sizePx == null ? null : sizePx * pxToUnit) ??
        math.min(
          math.max(w, h) * pxToUnit,
          page.isBoard ? 800 * pxToUnit : math.min(page.width, page.height) / 2,
        );
    final scale = longest / math.max(w, h);
    final center =
        at ?? _boardCenter(page) ?? Point2D(page.width / 2, page.height / 2);
    final image = newImage(
      id: ObjectId.generate(),
      pageId: page.id,
      assetHash: hash,
      width: w * scale,
      height: h * scale,
      center: center,
      name: name,
      tint: tint,
    );
    final insert = insertObjects(document, page.id, [
      image,
    ], label: 'Add image');
    final withAsset = Change(
      label: insert.label,
      objects: insert.objects,
      pages: insert.pages,
      assets: {
        if (!document.assets.containsKey(hash))
          hash: AssetInfo(
            mime: check.mime!,
            byteLength: bytes.length,
            licenseRef: licenseRef,
          ),
      },
    );
    _commit(
      _intoFrame(withAsset, [image.id], page.id, center),
      activePage: page.id,
      select: {image.id},
    );
    return image.id;
  }

  /// Adds template [contents] (P2.2.4): as frames on a board, otherwise as
  /// new pages after the active one. One undo step; selects new frames.
  void insertTemplate(ProjectContents contents) {
    final page = _editor.activePage;
    final media = ref.read(mediaCacheProvider);
    for (final MapEntry(key: hash, value: info)
        in contents.document.assets.entries) {
      if (contents.assets[hash] case final bytes?) {
        media.register(hash, bytes, info.mime);
      }
    }
    final result = tpl.insertTemplate(
      _editor.document,
      contents.document,
      after: page.id,
      asFramesOn: page.isBoard ? page.id : null,
    );
    // Moving between a board and stacked pages lays the view out anew.
    final first = contents.document.pages.first;
    if (!page.isBoard && first.isBoard) {
      ref.read(viewportProvider.notifier).reset();
    }
    if (page.isBoard) {
      _commit(result.change, select: result.frames.toSet());
    } else {
      _commit(result.change, activePage: result.pages.first, select: const {});
    }
  }

  /// Adds a vector path through [anchors] (page coordinates of [pageId])
  /// drawn with the pen or pencil (P2.6.1, P2.6.3): a dark stroke, no
  /// fill; objects drawn over a frame go into it. Returns the new id.
  ObjectId insertPath(
    List<PenAnchor> anchors, {
    required bool closed,
    required PageId pageId,
    bool freehand = false,
  }) {
    final document = _editor.document;
    final page = document.pages.firstWhere((p) => p.id == pageId);
    final width =
        newShape(
          ObjectType.line,
          page,
          id: const ObjectId('_'),
        ).style!.stroke!.width;
    final path = newPathObject(
      id: ObjectId.generate(),
      pageId: pageId,
      anchors: anchors,
      closed: closed,
      name: freehand ? 'Drawing' : null,
      style: ObjectStyle(stroke: Stroke(color: defaultTextColor, width: width)),
    );
    final b = path.transform;
    _commit(
      _intoFrame(
        insertObjects(document, pageId, [
          path,
        ], label: freehand ? 'Draw' : 'Add path'),
        [path.id],
        pageId,
        Point2D(b.x + b.width / 2, b.y + b.height / 2),
      ),
      activePage: pageId,
      select: {path.id},
    );
    return path.id;
  }

  /// Applies a plugin's result (P6.1.4) as one undo step named after the
  /// plugin, registering any new asset bytes, and selects what it created.
  void applyPluginEffect(PluginEffect effect, {required String name}) {
    final media = ref.read(mediaCacheProvider);
    for (final MapEntry(key: hash, value: bytes) in effect.assets.entries) {
      media.register(hash, bytes, 'image/svg+xml');
    }
    if (effect.change.isEmpty) return;
    _commit(
      Change(
        label: name,
        objects: effect.change.objects,
        pages: effect.change.pages,
        assets: effect.change.assets,
      ),
      select: effect.created.isEmpty ? null : effect.created.toSet(),
    );
  }

  /// Turns the selection into a main component (Ctrl+Alt+K).
  void createComponent() {
    final selected = _editor.selectedObjects;
    if (selected.isEmpty ||
        selected.any((o) => o.parentId != selected.first.parentId)) {
      return;
    }
    final (change, id) = makeComponent(_editor.document, _editor.selection);
    if (id != null) _commit(change, select: {id});
  }

  /// Adds an instance of [componentId] at [at] (the view or page centre
  /// by default); dropped on a frame it goes inside.
  ObjectId? insertInstance(
    ObjectId componentId, {
    Point2D? at,
    PageId? pageId,
  }) {
    final component = _editor.document.objects[componentId];
    if (!isComponent(component)) return null;
    final page =
        pageId == null
            ? _editor.activePage
            : _editor.document.pages.firstWhere((p) => p.id == pageId);
    // Default: beside the component when it is on this page.
    final bounds = worldBounds(_editor.document, componentId);
    final besideComponent =
        bounds != null &&
                rootOf(_editor.document, componentId)?.pageId == page.id
            ? Point2D(
              bounds.right + bounds.width * 0.1 + bounds.width / 2,
              bounds.top + bounds.height / 2,
            )
            : null;
    final center =
        at ??
        besideComponent ??
        _boardCenter(page) ??
        Point2D(page.width / 2, page.height / 2);
    final instance = newInstance(
      id: ObjectId.generate(),
      pageId: page.id,
      component: component!,
      center: center,
    );
    _commit(
      _intoFrame(
        insertObjects(_editor.document, page.id, [
          instance,
        ], label: 'Add instance'),
        [instance.id],
        page.id,
        center,
        // Never inside its own component.
        exclude: {componentId},
      ),
      activePage: page.id,
      select: {instance.id},
    );
    return instance.id;
  }

  /// Detaches selected instances into editable frames (Ctrl+Alt+B).
  void detachSelection() {
    var document = _editor.document;
    final objects = <ObjectId, DesignObject?>{};
    List<DesignPage>? pages;
    final created = <ObjectId>{};
    for (final o in _editor.selectedObjects) {
      if (o.type != ObjectType.instance) continue;
      final (change, id) = detachInstance(document, o.id);
      if (id == null) continue;
      document = change.applyTo(document).$1;
      objects.addAll(change.objects);
      if (change.pages != null) pages = change.pages;
      created.add(id);
    }
    if (created.isEmpty) return;
    _commit(
      Change(label: 'Detach instance', objects: objects, pages: pages),
      select: created,
    );
  }

  /// Selects the main component of instance [id], switching page.
  void goToMainComponent(ObjectId id) {
    final payload = _editor.document.objects[id]?.payload;
    if (payload is! InstancePayload) return;
    final component = _editor.document.objects[payload.componentId];
    if (component == null) return;
    final root = rootOf(_editor.document, component.id);
    if (root?.pageId case final page?) setActivePage(page);
    select({component.id});
  }

  /// Links [source] to frame [target] on the active page (prototyping);
  /// a `null` target removes the link.
  void setLink(
    ObjectId source,
    ObjectId? target, {
    PrototypeTransition transition = PrototypeTransition.dissolve,
  }) => _commit(
    setPrototypeLink(
      _editor.document,
      _editor.activePageId,
      source,
      target,
      transition: transition,
    ),
  );

  /// Removes anchor [index] of path [id] (at least two stay).
  void deletePathAnchor(ObjectId id, int index) {
    final object = _editor.document.objects[id];
    if (object == null) return;
    final (:anchors, :closed) = localAnchors(object);
    if (anchors.length <= 2 || index < 0 || index >= anchors.length) return;
    _commit(
      updateObjects(_editor.document, [
        withAnchors(object, [...anchors]..removeAt(index), closed: closed),
      ], label: 'Delete point'),
    );
  }

  /// Adds a frame (artboard). Without [topLeft] it is centred in the view
  /// on boards, or on the page. Frames inside frames nest.
  ObjectId insertFrame({
    required double width,
    required double height,
    String? name,
    Point2D? topLeft,
    PageId? pageId,
  }) {
    final document = _editor.document;
    final page =
        pageId == null
            ? _editor.activePage
            : document.pages.firstWhere((p) => p.id == pageId);
    final center =
        _boardCenter(page) ?? Point2D(page.width / 2, page.height / 2);
    final at = topLeft ?? Point2D(center.x - width / 2, center.y - height / 2);
    final frame = newFrame(
      id: ObjectId.generate(),
      pageId: page.id,
      width: width,
      height: height,
      at: at,
      name: name,
    );
    _commit(
      _intoFrame(
        insertObjects(document, page.id, [frame], label: 'Add frame'),
        [frame.id],
        page.id,
        _centerOf(frame.transform),
      ),
      activePage: page.id,
      select: {frame.id},
    );
    return frame.id;
  }

  /// Wraps the selection in a frame fitted to it (Ctrl+Alt+G).
  void frameSelection() {
    final selected = _editor.selectedObjects;
    if (selected.isEmpty ||
        selected.any((o) => o.parentId != selected.first.parentId)) {
      return;
    }
    final (change, id) = groupObjects(
      _editor.document,
      _editor.selection,
      asFrame: true,
    );
    if (id == null) return;
    _commit(change, select: {id});
  }

  /// View centre on a board page, `null` on fixed pages.
  Point2D? _boardCenter(DesignPage page) {
    if (!page.isBoard) return null;
    final viewport = ref.read(viewportProvider);
    if (viewport.size.isEmpty) return null;
    final frame = layoutPages(_editor.document.pages, active: page.id).single;
    return viewCenterOn(viewport, frame);
  }

  static Point2D _centerOf(ObjectTransform t) =>
      Point2D(t.x + t.width / 2, t.y + t.height / 2);

  /// [insert] followed by moving [ids] into the frame under [at], as one
  /// undo step.
  Change _intoFrame(
    Change insert,
    List<ObjectId> ids,
    PageId pageId,
    Point2D at, {
    Set<ObjectId> exclude = const {},
  }) {
    final (inserted, _) = insert.applyTo(_editor.document);
    final page = inserted.pages.firstWhere((p) => p.id == pageId);
    final target = frameAt(inserted, page, at, exclude: {...ids, ...exclude});
    if (target == null) return insert;
    return _chain(
      insert,
      reparentObjects(inserted, ids, target, pageId: pageId),
    );
  }

  /// [first] then [second] (computed on the result of [first]) as one
  /// change. Changes carry whole objects, so later entries win.
  static Change _chain(Change first, Change second) => Change(
    label: first.label,
    objects: {...first.objects, ...second.objects},
    pages: second.pages ?? first.pages,
    metadata: second.metadata ?? first.metadata,
    assets: {...first.assets, ...second.assets},
  );

  /// Adds a [type] shape with an explicit [transform] (drawn with a tool).
  void insertDrawnShape(
    ObjectType type,
    ObjectTransform transform, {
    required PageId pageId,
  }) {
    final page = _editor.document.pages.firstWhere((p) => p.id == pageId);
    final shape = newShape(
      type,
      page,
      id: ObjectId.generate(),
    ).copyWith(transform: transform);
    _commit(
      _intoFrame(
        insertObjects(_editor.document, pageId, [
          shape,
        ], label: 'Add ${typeLabel(type)}'),
        [shape.id],
        pageId,
        _centerOf(transform),
      ),
      activePage: pageId,
      select: {shape.id},
    );
  }

  /// Adds a text box for [role]. With [topLeft] the box starts there,
  /// otherwise it is centred on the page. Returns the new id.
  ObjectId insertText(
    TextRole role, {
    Point2D? topLeft,
    Point2D? center,
    PageId? pageId,
    String? text,
    TextPayload Function(TextPayload payload)? restyle,
  }) {
    final document = _editor.document;
    final page =
        pageId == null
            ? _editor.activePage
            : document.pages.firstWhere((p) => p.id == pageId);
    final measure = ref.read(textMeasurerProvider);
    var object = newText(
      page,
      id: ObjectId.generate(),
      role: role,
      text: text,
      center: center ?? (topLeft == null ? _boardCenter(page) : null),
      measure: measure,
      restyle: restyle,
    );
    if (topLeft != null) {
      object = object.copyWith(
        transform: object.transform.copyWith(x: topLeft.x, y: topLeft.y),
      );
    }
    _commit(
      _intoFrame(
        insertObjects(document, page.id, [object], label: 'Add text'),
        [object.id],
        page.id,
        topLeft ?? _centerOf(object.transform),
      ),
      activePage: page.id,
      select: {object.id},
    );
    return object.id;
  }

  // --------------------------------------------------------- text editing

  /// Starts inline editing of text object [id] (one undo step until
  /// [finishTextEdit]).
  void startTextEdit(ObjectId id) {
    final object = _editor.document.objects[id];
    if (object == null || object.payload is! TextPayload || object.locked) {
      return;
    }
    if (_editor.selection.length != 1 || !_editor.selection.contains(id)) {
      select({id});
    }
    beginGesture();
    ref.read(textEditingProvider.notifier).id = id;
  }

  /// Live update while typing; resizes auto-sized boxes.
  void updateEditedText(String text) {
    final id = ref.read(textEditingProvider);
    final object = id == null ? null : _editor.document.objects[id];
    final payload = object?.payload;
    if (object == null || payload is! TextPayload) return;
    previewObjects([_withText(object, payload.copyWith(text: text))]);
  }

  /// Ends inline editing. Empty text boxes are removed.
  void finishTextEdit() {
    final id = ref.read(textEditingProvider);
    if (id == null) return;
    ref.read(textEditingProvider.notifier).id = null;
    final payload = _editor.document.objects[id]?.payload;
    endGesture('Edit text');
    if (payload is TextPayload && payload.text.trim().isEmpty) {
      _commit(
        deleteObjects(_editor.document, [id], label: 'Delete text'),
        select: const {},
      );
    }
  }

  /// Changes the formatting of every selected text object (P1.5.2–P1.5.3).
  void updateSelectedText(
    TextPayload Function(TextPayload text) update, {
    required String label,
  }) {
    _commit(
      updateObjects(_editor.document, [
        for (final o in _editor.selectedObjects)
          if (o.payload case final TextPayload payload)
            _withText(o, update(payload)),
      ], label: label),
    );
  }

  /// [object] with [payload] and its box re-measured for its sizing mode.
  DesignObject _withText(DesignObject object, TextPayload payload) {
    final measure = ref.read(textMeasurerProvider);
    final t = object.transform;
    final size = switch (payload.sizing) {
      TextSizing.autoWidth => measure(payload),
      TextSizing.autoHeight => measure(payload, width: t.width),
      TextSizing.fixed => Point2D(t.width, t.height),
    };
    return object.copyWith(
      payload: payload,
      transform: t.copyWith(width: size.x, height: size.y),
    );
  }

  /// Spaces three or more selected objects evenly (P1.4.3).
  void distribute(DistributeAxis axis) {
    if (_editor.selection.length < 3) return;
    _commit(distributeObjects(_editor.document, _editor.selection, axis));
  }

  void deleteSelection() {
    if (_editor.selection.isEmpty) return;
    _commit(
      deleteObjects(_editor.document, _editor.selection),
      select: const {},
    );
  }

  void duplicateSelection() {
    if (_editor.selection.isEmpty) return;
    final (change, ids) = duplicateObjects(
      _editor.document,
      _editor.activePageId,
      _editor.selection,
      offset: _nudgeStep(large: true),
    );
    _commit(change, select: ids.toSet());
  }

  void copySelection() {
    if (_editor.selection.isEmpty) return;
    final ordered = pageObjectsInOrder(
      _editor.document,
      _editor.activePage,
    ).where(_editor.selection.contains);
    ref
        .read(clipboardProvider.notifier)
        .set(copySubtrees(_editor.document, ordered));
  }

  void cutSelection() {
    copySelection();
    if (_editor.selection.isEmpty) return;
    _commit(
      deleteObjects(_editor.document, _editor.selection, label: 'Cut'),
      select: const {},
    );
  }

  void paste() {
    final clipboard = ref.read(clipboardProvider);
    if (clipboard.isEmpty) return;
    final (change, ids) = pasteObjects(
      _editor.document,
      _editor.activePageId,
      clipboard,
      offset: _nudgeStep(large: true),
    );
    _commit(change, select: ids.toSet());
  }

  /// Arrow-key movement: 1 px-ish, or 10× with Shift.
  void nudge(int dx, int dy, {bool large = false}) {
    if (_editor.selection.isEmpty) return;
    final step = _nudgeStep(large: large);
    _commit(
      moveObjects(
        _editor.document,
        _editor.selection,
        dx * step,
        dy * step,
        label: 'Nudge',
      ),
    );
  }

  /// One screen-pixel-ish step in the active page's unit.
  double _nudgeStep({required bool large}) {
    final page = _editor.activePage;
    final unitsPerPixel = convertLength(
      1,
      from: LengthUnit.px,
      to: page.unit,
      dpi: page.dpi,
    );
    final step = page.unit == LengthUnit.px ? 1.0 : unitsPerPixel * 4;
    return large ? step * 10 : step;
  }

  /// Whether the selection can be grouped: two or more siblings.
  bool get canGroup {
    final selected = _editor.selectedObjects;
    return selected.length > 1 &&
        selected.every((o) => o.parentId == selected.first.parentId);
  }

  /// Whether the selection holds a group.
  bool get canUngroup => _editor.selectedObjects.any((o) => o.type.isContainer);

  /// Groups the selected siblings (P1.3.6) and selects the group.
  void groupSelection() {
    if (!canGroup) return;
    final (change, id) = groupObjects(_editor.document, _editor.selection);
    if (id == null) return;
    _commit(change, select: {id});
  }

  /// Dissolves selected groups and selects what they held.
  void ungroupSelection() {
    final groups = [
      for (final o in _editor.selectedObjects)
        if (o.type.isContainer) o.id,
    ];
    if (groups.isEmpty) return;
    final (change, released) = ungroupObjects(_editor.document, groups);
    final keep = _editor.selection.where((id) => !groups.contains(id));
    _commit(change, select: {...keep, ...released});
  }

  /// Escape inside a group selects the group; otherwise clears.
  void selectParentOrClear() {
    final parents = {
      for (final o in _editor.selectedObjects)
        if (o.parentId case final parentId?) parentId,
    };
    select(parents);
  }

  void arrange(ZOrderMove move) {
    if (_editor.selection.isEmpty) return;
    _commit(
      reorderObjects(
        _editor.document,
        _editor.activePageId,
        _editor.selection,
        move,
      ),
    );
  }

  /// Aligns one object to the page, several to their combined bounds.
  void align(AlignEdge edge) {
    final ids = _editor.selection;
    if (ids.isEmpty) return;
    final page = _editor.activePage;
    final reference =
        ids.length == 1
            ? Rect2D.fromLTWH(0, 0, page.width, page.height)
            : selectionBounds(_editor.document, ids);
    if (reference == null) return;
    _commit(alignObjects(_editor.document, ids, edge, reference));
  }

  /// Applies [update] to every selected object as one undo step.
  void updateSelected(
    DesignObject Function(DesignObject object) update, {
    required String label,
  }) {
    _commit(
      updateObjects(_editor.document, [
        for (final o in _editor.selectedObjects) update(o),
      ], label: label),
    );
  }

  /// Applies [update] to one object (layers panel).
  void updateObject(
    ObjectId id,
    DesignObject Function(DesignObject object) update, {
    required String label,
  }) {
    final object = _editor.document.objects[id];
    if (object == null) return;
    final updated = update(object);
    final selection = {..._editor.selection};
    if (updated.hidden || updated.locked) selection.remove(id);
    _commit(
      updateObjects(_editor.document, [updated], label: label),
      select: selection,
    );
  }

  /// Sets the active page's back-to-front layer order.
  void setLayerOrder(List<ObjectId> order) => _commit(
    engine.setLayerOrder(_editor.document, _editor.activePageId, order),
  );

  // ----------------------------------------------- gestures (live preview)

  /// Starts a drag that previews edits without recording history.
  void beginGesture() {
    _gestureBase ??= _editor.document;
    _gestureObjects.clear();
  }

  bool get isGestureActive => _gestureBase != null;

  /// Shows [objects] as edited during the drag.
  void previewObjects(Iterable<DesignObject> objects) {
    final base = _gestureBase;
    if (base == null) return;
    for (final o in objects) {
      _gestureObjects[o.id] = o;
    }
    final (preview, _) = Change(
      label: 'preview',
      objects: _gestureObjects,
    ).applyTo(base);
    _publish(_editor.copyWith(document: preview), edited: false);
  }

  /// Finishes the drag as one undo step named [label].
  void endGesture(String label) {
    final base = _gestureBase;
    _gestureBase = null;
    if (base == null) return;
    final change = updateObjects(base, _gestureObjects.values, label: label);
    _gestureObjects.clear();
    if (change.isEmpty) {
      _publish(_editor.copyWith(document: base), edited: false);
      return;
    }
    final (document, inverse) = change.applyTo(base);
    _history.recordApplied(inverse);
    _publish(_editor.copyWith(document: document), edited: true);
  }

  /// Ends a move drag released at page point [pointer]: objects dropped on
  /// a frame move into it, objects dragged out of their frame leave it
  /// (objects inside groups stay put). One undo step.
  void endMoveGesture(Point2D pointer) {
    final base = _gestureBase;
    _gestureBase = null;
    if (base == null) return;
    final move = updateObjects(base, _gestureObjects.values, label: 'Move');
    final moved = {..._gestureObjects.keys};
    _gestureObjects.clear();
    if (move.isEmpty) {
      _publish(_editor.copyWith(document: base), edited: false);
      return;
    }
    final (afterMove, _) = move.applyTo(base);
    final page = afterMove.pages.firstWhere(
      (p) => p.id == _editor.activePageId,
    );
    final target = frameAt(afterMove, page, pointer, exclude: moved);
    final movable = [
      for (final id in moved)
        if (afterMove.objects[id] case final o?
            when o.parentId != target &&
                (o.parentId == null ||
                    afterMove.objects[o.parentId]?.type == ObjectType.frame))
          id,
    ];
    final change =
        movable.isEmpty
            ? move
            : _chain(
              move,
              reparentObjects(afterMove, movable, target, pageId: page.id),
            );
    final (document, inverse) = change.applyTo(base);
    _history.recordApplied(inverse);
    _publish(_editor.copyWith(document: document), edited: true);
  }

  void _cancelGesture() {
    ref.read(textEditingProvider.notifier).id = null;
    final base = _gestureBase;
    if (base == null) return;
    _gestureBase = null;
    _gestureObjects.clear();
    _publish(_editor.copyWith(document: base), edited: false);
  }

  // --------------------------------------------------------------- pages

  /// Adds a blank page with the active page's size after it.
  /// Adds a page of [preset]'s size after the active page (or a board).
  void addPageFromPreset(PagePreset preset) {
    final page = preset.createPage(PageId.generate());
    _commit(
      engine.addPage(
        _editor.document,
        page,
        index: _editor.activePageIndex + 1,
      ),
      activePage: page.id,
      select: const {},
    );
    ref.read(viewportProvider.notifier).reset();
  }

  /// Adds an unbounded board (free canvas) after the active page.
  void addBoard() {
    final page = pagePresets
        .firstWhere((p) => p.kind == PageKind.board)
        .createPage(PageId.generate())
        .copyWith(name: 'Board');
    _commit(
      engine.addPage(
        _editor.document,
        page,
        index: _editor.activePageIndex + 1,
      ),
      activePage: page.id,
      select: const {},
    );
    ref.read(viewportProvider.notifier).reset();
  }

  void addPage() {
    final current = _editor.activePage;
    final page = DesignPage(
      id: PageId.generate(),
      width: current.width,
      height: current.height,
      unit: current.unit,
      dpi: current.dpi,
      background: current.background,
      kind: current.kind,
    );
    _commit(
      engine.addPage(
        _editor.document,
        page,
        index: _editor.activePageIndex + 1,
      ),
      activePage: page.id,
      select: const {},
    );
  }

  void duplicatePage(PageId pageId) {
    final (change, copy) = engine.duplicatePage(_editor.document, pageId);
    _commit(change, activePage: copy, select: const {});
  }

  /// Deletes [pageId] unless it is the last page.
  void deletePage(PageId pageId) {
    final pages = _editor.document.pages;
    if (pages.length <= 1) return;
    final index = pages.indexWhere((p) => p.id == pageId);
    final neighbour = pages[index == 0 ? 1 : index - 1].id;
    _commit(
      engine.deletePage(_editor.document, pageId),
      activePage: pageId == _editor.activePageId ? neighbour : null,
      select: const {},
    );
  }

  void movePage(int from, int to) =>
      _commit(engine.movePage(_editor.document, from, to));

  void updatePage(DesignPage page, {String label = 'Edit page'}) =>
      _commit(engine.updatePage(_editor.document, page, label: label));

  void rename(String title) => _commit(renameDocument(_editor.document, title));
}

/// Human name of an object type for menus, layers and undo labels.
String typeLabel(ObjectType type) => switch (type) {
  ObjectType.text => 'Text',
  ObjectType.rect => 'Rectangle',
  ObjectType.roundedRect => 'Rounded rectangle',
  ObjectType.ellipse => 'Ellipse',
  ObjectType.line => 'Line',
  ObjectType.arrow => 'Arrow',
  ObjectType.path => 'Shape',
  ObjectType.image => 'Image',
  ObjectType.group => 'Group',
  ObjectType.frame => 'Frame',
  ObjectType.instance => 'Instance',
  ObjectType.polygon => 'Polygon',
  ObjectType.star => 'Star',
};

/// Layer name: the user's name, or "Rectangle 2" style numbering.
String layerName(
  DesignDocument document,
  DesignPage page,
  DesignObject object,
) {
  final name = object.name;
  if (name != null && name.trim().isNotEmpty) return name;
  var n = 0;
  for (final id in pageObjectsInOrder(document, page)) {
    if (document.objects[id]?.type == object.type) n++;
    if (id == object.id) break;
  }
  return '${typeLabel(object.type)} ${math.max(n, 1)}';
}
