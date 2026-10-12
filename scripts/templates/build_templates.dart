// Builds OpenCanvasX's official, original templates (P2.2.6–P2.2.8) as
// ordinary `.opencanvasx` files plus `index.json` in `templates/official/`,
// a template repository (template-architecture.md, P6.2.1) that the app
// reads from a folder or downloads from a URL.
//
//   dart --packages=packages/storage/.dart_tool/package_config.json \
//       scripts/templates/build_templates.dart
//
// Everything here is designed for OpenCanvasX (no third-party templates).
// Icons come from the bundled Lucide pack (ISC) and a few Twemoji stickers
// (CC-BY 4.0); their licences are recorded on each embedded asset.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:document_model/document_model.dart';
import 'package:storage/storage.dart';

final root = File.fromUri(Platform.script).parent.parent.parent.path;
final packs = '$root/packages/asset_packs/assets/packs';
final out = '$root/templates/official';

const author = 'OpenCanvasX contributors';
const sans = null;
const serif = 'Georgia';

// ------------------------------------------------------------------ DSL

/// Collects the objects and assets of one template document.
class Doc {
  Doc(this.id);

  final String id;
  int _n = 0;
  final pages = <DesignPage>[];
  final objects = <ObjectId, DesignObject>{};
  final assets = <String, AssetInfo>{};
  final bytes = <String, Uint8List>{};

  ObjectId next() => ObjectId('$id-${_n++}');

  Page page(
    double w,
    double h, {
    int bg = 0xFFFFFFFF,
    LengthUnit unit = LengthUnit.px,
    String name = '',
    PageKind kind = PageKind.fixed,
  }) => Page(this, w, h, bg, unit, name, kind);

  String icon(String pack, String stem, String licenseRef) {
    final data = File('$packs/$pack/svg/$stem.svg').readAsBytesSync();
    final hash = sha256Hex(data);
    bytes[hash] = data;
    assets[hash] = AssetInfo(
      mime: 'image/svg+xml',
      byteLength: data.length,
      licenseRef: licenseRef,
    );
    return hash;
  }
}

/// Builds one page (or a frame's content when [parent] is set).
class Page {
  Page(this.doc, this.w, this.h, this.bg, this.unit, this.name, this.kind)
    : id = PageId('${doc.id}-p${doc.pages.length + 1}');

  final Doc doc;
  final double w;
  final double h;
  final int bg;
  final LengthUnit unit;
  final String name;
  final PageKind kind;
  final PageId id;
  final roots = <ObjectId>[];
  final _stack = <(ObjectId, List<ObjectId>)>[];

  void _add(
    ObjectType type,
    ObjectTransform t, {
    ObjectStyle? style,
    ObjectPayload payload = const NoPayload(),
    String? name,
    double opacity = 1,
  }) {
    final id = doc.next();
    final parent = _stack.isEmpty ? null : _stack.last;
    doc.objects[id] = DesignObject(
      id: id,
      type: type,
      transform: t,
      pageId: parent == null ? id_ : null,
      parentId: parent?.$1,
      style: style,
      payload: payload,
      name: name,
      opacity: opacity,
    );
    (parent?.$2 ?? roots).add(id);
  }

  PageId get id_ => id;

  ObjectStyle _style({int? fill, int? stroke, double sw = 0, double r = 0}) =>
      ObjectStyle(
        fill: fill == null ? null : SolidFill(ArgbColor(fill)),
        stroke:
            stroke == null ? null : Stroke(color: ArgbColor(stroke), width: sw),
        cornerRadius: r,
      );

  void rect(
    double x,
    double y,
    double w,
    double h, {
    int? fill,
    double r = 0,
    int? stroke,
    double sw = 0,
    double rot = 0,
    double opacity = 1,
    String? name,
  }) => _add(
    ObjectType.rect,
    ObjectTransform(x: x, y: y, width: w, height: h, rotation: rot),
    style: _style(fill: fill, stroke: stroke, sw: sw, r: r),
    opacity: opacity,
    name: name,
  );

  void circle(
    double x,
    double y,
    double w,
    double h, {
    int? fill,
    int? stroke,
    double sw = 0,
    double opacity = 1,
  }) => _add(
    ObjectType.ellipse,
    ObjectTransform(x: x, y: y, width: w, height: h),
    style: _style(fill: fill, stroke: stroke, sw: sw),
    opacity: opacity,
  );

  void star(
    double x,
    double y,
    double s, {
    required int fill,
    int points = 5,
    double inner = 0.5,
    double rot = 0,
  }) => _add(
    ObjectType.star,
    ObjectTransform(x: x, y: y, width: s, height: s, rotation: rot),
    style: _style(fill: fill),
    payload: StarPayload(points: points, innerRatio: inner),
  );

  void polygon(
    double x,
    double y,
    double w,
    double h, {
    required int fill,
    int sides = 6,
    double rot = 0,
    double opacity = 1,
  }) => _add(
    ObjectType.polygon,
    ObjectTransform(x: x, y: y, width: w, height: h, rotation: rot),
    style: _style(fill: fill),
    payload: PolygonPayload(sides: sides),
    opacity: opacity,
  );

  void line(
    double x,
    double y,
    double length, {
    required int color,
    double width = 2,
    double rot = 0,
    StrokeDash dash = StrokeDash.solid,
  }) => _add(
    ObjectType.line,
    ObjectTransform(x: x, y: y, width: length, height: 0, rotation: rot),
    style: ObjectStyle(
      stroke: Stroke(color: ArgbColor(color), width: width, dash: dash),
    ),
  );

  void text(
    String value,
    double x,
    double y,
    double w, {
    required double size,
    int weight = 400,
    int color = 0xFF16181D,
    TextAlignment align = TextAlignment.left,
    String? family = sans,
    bool italic = false,
    double lh = 1.2,
    double ls = 0,
    String? name,
  }) {
    final lines = value.split('\n').length;
    _add(
      ObjectType.text,
      ObjectTransform(
        x: x,
        y: y,
        width: w,
        height: lines * size * lh,
      ),
      style: ObjectStyle(fill: SolidFill(ArgbColor(color))),
      payload: TextPayload(
        value,
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        italic: italic,
        align: align,
        lineHeight: lh,
        letterSpacing: ls,
        sizing: TextSizing.autoHeight,
      ),
      name: name,
    );
  }

  /// A Lucide icon drawn in [color].
  void icon(String stem, double x, double y, double s, {required int color}) =>
      _add(
        ObjectType.image,
        ObjectTransform(x: x, y: y, width: s, height: s),
        style: ObjectStyle(fill: SolidFill(ArgbColor(color))),
        payload: ImagePayload(doc.icon('lucide', stem, 'pack:lucide@1.55.0')),
        name: stem,
      );

  /// A Twemoji sticker (full colour).
  void emoji(String code, double x, double y, double s) => _add(
    ObjectType.image,
    ObjectTransform(x: x, y: y, width: s, height: s),
    payload: ImagePayload(doc.icon('twemoji', code, 'pack:twemoji@15.0.0')),
    name: 'Sticker',
  );

  /// A frame (artboard) on a board; [build] adds its content.
  void frame(
    String frameName,
    double x,
    double y,
    double w,
    double h,
    void Function() build, {
    int fill = 0xFFFFFFFF,
    double r = 0,
  }) {
    final id = doc.next();
    final children = <ObjectId>[];
    _stack.add((id, children));
    build();
    _stack.removeLast();
    doc.objects[id] = DesignObject(
      id: id,
      type: ObjectType.frame,
      transform: ObjectTransform(
        x: x,
        y: y,
        width: w,
        height: h,
        anchorX: 0,
        anchorY: 0,
      ),
      pageId: _stack.isEmpty ? id_ : null,
      parentId: _stack.isEmpty ? null : _stack.last.$1,
      childIds: children,
      name: frameName,
      style: ObjectStyle(fill: SolidFill(ArgbColor(fill)), cornerRadius: r),
      payload: const FramePayload(),
    );
    (_stack.isEmpty ? roots : _stack.last.$2).add(id);
  }

  void done() => doc.pages.add(
    DesignPage(
      id: id,
      width: w,
      height: h,
      unit: unit,
      dpi: unit == LengthUnit.px ? defaultDpi : 300,
      name: name,
      kind: kind,
      background: SolidBackground(ArgbColor(bg)),
      objectIds: roots,
    ),
  );
}

/// A template definition: metadata plus the function that draws it.
class Template {
  Template(
    this.id,
    this.name,
    this.category,
    this.tags,
    this.build, {
    this.license = 'CC0-1.0',
  });

  final String id;
  final String name;
  final String category;
  final List<String> tags;
  final void Function(Doc doc) build;
  final String license;
}

// ------------------------------------------------------------- palettes

const ink = 0xFF16181D;
const paper = 0xFFFFFFFF;
const cobalt = 0xFF3256F0;
const coral = 0xFFFF6B57;
const sun = 0xFFFFC94D;
const mint = 0xFF2BB59A;
const plum = 0xFF5B3CC4;
const navy = 0xFF0F1B3D;
const cream = 0xFFFFF4E4;
const sand = 0xFFF2E6D0;
const blush = 0xFFFFE3E0;
const sky = 0xFFDDEBFF;
const forest = 0xFF1F4D3A;
const grey = 0xFF5B616E;
const mist = 0xFFF1F2F4;

// ------------------------------------------------------------ templates

final templates = <Template>[
  // ---- Social posts (1080 × 1080)
  Template('social-bold-sale', 'Bold sale', 'social', [
    'instagram',
    'sale',
    'shop',
    'discount',
  ], (d) {
    final p = d.page(1080, 1080, bg: coral)
      ..circle(620, -180, 640, 640, fill: sun)
      ..circle(-160, 760, 420, 420, fill: 0x33FFFFFF)
      ..text('SUMMER', 90, 150, 900, size: 84, weight: 600, color: paper, ls: 12)
      ..text('SALE', 80, 230, 900, size: 300, weight: 900, color: paper, lh: 1)
      ..rect(90, 600, 520, 120, fill: ink, r: 60)
      ..text(
        'Up to 50% off',
        90,
        632,
        520,
        size: 46,
        weight: 700,
        color: paper,
        align: TextAlignment.center,
      )
      ..text(
        'This weekend only · shop online or in store',
        90,
        780,
        800,
        size: 34,
        color: paper,
      )
      ..star(860, 760, 160, fill: sun, points: 12, inner: 0.75, rot: 12)
      ..text(
        '%',
        860,
        800,
        160,
        size: 70,
        weight: 900,
        color: ink,
        align: TextAlignment.center,
      );
    p.done();
  }),
  Template('social-quote', 'Quote card', 'social', [
    'instagram',
    'quote',
    'inspiration',
  ], (d) {
    d.page(1080, 1080, bg: cream)
      ..rect(70, 70, 940, 940, stroke: ink, sw: 3, r: 24)
      ..text('“', 120, 90, 300, size: 300, family: serif, color: coral, lh: 1)
      ..text(
        'Simplicity is not the absence of clutter; it is the presence of '
        'what matters.',
        150,
        360,
        780,
        size: 64,
        family: serif,
        lh: 1.3,
      )
      ..line(150, 820, 120, color: coral, width: 6)
      ..text('Your name', 150, 860, 600, size: 34, weight: 700)
      ..text('@yourhandle', 150, 910, 600, size: 28, color: grey)
      ..done();
  }),
  Template('social-launch', 'Product launch', 'social', [
    'instagram',
    'launch',
    'tech',
    'new',
  ], (d) {
    d.page(1080, 1080, bg: navy)
      ..circle(540, 300, 700, 700, fill: 0x223256F0)
      ..circle(640, 400, 500, 500, fill: 0x333256F0)
      ..rect(90, 110, 170, 64, fill: sun, r: 32)
      ..text(
        'NEW',
        90,
        122,
        170,
        size: 34,
        weight: 800,
        ls: 6,
        align: TextAlignment.center,
      )
      ..text(
        'Meet the\nall-new\nOrbit app',
        90,
        250,
        700,
        size: 110,
        weight: 800,
        color: paper,
        lh: 1.05,
      )
      ..text(
        'Plan, share and ship together — offline first.',
        90,
        660,
        620,
        size: 36,
        color: 0xCCFFFFFF,
        lh: 1.35,
      )
      ..rect(90, 850, 330, 96, fill: cobalt, r: 48)
      ..text(
        'Download now',
        90,
        876,
        330,
        size: 34,
        weight: 700,
        color: paper,
        align: TextAlignment.center,
      )
      ..icon('rocket', 720, 560, 260, color: sun)
      ..done();
  }),
  Template('social-tips', 'Tips carousel', 'social', [
    'instagram',
    'carousel',
    'tips',
    'education',
  ], (d) {
    const tips = [
      ('Plan the week', 'Block time for your three most important tasks.'),
      ('Batch the small stuff', 'Answer messages twice a day, not all day.'),
      ('Rest on purpose', 'Short breaks keep focus high until evening.'),
    ];
    d.page(1080, 1080, bg: mint, name: 'Cover')
      ..text(
        '3 habits\nfor a calmer\nwork week',
        90,
        200,
        900,
        size: 110,
        weight: 800,
        color: paper,
        lh: 1.05,
      )
      ..text('Swipe →', 90, 900, 400, size: 40, weight: 600, color: paper)
      ..icon('sparkles', 820, 120, 160, color: sun)
      ..done();
    for (final (i, (title, body)) in tips.indexed) {
      d.page(1080, 1080, bg: paper, name: 'Tip ${i + 1}')
        ..rect(0, 0, 1080, 24, fill: mint)
        ..text(
          '0${i + 1}',
          90,
          140,
          400,
          size: 200,
          weight: 900,
          color: mint,
          lh: 1,
        )
        ..text(title, 90, 420, 900, size: 80, weight: 800, lh: 1.1)
        ..text(body, 90, 560, 860, size: 44, color: grey, lh: 1.4)
        ..text(
          '${i + 1} / ${tips.length}',
          90,
          960,
          400,
          size: 30,
          color: grey,
        )
        ..done();
    }
  }),
  Template('social-event', 'Event announcement', 'social', [
    'instagram',
    'event',
    'workshop',
    'date',
  ], (d) {
    d.page(1080, 1080, bg: plum)
      ..polygon(-120, -120, 520, 520, fill: 0x22FFFFFF, rot: 15)
      ..polygon(760, 740, 460, 460, fill: 0x22FFFFFF, rot: -10)
      ..rect(90, 140, 260, 300, fill: paper, r: 28)
      ..text(
        'JUN',
        90,
        180,
        260,
        size: 50,
        weight: 700,
        color: coral,
        align: TextAlignment.center,
        ls: 6,
      )
      ..text(
        '24',
        90,
        240,
        260,
        size: 150,
        weight: 900,
        align: TextAlignment.center,
        lh: 1,
      )
      ..text(
        'Design\nworkshop',
        410,
        150,
        600,
        size: 100,
        weight: 800,
        color: paper,
        lh: 1.05,
      )
      ..icon('map-pin', 90, 560, 56, color: sun)
      ..text('Community Hall, 2nd floor', 170, 566, 800, size: 40, color: paper)
      ..icon('clock', 90, 650, 56, color: sun)
      ..text('10:00 – 16:00', 170, 656, 800, size: 40, color: paper)
      ..rect(90, 820, 420, 100, fill: sun, r: 50)
      ..text(
        'Reserve a seat',
        90,
        846,
        420,
        size: 38,
        weight: 700,
        align: TextAlignment.center,
      )
      ..done();
  }),
  Template('social-linkedin-hiring', 'We are hiring', 'social', [
    'linkedin',
    'hiring',
    'job',
    'career',
  ], (d) {
    d.page(1200, 627, bg: paper)
      ..rect(0, 0, 460, 627, fill: cobalt)
      ..icon('briefcase', 150, 170, 160, color: paper)
      ..text(
        'JOIN THE TEAM',
        150,
        380,
        300,
        size: 22,
        weight: 700,
        color: 0xCCFFFFFF,
        ls: 4,
      )
      ..text(
        'We are hiring',
        530,
        120,
        620,
        size: 76,
        weight: 800,
        lh: 1.05,
      )
      ..text(
        'Product designer · Remote or hybrid',
        530,
        230,
        620,
        size: 32,
        color: grey,
      )
      ..text(
        '• Shape tools people love\n• Small, kind team\n• Learning budget',
        530,
        310,
        620,
        size: 28,
        lh: 1.6,
      )
      ..rect(530, 480, 260, 70, fill: ink, r: 35)
      ..text(
        'Apply today',
        530,
        498,
        260,
        size: 26,
        weight: 700,
        color: paper,
        align: TextAlignment.center,
      )
      ..done();
  }),

  // ---- Stories (1080 × 1920)
  Template('story-routine', 'Morning routine', 'story', [
    'story',
    'routine',
    'checklist',
    'wellness',
  ], (d) {
    final p = d.page(1080, 1920, bg: blush)
      ..circle(560, -200, 760, 760, fill: 0x55FFC94D)
      ..text(
        'My morning\nroutine',
        90,
        220,
        900,
        size: 120,
        weight: 800,
        lh: 1.05,
      )
      ..emoji('2600', 820, 160, 170);
    const items = [
      ('sun', 'Wake up at 6:30'),
      ('coffee', 'Coffee, no phone'),
      ('leaf', 'Ten minutes outside'),
      ('target', 'Pick one big goal'),
    ];
    for (final (i, (icon, label)) in items.indexed) {
      final y = 720.0 + i * 230;
      p
        ..rect(90, y, 900, 180, fill: paper, r: 36)
        ..circle(130, y + 40, 100, 100, fill: blush)
        ..icon(icon, 155, y + 65, 50, color: coral)
        ..text(label, 270, y + 62, 680, size: 48, weight: 600);
    }
    p.done();
  }),
  Template('story-poll', 'Question poll', 'story', [
    'story',
    'poll',
    'question',
    'engagement',
  ], (d) {
    d.page(1080, 1920, bg: navy)
      ..text(
        'QUICK QUESTION',
        90,
        300,
        900,
        size: 36,
        weight: 700,
        color: sun,
        ls: 8,
      )
      ..text(
        'Tea or\ncoffee?',
        90,
        380,
        900,
        size: 170,
        weight: 900,
        color: paper,
        lh: 1,
      )
      ..rect(90, 1000, 900, 180, fill: paper, r: 90)
      ..text(
        'Tea, always',
        90,
        1058,
        900,
        size: 54,
        weight: 700,
        align: TextAlignment.center,
      )
      ..rect(90, 1240, 900, 180, fill: sun, r: 90)
      ..text(
        'Coffee, obviously',
        90,
        1298,
        900,
        size: 54,
        weight: 700,
        align: TextAlignment.center,
      )
      ..text(
        'Vote in the poll below',
        90,
        1700,
        900,
        size: 36,
        color: 0xAAFFFFFF,
        align: TextAlignment.center,
      )
      ..done();
  }, license: 'CC0-1.0'),
  Template('story-travel', 'Travel diary', 'story', [
    'story',
    'travel',
    'holiday',
    'trip',
  ], (d) {
    d.page(1080, 1920, bg: sky)
      ..circle(640, 180, 320, 320, fill: sun)
      ..rect(-100, 1380, 1300, 700, fill: 0xFF8CC9FF, rot: -4)
      ..rect(-100, 1500, 1300, 700, fill: cobalt, rot: 3)
      ..text(
        'Lisbon',
        90,
        620,
        900,
        size: 200,
        weight: 900,
        color: navy,
        lh: 1,
      )
      ..text('Day 3 of 7', 96, 860, 600, size: 48, weight: 600, color: navy)
      ..text(
        'Trams, tiles and the best pastries we have ever had.',
        96,
        950,
        820,
        size: 44,
        color: navy,
        lh: 1.4,
      )
      ..emoji('2708', 780, 520, 200)
      ..done();
  }, license: 'CC0-1.0 AND CC-BY-4.0'),

  // ---- Video thumbnails (1280 × 720)
  Template('video-tutorial', 'Tutorial thumbnail', 'video', [
    'youtube',
    'thumbnail',
    'tutorial',
    'how to',
  ], (d) {
    d.page(1280, 720, bg: ink)
      ..rect(0, 0, 14, 720, fill: sun)
      ..text(
        'BEGINNER GUIDE',
        80,
        110,
        700,
        size: 34,
        weight: 700,
        color: sun,
        ls: 6,
      )
      ..text(
        'Design a logo\nin 10 minutes',
        80,
        170,
        700,
        size: 92,
        weight: 900,
        color: paper,
        lh: 1.05,
      )
      ..circle(820, 160, 400, 400, fill: coral)
      ..icon('play', 960, 290, 140, color: paper)
      ..rect(80, 560, 250, 70, fill: paper, r: 12)
      ..text(
        'STEP BY STEP',
        80,
        578,
        250,
        size: 26,
        weight: 800,
        align: TextAlignment.center,
      )
      ..done();
  }),
  Template('video-podcast', 'Podcast episode', 'video', [
    'youtube',
    'podcast',
    'episode',
    'audio',
  ], (d) {
    final p = d.page(1280, 720, bg: forest)
      ..text(
        'EPISODE 42',
        80,
        120,
        600,
        size: 32,
        weight: 700,
        color: 0xFFB8F2D7,
        ls: 6,
      )
      ..text(
        'Building in\npublic',
        80,
        180,
        650,
        size: 100,
        weight: 900,
        color: paper,
        lh: 1.02,
      )
      ..icon('mic', 80, 520, 80, color: 0xFFB8F2D7)
      ..text(
        'with Sam & Alex',
        180,
        538,
        500,
        size: 38,
        color: paper,
      );
    const bars = [80, 160, 260, 200, 320, 240, 140, 280, 180, 100, 60];
    for (final (i, h) in bars.indexed) {
      p.rect(
        760 + i * 42.0,
        360 - h / 2,
        24,
        h.toDouble(),
        fill: 0xFFB8F2D7,
        r: 12,
      );
    }
    p.done();
  }),

  // ---- Presentations (1920 × 1080)
  Template('deck-pitch', 'Pitch deck', 'presentation', [
    'presentation',
    'pitch',
    'startup',
    'slides',
  ], (d) {
    d.page(1920, 1080, bg: navy, name: 'Title')
      ..circle(1200, -300, 1100, 1100, fill: 0x333256F0)
      ..text(
        'Orbit',
        160,
        360,
        1200,
        size: 180,
        weight: 900,
        color: paper,
        lh: 1,
      )
      ..text(
        'The calm way for small teams to plan their work',
        160,
        580,
        1100,
        size: 52,
        color: 0xCCFFFFFF,
      )
      ..text('Seed round · 2026', 160, 900, 800, size: 34, color: sun)
      ..done();
    d.page(1920, 1080, bg: paper, name: 'Problem')
      ..text('THE PROBLEM', 160, 140, 800, size: 32, weight: 700, color: coral, ls: 6)
      ..text(
        'Teams lose six hours a week\nchasing status updates.',
        160,
        210,
        1500,
        size: 84,
        weight: 800,
        lh: 1.1,
      )
      ..rect(160, 560, 480, 340, fill: blush, r: 32)
      ..text('62%', 210, 610, 400, size: 110, weight: 900, color: coral)
      ..text('feel out of the loop', 210, 760, 400, size: 36, color: grey)
      ..rect(720, 560, 480, 340, fill: sky, r: 32)
      ..text('6 h', 770, 610, 400, size: 110, weight: 900, color: cobalt)
      ..text('lost every week', 770, 760, 400, size: 36, color: grey)
      ..rect(1280, 560, 480, 340, fill: cream, r: 32)
      ..text('4 tools', 1330, 610, 400, size: 110, weight: 900, color: 0xFFB07A00)
      ..text('to find one answer', 1330, 760, 400, size: 36, color: grey)
      ..done();
    d.page(1920, 1080, bg: paper, name: 'Solution')
      ..text('THE SOLUTION', 160, 140, 800, size: 32, weight: 700, color: mint, ls: 6)
      ..text('One board, always current.', 160, 210, 1500, size: 84, weight: 800)
      ..icon('circle-check', 160, 420, 72, color: mint)
      ..text('Status writes itself from the work', 270, 432, 1300, size: 44)
      ..icon('circle-check', 160, 560, 72, color: mint)
      ..text('Works offline, syncs privately', 270, 572, 1300, size: 44)
      ..icon('circle-check', 160, 700, 72, color: mint)
      ..text('Weekly summary in one click', 270, 712, 1300, size: 44)
      ..done();
    final market = d.page(1920, 1080, bg: paper, name: 'Traction')
      ..text('TRACTION', 160, 140, 800, size: 32, weight: 700, color: cobalt, ls: 6)
      ..text('Monthly active teams', 160, 210, 1500, size: 84, weight: 800)
      ..line(160, 920, 1600, color: 0xFFD8DBE2, width: 4);
    const values = [120, 180, 260, 380, 520, 700];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    for (final (i, v) in values.indexed) {
      final x = 220 + i * 260.0;
      market
        ..rect(x, 920 - v.toDouble(), 150, v.toDouble(), fill: i == 5 ? cobalt : sky, r: 16)
        ..text(
          months[i],
          x,
          940,
          150,
          size: 30,
          color: grey,
          align: TextAlignment.center,
        );
    }
    market.done();
    d.page(1920, 1080, bg: cobalt, name: 'Contact')
      ..text(
        'Let’s talk.',
        160,
        360,
        1600,
        size: 180,
        weight: 900,
        color: paper,
      )
      ..icon('mail', 160, 680, 64, color: paper)
      ..text('hello@orbit.example', 260, 688, 1000, size: 44, color: paper)
      ..icon('globe', 160, 790, 64, color: paper)
      ..text('orbit.example', 260, 798, 1000, size: 44, color: paper)
      ..done();
  }),
  Template('deck-lecture', 'Minimal lecture', 'presentation', [
    'presentation',
    'education',
    'lecture',
    'class',
  ], (d) {
    d.page(1920, 1080, bg: cream, name: 'Title')
      ..rect(160, 300, 16, 420, fill: ink)
      ..text(
        'Introduction to\ncolour theory',
        230,
        320,
        1400,
        size: 120,
        family: serif,
        lh: 1.1,
      )
      ..text('Lecture 1 · Visual design basics', 230, 640, 1200, size: 40, color: grey)
      ..done();
    final wheel = d.page(1920, 1080, bg: cream, name: 'Hue')
      ..text('Hue, value and saturation', 160, 140, 1600, size: 80, family: serif)
      ..text(
        'Every colour can be described by where it sits on the wheel (hue), '
        'how light it is (value) and how intense it is (saturation).',
        160,
        280,
        900,
        size: 40,
        color: grey,
        lh: 1.5,
      );
    const hues = [coral, sun, mint, cobalt, plum, 0xFFE0569B];
    for (final (i, c) in hues.indexed) {
      wheel.circle(1150 + (i % 3) * 210.0, 300 + (i ~/ 3) * 210.0, 180, 180, fill: c);
    }
    wheel.done();
    d.page(1920, 1080, bg: ink, name: 'Summary')
      ..text('Remember', 160, 300, 1600, size: 120, family: serif, color: paper)
      ..text(
        '1. Start with one accent colour\n2. Use value for hierarchy\n'
        '3. Check contrast for text',
        160,
        500,
        1600,
        size: 52,
        color: 0xCCFFFFFF,
        lh: 1.6,
      )
      ..done();
  }),

  // ---- Print (mm)
  Template('print-poster', 'Event poster', 'print', [
    'poster',
    'a4',
    'event',
    'concert',
    'print',
  ], (d) {
    d.page(210, 297, bg: ink, unit: LengthUnit.mm)
      ..circle(-40, -30, 170, 170, fill: coral)
      ..circle(110, 40, 140, 140, fill: sun, opacity: 0.9)
      ..polygon(30, 120, 150, 150, fill: cobalt, sides: 3, rot: 12, opacity: 0.9)
      ..text(
        'NIGHT\nSOUNDS',
        16,
        170,
        180,
        size: 28,
        weight: 900,
        color: paper,
        lh: 0.95,
      )
      ..text(
        'Open-air music festival',
        16,
        230,
        180,
        size: 7,
        color: paper,
      )
      ..line(16, 248, 178, color: 0x55FFFFFF, width: 0.4)
      ..text('FRI 12 SEP · 19:00', 16, 256, 120, size: 6, weight: 700, color: sun)
      ..text('Riverside Park', 16, 266, 120, size: 6, color: paper)
      ..text(
        'Free entry',
        130,
        256,
        64,
        size: 6,
        weight: 700,
        color: paper,
        align: TextAlignment.right,
      )
      ..done();
  }),
  Template('print-menu', 'Cafe menu', 'print', [
    'menu',
    'cafe',
    'restaurant',
    'food',
    'a4',
  ], (d) {
    final p = d.page(210, 297, bg: cream, unit: LengthUnit.mm)
      ..icon('coffee', 93, 18, 24, color: forest)
      ..text(
        'Little Fern Café',
        15,
        46,
        180,
        size: 13,
        family: serif,
        color: forest,
        align: TextAlignment.center,
      )
      ..text(
        'COFFEE · TEA · PASTRIES',
        15,
        64,
        180,
        size: 4,
        weight: 700,
        color: grey,
        ls: 1.5,
        align: TextAlignment.center,
      )
      ..line(60, 76, 90, color: forest, width: 0.5);
    const sections = [
      ('Coffee', [('Espresso', '2.50'), ('Flat white', '3.40'), ('Oat latte', '3.80'), ('Cold brew', '4.00')]),
      ('Tea', [('Green sencha', '3.00'), ('Earl grey', '3.00'), ('Chai latte', '3.60')]),
      ('Bakery', [('Butter croissant', '2.80'), ('Cardamom bun', '3.20'), ('Banana bread', '3.00')]),
    ];
    var y = 88.0;
    for (final (title, items) in sections) {
      p.text(title, 30, y, 150, size: 8, family: serif, color: forest);
      y += 13;
      for (final (name, price) in items) {
        p
          ..text(name, 30, y, 110, size: 5)
          ..text(
            price,
            140,
            y,
            40,
            size: 5,
            weight: 700,
            align: TextAlignment.right,
          );
        y += 9;
      }
      y += 8;
    }
    p
      ..text(
        'Open daily 7:30 – 17:00',
        15,
        278,
        180,
        size: 4,
        color: grey,
        align: TextAlignment.center,
      )
      ..done();
  }),
  Template('print-flyer', 'Yoga class flyer', 'print', [
    'flyer',
    'yoga',
    'fitness',
    'class',
    'a4',
  ], (d) {
    d.page(210, 297, bg: 0xFFEAF4EF, unit: LengthUnit.mm)
      ..circle(55, 30, 100, 100, fill: 0xFFBFE3D2)
      ..icon('leaf', 85, 58, 40, color: forest)
      ..text(
        'Sunrise yoga',
        15,
        150,
        180,
        size: 22,
        weight: 800,
        color: forest,
        align: TextAlignment.center,
      )
      ..text(
        'Gentle flow for every level',
        15,
        178,
        180,
        size: 7,
        color: forest,
        align: TextAlignment.center,
      )
      ..rect(40, 200, 130, 36, fill: paper, r: 6)
      ..text(
        'Every Saturday · 7:00\nCommunity garden',
        40,
        208,
        130,
        size: 6,
        color: forest,
        lh: 1.5,
        align: TextAlignment.center,
      )
      ..text(
        'Bring a mat · first class free',
        15,
        258,
        180,
        size: 5,
        weight: 700,
        color: forest,
        align: TextAlignment.center,
      )
      ..done();
  }),

  // ---- Business cards (85 × 55 mm, front and back)
  Template('card-modern', 'Modern business card', 'business', [
    'business card',
    'card',
    'contact',
  ], (d) {
    d.page(85, 55, bg: navy, unit: LengthUnit.mm, name: 'Front')
      ..circle(52, -12, 46, 46, fill: cobalt)
      ..text('Alex Rivera', 7, 30, 70, size: 5.2, weight: 800, color: paper)
      ..text('Product designer', 7, 37.5, 70, size: 3, color: 0xCCFFFFFF)
      ..done();
    d.page(85, 55, bg: paper, unit: LengthUnit.mm, name: 'Back')
      ..rect(0, 0, 4, 55, fill: cobalt)
      ..icon('phone', 10, 14, 4, color: cobalt)
      ..text('+1 555 0100', 17, 14.4, 60, size: 2.8)
      ..icon('mail', 10, 23, 4, color: cobalt)
      ..text('alex@studio.example', 17, 23.4, 60, size: 2.8)
      ..icon('globe', 10, 32, 4, color: cobalt)
      ..text('studio.example', 17, 32.4, 60, size: 2.8)
      ..done();
  }),
  Template('card-classic', 'Classic business card', 'business', [
    'business card',
    'card',
    'elegant',
  ], (d) {
    d.page(85, 55, bg: cream, unit: LengthUnit.mm, name: 'Front')
      ..rect(4, 4, 77, 47, stroke: 0xFFB07A00, sw: 0.3)
      ..text(
        'Morgan & Lee',
        5,
        19,
        75,
        size: 5.5,
        family: serif,
        align: TextAlignment.center,
      )
      ..text(
        'ARCHITECTS',
        5,
        28,
        75,
        size: 2.4,
        weight: 700,
        color: 0xFFB07A00,
        ls: 1,
        align: TextAlignment.center,
      )
      ..done();
    d.page(85, 55, bg: cream, unit: LengthUnit.mm, name: 'Back')
      ..text(
        'Jordan Morgan\nPrincipal architect\n\n+1 555 0142\njordan@ml.example',
        10,
        14,
        65,
        size: 3,
        family: serif,
        lh: 1.5,
      )
      ..done();
  }),

  // ---- Documents
  Template('doc-resume', 'Clean resume', 'document', [
    'resume',
    'cv',
    'job',
    'a4',
  ], (d) {
    final p = d.page(210, 297, bg: paper, unit: LengthUnit.mm)
      ..rect(0, 0, 66, 297, fill: mist)
      ..circle(13, 16, 40, 40, fill: 0xFFD8DBE2)
      ..icon('user', 23, 26, 20, color: grey)
      ..text('CONTACT', 12, 70, 50, size: 3.2, weight: 700, color: cobalt, ls: 0.8)
      ..text(
        'sam@mail.example\n+1 555 0199\nBerlin, Germany',
        12,
        78,
        50,
        size: 3,
        lh: 1.6,
      )
      ..text('SKILLS', 12, 108, 50, size: 3.2, weight: 700, color: cobalt, ls: 0.8)
      ..text(
        'Product strategy\nUser research\nPrototyping\nDesign systems',
        12,
        116,
        50,
        size: 3,
        lh: 1.6,
      )
      ..text('Sam Taylor', 76, 16, 120, size: 11, weight: 800)
      ..text('Senior product designer', 76, 31, 120, size: 4.5, color: grey)
      ..line(76, 44, 120, color: 0xFFD8DBE2, width: 0.4)
      ..text('EXPERIENCE', 76, 52, 120, size: 3.2, weight: 700, color: cobalt, ls: 0.8);
    const jobs = [
      ('Lead designer · Northwind', '2022 – now', 'Led the redesign of the mobile app; grew the design team from 2 to 6.'),
      ('Product designer · Contoso', '2019 – 2022', 'Shipped the analytics dashboard used by 40k customers.'),
      ('UI designer · Fabrikam', '2016 – 2019', 'Built the first shared component library.'),
    ];
    var y = 60.0;
    for (final (role, period, what) in jobs) {
      p
        ..text(role, 76, y, 90, size: 4, weight: 700)
        ..text(period, 160, y, 36, size: 3, color: grey, align: TextAlignment.right)
        ..text(what, 76, y + 7, 120, size: 3.2, color: grey, lh: 1.5);
      y += 28;
    }
    p
      ..text('EDUCATION', 76, y + 4, 120, size: 3.2, weight: 700, color: cobalt, ls: 0.8)
      ..text('BA Interaction Design · University of the Arts', 76, y + 12, 120, size: 3.6)
      ..done();
  }),

  // ---- Events
  Template('event-certificate', 'Certificate of achievement', 'event', [
    'certificate',
    'award',
    'achievement',
    'a4',
  ], (d) {
    d.page(297, 210, bg: cream, unit: LengthUnit.mm)
      ..rect(10, 10, 277, 190, stroke: 0xFFB07A00, sw: 1)
      ..rect(14, 14, 269, 182, stroke: 0xFFB07A00, sw: 0.3)
      ..icon('award', 136, 26, 25, color: 0xFFB07A00)
      ..text(
        'CERTIFICATE OF ACHIEVEMENT',
        20,
        60,
        257,
        size: 6,
        weight: 700,
        ls: 2,
        align: TextAlignment.center,
      )
      ..text(
        'This certificate is presented to',
        20,
        76,
        257,
        size: 5,
        color: grey,
        align: TextAlignment.center,
        family: serif,
        italic: true,
      )
      ..text(
        'Jamie Chen',
        20,
        90,
        257,
        size: 18,
        family: serif,
        align: TextAlignment.center,
      )
      ..line(88, 118, 121, color: 0xFFB07A00, width: 0.4)
      ..text(
        'for outstanding work in the 2026 design challenge',
        20,
        125,
        257,
        size: 5,
        color: grey,
        align: TextAlignment.center,
      )
      ..line(50, 172, 70, color: ink, width: 0.3)
      ..text('Date', 50, 175, 70, size: 3.5, color: grey, align: TextAlignment.center)
      ..line(177, 172, 70, color: ink, width: 0.3)
      ..text('Signature', 177, 175, 70, size: 3.5, color: grey, align: TextAlignment.center)
      ..done();
  }),
  Template('event-birthday', 'Birthday invitation', 'event', [
    'invitation',
    'birthday',
    'party',
  ], (d) {
    d.page(127, 178, bg: 0xFFFFF0F6, unit: LengthUnit.mm)
      ..circle(-20, -20, 70, 70, fill: 0xFFFFC2DA)
      ..circle(90, 140, 60, 60, fill: 0xFFFFE08A)
      ..emoji('1f388', 44, 22, 38)
      ..text(
        'You’re invited!',
        8,
        70,
        111,
        size: 11,
        weight: 800,
        color: 0xFFC2185B,
        align: TextAlignment.center,
      )
      ..text(
        'Mia turns 7',
        8,
        88,
        111,
        size: 8,
        family: serif,
        italic: true,
        align: TextAlignment.center,
      )
      ..text(
        'Saturday 4 October · 15:00\n12 Garden Lane',
        8,
        110,
        111,
        size: 4.5,
        lh: 1.6,
        align: TextAlignment.center,
      )
      ..text(
        'RSVP to Anna · 555 0123',
        8,
        150,
        111,
        size: 3.5,
        color: grey,
        align: TextAlignment.center,
      )
      ..done();
  }, license: 'CC0-1.0 AND CC-BY-4.0'),
  Template('event-save-the-date', 'Save the date', 'event', [
    'invitation',
    'wedding',
    'save the date',
  ], (d) {
    d.page(127, 178, bg: paper, unit: LengthUnit.mm)
      ..rect(8, 8, 111, 162, stroke: 0xFF9AAE8C, sw: 0.4)
      ..icon('heart', 56, 30, 15, color: 0xFF9AAE8C)
      ..text(
        'SAVE THE DATE',
        8,
        56,
        111,
        size: 4.5,
        weight: 700,
        ls: 2,
        align: TextAlignment.center,
      )
      ..text(
        'Elena\n&\nDaniel',
        8,
        70,
        111,
        size: 13,
        family: serif,
        lh: 1.15,
        align: TextAlignment.center,
      )
      ..text(
        '18 · 06 · 2027',
        8,
        128,
        111,
        size: 6,
        family: serif,
        align: TextAlignment.center,
      )
      ..text(
        'Lake House, Annecy',
        8,
        142,
        111,
        size: 4,
        color: grey,
        align: TextAlignment.center,
      )
      ..done();
  }),

  // ---- Websites and apps (boards of frames)
  Template('web-mobile-app', 'Mobile app screens', 'web', [
    'app',
    'mobile',
    'ui',
    'prototype',
    'board',
  ], (d) {
    final board = d.page(1920, 1080, bg: 0xFFF1F2F4, kind: PageKind.board, name: 'App');
    board
      ..frame('Sign in', 0, 0, 390, 844, () {
        board
          ..circle(145, 120, 100, 100, fill: cobalt)
          ..icon('sparkles', 170, 145, 50, color: paper)
          ..text('Welcome back', 24, 260, 342, size: 30, weight: 800, align: TextAlignment.center)
          ..text('Sign in to continue', 24, 306, 342, size: 16, color: grey, align: TextAlignment.center)
          ..rect(24, 380, 342, 52, fill: mist, r: 12)
          ..text('Email', 44, 396, 300, size: 16, color: grey)
          ..rect(24, 448, 342, 52, fill: mist, r: 12)
          ..text('Password', 44, 464, 300, size: 16, color: grey)
          ..rect(24, 540, 342, 56, fill: cobalt, r: 14)
          ..text('Sign in', 24, 557, 342, size: 18, weight: 700, color: paper, align: TextAlignment.center)
          ..text('Create an account', 24, 780, 342, size: 15, weight: 600, color: cobalt, align: TextAlignment.center);
      }, r: 0)
      ..frame('Home', 470, 0, 390, 844, () {
        board
          ..rect(0, 0, 390, 220, fill: cobalt)
          ..text('Good morning, Sam', 24, 70, 300, size: 24, weight: 800, color: paper)
          ..text('3 tasks due today', 24, 108, 300, size: 15, color: 0xCCFFFFFF)
          ..icon('bell', 330, 66, 28, color: paper)
          ..rect(24, 170, 342, 100, fill: paper, r: 18)
          ..text('Weekly progress', 44, 190, 300, size: 14, color: grey)
          ..rect(44, 222, 302, 12, fill: mist, r: 6)
          ..rect(44, 222, 200, 12, fill: mint, r: 6);
        for (var i = 0; i < 3; i++) {
          final y = 310.0 + i * 96;
          board
            ..rect(24, y, 342, 80, fill: paper, r: 16, stroke: 0xFFE1E3E8, sw: 1)
            ..icon(i == 0 ? 'circle-check' : 'clock', 44, y + 26, 28, color: i == 0 ? mint : grey)
            ..text(['Review designs', 'Team stand-up', 'Write release notes'][i], 88, y + 28, 260, size: 16, weight: 600);
        }
        board
          ..rect(0, 764, 390, 80, fill: paper, stroke: 0xFFE1E3E8, sw: 1)
          ..icon('house', 50, 790, 28, color: cobalt)
          ..icon('search', 142, 790, 28, color: grey)
          ..icon('calendar', 234, 790, 28, color: grey)
          ..icon('user', 318, 790, 28, color: grey);
      })
      ..frame('Profile', 940, 0, 390, 844, () {
        board
          ..circle(135, 80, 120, 120, fill: sky)
          ..icon('user', 165, 110, 60, color: cobalt)
          ..text('Sam Taylor', 24, 220, 342, size: 26, weight: 800, align: TextAlignment.center)
          ..text('Product designer', 24, 258, 342, size: 15, color: grey, align: TextAlignment.center);
        const rows = [('settings', 'Settings'), ('bell', 'Notifications'), ('shield-check', 'Privacy'), ('lock', 'Sign out')];
        for (final (i, (icon, label)) in rows.indexed) {
          final y = 330.0 + i * 70;
          board
            ..icon(icon, 32, y + 18, 26, color: grey)
            ..text(label, 76, y + 20, 240, size: 17)
            ..icon('chevron-right', 334, y + 18, 24, color: grey)
            ..line(24, y + 66, 342, color: 0xFFE1E3E8, width: 1);
        }
      });
    board.done();
  }),
  Template('web-landing', 'Landing page', 'web', [
    'website',
    'landing page',
    'web',
    'board',
  ], (d) {
    final board = d.page(1920, 1080, bg: 0xFFF1F2F4, kind: PageKind.board, name: 'Website');
    board
      ..frame('Desktop — Landing', 0, 0, 1440, 1900, () {
        board
          ..rect(0, 0, 1440, 80, fill: paper)
          ..icon('sparkles', 120, 24, 32, color: cobalt)
          ..text('Orbit', 162, 26, 200, size: 24, weight: 800)
          ..text('Product      Pricing      Docs      Blog', 640, 30, 520, size: 17, color: grey)
          ..rect(1180, 18, 140, 44, fill: cobalt, r: 10)
          ..text('Get started', 1180, 30, 140, size: 16, weight: 700, color: paper, align: TextAlignment.center)
          ..text(
            'Plan together.\nShip calmly.',
            120,
            200,
            700,
            size: 84,
            weight: 900,
            lh: 1.05,
          )
          ..text(
            'Orbit keeps small teams in sync without the noise — '
            'offline-first and private by design.',
            120,
            420,
            600,
            size: 22,
            color: grey,
            lh: 1.5,
          )
          ..rect(120, 530, 220, 60, fill: cobalt, r: 12)
          ..text('Try it free', 120, 548, 220, size: 19, weight: 700, color: paper, align: TextAlignment.center)
          ..rect(360, 530, 200, 60, fill: paper, r: 12, stroke: 0xFFD8DBE2, sw: 1.5)
          ..text('Watch demo', 360, 548, 200, size: 19, weight: 600, align: TextAlignment.center)
          ..rect(800, 160, 520, 480, fill: sky, r: 28)
          ..rect(850, 220, 420, 70, fill: paper, r: 14)
          ..rect(850, 310, 420, 70, fill: paper, r: 14)
          ..rect(850, 400, 300, 70, fill: paper, r: 14)
          ..circle(1180, 520, 100, 100, fill: sun)
          ..text('Why teams switch', 120, 760, 1200, size: 44, weight: 800, align: TextAlignment.center);
        const features = [
          ('zap', 'Fast', 'Opens instantly, even with thousands of tasks.'),
          ('shield-check', 'Private', 'Your data stays on your devices.'),
          ('users', 'Together', 'Share a board with a link or QR code.'),
        ];
        for (final (i, (icon, title, body)) in features.indexed) {
          final x = 120.0 + i * 420;
          board
            ..rect(x, 860, 380, 300, fill: paper, r: 22)
            ..circle(x + 40, 900, 72, 72, fill: sky)
            ..icon(icon, x + 58, 918, 36, color: cobalt)
            ..text(title, x + 40, 1000, 300, size: 26, weight: 800)
            ..text(body, x + 40, 1046, 300, size: 18, color: grey, lh: 1.5);
        }
        board
          ..rect(120, 1260, 1200, 360, fill: navy, r: 32)
          ..text('Start planning in minutes', 120, 1360, 1200, size: 52, weight: 900, color: paper, align: TextAlignment.center)
          ..rect(600, 1480, 240, 64, fill: sun, r: 14)
          ..text('Get started', 600, 1500, 240, size: 20, weight: 800, align: TextAlignment.center)
          ..text('© 2026 Orbit · Privacy · Terms', 120, 1760, 1200, size: 15, color: grey, align: TextAlignment.center);
      });
    board.done();
  }),
];

Future<void> main() async {
  Directory(out).createSync(recursive: true);
  final index = <Map<String, Object?>>[];
  for (final t in templates) {
    final doc = Doc(t.id);
    t.build(doc);
    final document = DesignDocument(
      id: DocumentId('tpl-${t.id}'),
      metadata: DocumentMetadata(title: t.name, author: author),
      pages: doc.pages,
      objects: doc.objects,
      assets: doc.assets,
    );
    final issues = validatePages(document.pages, document.objects);
    if (issues.isNotEmpty) {
      stderr.writeln('${t.id}: $issues');
      exitCode = 1;
      continue;
    }
    final bytes = encodeProject(document, assets: doc.bytes);
    File('$out/${t.id}.opencanvasx').writeAsBytesSync(bytes);
    final first = document.pages.first;
    index.add({
      'id': t.id,
      'name': t.name,
      'category': t.category,
      'file': '${t.id}.opencanvasx',
      'width': first.width,
      'height': first.height,
      'unit': first.unit.symbol,
      'pages': document.pages.length,
      'license': t.license,
      'license_url':
          t.license.contains('CC-BY')
              ? 'https://creativecommons.org/licenses/by/4.0/'
              : 'https://creativecommons.org/publicdomain/zero/1.0/',
      'author': author,
      'version': '1.0.0',
      'sha256': sha256Hex(bytes),
      'bytes': bytes.length,
      'tags': t.tags,
      if (first.isBoard) 'board': true,
    });
    stdout.writeln(
      '  ${t.id}: ${document.pages.length} page(s), '
      '${document.objects.length} objects, ${bytes.length ~/ 1024} KB',
    );
  }
  File('$out/index.json').writeAsStringSync(
    '${const JsonEncoder.withIndent(' ').convert({'templates': index})}\n',
  );
  stdout.writeln('${index.length} templates written to $out');
}
