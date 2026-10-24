#!/usr/bin/env bash
# Local release build: Windows EXE + signed Android APK.
# Needs: Godot 4.3 binary ($GODOT), its export templates, Java, and uber-apk-signer ($APK_SIGNER jar).
# For Android, Godot only checks that an SDK folder with platform-tools/ and build-tools/*/apksigner
# exists; signing is done afterwards by uber-apk-signer (zipalign + v1/v2/v3 signature).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
APK_SIGNER=${APK_SIGNER:-uber-apk-signer.jar}
mkdir -p build/windows build/android
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/EU5Lite.exe
"$GODOT" --headless --path . --export-release "Android" build/android/EU5Lite-unsigned.apk
java -jar "$APK_SIGNER" --apks build/android/EU5Lite-unsigned.apk --out build/android
mv build/android/EU5Lite-aligned-debugSigned.apk build/android/EU5Lite.apk
rm -f build/android/*.idsig build/android/EU5Lite-unsigned.apk
ls -la build/windows build/android
