import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> entry({String id = 'post', String? license = 'CC0-1.0'}) =>
    {
      'id': id,
      'name': 'Post',
      'category': 'social',
      'file': '$id.opencanvasx',
      'width': 1080,
      'height': 1080,
      'unit': 'px',
      'pages': 1,
      'license': license,
      'license_url': 'https://creativecommons.org/publicdomain/zero/1.0/',
      'author': 'OpenCanvasX contributors',
      'tags': ['Instagram', 'sale'],
    };

DesignDocument template() {
  const page = PageId('tp');
  final frame = DesignObject(
    id: const ObjectId('g'),
    type: ObjectType.group,
    pageId: page,
    childIds: const [ObjectId('a')],
    transform: ObjectTransform(width: 100, height: 100),
  );
  final child = DesignObject(
    id: const ObjectId('a'),
    type: ObjectType.rect,
    parentId: const ObjectId('g'),
    transform: ObjectTransform(width: 10, height: 10),
  );
  return DesignDocument(
    id: const DocumentId('tpl'),
    metadata: const DocumentMetadata(title: 'Template'),
    pages: [
      DesignPage(
        id: page,
        width: 1080,
        height: 1080,
        name: 'Cover',
        background: SolidBackground(ArgbColor(0xFFFF0000)),
        objectIds: const [ObjectId('g')],
      ),
    ],
    objects: {frame.id: frame, child.id: child},
  );
}

DesignDocument target({bool board = false}) => DesignDocument(
  id: const DocumentId('doc'),
  metadata: const DocumentMetadata(title: 'Mine'),
  pages: [
    DesignPage(
      id: const PageId('p1'),
      width: 1920,
      height: 1080,
      kind: board ? PageKind.board : PageKind.fixed,
    ),
  ],
);

ObjectId Function() ids(String prefix) {
  var n = 0;
  return () => ObjectId('$prefix${n++}');
}

PageId Function() pageIds() {
  var n = 0;
  return () => PageId('np${n++}');
}

void main() {
  group('TemplateInfo', () {
    test('parses an index entry', () {
      final info = TemplateInfo.fromJson(entry());
      expect(info.categoryLabel, 'Social media');
      expect(info.tags, ['instagram', 'sale']);
      expect(info.matches('sale post'), isTrue);
      expect(info.matches('wedding'), isFalse);
      expect(TemplateInfo.fromJson(info.toJson()).id, 'post');
    });

    test('rejects entries without licence or with unsafe paths', () {
      expect(
        () => TemplateInfo.fromJson(entry(license: null)),
        throwsFormatException,
      );
      final unsafe = entry()..['file'] = '../evil.opencanvasx';
      expect(() => TemplateInfo.fromJson(unsafe), throwsFormatException);
      final notDesign = entry()..['file'] = 'x.exe';
      expect(() => TemplateInfo.fromJson(notDesign), throwsFormatException);
    });

    test('index drops duplicate ids', () {
      final list = parseTemplateIndex({
        'templates': [entry(), entry(), entry(id: 'other')],
      });
      expect(list.map((t) => t.id), ['post', 'other']);
    });
  });

  group('templates', () {
    test('a valid template has no issues; broken ones are reported', () {
      expect(validateTemplate(template()), isEmpty);
      final broken = DesignDocument(
        id: const DocumentId('x'),
        metadata: const DocumentMetadata(title: 'x'),
        pages: const [],
      );
      expect(validateTemplate(broken), contains('template has no pages'));
    });

    test('instantiate gives fresh ids and the new title', () {
      final doc = instantiateTemplate(
        template(),
        title: 'My post',
        newObjectId: ids('o'),
        newPageId: pageIds(),
      );
      expect(doc.metadata.title, 'My post');
      expect(doc.id, isNot(const DocumentId('tpl')));
      expect(doc.pages.single.id, const PageId('np0'));
      expect(doc.objects.keys.toSet(), {
        const ObjectId('o0'),
        const ObjectId('o1'),
      });
      expect(validatePages(doc.pages, doc.objects), isEmpty);
    });

    test('insert adds template pages after the active page', () {
      final doc = target();
      final result = insertTemplate(
        doc,
        template(),
        after: const PageId('p1'),
        newObjectId: ids('o'),
        newPageId: pageIds(),
      );
      final (after, undo) = result.change.applyTo(doc);
      expect(after.pages.map((p) => p.id), [
        const PageId('p1'),
        const PageId('np0'),
      ]);
      expect(result.pages, [const PageId('np0')]);
      expect(validatePages(after.pages, after.objects), isEmpty);
      expect(undo.applyTo(after).$1, doc);
    });

    test('on a board, template pages become frames side by side', () {
      final doc = target(board: true);
      final result = insertTemplate(
        doc,
        template(),
        after: const PageId('p1'),
        asFramesOn: const PageId('p1'),
        newObjectId: ids('o'),
        newPageId: pageIds(),
      );
      final (after, _) = result.change.applyTo(doc);
      final frame = after.objects[result.frames.single]!;
      expect(frame.type, ObjectType.frame);
      expect(frame.name, 'Cover');
      expect(frame.style!.fill, SolidFill(ArgbColor(0xFFFF0000)));
      expect(after.pages.single.objectIds, result.frames);
      expect(validatePages(after.pages, after.objects), isEmpty);
      expect(worldBounds(after, frame.id)!.width, closeTo(1080, 1e-9));
    });
  });
}
