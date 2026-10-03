import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/component.dart';
import 'installer.dart';

/// Android Studio: a `.dmg` copied to /Applications on macOS, a zip extracted
/// to the user's Programs folder on Windows. Neither needs administrator rights.
class AndroidStudioInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.androidStudio;

  @override
  Future<void> install(InstallContext ctx) async {
    final release = ctx.versions.androidStudio;
    final archive = await ctx.download(release);
    if (ctx.platform.isMac) {
      ctx.report.progress(null, 'Copying Android Studio to /Applications…');
      final app = await ctx.extractor.installDmgApp(archive, onLine: ctx.report.log);
      ctx.report.log('Installed Android Studio ${release.version} at $app');
      return;
    }
    ctx.report.progress(null, 'Extracting Android Studio…');
    final tmp = await ctx.tempDir('studio');
    await ctx.extractor.extract(archive, tmp.path, onLine: ctx.report.log);
    await ctx.moveDir(await ctx.singleSubdir(tmp, startsWith: 'android-studio'), ctx.paths.androidStudio);
    await tmp.delete(recursive: true);
    await _createShortcut(ctx);
    ctx.report.log('Installed Android Studio ${release.version} at ${ctx.paths.androidStudio}');
  }

  Future<void> _createShortcut(InstallContext ctx) async {
    final exe = p.join(ctx.paths.androidStudio, 'bin', 'studio64.exe');
    final script = '''
\$ws = New-Object -ComObject WScript.Shell
\$menu = [Environment]::GetFolderPath('Programs')
\$s = \$ws.CreateShortcut((Join-Path \$menu 'Android Studio.lnk'))
\$s.TargetPath = '${exe.replaceAll("'", "''")}'
\$s.WorkingDirectory = '${p.dirname(exe).replaceAll("'", "''")}'
\$s.Save()
''';
    final r = await ctx.runner.powershell(script);
    if (r.ok) ctx.report.log('Added Android Studio to the Start menu.');
  }
}

/// Android SDK through the official command line tools.
class AndroidSdkInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.androidSdk;

  @override
  Future<void> install(InstallContext ctx) async {
    final sdk = ctx.sdkRoot;
    await Directory(sdk).create(recursive: true);
    ctx.androidSdk = sdk;

    if (!await File(ctx.sdkManager).exists()) {
      await _installCmdlineTools(ctx, sdk);
    } else {
      ctx.report.log('Command line tools already present at ${p.dirname(ctx.sdkManager)}');
    }

    await acceptLicenses(ctx);

    final packages = ctx.catalog.sdkPackages(ctx.platform.isArm).where((pkg) => !pkg.startsWith('system-images')).toList();
    await runSdkManager(ctx, packages, label: 'Installing platform tools, Android ${ctx.catalog.androidApiLevel} and build tools…');
    ctx.report.log('Android SDK ready at $sdk');
  }

  Future<void> _installCmdlineTools(InstallContext ctx, String sdk) async {
    final release = ctx.versions.cmdlineTools;
    final zip = await ctx.download(release);
    ctx.report.progress(null, 'Extracting command line tools…');
    final tmp = await ctx.tempDir('cmdline-tools');
    await ctx.extractor.extract(zip, tmp.path, onLine: ctx.report.log);
    final extracted = await ctx.singleSubdir(tmp, startsWith: 'cmdline-tools');
    await ctx.moveDir(extracted, p.join(sdk, 'cmdline-tools', 'latest'));
    await tmp.delete(recursive: true);
    if (!ctx.platform.isWindows) {
      await ctx.runner.run('/bin/chmod', ['-R', 'u+x', p.join(sdk, 'cmdline-tools', 'latest', 'bin')]);
    }
    ctx.report.log('Command line tools build ${release.version} installed.');
  }

  static void _requireJdk(InstallContext ctx) {
    if (ctx.jdkHome == null) {
      throw InstallException('A Java JDK is required before the Android SDK can be installed.', hint: 'Re-run the setup and keep the "Java JDK" step selected.');
    }
  }

  static Future<void> acceptLicenses(InstallContext ctx) async {
    _requireJdk(ctx);
    ctx.report.progress(null, 'Accepting Android SDK licenses…');
    final r = await ctx.runner.run(
      ctx.sdkManager,
      ['--sdk_root=${ctx.sdkRoot}', '--licenses'],
      environment: ctx.childEnv,
      stdinText: 'y\n' * 40,
      timeout: const Duration(minutes: 10),
    );
    if (!r.ok && !r.combined.contains('accepted')) {
      throw InstallException('Could not accept the Android SDK licenses: ${_lastLine(r.combined)}');
    }
  }

  static Future<void> runSdkManager(InstallContext ctx, List<String> packages, {required String label}) async {
    _requireJdk(ctx);
    ctx.report.progress(null, label);
    final r = await ctx.runner.run(
      ctx.sdkManager,
      ['--sdk_root=${ctx.sdkRoot}', ...packages],
      environment: ctx.childEnv,
      stdinText: 'y\n' * 40,
      timeout: const Duration(minutes: 60),
      onLine: (line) {
        final m = RegExp(r'(\d{1,3})%').firstMatch(line);
        if (m != null) {
          ctx.report.progress(int.parse(m.group(1)!) / 100, label);
        } else if (line.trim().isNotEmpty) {
          ctx.report.log(line.trim());
        }
      },
    );
    if (!r.ok) {
      throw InstallException('sdkmanager failed while installing ${packages.join(', ')}: ${_lastLine(r.combined)}', hint: 'Check your connection and free disk space, then retry this step.');
    }
  }

  static String _lastLine(String s) {
    final lines = s.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    return lines.isEmpty ? 'no output' : lines.last.trim();
  }
}

/// Emulator engine, a system image and one ready-to-use virtual device.
class EmulatorInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.emulator;

  @override
  Future<void> install(InstallContext ctx) async {
    final image = ctx.catalog.emulatorSystemImage(ctx.platform.isArm);
    await AndroidSdkInstaller.runSdkManager(ctx, ['emulator', image], label: 'Downloading the Android system image (about 1.5 GB)…');

    ctx.report.progress(null, 'Creating the "${ctx.catalog.emulatorName}" virtual device…');
    final r = await ctx.runner.run(
      ctx.avdManager,
      ['create', 'avd', '--force', '--name', ctx.catalog.emulatorName, '--package', image, '--device', ctx.catalog.emulatorDevice],
      environment: ctx.childEnv,
      stdinText: 'no\n',
      onLine: ctx.report.log,
      timeout: const Duration(minutes: 5),
    );
    if (!r.ok) throw InstallException('Could not create the virtual device: ${r.stderr.trim()}');
    ctx.report.log('Virtual device "${ctx.catalog.emulatorName}" created. Start it with: flutter emulators --launch ${ctx.catalog.emulatorName}');
    if (ctx.platform.isWindows) {
      ctx.report.log('Note: on Windows the emulator needs hardware virtualization (Hyper-V or Windows Hypervisor Platform) to be enabled in Windows Features.');
    }
  }
}

/// Accepts Android licenses through Flutter so `flutter doctor` is satisfied.
class LicensesInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.licenses;

  @override
  Future<void> install(InstallContext ctx) async {
    ctx.report.progress(null, 'Accepting Android licenses through Flutter…');
    final r = await ctx.runner.run(
      ctx.flutterBin,
      ['doctor', '--android-licenses'],
      environment: ctx.childEnv,
      stdinText: 'y\n' * 50,
      onLine: (l) {
        if (l.trim().isNotEmpty && !l.contains('----')) ctx.report.log(l.trim());
      },
      timeout: const Duration(minutes: 10),
    );
    if (!r.ok && !r.combined.toLowerCase().contains('licenses accepted')) {
      throw InstallException('Flutter could not accept the Android licenses: ${r.stderr.trim()}', hint: 'Make sure the Android SDK and Java steps completed first.');
    }
    ctx.report.log('All Android SDK licenses accepted.');
  }
}
