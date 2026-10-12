import 'package:ocx_native_bridge/ocx_native_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('native bridge stub version', () async {
    await OcxNativeBridge.init();
    expect(OcxNativeBridge.nativeVersion(), '0.0.1');
    expect(packageVersion(), '0.0.1');
  });
}
