import 'package:flutter/material.dart';
import 'package:flutter_setup_assistant/core/install_paths.dart';
import 'package:flutter_setup_assistant/core/platform_info.dart';
import 'package:flutter_setup_assistant/domain/component.dart';
import 'package:flutter_setup_assistant/domain/setup_step.dart';
import 'package:flutter_setup_assistant/services/detection/environment_detector.dart';
import 'package:flutter_setup_assistant/services/release_resolver.dart';
import 'package:flutter_setup_assistant/services/setup_orchestrator.dart';
import 'package:flutter_setup_assistant/state/setup_controller.dart';
import 'package:flutter_setup_assistant/ui/app_shell.dart';
import 'package:flutter_setup_assistant/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

SetupController _controller() {
  final platform = PlatformInfo(os: HostOs.macos, arch: HostArch.arm64, home: '/Users/me', osVersion: 'Version 27.0', shell: '/bin/zsh', localAppData: '');
  final c = SetupController()
    ..platform = platform
    ..paths = InstallPaths.defaults(platform);
  c.orchestrator = SetupOrchestrator(platform);
  c.scan = EnvironmentScan(scannedAt: DateTime.now(), components: {
    ComponentId.git: const DetectedComponent(id: ComponentId.git, status: ComponentStatus.installed, version: '2.54.0', path: '/usr/bin/git'),
    ComponentId.flutter: const DetectedComponent(id: ComponentId.flutter, status: ComponentStatus.missing),
    ComponentId.jdk: const DetectedComponent(id: ComponentId.jdk, status: ComponentStatus.incompatible, version: '25', note: 'Java 25 is newer than the Android Gradle plugin supports.'),
    ComponentId.androidStudio: const DetectedComponent(id: ComponentId.androidStudio, status: ComponentStatus.missing),
    ComponentId.androidSdk: const DetectedComponent(id: ComponentId.androidSdk, status: ComponentStatus.partial, note: 'Missing: command line tools.'),
    ComponentId.emulator: const DetectedComponent(id: ComponentId.emulator, status: ComponentStatus.missing),
    ComponentId.vscode: const DetectedComponent(id: ComponentId.vscode, status: ComponentStatus.installed, version: '1.140.0'),
    ComponentId.vscodeExtensions: const DetectedComponent(id: ComponentId.vscodeExtensions, status: ComponentStatus.installed),
    ComponentId.xcode: const DetectedComponent(id: ComponentId.xcode, status: ComponentStatus.missing),
    ComponentId.cocoapods: const DetectedComponent(id: ComponentId.cocoapods, status: ComponentStatus.missing),
    ComponentId.chrome: const DetectedComponent(id: ComponentId.chrome, status: ComponentStatus.installed),
    ComponentId.environment: const DetectedComponent(id: ComponentId.environment, status: ComponentStatus.missing),
    ComponentId.licenses: const DetectedComponent(id: ComponentId.licenses, status: ComponentStatus.missing),
  });
  const r = ReleaseInfo(version: '3.47.6', url: 'https://example.com/x.zip');
  c.versions = ResolvedVersions(flutter: r, jdk: r, androidStudio: r, cmdlineTools: r, vscode: r, gitForWindows: null, warnings: ['Could not check Flutter online. Using 3.47.6.']);
  c.plan = c.orchestrator!.buildPlan(c.scan!);
  return c;
}

Widget _app(SetupController c) => ChangeNotifierProvider.value(value: c, child: MaterialApp(theme: AppTheme.light(), home: const AppShell()));

void main() {
  testWidgets('scan screen lists detected components', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    final c = _controller()..stage = Stage.scan;
    await tester.pumpWidget(_app(c));
    expect(find.text('Scan results'), findsOneWidget);
    expect(find.text('Flutter SDK'), findsOneWidget);
    expect(find.text('Incompatible'), findsOneWidget);
    expect(find.textContaining('Could not check Flutter online'), findsOneWidget);
  });

  testWidgets('plan screen proposes installs and side-by-side JDK', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    final c = _controller()..stage = Stage.plan;
    await tester.pumpWidget(_app(c));
    expect(find.text('Here is the plan'), findsOneWidget);
    expect(find.text('Install compatible version'), findsOneWidget);
    expect(find.textContaining('Start installation'), findsOneWidget);
    expect(c.plan.firstWhere((p) => p.id == ComponentId.xcode).action.name, 'manual');
    expect(c.plan.firstWhere((p) => p.id == ComponentId.cocoapods).selected, isFalse);
    expect(c.actionCount, greaterThanOrEqualTo(7));
  });

  testWidgets('install screen renders steps and errors', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    final c = _controller()..stage = Stage.install;
    c.steps = c.orchestrator!.buildSteps(c.plan);
    c.steps.first.state = SetupStepState.done;
    c.steps[1]
      ..state = SetupStepState.failed
      ..error = 'Download failed';
    await tester.pumpWidget(_app(c));
    expect(find.text('Installation'), findsOneWidget);
    expect(find.text('Download failed'), findsOneWidget);
    expect(find.text('Run flutter doctor'), findsOneWidget);
  });

  testWidgets('done screen shows next steps', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    final c = _controller()..stage = Stage.done;
    await tester.pumpWidget(_app(c));
    expect(find.textContaining('flutter create my_app'), findsOneWidget);
    expect(find.textContaining('Flutter_Pixel_7'), findsOneWidget);
  });
}
