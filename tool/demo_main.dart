// Demo entrypoint used only to capture screenshots of each screen with
// realistic sample data, without touching the machine it runs on.
//
//   flutter build macos --release -t tool/demo_main.dart
//   FSA_DEMO_STAGE=plan "build/macos/Build/Products/Release/Flutter Setup Assistant.app/Contents/MacOS/Flutter Setup Assistant"
//
// FSA_DEMO_STAGE is one of: welcome, scan, plan, install, doctor, done.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_setup_assistant/core/install_paths.dart';
import 'package:flutter_setup_assistant/core/platform_info.dart';
import 'package:flutter_setup_assistant/domain/component.dart';
import 'package:flutter_setup_assistant/domain/doctor.dart';
import 'package:flutter_setup_assistant/domain/setup_step.dart';
import 'package:flutter_setup_assistant/services/detection/environment_detector.dart';
import 'package:flutter_setup_assistant/services/doctor/doctor_parser.dart';
import 'package:flutter_setup_assistant/services/doctor/fix_catalog.dart';
import 'package:flutter_setup_assistant/services/release_resolver.dart';
import 'package:flutter_setup_assistant/services/setup_orchestrator.dart';
import 'package:flutter_setup_assistant/state/setup_controller.dart';
import 'package:flutter_setup_assistant/ui/app_shell.dart';
import 'package:flutter_setup_assistant/ui/theme.dart';
import 'package:provider/provider.dart';

const _doctorRaw = '''
[✓] Flutter (Channel stable, 3.47.6, on macOS 27.1 27B74 darwin-arm64, locale en-US) [612ms]
    • Flutter version 3.47.6 on channel stable at /Users/alex/development/flutter
    • Dart version 3.13.5
    • DevTools version 2.57.0

[!] Android toolchain - develop for Android devices (Android SDK version 36.0.0) [1,104ms]
    • Android SDK at /Users/alex/Library/Android/sdk
    • Platform android-36, build-tools 36.0.0
    • Java binary at: /Users/alex/development/jdk-17/Contents/Home/bin/java
    ✗ Android license status unknown.
      Run `flutter doctor --android-licenses` to accept the SDK licenses.

[✗] Xcode - develop for iOS and macOS
    ✗ Xcode installation is incomplete; a full installation is necessary for iOS and macOS development.
      Download at: https://developer.apple.com/xcode/

[✓] Chrome - develop for the web [8ms]
    • Chrome at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

[✓] Android Studio (version 2026.2) [4ms]
    • Android Studio at /Applications/Android Studio.app/Contents

[✓] VS Code (version 1.140.0) [3ms]
    • VS Code at /Applications/Visual Studio Code.app/Contents
    • Flutter extension version 3.126.0

[✓] Connected device (2 available) [6.8s]
    • Flutter_Pixel_7 (mobile) • emulator-5554 • android-arm64 • Android 16 (API 36) (emulator)
    • macOS (desktop) • macos • darwin-arm64 • macOS 27.1

[✓] Network resources [412ms]
    • All expected network resources are available.

! Doctor found issues in 2 categories.
''';

SetupController _seed(String stage) {
  final platform = PlatformInfo(os: HostOs.macos, arch: HostArch.arm64, home: '/Users/alex', osVersion: '27.1', shell: '/bin/zsh', localAppData: '');
  final c = SetupController()
    ..platform = platform
    ..paths = InstallPaths.defaults(platform);
  c.orchestrator = SetupOrchestrator(platform);
  if (stage == 'welcome') return c;

  c.scan = EnvironmentScan(scannedAt: DateTime.now(), components: {
    ComponentId.git: const DetectedComponent(id: ComponentId.git, status: ComponentStatus.installed, version: '2.50.1', path: '/usr/bin/git'),
    ComponentId.flutter: const DetectedComponent(id: ComponentId.flutter, status: ComponentStatus.missing, note: 'No flutter command found on PATH or in ~/development.'),
    ComponentId.jdk: const DetectedComponent(id: ComponentId.jdk, status: ComponentStatus.incompatible, version: '25.0.1', path: '/Library/Java/JavaVirtualMachines/jdk-25.jdk', note: 'Java 25 is newer than the Android Gradle plugin supports. A JDK 17 will be installed alongside it; your existing Java is not touched.'),
    ComponentId.androidStudio: const DetectedComponent(id: ComponentId.androidStudio, status: ComponentStatus.missing),
    ComponentId.androidSdk: const DetectedComponent(id: ComponentId.androidSdk, status: ComponentStatus.missing, note: 'No SDK at ~/Library/Android/sdk.'),
    ComponentId.emulator: const DetectedComponent(id: ComponentId.emulator, status: ComponentStatus.missing),
    ComponentId.vscode: const DetectedComponent(id: ComponentId.vscode, status: ComponentStatus.installed, version: '1.140.0', path: '/Applications/Visual Studio Code.app'),
    ComponentId.vscodeExtensions: const DetectedComponent(id: ComponentId.vscodeExtensions, status: ComponentStatus.partial, note: 'Missing: Dart-Code.flutter.'),
    ComponentId.xcode: const DetectedComponent(id: ComponentId.xcode, status: ComponentStatus.missing, note: 'Only needed for iOS and macOS apps.'),
    ComponentId.cocoapods: const DetectedComponent(id: ComponentId.cocoapods, status: ComponentStatus.missing),
    ComponentId.chrome: const DetectedComponent(id: ComponentId.chrome, status: ComponentStatus.installed, path: '/Applications/Google Chrome.app'),
    ComponentId.environment: const DetectedComponent(id: ComponentId.environment, status: ComponentStatus.missing, note: 'PATH, JAVA_HOME and ANDROID_HOME are not set.'),
    ComponentId.licenses: const DetectedComponent(id: ComponentId.licenses, status: ComponentStatus.missing),
  });
  c.versions = ResolvedVersions(
    flutter: const ReleaseInfo(version: '3.47.6', url: 'https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.6-stable.zip'),
    jdk: const ReleaseInfo(version: '17.0.17+10', url: 'https://api.adoptium.net/v3/binary/latest/17/ga/mac/aarch64/jdk/hotspot/normal/eclipse'),
    androidStudio: const ReleaseInfo(version: '2026.2.1.8', url: 'https://redirector.gvt1.com/edgedl/android/studio/install/2026.2.1.8/android-studio-2026.2.1.8-mac_arm.dmg'),
    cmdlineTools: const ReleaseInfo(version: '15641748', url: 'https://dl.google.com/android/repository/commandlinetools-mac-15641748_latest.zip'),
    vscode: const ReleaseInfo(version: '1.140.0', url: 'https://update.code.visualstudio.com/latest/darwin-arm64/stable'),
    gitForWindows: null,
    warnings: const [],
  );
  c.scanStatus = 'Scan complete';
  c.plan = c.orchestrator!.buildPlan(c.scan!);
  if (stage == 'scan' || stage == 'plan') return c;

  c.steps = c.orchestrator!.buildSteps(c.plan);
  final now = DateTime.now();
  var t = now.subtract(const Duration(minutes: 6, seconds: 12));
  const durations = [Duration(minutes: 1, seconds: 48), Duration(seconds: 41), Duration(minutes: 2, seconds: 10)];
  const details = ['Flutter 3.47.6 installed to ~/development/flutter', 'Temurin JDK 17.0.17 installed to ~/development/jdk-17', 'Android Studio 2026.2.1.8 copied to /Applications'];
  for (var i = 0; i < 3 && i < c.steps.length; i++) {
    c.steps[i]
      ..state = SetupStepState.done
      ..startedAt = t
      ..endedAt = t.add(durations[i])
      ..detail = details[i];
    t = t.add(durations[i]);
  }
  if (stage == 'install') {
    if (c.steps.length > 3) {
      c.steps[3]
        ..state = SetupStepState.running
        ..startedAt = t
        ..progress = 0.63
        ..detail = 'sdkmanager: installing platforms;android-36, build-tools;36.0.0 · 63%';
    }
    c.installing = true;
    for (final line in const [
      '[12:04:11] Flutter 3.47.6: sha256 verified',
      '[12:04:12] Extracted flutter_macos_arm64_3.47.6-stable.zip → /Users/alex/development/flutter',
      '[12:04:58] Temurin JDK 17.0.17+10: sha256 verified',
      '[12:05:01] Extracted OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.17_10.tar.gz → /Users/alex/development/jdk-17',
      '[12:05:02] android-studio-2026.2.1.8-mac_arm.dmg: sha256 verified',
      '[12:07:12] Copied Android Studio.app → /Applications',
      '[12:07:13] Extracted commandlinetools-mac-15641748_latest.zip → ~/Library/Android/sdk/cmdline-tools/latest',
      '[12:07:14] \$ sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.0.0" "emulator"',
    ]) {
      c.log.add(line);
    }
    return c;
  }

  for (final s in c.steps.skip(3)) {
    s
      ..state = SetupStepState.done
      ..startedAt = t
      ..endedAt = t.add(const Duration(seconds: 30))
      ..detail = 'Done';
  }
  final cats = DoctorParser.parse(_doctorRaw);
  c.doctor = DoctorReport(categories: cats, issues: FixCatalog(platform).explain(cats), raw: _doctorRaw, ranAt: DateTime.now());
  return c;
}

final _shot = GlobalKey();

Future<void> _capture(String out) async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final boundary = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(out).writeAsBytes(bytes!.buffer.asUint8List());
  exit(0);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final stage = Platform.environment['FSA_DEMO_STAGE'] ?? 'welcome';
  final out = Platform.environment['FSA_DEMO_OUT'];
  final c = _seed(stage)..stage = Stage.values.firstWhere((s) => s.name == stage, orElse: () => Stage.welcome);
  runApp(ChangeNotifierProvider.value(
    value: c,
    child: MaterialApp(
      title: 'Flutter Environment Setup Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: RepaintBoundary(key: _shot, child: const AppShell()),
    ),
  ));
  if (out != null) WidgetsBinding.instance.addPostFrameCallback((_) => _capture(out));
}
