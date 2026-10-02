import 'package:ods_native_bridge/ods_native_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('native bridge stub version', () async {
    await OdsNativeBridge.init();
    expect(OdsNativeBridge.nativeVersion(), '0.0.1');
    expect(packageVersion(), '0.0.1');
  });
}
