#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/.toolchain/flutter/bin:$HOME/.pub-cache/bin:$PATH"
if ! command -v melos >/dev/null 2>&1; then
  dart pub global activate melos
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found. Install Flutter or run:"
  echo "  scripts/install_flutter_linux.sh"
  exit 1
fi

cd "$ROOT"
dart pub get
dart run melos bootstrap
flutter --version
