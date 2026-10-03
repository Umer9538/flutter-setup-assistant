import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/install_paths.dart';
import '../../core/platform_info.dart';
import '../../core/process_runner.dart';
import '../../domain/component.dart';
import '../../domain/version.dart';
import '../../domain/version_catalog.dart';

/// Everything the scan learned about this machine.
class EnvironmentScan {
  EnvironmentScan({required this.components, required this.scannedAt});
  final Map<ComponentId, DetectedComponent> components;
  final DateTime scannedAt;

  DetectedComponent? operator [](ComponentId id) => components[id];
  String? pathOf(ComponentId id) => components[id]?.path;
  bool isReady(ComponentId id) => components[id]?.status == ComponentStatus.installed;
}

/// Looks for every component without changing anything.
class EnvironmentDetector {
  EnvironmentDetector({required this.platform, required this.paths, required this.runner, required this.catalog});

  final PlatformInfo platform;
  final InstallPaths paths;
  final ProcessRunner runner;
  final VersionCatalog catalog;

  Future<EnvironmentScan> scan({void Function(String)? log}) async {
    final results = <ComponentId, DetectedComponent>{};

    Future<void> step(ComponentId id, Future<DetectedComponent> Function() fn) async {
      log?.call('Checking ${componentInfo(id).name}…');
      try {
        results[id] = await fn();
      } catch (e) {
        results[id] = DetectedComponent(id: id, status: ComponentStatus.unknown, note: 'Check failed: $e');
      }
    }

    await step(ComponentId.git, _git);
    await step(ComponentId.flutter, _flutter);
    await step(ComponentId.jdk, _jdk);
    await step(ComponentId.androidStudio, _androidStudio);
    await step(ComponentId.androidSdk, _androidSdk);
    await step(ComponentId.emulator, () => _emulator(results[ComponentId.androidSdk]));
    await step(ComponentId.vscode, _vscode);
    await step(ComponentId.vscodeExtensions, () => _vscodeExtensions(results[ComponentId.vscode]));
    if (platform.isMac) {
      await step(ComponentId.xcode, _xcode);
      await step(ComponentId.cocoapods, _cocoapods);
    }
    if (platform.isWindows) {
      await step(ComponentId.visualStudio, _visualStudio);
    }
    await step(ComponentId.chrome, _chrome);
    await step(ComponentId.environment, () => _environment(results[ComponentId.flutter]));
    await step(ComponentId.licenses, () => _licenses(results[ComponentId.androidSdk]));

    return EnvironmentScan(components: results, scannedAt: DateTime.now());
  }

  // ---- Git -----------------------------------------------------------------

  Future<DetectedComponent> _git() async {
    if (platform.isMac) {
      // Calling /usr/bin/git without Command Line Tools pops a GUI dialog; check first.
      final sel = await runner.run('/usr/bin/xcode-select', ['-p']);
      if (!sel.ok) {
        return const DetectedComponent(id: ComponentId.git, status: ComponentStatus.missing, note: 'Apple Command Line Tools (which provide Git) are not installed.');
      }
    }
    final git = await runner.which('git');
    if (git == null) return const DetectedComponent(id: ComponentId.git, status: ComponentStatus.missing);
    final r = await runner.run(git, ['--version']);
    return DetectedComponent(id: ComponentId.git, status: ComponentStatus.installed, version: Version.parse(r.stdout)?.toString(), path: git);
  }

  // ---- Flutter -------------------------------------------------------------

  Future<DetectedComponent> _flutter() async {
    final candidates = <String>[];
    final onPath = await runner.which('flutter');
    if (onPath != null) {
      var resolved = onPath;
      try {
        resolved = await File(onPath).resolveSymbolicLinks();
      } catch (_) {}
      candidates.add(p.dirname(p.dirname(resolved)));
    }
    candidates.addAll([
      paths.flutterSdk,
      p.join(platform.home, 'flutter'),
      p.join(platform.home, 'fvm', 'default'),
      if (platform.isWindows) r'C:\src\flutter',
      if (platform.isWindows) r'C:\flutter',
      if (platform.isMac) '/opt/homebrew/Caskroom/flutter/latest/flutter',
    ]);

    for (final sdk in candidates) {
      final bin = p.join(sdk, 'bin', platform.isWindows ? 'flutter.bat' : 'flutter');
      if (!await File(bin).exists()) continue;
      final version = await _flutterVersion(sdk, bin);
      final issue = catalog.flutterCompatibilityIssue(Version.parse(version));
      return DetectedComponent(
        id: ComponentId.flutter,
        status: issue == null ? ComponentStatus.installed : ComponentStatus.outdated,
        version: version,
        path: sdk,
        note: issue ?? (onPath == null ? 'Found at $sdk but it is not on your PATH yet.' : null),
      );
    }
    return const DetectedComponent(id: ComponentId.flutter, status: ComponentStatus.missing);
  }

  Future<String?> _flutterVersion(String sdk, String bin) async {
    final json = File(p.join(sdk, 'bin', 'cache', 'flutter.version.json'));
    if (await json.exists()) {
      try {
        final m = jsonDecode(await json.readAsString()) as Map<String, dynamic>;
        final v = (m['frameworkVersion'] ?? m['flutterVersion']) as String?;
        if (v != null) return v;
      } catch (_) {}
    }
    final legacy = File(p.join(sdk, 'version'));
    if (await legacy.exists()) {
      final v = (await legacy.readAsString()).trim();
      if (v.isNotEmpty) return v;
    }
    final r = await runner.run(bin, ['--version', '--machine'], timeout: const Duration(minutes: 3));
    if (r.ok) {
      try {
        final m = jsonDecode(r.stdout.substring(r.stdout.indexOf('{'))) as Map<String, dynamic>;
        return m['frameworkVersion'] as String?;
      } catch (_) {}
    }
    return null;
  }

  // ---- JDK -----------------------------------------------------------------

  Future<DetectedComponent> _jdk() async {
    final env = Platform.environment;
    final candidates = <String>[
      paths.jdkHome,
      if (env['JAVA_HOME'] != null) env['JAVA_HOME']!,
      if (platform.isMac) p.join(paths.androidStudio, 'Contents', 'jbr', 'Contents', 'Home'),
      if (platform.isWindows) p.join(paths.androidStudio, 'jbr'),
      if (platform.isWindows) r'C:\Program Files\Android\Android Studio\jbr',
    ];
    if (platform.isMac) {
      final jh = await runner.run('/usr/libexec/java_home', ['-v', '${catalog.minJdk}+']);
      if (jh.ok && jh.stdout.trim().isNotEmpty) candidates.add(jh.stdout.trim());
    }
    final onPath = await runner.which('java');
    if (onPath != null) {
      try {
        final resolved = await File(onPath).resolveSymbolicLinks();
        candidates.add(p.dirname(p.dirname(resolved)));
      } catch (_) {}
    }

    DetectedComponent? incompatible;
    for (final home in candidates) {
      final java = p.join(home, 'bin', platform.isWindows ? 'java.exe' : 'java');
      if (!await File(java).exists()) continue;
      final r = await runner.run(java, ['-version']);
      final m = RegExp(r'version "([^"]+)"').firstMatch(r.combined);
      final version = m?.group(1);
      final major = _javaMajor(version);
      final issue = catalog.jdkCompatibilityIssue(major);
      if (issue == null) {
        return DetectedComponent(id: ComponentId.jdk, status: ComponentStatus.installed, version: version, path: home);
      }
      incompatible ??= DetectedComponent(id: ComponentId.jdk, status: ComponentStatus.incompatible, version: version, path: home, note: issue);
    }
    return incompatible ?? const DetectedComponent(id: ComponentId.jdk, status: ComponentStatus.missing);
  }

  static int? _javaMajor(String? v) {
    if (v == null) return null;
    final parts = v.split('.');
    final first = int.tryParse(parts.first);
    if (first == 1 && parts.length > 1) return int.tryParse(parts[1]);
    return first;
  }

  // ---- Android Studio ------------------------------------------------------

  Future<DetectedComponent> _androidStudio() async {
    final candidates = [
      paths.androidStudio,
      if (platform.isMac) p.join(platform.home, 'Applications', 'Android Studio.app'),
      if (platform.isWindows) r'C:\Program Files\Android\Android Studio',
    ];
    for (final dir in candidates) {
      if (!await Directory(dir).exists()) continue;
      final version = await _studioVersion(dir);
      final issue = catalog.androidStudioCompatibilityIssue(Version.parse(version));
      return DetectedComponent(
        id: ComponentId.androidStudio,
        status: issue == null ? ComponentStatus.installed : ComponentStatus.outdated,
        version: version,
        path: dir,
        note: issue,
      );
    }
    return const DetectedComponent(id: ComponentId.androidStudio, status: ComponentStatus.missing);
  }

  Future<String?> _studioVersion(String dir) async {
    final info = File(platform.isMac ? p.join(dir, 'Contents', 'Resources', 'product-info.json') : p.join(dir, 'product-info.json'));
    if (await info.exists()) {
      try {
        final m = jsonDecode(await info.readAsString()) as Map<String, dynamic>;
        final data = m['dataDirectoryName'] as String?;
        final v = Version.parse(data?.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (v != null) return v.toString();
      } catch (_) {}
    }
    if (platform.isMac) {
      final r = await runner.run('/usr/bin/defaults', ['read', p.join(dir, 'Contents', 'Info.plist'), 'CFBundleShortVersionString']);
      if (r.ok) return r.stdout.trim();
    }
    return null;
  }

  // ---- Android SDK ---------------------------------------------------------

  Future<DetectedComponent> _androidSdk() async {
    final env = Platform.environment;
    final candidates = <String>{
      if (env['ANDROID_HOME'] != null) env['ANDROID_HOME']!,
      if (env['ANDROID_SDK_ROOT'] != null) env['ANDROID_SDK_ROOT']!,
      paths.androidSdk,
    };
    for (final sdk in candidates) {
      if (!await Directory(sdk).exists()) continue;
      final missing = <String>[];
      if (!await File(paths.sdkManager.replaceFirst(paths.androidSdk, sdk)).exists()) missing.add('command line tools');
      if (!await File(p.join(sdk, 'platform-tools', platform.isWindows ? 'adb.exe' : 'adb')).exists()) missing.add('platform tools');
      final platforms = await _subdirs(p.join(sdk, 'platforms'));
      if (platforms.isEmpty) missing.add('an Android platform');
      final buildTools = await _subdirs(p.join(sdk, 'build-tools'));
      if (buildTools.isEmpty) missing.add('build tools');
      final highest = platforms.map((e) => Version.parse(e.replaceAll('android-', ''))).whereType<Version>().fold<Version?>(null, (a, b) => a == null || b > a ? b : a);
      return DetectedComponent(
        id: ComponentId.androidSdk,
        status: missing.isEmpty ? ComponentStatus.installed : ComponentStatus.partial,
        version: highest == null ? null : 'API ${highest.major}',
        path: sdk,
        note: missing.isEmpty ? null : 'Missing: ${missing.join(', ')}.',
      );
    }
    return const DetectedComponent(id: ComponentId.androidSdk, status: ComponentStatus.missing);
  }

  Future<List<String>> _subdirs(String dir) async {
    final d = Directory(dir);
    if (!await d.exists()) return [];
    return d.list().where((e) => e is Directory).map((e) => p.basename(e.path)).toList();
  }

  // ---- Emulator ------------------------------------------------------------

  Future<DetectedComponent> _emulator(DetectedComponent? sdk) async {
    final sdkPath = sdk?.path;
    if (sdkPath == null) return const DetectedComponent(id: ComponentId.emulator, status: ComponentStatus.missing);
    final emulator = File(p.join(sdkPath, 'emulator', platform.isWindows ? 'emulator.exe' : 'emulator'));
    if (!await emulator.exists()) {
      return const DetectedComponent(id: ComponentId.emulator, status: ComponentStatus.missing, note: 'The emulator engine is not installed.');
    }
    final images = await _subdirs(p.join(sdkPath, 'system-images'));
    final avdHome = Platform.environment['ANDROID_AVD_HOME'] ?? p.join(platform.home, '.android', 'avd');
    final avds = await Directory(avdHome).exists() ? await Directory(avdHome).list().where((e) => e.path.endsWith('.ini')).map((e) => p.basenameWithoutExtension(e.path)).toList() : <String>[];
    if (images.isEmpty || avds.isEmpty) {
      return DetectedComponent(
        id: ComponentId.emulator,
        status: ComponentStatus.partial,
        path: emulator.path,
        note: avds.isEmpty ? 'No virtual device has been created yet.' : 'No system image is installed.',
      );
    }
    return DetectedComponent(id: ComponentId.emulator, status: ComponentStatus.installed, path: emulator.path, version: avds.join(', '));
  }

  // ---- VS Code -------------------------------------------------------------

  Future<DetectedComponent> _vscode() async {
    final candidates = <String>[
      paths.vscodeCli,
      if (platform.isWindows) r'C:\Program Files\Microsoft VS Code\bin\code.cmd',
      if (platform.isMac) '/usr/local/bin/code',
    ];
    final onPath = await runner.which('code');
    if (onPath != null) candidates.insert(0, onPath);
    for (final cli in candidates) {
      if (!await File(cli).exists()) continue;
      final r = await runner.run(cli, ['--version'], timeout: const Duration(seconds: 60));
      final version = r.ok ? r.stdout.trim().split('\n').first.trim() : null;
      return DetectedComponent(id: ComponentId.vscode, status: ComponentStatus.installed, version: version, path: cli);
    }
    return const DetectedComponent(id: ComponentId.vscode, status: ComponentStatus.missing);
  }

  Future<DetectedComponent> _vscodeExtensions(DetectedComponent? vscode) async {
    final cli = vscode?.path;
    if (cli == null || vscode!.status != ComponentStatus.installed) {
      return const DetectedComponent(id: ComponentId.vscodeExtensions, status: ComponentStatus.missing, note: 'VS Code is not installed.');
    }
    final r = await runner.run(cli, ['--list-extensions'], timeout: const Duration(seconds: 60));
    final installed = r.stdout.toLowerCase().split('\n').map((e) => e.trim()).toSet();
    final missing = catalog.vscodeExtensions.where((e) => !installed.contains(e.toLowerCase())).toList();
    if (missing.isEmpty) return const DetectedComponent(id: ComponentId.vscodeExtensions, status: ComponentStatus.installed);
    return DetectedComponent(id: ComponentId.vscodeExtensions, status: ComponentStatus.partial, note: 'Missing: ${missing.join(', ')}');
  }

  // ---- macOS only ----------------------------------------------------------

  Future<DetectedComponent> _xcode() async {
    final sel = await runner.run('/usr/bin/xcode-select', ['-p']);
    if (!sel.ok) return const DetectedComponent(id: ComponentId.xcode, status: ComponentStatus.missing);
    final path = sel.stdout.trim();
    if (!path.contains('.app')) {
      return DetectedComponent(id: ComponentId.xcode, status: ComponentStatus.partial, path: path, note: 'Only the Command Line Tools are installed. Full Xcode is needed for iOS apps.');
    }
    final r = await runner.run('/usr/bin/xcodebuild', ['-version']);
    return DetectedComponent(id: ComponentId.xcode, status: ComponentStatus.installed, version: Version.parse(r.stdout)?.toString(), path: path);
  }

  Future<DetectedComponent> _cocoapods() async {
    final candidates = [
      await runner.which('pod'),
      '/opt/homebrew/bin/pod',
      '/usr/local/bin/pod',
    ].whereType<String>();
    for (final pod in candidates) {
      if (!await File(pod).exists()) continue;
      final r = await runner.run(pod, ['--version'], timeout: const Duration(seconds: 60));
      if (r.ok) return DetectedComponent(id: ComponentId.cocoapods, status: ComponentStatus.installed, version: r.stdout.trim(), path: pod);
    }
    return const DetectedComponent(id: ComponentId.cocoapods, status: ComponentStatus.missing);
  }

  // ---- Windows only --------------------------------------------------------

  Future<DetectedComponent> _visualStudio() async {
    const vswhere = r'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe';
    if (!await File(vswhere).exists()) return const DetectedComponent(id: ComponentId.visualStudio, status: ComponentStatus.missing);
    final r = await runner.run(vswhere, ['-latest', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationVersion']);
    final v = r.stdout.trim();
    if (v.isEmpty) return const DetectedComponent(id: ComponentId.visualStudio, status: ComponentStatus.partial, note: 'Visual Studio is installed but the "Desktop development with C++" workload is missing.');
    return DetectedComponent(id: ComponentId.visualStudio, status: ComponentStatus.installed, version: v);
  }

  // ---- Chrome --------------------------------------------------------------

  Future<DetectedComponent> _chrome() async {
    final candidates = platform.isMac
        ? ['/Applications/Google Chrome.app']
        : [
            r'C:\Program Files\Google\Chrome\Application\chrome.exe',
            r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
            p.join(platform.localAppData, 'Google', 'Chrome', 'Application', 'chrome.exe'),
          ];
    for (final c in candidates) {
      if (await FileSystemEntity.type(c) != FileSystemEntityType.notFound) {
        return DetectedComponent(id: ComponentId.chrome, status: ComponentStatus.installed, path: c);
      }
    }
    return const DetectedComponent(id: ComponentId.chrome, status: ComponentStatus.missing);
  }

  // ---- Environment & licenses ---------------------------------------------

  Future<DetectedComponent> _environment(DetectedComponent? flutter) async {
    if (flutter == null || flutter.status == ComponentStatus.missing) {
      return const DetectedComponent(id: ComponentId.environment, status: ComponentStatus.missing);
    }
    final onPath = await runner.which('flutter');
    final env = Platform.environment;
    final missing = <String>[
      if (onPath == null) 'flutter is not on PATH',
      if (env['ANDROID_HOME'] == null) 'ANDROID_HOME is not set',
    ];
    if (missing.isEmpty) return const DetectedComponent(id: ComponentId.environment, status: ComponentStatus.installed);
    return DetectedComponent(id: ComponentId.environment, status: ComponentStatus.partial, note: missing.join('; '));
  }

  Future<DetectedComponent> _licenses(DetectedComponent? sdk) async {
    final sdkPath = sdk?.path;
    if (sdkPath == null) return const DetectedComponent(id: ComponentId.licenses, status: ComponentStatus.missing);
    final accepted = await File(p.join(sdkPath, 'licenses', 'android-sdk-license')).exists();
    return DetectedComponent(id: ComponentId.licenses, status: accepted ? ComponentStatus.installed : ComponentStatus.missing);
  }
}
