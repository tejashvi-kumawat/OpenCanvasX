import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  const page = PageId('page-1');
  const id = ObjectId('obj-1');
  final box = ObjectTransform(width: 100, height: 50);

  DesignObject rect({PageId? pageId = page, ObjectId? parentId}) =>
      DesignObject(
        id: id,
        type: ObjectType.rect,
        transform: box,
        pageId: pageId,
        parentId: parentId,
      );

  test('creates a root rectangle with defaults', () {
    final o = rect();
    expect(o.isRoot, isTrue);
    expect(o.opacity, 1);
    expect(o.blendMode, ObjectBlendMode.normal);
    expect(o.locked, isFalse);
    expect(o.hidden, isFalse);
    expect(o.childIds, isEmpty);
    expect(o.payload, const NoPayload());
  });

  test('requires exactly one of pageId or parentId', () {
    expect(() => rect(pageId: null), throwsArgumentError);
    expect(() => rect(parentId: const ObjectId('group')), throwsArgumentError);
    expect(
      rect(pageId: null, parentId: const ObjectId('group')).isRoot,
      isFalse,
    );
  });

  test('rejects self as parent', () {
    expect(() => rect(pageId: null, parentId: id), throwsArgumentError);
  });

  test('only groups have children, without duplicates or self', () {
    expect(
      () => DesignObject(
        id: id,
        type: ObjectType.rect,
        transform: box,
        pageId: page,
        childIds: const [ObjectId('c')],
      ),
      throwsArgumentError,
    );
    DesignObject group(List<ObjectId> children) => DesignObject(
      id: id,
      type: ObjectType.group,
      transform: box,
      pageId: page,
      childIds: children,
    );
    expect(group(const [ObjectId('a'), ObjectId('b')]).childIds, hasLength(2));
    expect(
      () => group(const [ObjectId('a'), ObjectId('a')]),
      throwsArgumentError,
    );
    expect(() => group(const [id]), throwsArgumentError);
  });

  test('childIds are an unmodifiable copy', () {
    final children = [const ObjectId('a')];
    final g = DesignObject(
      id: id,
      type: ObjectType.group,
      transform: box,
      pageId: page,
      childIds: children,
    );
    children.add(const ObjectId('b'));
    expect(g.childIds, [const ObjectId('a')]);
    expect(() => g.childIds.add(const ObjectId('c')), throwsUnsupportedError);
  });

  test('rejects opacity outside 0..1', () {
    expect(
      () => DesignObject(
        id: id,
        type: ObjectType.rect,
        transform: box,
        pageId: page,
        opacity: 1.2,
      ),
      throwsArgumentError,
    );
  });

  test('rejects payload that does not match the type', () {
    expect(
      () => DesignObject(
        id: id,
        type: ObjectType.text,
        transform: box,
        pageId: page,
      ),
      throwsArgumentError,
    );
    final text = DesignObject(
      id: id,
      type: ObjectType.text,
      transform: box,
      pageId: page,
      payload: TextPayload('Hello'),
    );
    expect((text.payload as TextPayload).text, 'Hello');
  });

  group('copyWith', () {
    test('replaces given fields and keeps the id', () {
      final o = rect().copyWith(opacity: 0.5, locked: true, name: 'Box');
      expect(o.id, id);
      expect(o.opacity, 0.5);
      expect(o.locked, isTrue);
      expect(o.name, 'Box');
      expect(o.pageId, page);
    });

    test('can clear nullable fields to move an object into a group', () {
      final moved = rect().copyWith(
        pageId: null,
        parentId: const ObjectId('group'),
      );
      expect(moved.pageId, isNull);
      expect(moved.parentId, const ObjectId('group'));
    });

    test('still validates', () {
      expect(() => rect().copyWith(pageId: null), throwsArgumentError);
    });
  });

  test('equality is by value', () {
    expect(rect(), rect());
    expect(rect().hashCode, rect().hashCode);
    expect(rect(), isNot(rect().copyWith(hidden: true)));
  });
}
