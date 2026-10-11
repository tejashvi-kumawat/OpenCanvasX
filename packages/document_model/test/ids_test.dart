import 'dart:math';

import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generateUuidV4 produces canonical version 4 UUIDs', () {
    for (var i = 0; i < 100; i++) {
      expect(generateUuidV4(), matches(uuidV4));
    }
  });

  test('generated ids are unique', () {
    final ids = {for (var i = 0; i < 1000; i++) ObjectId.generate()};
    expect(ids, hasLength(1000));
  });

  test('seeded random gives reproducible ids', () {
    expect(ObjectId.generate(Random(1)), ObjectId.generate(Random(1)));
    expect(PageId.generate(Random(1)).value, matches(uuidV4));
  });

  test('ids compare by value', () {
    expect(const ObjectId('a'), const ObjectId('a'));
    expect(const ObjectId('a'), isNot(const ObjectId('b')));
  });
}
