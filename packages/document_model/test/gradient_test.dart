import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  final red = ArgbColor(0xFFFF0000);
  final blue = ArgbColor(0xFF0000FF);

  test('gradients sort stops and need two of them', () {
    final g = LinearGradientFill([GradientStop(1, blue), GradientStop(0, red)]);
    expect(g.stops.first.color, red);
    expect(g.representative, red);
    expect(g.solidColor, isNull);
    expect(g.angle, 90);
    expect(LinearGradientFill(g.stops, angle: -90).angle, 270);
    expect(
      () => LinearGradientFill([GradientStop(0, red)]),
      throwsArgumentError,
    );
    expect(() => GradientStop(1.5, red), throwsArgumentError);
    expect(() => RadialGradientFill(g.stops, radius: 0), throwsArgumentError);
    expect(SolidFill(red).solidColor, red);
  });

  test('gradient fills round-trip through JSON', () {
    const page = PageId('p');
    DesignObject shape(String id, Fill fill) => DesignObject(
      id: ObjectId(id),
      type: ObjectType.rect,
      pageId: page,
      transform: ObjectTransform(width: 10, height: 10),
      style: ObjectStyle(fill: fill),
    );
    final linear = shape(
      'l',
      LinearGradientFill([
        GradientStop(0, red),
        GradientStop(0.6, blue),
      ], angle: 45),
    );
    final radial = shape(
      'r',
      RadialGradientFill(
        [GradientStop(0, red), GradientStop(1, blue)],
        centerX: 0.2,
        radius: 0.8,
      ),
    );
    final doc = DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'g'),
      pages: [
        DesignPage(
          id: page,
          width: 100,
          height: 100,
          objectIds: [linear.id, radial.id],
        ),
      ],
      objects: {linear.id: linear, radial.id: radial},
    );
    final body = encodeDocumentBody(doc);
    final back = decodeDocument(manifest: encodeManifest(doc), body: body);
    expect(back, doc);
    final fill = (body['objects']! as Map)['l'] as Map;
    expect(((fill['style']! as Map)['fill']! as Map)['type'], 'linear');
  });
}
