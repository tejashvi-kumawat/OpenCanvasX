#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$ROOT/.toolchain/flutter"
VERSION="${FLUTTER_VERSION:-3.29.3}"

if [[ -x "$FLUTTER_DIR/bin/flutter" ]]; then
  echo "Flutter already installed at $FLUTTER_DIR"
  exit 0
fi

mkdir -p "$ROOT/.toolchain"
ARCHIVE="flutter_linux_${VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$ARCHIVE"
echo "Downloading $URL ..."
curl -fsSL "$URL" -o "/tmp/$ARCHIVE"
tar -xf "/tmp/$ARCHIVE" -C "$ROOT/.toolchain"
"$FLUTTER_DIR/bin/flutter" config --no-analytics
"$FLUTTER_DIR/bin/flutter" precache --linux
echo "Flutter ready: $($FLUTTER_DIR/bin/flutter --version)"
