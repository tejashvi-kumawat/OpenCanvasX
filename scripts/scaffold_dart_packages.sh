#!/usr/bin/env bash
# Creates skeleton Dart packages under packages/ (idempotent for lib/test).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES=(
  design_engine
  document_model
  renderer
  template_engine
  asset_engine
  typography
  export_engine
  pdf_engine
  media_engine
  collaboration
  crdt
  crypto_engine
  networking
  identity
  ai_engine
  agents
  plugins_sdk
  search
  storage
  ocx_logging
  ocx_native_bridge
)

for pkg in "${PACKAGES[@]}"; do
  dir="$ROOT/packages/$pkg"
  mkdir -p "$dir/lib" "$dir/test"
  if [[ ! -f "$dir/pubspec.yaml" ]]; then
    cat >"$dir/pubspec.yaml" <<EOF
name: $pkg
description: OpenCanvasX — $pkg (skeleton).
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.7.0

dev_dependencies:
  test: ^1.25.0
  very_good_analysis: ^7.0.0
EOF
  fi
  lib_file="$dir/lib/${pkg}.dart"
  if [[ ! -f "$lib_file" ]]; then
    cat >"$lib_file" <<EOF
/// OpenCanvasX — \`$pkg\` package (Phase 0 skeleton).
library;

/// Package marker for Phase 0; replaced with real APIs in later phases.
String packageVersion() => '0.0.1';
EOF
  fi
  test_file="$dir/test/${pkg}_test.dart"
  if [[ ! -f "$test_file" ]]; then
    cat >"$test_file" <<EOF
import 'package:$pkg/$pkg.dart';
import 'package:test/test.dart';

void main() {
  test('packageVersion returns semver', () {
    expect(packageVersion(), '0.0.1');
  });
}
EOF
  fi
done

echo "Scaffolded ${#PACKAGES[@]} Dart packages under packages/"
