import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  const page = PageId('page-1');
  final box = ObjectTransform(width: 10, height: 10);

  DesignObject group(String id, List<String> children, {String? parent}) =>
      DesignObject(
        id: ObjectId(id),
        type: ObjectType.group,
        transform: box,
        pageId: parent == null ? page : null,
        parentId: parent == null ? null : ObjectId(parent),
        childIds: children.map(ObjectId.new),
      );

  DesignObject shape(String id, {String? parent}) => DesignObject(
    id: ObjectId(id),
    type: ObjectType.ellipse,
    transform: box,
    pageId: parent == null ? page : null,
    parentId: parent == null ? null : ObjectId(parent),
  );

  Map<ObjectId, DesignObject> mapOf(List<DesignObject> objects) => {
    for (final o in objects) o.id: o,
  };

  List<String> messages(List<DesignObject> objects) =>
      validateObjectGraph(mapOf(objects)).map((i) => i.toString()).toList();

  test('accepts a consistent nested tree', () {
    expect(
      messages([
        group('g1', ['a', 'g2']),
        shape('a', parent: 'g1'),
        group('g2', ['b'], parent: 'g1'),
        shape('b', parent: 'g2'),
        shape('root'),
      ]),
      isEmpty,
    );
  });

  test('accepts an empty document', () {
    expect(validateObjectGraph({}), isEmpty);
  });

  test('reports a missing parent', () {
    expect(messages([shape('a', parent: 'ghost')]), [
      'a: parent ghost does not exist',
    ]);
  });

  test('reports a parent that is not a group', () {
    expect(
      messages([shape('p'), shape('a', parent: 'p')]),
      contains('a: parent p is not a group or frame'),
    );
  });

  test('reports a parent that does not list the child', () {
    expect(messages([group('g', []), shape('a', parent: 'g')]), [
      'a: parent g does not list it as child',
    ]);
  });

  test('reports a missing child and a child pointing elsewhere', () {
    expect(
      messages([
        group('g', ['missing', 'a']),
        shape('a'),
      ]),
      ['g: child missing does not exist', 'g: child a has a different parent'],
    );
  });

  test('reports a key that differs from the object id', () {
    final issues = validateObjectGraph({const ObjectId('wrong'): shape('a')});
    expect(issues.single.toString(), 'a: stored under different key wrong');
  });

  test('reports cycles', () {
    final issues = messages([
      group('x', ['y'], parent: 'y'),
      group('y', ['x'], parent: 'x'),
    ]);
    expect(
      issues,
      containsAll(['x: is its own ancestor', 'y: is its own ancestor']),
    );
  });
}
