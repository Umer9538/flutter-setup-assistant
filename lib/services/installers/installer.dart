import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/downloader.dart';
import '../../core/extractor.dart';
import '../../core/install_paths.dart';
import '../../core/platform_info.dart';
import '../../core/process_runner.dart';
import '../../core/shell_env.dart';
import '../../domain/component.dart';
import '../../domain/version_catalog.dart';
import '../detection/environment_detector.dart';
import '../release_resolver.dart';

class InstallException implements Exception {
  InstallException(this.message, {this.hint});
  final String message;

  /// Plain-language suggestion for what the user can do.
  final String? hint;
  @override
  String toString() => hint == null ? message : '$message\n$hint';
}

/// Lets an installer report progress to the UI.
abstract class StepReporter {
  void log(String line);
  void progress(double? fraction, [String? detail]);
  void detail(String text);
}

/// Shared state for one setup run. Installers update the resolved locations
/// as they complete so later steps can find what earlier steps produced.
class InstallContext {
  InstallContext({
    required this.platform,
    required this.paths,
    required this.catalog,
    required this.versions,
    required this.runner,
    required this.downloader,
    required this.extractor,
    required this.shellEnv,
    required this.scan,
    required this.report,
  })  : flutterSdk = scan.isReady(ComponentId.flutter) || scan[ComponentId.flutter]?.status == ComponentStatus.outdated ? scan.pathOf(ComponentId.flutter) : null,
        jdkHome = scan.isReady(ComponentId.jdk) ? scan.pathOf(ComponentId.jdk) : null,
        androidSdk = scan.pathOf(ComponentId.androidSdk),
        vscodeCli = scan.isReady(ComponentId.vscode) ? scan.pathOf(ComponentId.vscode) : null,
        gitCmdDir = null;

  final PlatformInfo platform;
  final InstallPaths paths;
  final VersionCatalog catalog;
  final ResolvedVersions versions;
  final ProcessRunner runner;
  final Downloader downloader;
  final Extractor extractor;
  final ShellEnvironment shellEnv;
  final EnvironmentScan scan;
  final StepReporter report;

  String? flutterSdk;
  String? jdkHome;
  String? androidSdk;
  String? vscodeCli;
  String? gitCmdDir;
  bool jdkInstalledByAssistant = false;

  String get flutterBin => p.join(flutterSdk ?? paths.flutterSdk, 'bin', platform.isWindows ? 'flutter.bat' : 'flutter');
  String get sdkRoot => androidSdk ?? paths.androidSdk;
  String get sdkManager => p.join(sdkRoot, 'cmdline-tools', 'latest', 'bin', platform.isWindows ? 'sdkmanager.bat' : 'sdkmanager');
  String get avdManager => p.join(sdkRoot, 'cmdline-tools', 'latest', 'bin', platform.isWindows ? 'avdmanager.bat' : 'avdmanager');

  /// Environment for child processes that already reflects what has been
  /// installed so far, even before the user opens a new terminal.
  Map<String, String> get childEnv {
    final env = Map<String, String>.from(Platform.environment);
    if (jdkHome != null) env['JAVA_HOME'] = jdkHome!;
    env['ANDROID_HOME'] = sdkRoot;
    env['ANDROID_SDK_ROOT'] = sdkRoot;
    final sep = platform.isWindows ? ';' : ':';
    final key = platform.isWindows ? env.keys.firstWhere((k) => k.toUpperCase() == 'PATH', orElse: () => 'Path') : 'PATH';
    final extra = <String>[
      if (jdkHome != null) p.join(jdkHome!, 'bin'),
      p.join(flutterSdk ?? paths.flutterSdk, 'bin'),
      p.join(sdkRoot, 'platform-tools'),
      p.join(sdkRoot, 'emulator'),
      p.join(sdkRoot, 'cmdline-tools', 'latest', 'bin'),
      ?gitCmdDir,
    ];
    env[key] = '${extra.join(sep)}$sep${env[key] ?? ''}';
    // Keep Gradle and sdkmanager from asking questions.
    env['JAVA_TOOL_OPTIONS'] = '-Dfile.encoding=UTF-8';
    return env;
  }

  /// Downloads with progress reporting wired to the current step.
  Future<String> download(ReleaseInfo release, {String? fileName}) {
    report.progress(0, 'Downloading ${fileName ?? p.basename(Uri.parse(release.url).path)}…');
    return downloader.download(
      release.url,
      cacheDir: paths.cache,
      fileName: fileName,
      sha256Hex: release.sha256,
      onProgress: (pr) {
        final mb = (pr.received / 1048576).toStringAsFixed(0);
        final totalMb = pr.total == null ? null : (pr.total! / 1048576).toStringAsFixed(0);
        report.progress(pr.fraction, totalMb == null ? 'Downloaded $mb MB' : 'Downloaded $mb of $totalMb MB');
      },
    );
  }

  /// A fresh temporary directory inside the cache for extraction.
  Future<Directory> tempDir(String label) async {
    final dir = Directory(p.join(paths.cache, 'tmp-$label'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    return dir;
  }

  /// Moves a directory, falling back to copy+delete across volumes.
  Future<void> moveDir(String from, String to) async {
    await Directory(p.dirname(to)).create(recursive: true);
    if (await Directory(to).exists()) await Directory(to).delete(recursive: true);
    try {
      await Directory(from).rename(to);
    } on FileSystemException {
      final r = platform.isWindows
          ? await runner.run('robocopy', [from, to, '/E', '/MOVE', '/NFL', '/NDL', '/NJH', '/NJS'])
          : await runner.run('/usr/bin/ditto', [from, to]);
      // robocopy returns codes < 8 on success.
      if (platform.isWindows ? r.exitCode >= 8 : !r.ok) throw InstallException('Could not move $from to $to: ${r.stderr}');
      if (await Directory(from).exists()) await Directory(from).delete(recursive: true);
    }
  }

  /// Finds the single top-level directory an archive extracted to.
  Future<String> singleSubdir(Directory dir, {String? startsWith}) async {
    final entries = await dir.list().where((e) => e is Directory).map((e) => e.path).toList();
    final match = entries.where((e) => startsWith == null || p.basename(e).toLowerCase().startsWith(startsWith.toLowerCase())).toList();
    if (match.isEmpty) throw InstallException('The downloaded archive did not contain the expected folder.');
    return match.first;
  }
}

abstract class Installer {
  ComponentId get id;
  Future<void> install(InstallContext ctx);
}
