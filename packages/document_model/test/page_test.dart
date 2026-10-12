import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  const id = PageId('page-1');
  const hash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  DesignPage a4() => DesignPage(
    id: id,
    width: 210,
    height: 297,
    unit: LengthUnit.mm,
    dpi: 300,
  );

  group('DesignPage', () {
    test('has sensible defaults', () {
      final page = DesignPage(id: id, width: 1080, height: 1080);
      expect(page.name, '');
      expect(page.unit, LengthUnit.px);
      expect(page.dpi, 96);
      expect(page.background, const SolidBackground(ArgbColor.white));
      expect(page.bleed, PageInsets.zero);
      expect(page.margins, PageInsets.zero);
      expect(page.guides, isEmpty);
      expect(page.objectIds, isEmpty);
    });

    test('stores print settings', () {
      final page = a4().copyWith(
        name: 'Cover',
        bleed: PageInsets.all(3),
        margins: PageInsets(top: 20, right: 15, bottom: 20, left: 15),
        guides: [Guide(GuideAxis.vertical, 105)],
        background: const TransparentBackground(),
      );
      expect(page.name, 'Cover');
      expect(page.unit.symbol, 'mm');
      expect(page.bleed.left, 3);
      expect(page.margins.top, 20);
      expect(page.guides.single, Guide(GuideAxis.vertical, 105));
      expect(page.background, const TransparentBackground());
    });

    test('rejects non-positive or non-finite size and dpi', () {
      expect(
        () => DesignPage(id: id, width: 0, height: 10),
        throwsArgumentError,
      );
      expect(
        () => DesignPage(id: id, width: 10, height: -1),
        throwsArgumentError,
      );
      expect(
        () => DesignPage(id: id, width: double.infinity, height: 10),
        throwsArgumentError,
      );
      expect(
        () => DesignPage(id: id, width: 10, height: 10, dpi: 0),
        throwsArgumentError,
      );
    });

    test('rejects margins larger than the page', () {
      expect(
        () => DesignPage(
          id: id,
          width: 100,
          height: 100,
          margins: PageInsets(left: 60, right: 50),
        ),
        throwsArgumentError,
      );
      expect(
        () => DesignPage(
          id: id,
          width: 100,
          height: 100,
          margins: PageInsets(top: 101),
        ),
        throwsArgumentError,
      );
      expect(
        DesignPage(
          id: id,
          width: 100,
          height: 100,
          margins: PageInsets(left: 50, right: 50),
        ).margins.left,
        50,
      );
    });

    test('rejects duplicate root object ids', () {
      expect(
        () => DesignPage(
          id: id,
          width: 10,
          height: 10,
          objectIds: const [ObjectId('a'), ObjectId('a')],
        ),
        throwsArgumentError,
      );
    });

    test('lists are unmodifiable copies', () {
      final roots = [const ObjectId('a')];
      final page = DesignPage(id: id, width: 10, height: 10, objectIds: roots);
      roots.add(const ObjectId('b'));
      expect(page.objectIds, [const ObjectId('a')]);
      expect(
        () => page.objectIds.add(const ObjectId('c')),
        throwsUnsupportedError,
      );
      expect(
        () => page.guides.add(Guide(GuideAxis.horizontal, 1)),
        throwsUnsupportedError,
      );
    });

    test('copyWith keeps the id and validates', () {
      final page = a4();
      expect(page.copyWith(width: 100).id, id);
      expect(() => page.copyWith(width: -1), throwsArgumentError);
    });

    test('equality is by value', () {
      expect(a4(), a4());
      expect(a4().hashCode, a4().hashCode);
      expect(a4(), isNot(a4().copyWith(name: 'Other')));
    });
  });

  group('PageInsets', () {
    test('all sets every edge', () {
      expect(
        PageInsets.all(5),
        PageInsets(top: 5, right: 5, bottom: 5, left: 5),
      );
    });

    test('rejects negative or non-finite values', () {
      expect(() => PageInsets(top: -1), throwsArgumentError);
      expect(() => PageInsets(left: double.nan), throwsArgumentError);
    });
  });

  group('Guide', () {
    test('may lie outside the page but must be finite', () {
      expect(Guide(GuideAxis.horizontal, -50).position, -50);
      expect(
        () => Guide(GuideAxis.horizontal, double.infinity),
        throwsArgumentError,
      );
    });
  });

  group('PageBackground', () {
    test('image background requires a SHA-256 hex digest', () {
      expect(ImageBackground(hash).assetHash, hash);
      expect(() => ImageBackground('not-a-hash'), throwsArgumentError);
    });

    test('compares by value', () {
      expect(
        SolidBackground(ArgbColor(0xFF112233)),
        SolidBackground(ArgbColor(0xFF112233)),
      );
      expect(ImageBackground(hash), ImageBackground(hash));
    });
  });

  test('LengthUnit symbols match the file format', () {
    expect(LengthUnit.values.map((u) => u.symbol), [
      'px',
      'pt',
      'mm',
      'cm',
      'in',
    ]);
  });
}
