// Headless scan for debugging: `dart run tool/scan_cli.dart`
// Prints what the assistant detects and which versions it would install.
import 'dart:io';

import 'package:flutter_setup_assistant/core/downloader.dart';
import 'package:flutter_setup_assistant/core/install_paths.dart';
import 'package:flutter_setup_assistant/core/platform_info.dart';
import 'package:flutter_setup_assistant/core/process_runner.dart';
import 'package:flutter_setup_assistant/domain/component.dart';
import 'package:flutter_setup_assistant/domain/plan.dart';
import 'package:flutter_setup_assistant/domain/version_catalog.dart';
import 'package:flutter_setup_assistant/services/detection/environment_detector.dart';
import 'package:flutter_setup_assistant/services/release_resolver.dart';
import 'package:flutter_setup_assistant/services/setup_orchestrator.dart';

Future<void> main() async {
  final runner = ProcessRunner();
  final platform = await PlatformInfo.detect(runner);
  final paths = InstallPaths.defaults(platform);
  const catalog = VersionCatalog();
  stdout.writeln('Platform: ${platform.osLabel} ${platform.osVersion} ${platform.archLabel}, root ${paths.root}');

  final scan = await EnvironmentDetector(platform: platform, paths: paths, runner: runner, catalog: catalog).scan(log: (m) => stdout.writeln('  $m'));
  stdout.writeln('\nDetected:');
  for (final c in scan.components.values) {
    stdout.writeln('  ${c.id.name.padRight(18)} ${c.status.label.padRight(16)} ${c.version ?? ''}  ${c.path ?? ''}  ${c.note ?? ''}');
  }

  final plan = SetupOrchestrator(platform).buildPlan(scan);
  stdout.writeln('\nPlan:');
  for (final p in plan) {
    stdout.writeln('  [${p.selected ? 'x' : ' '}] ${p.action.label.padRight(28)} ${p.info.name.padRight(28)} ${p.reason}');
  }

  final downloader = Downloader();
  final v = await ReleaseResolver(platform: platform, catalog: catalog, downloader: downloader).resolve(log: (m) => stdout.writeln('  $m'));
  stdout.writeln('\nVersions:');
  for (final r in [v.flutter, v.jdk, v.androidStudio, v.cmdlineTools, v.vscode, ?v.gitForWindows]) {
    stdout.writeln('  ${r.version.padRight(22)} ${r.fromFallback ? '(fallback) ' : ''}${r.url}  sha256=${r.sha256 ?? '-'}');
  }
  for (final w in v.warnings) {
    stdout.writeln('  warning: $w');
  }
  downloader.close();
}
