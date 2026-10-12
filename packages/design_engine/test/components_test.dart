import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

DesignDocument apply(DesignDocument doc, Change change) =>
    change.applyTo(doc).$1;

ObjectId Function() ids(String p) {
  var n = 0;
  return () => ObjectId('$p${n++}');
}

void main() {
  final doc = documentWith([
    rect('a', x: 100, y: 100),
    rect('b', x: 250, y: 100, w: 50),
  ]);

  test('a selection becomes an unfilled component frame', () {
    final (change, id) = makeComponent(doc, const [
      ObjectId('a'),
      ObjectId('b'),
    ], newId: ids('c'));
    final after = apply(doc, change);
    final component = after.objects[id]!;
    expect(isComponent(component), isTrue);
    expect(component.style, ObjectStyle.none);
    expect(component.childIds, hasLength(2));
    expect(componentsIn(after).single.id, id);
    expect(validatePages(after.pages, after.objects), isEmpty);
  });

  test('a single frame is flagged in place', () {
    final framed = apply(
      doc,
      groupObjects(
        doc,
        const [ObjectId('a')],
        asFrame: true,
        newId: ids('f'),
      ).$1,
    );
    final (change, id) = makeComponent(framed, const [ObjectId('f0')]);
    expect(id, const ObjectId('f0'));
    expect(isComponent(apply(framed, change).objects[id]), isTrue);
  });

  test('instances detach into scaled, editable copies', () {
    final (change, componentId) = makeComponent(doc, const [
      ObjectId('a'),
      ObjectId('b'),
    ], newId: ids('c'));
    var d = apply(doc, change);
    final component = d.objects[componentId]!;
    final instance = newInstance(
      id: const ObjectId('i'),
      pageId: page1,
      component: component,
      center: const Point2D(500, 500),
    ).copyWith(
      transform: ObjectTransform(
        x: 400,
        y: 400,
        width: component.transform.width * 2,
        height: component.transform.height * 2,
      ),
    );
    d = apply(d, insertObjects(d, page1, [instance]));
    final (detach, frameId) = detachInstance(
      d,
      const ObjectId('i'),
      newId: ids('d'),
    );
    final after = apply(d, detach);
    expect(after.objects.containsKey(const ObjectId('i')), isFalse);
    final frame = after.objects[frameId]!;
    expect(frame.type, ObjectType.frame);
    expect(isComponent(frame), isFalse);
    expect(after.pages.first.objectIds.last, frameId);
    final child = after.objects[frame.childIds.first]!;
    expect(child.transform.width, 200); // 100 × 2
    expect(validatePages(after.pages, after.objects), isEmpty);
    // The main component is untouched.
    expect(after.objects[componentId], d.objects[componentId]);
  });

  test('detaching without a component does nothing', () {
    final orphan = DesignObject(
      id: const ObjectId('i'),
      type: ObjectType.instance,
      pageId: page1,
      transform: ObjectTransform(width: 10, height: 10),
      payload: const InstancePayload(ObjectId('gone')),
    );
    final d = apply(doc, insertObjects(doc, page1, [orphan]));
    expect(detachInstance(d, const ObjectId('i')).$2, isNull);
  });
}
