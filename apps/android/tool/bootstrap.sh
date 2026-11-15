#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required. Install Flutter, then run this script again." >&2
  exit 1
fi

if [[ -e "$ROOT/android" ]]; then
  echo "The Android platform folder already exists. Remove it before bootstrapping again." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

flutter create \
  --project-name loopmate \
  --org dev.loopmate \
  --platforms=android \
  "$TMP_DIR/generated"

cp -a "$TMP_DIR/generated/android" "$ROOT/android"
if [[ -f "$TMP_DIR/generated/.metadata" ]]; then
  cp "$TMP_DIR/generated/.metadata" "$ROOT/.metadata"
fi

# GestureDescription dispatch requires Android API 24 or newer.
python3 - "$ROOT/android/app/build.gradle.kts" "$ROOT/android/app/build.gradle" <<'PY'
from pathlib import Path
import re
import sys

for candidate in map(Path, sys.argv[1:]):
    if not candidate.is_file():
        continue
    source = candidate.read_text()
    updated = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", source)
    updated = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", updated)
    if updated == source and not re.search(r"minSdk(?:Version)?\s*[= ]\s*24", source):
        raise SystemExit(f"Could not set Android minSdk to 24 in {candidate}")
    candidate.write_text(updated)
    break
else:
    raise SystemExit("Could not find the generated Android app Gradle file")
PY

ANDROID_MAIN="$ROOT/android/app/src/main"
CUSTOM_ANDROID="$ROOT/platform/android/app/src/main"
cp "$CUSTOM_ANDROID/AndroidManifest.xml" "$ANDROID_MAIN/AndroidManifest.xml"
mkdir -p "$ANDROID_MAIN/kotlin/dev/loopmate/loopmate"
cp "$CUSTOM_ANDROID/kotlin/dev/loopmate/loopmate/MainActivity.kt" \
  "$ANDROID_MAIN/kotlin/dev/loopmate/loopmate/MainActivity.kt"
cp "$CUSTOM_ANDROID/kotlin/dev/loopmate/loopmate/LoopAccessibilityService.kt" \
  "$ANDROID_MAIN/kotlin/dev/loopmate/loopmate/LoopAccessibilityService.kt"
mkdir -p "$ANDROID_MAIN/res/xml" "$ANDROID_MAIN/res/values"
cp "$CUSTOM_ANDROID/res/xml/loopmate_accessibility_service.xml" "$ANDROID_MAIN/res/xml/"
cp "$CUSTOM_ANDROID/res/values/loopmate_strings.xml" "$ANDROID_MAIN/res/values/"

(
  cd "$ROOT"
  flutter pub get
)

echo "Android project is ready. Run flutter run from this directory."
