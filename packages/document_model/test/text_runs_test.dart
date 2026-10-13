import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  const text = 'Hello bold world';
  final bold = textRunPatch(fontWeight: 700);

  List<(int, int, int?)> spans(List<TextRun> runs) => [
    for (final r in runs) (r.start, r.end, r.fontWeight),
  ];

  test('applying a style splits and merges runs', () {
    var runs = applyRunPatch(const [], 6, 10, bold, text.length);
    expect(spans(runs), [(6, 10, 700)]);
    // Overlapping and touching ranges merge into one run.
    runs = applyRunPatch(runs, 10, 16, bold, text.length);
    expect(spans(runs), [(6, 16, 700)]);
    runs = applyRunPatch(runs, 0, 8, textRunPatch(italic: true), text.length);
    expect(
      [for (final r in runs) (r.start, r.end, r.fontWeight, r.italic)],
      [(0, 6, null, true), (6, 8, 700, true), (8, 16, 700, null)],
    );
    expect(runStyleAt(runs, 7).italic, isTrue);
    expect(runStyleAt(runs, 12).italic, isNull);
  });

  test('clearing a field removes it and drops plain runs', () {
    final runs = applyRunPatch(const [], 6, 10, bold, text.length);
    expect(clearRunFields(runs, 0, 16, text.length, fontWeight: true), isEmpty);
    expect(spans(clearRunFields(runs, 6, 8, text.length, fontWeight: true)), [
      (8, 10, 700),
    ]);
  });

  test('typing keeps formatting where it belongs', () {
    final runs = applyRunPatch(const [], 6, 10, bold, text.length);
    // Typing after "bold" continues in bold.
    expect(spans(shiftRunsForEdit(runs, text, 'Hello bolder world')), [
      (6, 12, 700),
    ]);
    // Typing before "bold" stays plain; the run moves.
    expect(spans(shiftRunsForEdit(runs, text, 'Hello so bold world')), [
      (9, 13, 700),
    ]);
    // Deleting part of the run shrinks it; deleting all of it drops it.
    expect(spans(shiftRunsForEdit(runs, text, 'Hello bd world')), [
      (6, 8, 700),
    ]);
    expect(shiftRunsForEdit(runs, text, 'Hello  world'), isEmpty);
    // Replacing the whole text keeps nothing beyond its length.
    expect(spans(shiftRunsForEdit(runs, text, 'Hi')), isEmpty);
  });

  test('payloads normalise runs and survive JSON', () {
    final payload = TextPayload(
      text,
      runs: [
        TextRun(6, 10, fontWeight: 700, color: ArgbColor(0xFFFF0000)),
        TextRun(11, 99, underline: true, fontFamily: 'Lora', fontSize: 30),
      ],
    );
    expect(payload.runs.last.end, text.length);
    const page = PageId('p');
    final o = DesignObject(
      id: const ObjectId('t'),
      type: ObjectType.text,
      pageId: page,
      transform: ObjectTransform(width: 100, height: 20),
      payload: payload,
    );
    final doc = DesignDocument(
      id: const DocumentId('d'),
      metadata: const DocumentMetadata(title: 'runs'),
      pages: [
        DesignPage(id: page, width: 100, height: 100, objectIds: [o.id]),
      ],
      objects: {o.id: o},
    );
    final back = decodeDocument(
      manifest: encodeManifest(doc),
      body: encodeDocumentBody(doc),
    );
    expect(back.objects[o.id]!.payload, payload);
    expect(() => TextRun(3, 3), throwsArgumentError);
    expect(() => TextRun(0, 2, fontWeight: 650), throwsArgumentError);
  });
}
