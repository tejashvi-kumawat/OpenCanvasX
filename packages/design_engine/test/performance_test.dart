@Tags(['performance'])
library;

import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

/// Phase 1 exit gate: a 1,000-object document stays responsive. Each
/// per-frame operation must stay well inside a 60 fps frame even in this
/// unoptimised JIT test run; whole-document work (save) gets more time.
void main() {
  const page = PageId('p');
  final objects = <ObjectId, DesignObject>{};
  for (var i = 0; i < 1000; i++) {
    final id = ObjectId('o$i');
    objects[id] = DesignObject(
      id: id,
      type: switch (i % 3) {
        0 => ObjectType.rect,
        1 => ObjectType.ellipse,
        _ => ObjectType.text,
      },
      pageId: page,
      transform: ObjectTransform(
        x: (i % 40) * 50.0,
        y: (i ~/ 40) * 50.0,
        width: 40,
        height: 40,
        rotation: (i % 7) * 5.0,
      ),
      payload:
          i % 3 == 2
              ? TextPayload('Label $i', fontSize: 14)
              : const NoPayload(),
    );
  }
  final doc = DesignDocument(
    id: const DocumentId('perf'),
    metadata: const DocumentMetadata(title: 'Perf'),
    pages: [
      DesignPage(
        id: page,
        width: 2000,
        height: 1250,
        objectIds: objects.keys.toList(),
      ),
    ],
    objects: objects,
  );
  final p = doc.pages.single;

  /// Median milliseconds of [runs] calls of [body].
  double median(void Function() body, {int runs = 15}) {
    body(); // warm up
    final times = <double>[];
    for (var i = 0; i < runs; i++) {
      final w = Stopwatch()..start();
      body();
      times.add(w.elapsedMicroseconds / 1000);
    }
    times.sort();
    return times[times.length ~/ 2];
  }

  test('snapping targets and a snap per pointer move', () {
    late SnapTargets targets;
    final collect = median(
      () =>
          targets = SnapTargets.collect(
            doc,
            p,
            exclude: const {ObjectId('o0')},
          ),
    );
    final snap = median(
      () => targets.snapRect(Rect2D.fromLTWH(503, 498, 40, 40), threshold: 5),
    );
    expect(collect, lessThan(50), reason: 'collect $collect ms');
    expect(snap, lessThan(8), reason: 'snapRect $snap ms');
  });

  test('hit testing a click', () {
    final hit = median(() => pickObject(doc, p, const Point2D(1975, 1225)));
    final miss = median(() => pickObject(doc, p, const Point2D(1999, 1249)));
    expect(hit, lessThan(8), reason: 'hit $hit ms');
    expect(miss, lessThan(8), reason: 'miss $miss ms');
  });

  test('moving one object and undoing it', () {
    final history = History();
    var current = doc;
    final step = median(() {
      current = history.apply(
        current,
        moveObjects(current, [const ObjectId('o500')], 3, 2),
      );
    });
    final undo = median(() => current = history.undo(current));
    expect(step, lessThan(8), reason: 'move $step ms');
    expect(undo, lessThan(8), reason: 'undo $undo ms');
  });

  test('moving 100 selected objects at once', () {
    final ids = [for (var i = 0; i < 100; i++) ObjectId('o${i * 10}')];
    final move = median(() => moveObjects(doc, ids, 4, 4).applyTo(doc));
    expect(move, lessThan(16), reason: 'move 100 $move ms');
  });

  test('encoding and decoding the whole document', () {
    final encode = median(() => encodeDocumentBody(doc), runs: 5);
    final body = encodeDocumentBody(doc);
    final manifest = encodeManifest(doc);
    final decode = median(
      () => decodeDocument(manifest: manifest, body: body),
      runs: 5,
    );
    expect(encode, lessThan(200), reason: 'encode $encode ms');
    expect(decode, lessThan(300), reason: 'decode $decode ms');
  });
}
