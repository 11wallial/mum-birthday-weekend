#!/usr/bin/env bash
#
# Builds self-contained Break the Bank binaries into dist/.
#
# Every target embeds its content, so a build is one file (desktop) or one
# installable package (Android) that runs offline from the first launch. No
# asset is fetched at runtime — the audio cues are synthesised in-process and
# everything else is packed.
#
# Usage:  tools/package/build.sh [target ...]
#         tools/package/build.sh                 # every target this host can do
#         tools/package/build.sh linux windows   # just those
#
# GODOT may point at the editor binary; it defaults to `godot` on PATH.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST="$PROJECT_DIR/dist"
GODOT="${GODOT:-godot}"

# Android is the one target that needs a toolchain beyond Godot's own export
# templates: the APK has to be signed, and that means the Android SDK plus a
# keystore. Godot takes the keystore from GODOT_ANDROID_KEYSTORE_RELEASE_PATH /
# _USER / _PASSWORD, which is how a key stays out of the tracked presets file.
# Both are skipped rather than failed when absent, so a desktop-only host still
# builds everything else — and a missing keystore is caught here rather than in
# Godot, which downgrades a failed signing to a warning and writes an APK that
# cannot be installed.
ALL_TARGETS=(linux windows web android macos)
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=("${ALL_TARGETS[@]}")
fi

preset_for() {
    case "$1" in
        linux)   echo "Linux" ;;
        windows) echo "Windows Desktop" ;;
        android) echo "Android" ;;
        web)     echo "Web" ;;
        macos)   echo "macOS" ;;
        *)       echo "" ;;
    esac
}

output_for() {
    case "$1" in
        linux)   echo "$DIST/linux/BreakTheBank.x86_64" ;;
        windows) echo "$DIST/windows/BreakTheBank.exe" ;;
        android) echo "$DIST/android/BreakTheBank.apk" ;;
        web)     echo "$DIST/web/index.html" ;;
        macos)   echo "$DIST/macos/BreakTheBank.zip" ;;
        *)       echo "" ;;
    esac
}

built=()
skipped=()

for target in "${TARGETS[@]}"; do
    preset="$(preset_for "$target")"
    if [ -z "$preset" ]; then
        echo "unknown target: $target" >&2
        exit 2
    fi

    if [ "$target" = "android" ]; then
        if [ -z "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ]; then
            skipped+=("android (no ANDROID_HOME or ANDROID_SDK_ROOT)")
            continue
        fi
        if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
            skipped+=("android (no GODOT_ANDROID_KEYSTORE_RELEASE_PATH; an unsigned APK will not install)")
            continue
        fi
    fi

    out="$(output_for "$target")"
    mkdir -p "$(dirname "$out")"
    echo "==> $preset"
    # --headless keeps this usable from CI and a terminal; a failed export still
    # leaves a zero-byte file behind, so the size check below is the real gate.
    "$GODOT" --headless --path "$PROJECT_DIR" --export-release "$preset" "$out"

    if [ ! -s "$out" ]; then
        echo "export produced nothing at $out" >&2
        exit 1
    fi
    built+=("$target  $(du -h "$out" | cut -f1)  $out")
done

echo
echo "Built:"
printf '  %s\n' "${built[@]}"
if [ ${#skipped[@]} -gt 0 ]; then
    echo "Skipped:"
    printf '  %s\n' "${skipped[@]}"
fi
