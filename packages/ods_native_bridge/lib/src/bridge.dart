/// Phase 0 bridge: FRB codegen wired in CI via `scripts/codegen_rust_bridge.sh`.
///
/// Until native libraries are linked, falls back to a Dart stub so the app compiles everywhere.
class OdsNativeBridge {
  OdsNativeBridge._();

  static bool _initialized = false;

  /// Call once at startup before other native APIs.
  static Future<void> init() async {
    _initialized = true;
  }

  /// Native core semver (stub until FRB dynamic library is loaded).
  static String nativeVersion() {
    if (!_initialized) {
      throw StateError('OdsNativeBridge.init() must be called first');
    }
    return '0.0.1';
  }
}

String packageVersion() => '0.0.1';
