#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required. Install Flutter, then run this script again." >&2
  exit 1
fi

if [[ -e "$ROOT/ios" ]]; then
  echo "The iOS platform folder already exists. Remove it before bootstrapping again." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

flutter create \
  --project-name loopmate \
  --org dev.loopmate \
  --platforms=ios \
  "$TMP_DIR/generated"

cp -a "$TMP_DIR/generated/ios" "$ROOT/ios"
if [[ -f "$TMP_DIR/generated/.metadata" ]]; then
  cp "$TMP_DIR/generated/.metadata" "$ROOT/.metadata"
fi

(
  cd "$ROOT"
  flutter pub get
)

echo "iOS project is ready. Run flutter run from this directory."
