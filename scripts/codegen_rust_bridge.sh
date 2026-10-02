#!/usr/bin/env bash
# Generates Dart bindings from rust/ods_native (requires flutter_rust_bridge_codegen).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/.toolchain/flutter/bin:$PATH"

cd "$ROOT"
dart pub global activate flutter_rust_bridge_codegen 2.9.0
flutter_rust_bridge_codegen generate
