# Flutter Environment Setup Assistant

A desktop app for macOS and Windows that takes a fresh computer to a fully
working Flutter development environment: scan, plan, install, configure,
diagnose, repair. No tutorials, no manual PATH edits.

**Download:** https://github.com/Umer9538/flutter-setup-assistant/releases/latest

**New here? Read the [User Guide](GUIDE.md)** for step-by-step instructions, including how to open the app the first time on macOS and Windows.

## What it installs and configures

| Component | macOS | Windows | Notes |
|---|---|---|---|
| Git | Apple Command Line Tools (`xcode-select --install`) | Git for Windows, per-user silent install | Flutter needs Git to manage its SDK |
| Flutter SDK | Official stable zip, SHA-256 verified | Same | Installed to `~/development/flutter` |
| Java JDK 17 | Eclipse Temurin tar.gz | Temurin zip | Installed side by side; existing JDK 17-21 is reused |
| Android Studio | `.dmg` copied to `/Applications` | zip to `%LOCALAPPDATA%\Programs` + Start menu shortcut | No admin rights needed |
| Android SDK | cmdline-tools → `sdkmanager` | Same | platform-tools, platform, build-tools, emulator |
| Emulator | ARM64 or x86_64 system image + `Pixel 7` AVD | x86_64 image + AVD | Started with `flutter emulators --launch Flutter_Pixel_7` |
| VS Code | zip to `/Applications` | User setup, silent | Plus Dart and Flutter extensions |
| CocoaPods | Homebrew | n/a | Only when Xcode is present |
| Environment | Managed block in `~/.zprofile` / `~/.zshrc` | User-scope registry via .NET API | PATH, `ANDROID_HOME`, `JAVA_HOME`, `flutter config` |
| Licenses | `sdkmanager --licenses` + `flutter doctor --android-licenses` | Same | Accepted automatically |

Xcode, Visual Studio and Chrome cannot be installed silently; the app explains
exactly what to do and links to the download.

## Safety rules

* Nothing runs as administrator. Everything goes to user-writable folders.
* Existing tools are never deleted. Incompatible versions are left alone and a
  compatible copy is installed beside them (an older Flutter folder is moved
  aside, not removed).
* Shell profiles are backed up to `~/development/.setup-assistant/backups`
  before they are edited; the environment block is delimited and idempotent.
* On Windows the current user environment is snapshotted before any change,
  and PATH is edited through `[Environment]::SetEnvironmentVariable`, never
  `setx` (which truncates at 1024 characters).
* Every download is checksum-verified when the publisher provides a hash, and
  cached in `~/development/.setup-assistant/downloads` so retries resume.
* The user approves the plan before anything is written.
* A full log is written to `~/development/.setup-assistant/logs`.

## Version management

`lib/domain/version_catalog.dart` holds the compatibility rules and pinned
fallbacks (JDK 17-21 accepted, Android API 36, minimum Flutter 3.24, minimum
Android Studio 2024.1). At scan time `lib/services/release_resolver.dart`
fetches the current versions from the official feeds:

* Flutter: `storage.googleapis.com/flutter_infra_release/releases/releases_<os>.json`
* JDK: Adoptium API v3
* Android Studio: JetBrains `android-studio-releases-list.json` (Release channel)
* Command line tools: Google `repository2-3.xml`
* VS Code: `update.code.visualstudio.com`
* Git for Windows: GitHub releases API

If a feed is unreachable the pinned fallback is used and the plan says so.

## Project layout

```
lib/
  core/        platform info, process runner, downloader, extractor, shell env, log, paths
  domain/      component model, version rules, plan, steps, doctor report
  services/
    detection/ EnvironmentDetector – read-only scan
    installers/ one installer per component, shared InstallContext
    doctor/    flutter doctor parser + plain-language FixCatalog
    release_resolver.dart, setup_orchestrator.dart
  state/       SetupController (ChangeNotifier) drives the flow
  ui/          AppShell + Welcome / Scan / Plan / Install / Diagnose / Finish screens
tool/scan_cli.dart  headless scan for debugging: dart run tool/scan_cli.dart
test/               parser, environment block and version rule tests
```

Adding another stack later means adding `ComponentId`s, a detector branch,
an installer, and fix-catalog entries; the flow, UI and safety machinery are
stack-agnostic.

## Build

```
flutter pub get
flutter test
flutter build macos --release     # on macOS
flutter build windows --release   # on Windows
```

The macOS target has App Sandbox disabled (see `macos/Runner/*.entitlements`)
because the app must write to `/Applications`, mount disk images and run
installers. For distribution outside the App Store, sign and notarize with a
Developer ID certificate.
