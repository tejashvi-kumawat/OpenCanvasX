import 'package:document_model/document_model.dart';
import 'package:test/test.dart';

void main() {
  test('packageVersion returns semver', () {
    expect(packageVersion(), '0.0.1');
  });
}
