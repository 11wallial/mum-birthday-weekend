# Packaging

Break the Bank ships as a set of self-contained builds. The rule they all obey:
**nothing is fetched at launch.** Content, scripts, fonts and audio are packed
into the binary, and the audio cues are synthesised in-process rather than
streamed, so a build opened offline on a machine that has never seen the game
behaves exactly like one that has.

## What gets built

| Target | Output | Shape |
| --- | --- | --- |
| Windows | `dist/windows/BreakTheBank.exe` | One file — the PCK is embedded |
| Linux | `dist/linux/BreakTheBank.x86_64` | One file — the PCK is embedded |
| macOS | `dist/macos/BreakTheBank.zip` | A `.app` bundle, universal, unsigned |
| Android | `dist/android/BreakTheBank.apk` | arm64 + x86_64, signed with the release keystore |
| Web | `dist/web/` | `index.html` plus wasm, PCK and a service worker |

`dist/` is ignored by git. Builds are published as CI artifacts instead, so the
repository never carries a binary.

## Building

```bash
cd break-the-bank
tools/package/build.sh                 # everything this host can do
tools/package/build.sh linux windows   # just those
```

The script needs Godot 4.4.1 on `PATH` (or `GODOT=/path/to/godot`) and its
**export templates** installed — those are the platform runtimes each build is
wrapped around, a 1.2 GB download from the Godot release page for the matching
version.

Android additionally needs the Android SDK and a keystore, because an APK that
is not signed will not install at all. Two settings live outside the project:

- **The SDK path** comes from Godot's *editor settings*, not the project, so CI
  writes a throwaway editor profile carrying `export/android/android_sdk_path`.
- **The keystore** comes from the environment —
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`. That seam
  exists so a signing key never has to be written into `export_presets.cfg`,
  which is tracked.

Note the *release* keystore specifically: `--export-release` ignores the debug
one, which is the mistake that made the first packaging run fail.

The script skips Android rather than failing when either is missing, so a
desktop-only machine still builds everything else.

## Verifying a build

An export that fails still leaves a file behind, so file existence proves
nothing. What is actually checked:

- `build.sh` fails on a zero-byte output.
- CI re-checks every expected path and runs `apksigner verify` on the APK. That
  check is not cosmetic: Godot downgrades a failed signing to a *warning* and
  still writes the APK, so an export can "succeed" and hand you a package no
  device will install.
- The Linux binary is booted under `xvfb` with the software GL driver, and the
  web build is loaded in headless Chromium and screenshotted, on both a desktop
  and a phone viewport. Both are checked for script errors, not just for
  starting.

That last one is worth keeping. Loading the web build in a browser is how the
audio playback bug was found: the web export defaults to *sample* playback,
which cannot play an `AudioStreamGenerator` at all, so every ambience bed was
silently failing with a warning per voice. Every voice now asks for
`PLAYBACK_TYPE_STREAM` explicitly.

## Mobile specifics

- **Orientation** is locked to landscape on handhelds (`display/window/handheld/orientation`).
  The web build follows the page instead, so it can end up portrait.
- **Renderer** is `mobile` on handhelds and Forward+ on desktop, set per-platform
  in `project.godot` so one project serves both.
- **Framing** adapts: `CameraController._fit_to_screen()` measures the window and
  switches the camera between a fixed vertical and a fixed horizontal field.
  Without it a portrait phone crops the machine off both edges — the framing was
  authored at 16:9 and a narrower screen keeps the vertical field by default.
- **Reachability** was the real work. Leaving the draft, opening setup, toggling
  the camera and starting a new run were all keyboard-only; a phone would have
  been stuck in the shop with no way out. The draft and the setup panel now carry
  their own buttons, and `TouchBar` supplies the rest.

## Web hosting

The web build is exported without thread support, which is deliberate: the
threaded build requires `SharedArrayBuffer`, and that requires cross-origin
isolation headers most static hosts do not send — the usual cause of a Godot web
build that shows a blank canvas on a phone. The no-threads build runs from any
plain static host.

It cannot run from a `file://` path; browsers refuse to instantiate WebAssembly
that way. Any static server works:

```bash
cd break-the-bank/dist/web && python3 -m http.server 8080
```

A service worker and manifest ship with it, so once a browser has loaded it the
game is installable and works offline.
