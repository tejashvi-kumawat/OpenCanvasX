import 'dart:convert';
import 'dart:typed_data';

import 'package:document_model/document_model.dart';
import 'package:export_engine/export_engine.dart';
import 'package:test/test.dart';

const pageId = PageId('p');
const boardId = PageId('b');
final hash = 'a' * 64;

DesignObject obj(
  String id,
  ObjectType type, {
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 50,
  PageId? page = pageId,
  String? parent,
  List<String> children = const [],
  ObjectStyle? style,
  ObjectPayload payload = const NoPayload(),
  String? name,
}) => DesignObject(
  id: ObjectId(id),
  type: type,
  pageId: parent == null ? page : null,
  parentId: parent == null ? null : ObjectId(parent),
  childIds: children.map(ObjectId.new),
  name: name,
  transform: ObjectTransform(x: x, y: y, width: w, height: h),
  style: style,
  payload: payload,
);

final red = ObjectStyle(fill: SolidFill(ArgbColor(0xFFFF0000)));

DesignDocument document() {
  final objects = [
    obj('r', ObjectType.rect, x: 10, y: 20, style: red),
    obj('e', ObjectType.ellipse, x: 200, y: 100, w: 80, h: 80),
    obj(
      't',
      ObjectType.text,
      x: 50,
      y: 300,
      w: 300,
      h: 60,
      style: red,
      payload: TextPayload('Hello <world>\nsecond', fontSize: 20),
    ),
    obj(
      'i',
      ObjectType.image,
      x: 400,
      y: 400,
      style: ObjectStyle(fill: SolidFill(ArgbColor(0xFF3256F0))),
      payload: ImagePayload(hash),
    ),
    obj(
      'f',
      ObjectType.frame,
      page: boardId,
      x: -100,
      w: 390,
      h: 844,
      children: ['fc'],
      name: 'Phone — Home',
      style: ObjectStyle(fill: const SolidFill(ArgbColor.white)),
      payload: const FramePayload(),
    ),
    obj('fc', ObjectType.star, parent: 'f', payload: StarPayload()),
    obj('loose', ObjectType.rect, page: boardId, x: 900, y: 900),
  ];
  return DesignDocument(
    id: const DocumentId('d'),
    metadata: const DocumentMetadata(title: 'Doc'),
    pages: [
      DesignPage(
        id: pageId,
        width: 1080,
        height: 1080,
        objectIds: const [
          ObjectId('r'),
          ObjectId('e'),
          ObjectId('t'),
          ObjectId('i'),
        ],
      ),
      DesignPage(
        id: boardId,
        width: 1920,
        height: 1080,
        kind: PageKind.board,
        name: 'Board',
        objectIds: const [ObjectId('f'), ObjectId('loose')],
      ),
    ],
    objects: {for (final o in objects) o.id: o},
    assets: {hash: AssetInfo(mime: 'image/svg+xml', byteLength: 10)},
  );
}

void main() {
  final doc = document();

  group('exportTargets', () {
    test('a fixed page exports whole with its background', () {
      final targets = exportTargets(
        doc,
        scope: ExportScope.currentPage,
        activePage: pageId,
      );
      expect(targets.single.name, 'Page 1');
      expect(targets.single.region, Rect2D.fromLTWH(0, 0, 1080, 1080));
      expect(targets.single.includeBackground, isTrue);
    });

    test('a board exports each top-level frame', () {
      final targets = exportTargets(
        doc,
        scope: ExportScope.currentPage,
        activePage: boardId,
      );
      expect(targets.single.name, 'Phone — Home');
      expect(targets.single.region, Rect2D.fromLTWH(-100, 0, 390, 844));
      expect(targets.single.roots, const [ObjectId('f')]);
      expect(targets.single.includeBackground, isFalse);
    });

    test('all pages and the selection', () {
      expect(
        exportTargets(doc, scope: ExportScope.allPages, activePage: pageId),
        hasLength(2),
      );
      final selection =
          exportTargets(
            doc,
            scope: ExportScope.selection,
            activePage: pageId,
            selection: {const ObjectId('r'), const ObjectId('e')},
          ).single;
      expect(selection.region, Rect2D.fromLTWH(10, 20, 270, 160));
      expect(selection.roots, const [ObjectId('r'), ObjectId('e')]);
      expect(
        exportTargets(doc, scope: ExportScope.selection, activePage: pageId),
        isEmpty,
      );
    });

    test('pixel and point sizes follow units and DPI', () {
      final a4 = DesignPage(
        id: pageId,
        width: 210,
        height: 297,
        unit: LengthUnit.mm,
        dpi: 300,
      );
      final target = ExportTarget(
        pageId: pageId,
        name: 'A4',
        region: Rect2D.fromLTWH(0, 0, 210, 297),
        roots: const [],
        includeBackground: true,
      );
      final px = exportPixelSize(a4, target);
      expect((px.width, px.height), (2480, 3508));
      expect(exportPixelSize(a4, target, scale: 0.5).width, 1240);
      final pt = exportPointSize(a4, target);
      expect(pt.width, closeTo(595.28, 0.01));
      expect(pt.height, closeTo(841.89, 0.01));
    });

    test('file names are safe', () {
      expect(exportFileName('Phone — Home', 'png'), 'Phone - Home.png');
      expect(exportFileName('a/b:c', 'svg'), 'a-b-c.svg');
      expect(exportFileName('   ', 'pdf'), 'Export.pdf');
    });
  });

  group('exportSvg', () {
    final icon = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        ' <path stroke="currentColor" d="M0 0h24"/></svg>',
      ),
    );

    test('writes shapes, text and tinted images', () {
      final target =
          exportTargets(
            doc,
            scope: ExportScope.currentPage,
            activePage: pageId,
          ).single;
      final svg = exportSvg(doc, target, assets: {hash: icon});
      expect(svg, startsWith('<?xml'));
      expect(svg, contains('width="1080" height="1080"'));
      expect(svg, contains('viewBox="0 0 1080 1080"'));
      expect(svg, contains('<rect x="0" y="0" width="100" height="50"'));
      expect(svg, contains('fill="#ff0000"'));
      expect(svg, contains('<ellipse cx="40" cy="40" rx="40" ry="40"'));
      expect(svg, contains('Hello &lt;world&gt;</tspan>'));
      expect(svg, contains('>second</tspan>'));
      expect(svg, contains('xlink:href="data:image/svg+xml;base64,'));
      final encoded = RegExp(r'base64,([^"]+)').firstMatch(svg)!.group(1)!;
      expect(utf8.decode(base64Decode(encoded)), contains('#3256f0'));
      // The white page background comes first.
      expect(svg.indexOf('fill="#ffffff"'), lessThan(svg.indexOf('#ff0000')));
    });

    test('frames clip their content and transparent drops the background', () {
      final target =
          exportTargets(
            doc,
            scope: ExportScope.currentPage,
            activePage: boardId,
          ).single;
      final svg = exportSvg(doc, target, assets: const {}, transparent: true);
      expect(svg, contains('<clipPath id="clip0">'));
      expect(svg, contains('clip-path="url(#clip0)"'));
      expect(svg, contains('<polygon points='));
      expect(svg, contains('<title>Phone — Home</title>'));
      expect(svg, contains('viewBox="-100 0 390 844"'));
    });

    test('custom line breaks are honoured', () {
      final target =
          exportTargets(
            doc,
            scope: ExportScope.selection,
            activePage: pageId,
            selection: {const ObjectId('t')},
          ).single;
      final svg = exportSvg(
        doc,
        target,
        assets: const {},
        lines: (_) => ['one', 'two', 'three'],
      );
      expect(RegExp('<tspan').allMatches(svg), hasLength(3));
    });
  });

  group('encoders', () {
    RgbaPixels pixels() {
      final rgba = Uint8List(4 * 4 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba
          ..[i] = 255
          ..[i + 3] = i < 32 ? 255 : 0;
      }
      return (rgba: rgba, width: 4, height: 4);
    }

    test('JPEG and PNG have the right signatures', () {
      final jpeg = encodeJpeg(pixels(), quality: 80);
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      final png = encodePng(pixels());
      expect(png.sublist(1, 4), utf8.encode('PNG'));
    });

    test('PDF pages have the physical size and metadata', () async {
      final pdf = await encodeRasterPdf(
        [
          (widthPt: 595.28, heightPt: 841.89, pixels: pixels()),
          (widthPt: 300, heightPt: 200, pixels: pixels()),
        ],
        title: 'My design',
        author: 'Me',
      );
      final text = latin1.decode(pdf);
      expect(text, startsWith('%PDF-'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(text), hasLength(2));
      expect(text, contains('595.28'));
      expect(text, contains('OpenCanvasX'));
    });
  });

  test('gradients become SVG gradient definitions', () {
    final g = DesignObject(
      id: const ObjectId('g'),
      type: ObjectType.ellipse,
      pageId: pageId,
      transform: ObjectTransform(width: 100, height: 100),
      style: ObjectStyle(
        fill: RadialGradientFill([
          GradientStop(0, ArgbColor(0xFFFFFFFF)),
          GradientStop(1, ArgbColor(0x803256F0)),
        ]),
      ),
    );
    final gd = DesignDocument(
      id: const DocumentId('g'),
      metadata: const DocumentMetadata(title: 'g'),
      pages: [
        DesignPage(id: pageId, width: 100, height: 100, objectIds: [g.id]),
      ],
      objects: {g.id: g},
    );
    final target =
        exportTargets(
          gd,
          scope: ExportScope.currentPage,
          activePage: pageId,
        ).single;
    final svg = exportSvg(gd, target, assets: const {});
    expect(
      svg,
      contains('<radialGradient id="grad0" cx="0.5" cy="0.5" r="0.5">'),
    );
    expect(svg, contains('stop-opacity="0.502"'));
    expect(svg, contains('fill="url(#grad0)"'));
    expect(svg.indexOf('<defs>'), lessThan(svg.indexOf('url(#grad0)')));
  });
}
