import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  group('ArgbColor', () {
    test('packs and unpacks channels', () {
      final c = ArgbColor.fromArgb(0x80, 0x12, 0x34, 0x56);
      expect(c.value, 0x80123456);
      expect([c.alpha, c.red, c.green, c.blue], [0x80, 0x12, 0x34, 0x56]);
      expect(c, ArgbColor(0x80123456));
    });

    test('rejects out-of-range values', () {
      expect(() => ArgbColor(-1), throwsArgumentError);
      expect(() => ArgbColor(0x100000000), throwsArgumentError);
      expect(() => ArgbColor.fromArgb(256, 0, 0, 0), throwsRangeError);
    });
  });

  group('ObjectTransform', () {
    test('has sensible defaults', () {
      final t = ObjectTransform(width: 10, height: 20);
      expect([t.x, t.y, t.rotation], [0, 0, 0]);
      expect([t.scaleX, t.scaleY], [1, 1]);
      expect([t.anchorX, t.anchorY], [0.5, 0.5]);
      expect(t.isFlippedHorizontally, isFalse);
    });

    test('negative scale means flipped', () {
      final t = ObjectTransform(width: 1, height: 1, scaleX: -1, scaleY: -2);
      expect(t.isFlippedHorizontally, isTrue);
      expect(t.isFlippedVertically, isTrue);
    });

    test('allows zero-height lines', () {
      expect(ObjectTransform(width: 100, height: 0).height, 0);
    });

    test('rejects invalid values', () {
      expect(() => ObjectTransform(width: -1, height: 1), throwsArgumentError);
      expect(
        () => ObjectTransform(width: double.nan, height: 1),
        throwsArgumentError,
      );
      expect(
        () => ObjectTransform(width: 1, height: 1, x: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => ObjectTransform(width: 1, height: 1, scaleX: 0),
        throwsArgumentError,
      );
      expect(
        () => ObjectTransform(width: 1, height: 1, anchorY: 1.5),
        throwsArgumentError,
      );
    });

    test('copyWith replaces fields and keeps validation', () {
      final t = ObjectTransform(width: 10, height: 10);
      expect(t.copyWith(rotation: 45).rotation, 45);
      expect(t.copyWith(rotation: 45).width, 10);
      expect(() => t.copyWith(width: -5), throwsArgumentError);
    });

    test('equality is by value', () {
      expect(
        ObjectTransform(width: 1, height: 2, x: 3),
        ObjectTransform(width: 1, height: 2, x: 3),
      );
      expect(
        ObjectTransform(width: 1, height: 2).hashCode,
        ObjectTransform(width: 1, height: 2).hashCode,
      );
    });
  });

  group('ObjectStyle', () {
    test('compares by value', () {
      final a = ObjectStyle(
        fill: const SolidFill(ArgbColor.white),
        stroke: Stroke(color: ArgbColor.black, width: 2),
        cornerRadius: 4,
      );
      final b = ObjectStyle(
        fill: const SolidFill(ArgbColor.white),
        stroke: Stroke(color: ArgbColor.black, width: 2),
        cornerRadius: 4,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('rejects negative stroke width and corner radius', () {
      expect(
        () => Stroke(color: ArgbColor.black, width: -1),
        throwsArgumentError,
      );
      expect(() => ObjectStyle(cornerRadius: -1), throwsArgumentError);
    });
  });

  group('payloads', () {
    const hash =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    test('image payload requires a lowercase SHA-256 hex digest', () {
      expect(ImagePayload(hash).assetHash, hash);
      expect(() => ImagePayload('abc'), throwsArgumentError);
      expect(() => ImagePayload(hash.toUpperCase()), throwsArgumentError);
    });

    test('path payload is immutable and compares by segments', () {
      final segments = [MoveTo(0, 0), LineTo(10, 0), const ClosePath()];
      final path = PathPayload(segments);
      segments.add(LineTo(5, 5));
      expect(path.segments, hasLength(3));
      expect(() => path.segments.add(LineTo(1, 1)), throwsUnsupportedError);
      expect(
        path,
        PathPayload([MoveTo(0, 0), LineTo(10, 0), const ClosePath()]),
      );
    });

    test('path segments reject non-finite coordinates', () {
      expect(() => MoveTo(double.nan, 0), throwsArgumentError);
      expect(() => QuadTo(0, 0, double.infinity, 0), throwsArgumentError);
      expect(() => CubicTo(0, 0, 0, 0, 0, double.nan), throwsArgumentError);
    });

    test('fits matches each object type', () {
      expect(TextPayload('hi').fits(ObjectType.text), isTrue);
      expect(TextPayload('hi').fits(ObjectType.rect), isFalse);
      expect(ImagePayload(hash).fits(ObjectType.image), isTrue);
      expect(PathPayload(const []).fits(ObjectType.path), isTrue);
      expect(() => PathPayload(const [], viewWidth: 0), throwsArgumentError);
      expect(
        PathPayload(const [], viewWidth: 2, viewHeight: 3),
        isNot(PathPayload(const [])),
      );
      for (final type in [
        ObjectType.rect,
        ObjectType.roundedRect,
        ObjectType.ellipse,
        ObjectType.line,
        ObjectType.arrow,
        ObjectType.group,
      ]) {
        expect(const NoPayload().fits(type), isTrue, reason: type.name);
      }
      expect(const NoPayload().fits(ObjectType.text), isFalse);
    });
  });
}
