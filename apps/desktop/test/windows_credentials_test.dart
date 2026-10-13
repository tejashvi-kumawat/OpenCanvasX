import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencanvasx/src/ai/windows_credentials.dart';

void main() {
  test('Credential Manager round trip', () {
    const name = 'opencanvasx.test.roundtrip';
    deleteWindowsCredential(name);
    expect(readWindowsCredential(name), isNull);
    writeWindowsCredential(name, 'sk-tëst-123');
    expect(readWindowsCredential(name), 'sk-tëst-123');
    deleteWindowsCredential(name);
    expect(readWindowsCredential(name), isNull);
  }, skip: !Platform.isWindows);
}
