import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/component.dart';
import 'installer.dart';

/// Git: Apple Command Line Tools on macOS, Git for Windows on Windows.
class GitInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.git;

  @override
  Future<void> install(InstallContext ctx) async {
    if (ctx.platform.isMac) return _installCommandLineTools(ctx);
    return _installGitForWindows(ctx);
  }

  Future<void> _installCommandLineTools(InstallContext ctx) async {
    final r = ctx.report;
    r.detail('Asking macOS to install the Command Line Tools…');
    await ctx.runner.run('/usr/bin/xcode-select', ['--install']);
    r.log('A macOS dialog has opened. Click "Install" and accept the license. This usually takes 5-15 minutes.');
    r.progress(null, 'Waiting for you to confirm the macOS dialog, then for Apple\'s installer to finish…');
    final deadline = DateTime.now().add(const Duration(minutes: 45));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 5));
      final check = await ctx.runner.run('/usr/bin/xcode-select', ['-p']);
      if (check.ok) {
        final git = await ctx.runner.run('/usr/bin/git', ['--version']);
        if (git.ok) {
          r.log('Command Line Tools installed: ${git.stdout.trim()}');
          return;
        }
      }
    }
    throw InstallException(
      'The Command Line Tools did not finish installing.',
      hint: 'Open Terminal, run "xcode-select --install", complete the dialog, then run this assistant again.',
    );
  }

  Future<void> _installGitForWindows(InstallContext ctx) async {
    final release = ctx.versions.gitForWindows!;
    final installer = await ctx.download(release);
    final dir = p.join(ctx.paths.root, 'Git');
    ctx.report.progress(null, 'Running the Git installer silently…');
    final r = await ctx.runner.run(installer, [
      '/CURRENTUSER',
      '/VERYSILENT',
      '/NORESTART',
      '/NOCANCEL',
      '/SP-',
      '/CLOSEAPPLICATIONS',
      '/DIR=$dir',
      '/COMPONENTS=ext,ext\\shellhere,assoc,assoc_sh',
    ], onLine: ctx.report.log, timeout: const Duration(minutes: 20));
    final gitExe = p.join(dir, 'cmd', 'git.exe');
    if (!r.ok || !await File(gitExe).exists()) {
      throw InstallException('The Git installer did not complete (exit code ${r.exitCode}).', hint: 'You can install Git manually from https://git-scm.com and run the assistant again.');
    }
    ctx.gitCmdDir = p.join(dir, 'cmd');
    final v = await ctx.runner.run(gitExe, ['--version']);
    ctx.report.log('Installed ${v.stdout.trim()}');
  }
}

/// Flutter SDK from the official release archive, verified by checksum.
class FlutterInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.flutter;

  @override
  Future<void> install(InstallContext ctx) async {
    final existing = ctx.scan[ComponentId.flutter];
    if (existing?.status == ComponentStatus.outdated && existing?.path != null && await Directory(p.join(existing!.path!, '.git')).exists()) {
      if (await _upgradeInPlace(ctx, existing.path!)) return;
      ctx.report.log('In-place upgrade did not succeed; installing a fresh SDK instead.');
    }

    final release = ctx.versions.flutter;
    final archive = await ctx.download(release);
    final target = ctx.paths.flutterSdk;
    if (await Directory(target).exists()) {
      final backup = '$target-old-${DateTime.now().millisecondsSinceEpoch}';
      ctx.report.log('An older Flutter folder exists at $target. Moving it aside to $backup (nothing is deleted).');
      await Directory(target).rename(backup);
    }
    ctx.report.progress(null, 'Extracting the Flutter SDK (about 1 GB, this takes a minute)…');
    final tmp = await ctx.tempDir('flutter');
    await ctx.extractor.extract(archive, tmp.path, onLine: ctx.report.log);
    await ctx.moveDir(await ctx.singleSubdir(tmp, startsWith: 'flutter'), target);
    await tmp.delete(recursive: true);
    ctx.flutterSdk = target;

    ctx.report.progress(null, 'Running Flutter for the first time to download the Dart SDK…');
    final v = await ctx.runner.run(ctx.flutterBin, ['--version'], environment: ctx.childEnv, onLine: ctx.report.log, timeout: const Duration(minutes: 20));
    if (!v.ok) throw InstallException('Flutter was extracted but failed to start: ${v.stderr.trim()}', hint: 'Check your internet connection and retry; Flutter downloads the Dart SDK on first run.');
    ctx.report.log('Flutter ${release.version} installed at $target');
  }

  Future<bool> _upgradeInPlace(InstallContext ctx, String sdk) async {
    ctx.report.progress(null, 'Upgrading your existing Flutter SDK at $sdk…');
    final bin = p.join(sdk, 'bin', ctx.platform.isWindows ? 'flutter.bat' : 'flutter');
    final ch = await ctx.runner.run(bin, ['channel', 'stable'], environment: ctx.childEnv, onLine: ctx.report.log, timeout: const Duration(minutes: 10));
    if (!ch.ok) return false;
    final up = await ctx.runner.run(bin, ['upgrade', '--force'], environment: ctx.childEnv, onLine: ctx.report.log, timeout: const Duration(minutes: 30));
    if (!up.ok) return false;
    ctx.flutterSdk = sdk;
    return true;
  }
}

/// Eclipse Temurin JDK, installed into the user's SDK folder.
class JdkInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.jdk;

  @override
  Future<void> install(InstallContext ctx) async {
    final release = ctx.versions.jdk;
    final archive = await ctx.download(release, fileName: release.fromFallback ? 'temurin-jdk-${ctx.catalog.jdkFeatureVersion}${ctx.platform.isWindows ? '.zip' : '.tar.gz'}' : null);
    ctx.report.progress(null, 'Extracting the JDK…');
    final tmp = await ctx.tempDir('jdk');
    await ctx.extractor.extract(archive, tmp.path, onLine: ctx.report.log);
    await ctx.moveDir(await ctx.singleSubdir(tmp, startsWith: 'jdk'), ctx.paths.jdkDir);
    await tmp.delete(recursive: true);

    final java = p.join(ctx.paths.jdkHome, 'bin', ctx.platform.isWindows ? 'java.exe' : 'java');
    final v = await ctx.runner.run(java, ['-version']);
    if (!v.ok) throw InstallException('The JDK was extracted but java does not start: ${v.stderr.trim()}');
    ctx.jdkHome = ctx.paths.jdkHome;
    ctx.jdkInstalledByAssistant = true;
    ctx.report.log('Installed ${v.combined.split('\n').first}');
  }
}
