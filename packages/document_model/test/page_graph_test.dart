import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  final box = ObjectTransform(width: 10, height: 10);

  DesignPage page(String id, List<String> roots) => DesignPage(
    id: PageId(id),
    width: 100,
    height: 100,
    objectIds: roots.map(ObjectId.new),
  );

  DesignObject root(String id, String pageId) => DesignObject(
    id: ObjectId(id),
    type: ObjectType.rect,
    transform: box,
    pageId: PageId(pageId),
  );

  DesignObject nested(String id, String parent) => DesignObject(
    id: ObjectId(id),
    type: ObjectType.rect,
    transform: box,
    parentId: ObjectId(parent),
  );

  List<String> messages(List<DesignPage> pages, List<DesignObject> objects) =>
      validatePages(pages, {
        for (final o in objects) o.id: o,
      }).map((i) => i.toString()).toList();

  test('accepts consistent pages and roots', () {
    expect(
      messages(
        [
          page('p1', ['a', 'b']),
          page('p2', ['c']),
          page('empty', []),
        ],
        [root('a', 'p1'), root('b', 'p1'), root('c', 'p2')],
      ),
      isEmpty,
    );
  });

  test('ignores nested objects', () {
    expect(messages([page('p1', [])], [nested('x', 'g')]), isEmpty);
  });

  test('reports duplicate page ids', () {
    expect(messages([page('p1', []), page('p1', [])], []), [
      'p1: duplicate page id',
    ]);
  });

  test('reports a listed object that does not exist', () {
    expect(
      messages([
        page('p1', ['ghost']),
      ], []),
      ['p1: object ghost does not exist'],
    );
  });

  test('reports a listed object that belongs elsewhere', () {
    expect(
      messages(
        [
          page('p1', ['a', 'n']),
          page('p2', ['a']),
        ],
        [root('a', 'p2'), nested('n', 'g')],
      ),
      [
        'p1: object a is not a root object of this page',
        'p1: object n is not a root object of this page',
      ],
    );
  });

  test('reports a root on a missing page', () {
    expect(messages([], [root('a', 'gone')]), ['a: page gone does not exist']);
  });

  test('reports a root its page does not list', () {
    expect(messages([page('p1', [])], [root('a', 'p1')]), [
      'a: page p1 does not list it',
    ]);
  });
}
