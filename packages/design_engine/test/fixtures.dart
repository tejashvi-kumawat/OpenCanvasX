import 'package:document_model/document_model.dart';

const page1 = PageId('p1');
const page2 = PageId('p2');

/// Sequential ids: n1, n2, … for predictable assertions.
ObjectId Function() idSequence([String prefix = 'n']) {
  var next = 0;
  return () => ObjectId('$prefix${++next}');
}

DesignObject rect(
  String id, {
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 50,
  double rotation = 0,
  PageId? pageId = page1,
  String? parent,
  List<String> children = const [],
  bool hidden = false,
  bool locked = false,
  ObjectType type = ObjectType.rect,
}) => DesignObject(
  id: ObjectId(id),
  type: children.isNotEmpty ? ObjectType.group : type,
  transform: ObjectTransform(
    x: x,
    y: y,
    width: w,
    height: h,
    rotation: rotation,
  ),
  pageId: parent == null ? pageId : null,
  parentId: parent == null ? null : ObjectId(parent),
  childIds: children.map(ObjectId.new),
  hidden: hidden,
  locked: locked,
);

/// Two 1000×1000 px pages; page 1 holds [roots] (+ [nested]) in order.
DesignDocument documentWith(
  List<DesignObject> roots, {
  List<DesignObject> nested = const [],
  List<DesignObject> page2Roots = const [],
}) => DesignDocument(
  id: const DocumentId('doc'),
  metadata: const DocumentMetadata(title: 'Test'),
  pages: [
    DesignPage(
      id: page1,
      width: 1000,
      height: 1000,
      objectIds: roots.map((o) => o.id),
    ),
    DesignPage(
      id: page2,
      width: 1000,
      height: 1000,
      objectIds: page2Roots.map((o) => o.id),
    ),
  ],
  objects: {
    for (final o in [...roots, ...nested, ...page2Roots]) o.id: o,
  },
);
