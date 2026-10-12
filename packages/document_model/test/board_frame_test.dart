import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  const page = PageId('board');
  final frame = DesignObject(
    id: const ObjectId('f'),
    type: ObjectType.frame,
    pageId: page,
    childIds: const [ObjectId('r')],
    transform: ObjectTransform(x: -500, y: 200, width: 390, height: 844),
    style: ObjectStyle(fill: const SolidFill(ArgbColor.white)),
    payload: const FramePayload(clipContent: false),
    name: 'iPhone',
  );
  final child = DesignObject(
    id: const ObjectId('r'),
    type: ObjectType.rect,
    parentId: const ObjectId('f'),
    transform: ObjectTransform(width: 10, height: 10),
  );
  final doc = DesignDocument(
    id: const DocumentId('d'),
    metadata: const DocumentMetadata(title: 'Board'),
    pages: [
      DesignPage(
        id: page,
        width: 1440,
        height: 1024,
        kind: PageKind.board,
        objectIds: const [ObjectId('f')],
      ),
    ],
    objects: {frame.id: frame, child.id: child},
  );

  test('frames are containers with a frame payload', () {
    expect(ObjectType.frame.isContainer, isTrue);
    expect(ObjectType.rect.isContainer, isFalse);
    expect(validatePages(doc.pages, doc.objects), isEmpty);
    expect(const FramePayload().clipContent, isTrue);
    expect(const FramePayload().fits(ObjectType.frame), isTrue);
    expect(const NoPayload().fits(ObjectType.frame), isFalse);
  });

  test('boards and frames round-trip through JSON', () {
    final body = encodeDocumentBody(doc);
    final pageJson = (body['pages']! as List).single as Map;
    expect(pageJson['kind'], 'board');
    final back = decodeDocument(manifest: encodeManifest(doc), body: body);
    expect(back, doc);
    expect(back.pages.single.isBoard, isTrue);
  });

  test('fixed pages omit the kind key', () {
    final fixed = DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'Fixed'),
      pages: [DesignPage(id: page, width: 10, height: 10)],
    );
    final pageJson =
        (encodeDocumentBody(fixed)['pages']! as List).single as Map;
    expect(pageJson.containsKey('kind'), isFalse);
  });

  test('version 1 documents still open', () {
    final body = encodeDocumentBody(doc)..['schema_version'] = 1;
    expect(
      decodeDocument(manifest: encodeManifest(doc), body: body).pages,
      hasLength(1),
    );
  });

  test('prototype links round-trip and keep one link per source', () {
    final page = doc.pages.single.copyWith(
      links: const [
        PrototypeLink(source: ObjectId('r'), target: ObjectId('f')),
        PrototypeLink(
          source: ObjectId('r'),
          target: ObjectId('f'),
          transition: PrototypeTransition.slideLeft,
        ),
      ],
    );
    expect(page.links.single.transition, PrototypeTransition.slideLeft);
    final linked = DesignDocument(
      id: doc.id,
      metadata: doc.metadata,
      pages: [page],
      objects: doc.objects,
    );
    final body = encodeDocumentBody(linked);
    final pageJson = (body['pages']! as List).single as Map;
    expect(
      ((pageJson['links']! as List).single as Map)['transition'],
      'slide_left',
    );
    expect(
      decodeDocument(manifest: encodeManifest(linked), body: body),
      linked,
    );
  });
}
