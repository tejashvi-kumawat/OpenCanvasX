import 'package:crypto_engine/crypto_engine.dart';
import 'package:test/test.dart';

void main() {
  test('packageVersion returns semver', () {
    expect(packageVersion(), '0.0.1');
  });
}
