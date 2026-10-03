import 'dart:io';


import '../../domain/component.dart';
import 'installer.dart';

class VsCodeInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.vscode;

  @override
  Future<void> install(InstallContext ctx) async {
    final release = ctx.versions.vscode;
    if (ctx.platform.isMac) {
      final zip = await ctx.download(release, fileName: 'VSCode-darwin-universal.zip');
      ctx.report.progress(null, 'Copying Visual Studio Code to /Applications…');
      final tmp = await ctx.tempDir('vscode');
      await ctx.extractor.extract(zip, tmp.path, onLine: ctx.report.log);
      final app = await ctx.singleSubdir(tmp, startsWith: 'Visual Studio Code');
      await ctx.moveDir(app, ctx.paths.vscode);
      await ctx.runner.run('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', ctx.paths.vscode]);
      await tmp.delete(recursive: true);
    } else {
      final exe = await ctx.download(release, fileName: 'VSCodeUserSetup.exe');
      ctx.report.progress(null, 'Running the VS Code installer silently…');
      final r = await ctx.runner.run(
        exe,
        ['/VERYSILENT', '/NORESTART', '/MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath'],
        onLine: ctx.report.log,
        timeout: const Duration(minutes: 15),
      );
      if (!r.ok) throw InstallException('The VS Code installer did not complete (exit code ${r.exitCode}).');
    }
    if (!await File(ctx.paths.vscodeCli).exists()) {
      throw InstallException('VS Code was installed but its command line tool was not found at ${ctx.paths.vscodeCli}.');
    }
    ctx.vscodeCli = ctx.paths.vscodeCli;
    ctx.report.log('Visual Studio Code ${release.version} installed.');
  }
}

class VsCodeExtensionsInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.vscodeExtensions;

  @override
  Future<void> install(InstallContext ctx) async {
    final cli = ctx.vscodeCli;
    if (cli == null) throw InstallException('VS Code is not installed, so its extensions cannot be installed.');
    for (final ext in ctx.catalog.vscodeExtensions) {
      ctx.report.progress(null, 'Installing $ext…');
      final r = await ctx.runner.run(cli, ['--install-extension', ext, '--force'], onLine: ctx.report.log, timeout: const Duration(minutes: 10));
      if (!r.ok) throw InstallException('Could not install the VS Code extension $ext: ${r.stderr.trim()}');
    }
    ctx.report.log('Dart and Flutter extensions installed.');
  }
}

/// CocoaPods via Homebrew (macOS). Without Homebrew the step explains the
/// one manual command instead of asking for an administrator password.
class CocoaPodsInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.cocoapods;

  @override
  Future<void> install(InstallContext ctx) async {
    final brew = await _findBrew(ctx);
    if (brew == null) {
      throw InstallException(
        'Homebrew is not installed, so CocoaPods cannot be installed automatically.',
        hint: 'Install Homebrew from https://brew.sh, then run "brew install cocoapods". Or run "sudo gem install cocoapods" in Terminal.',
      );
    }
    ctx.report.progress(null, 'Installing CocoaPods with Homebrew…');
    final r = await ctx.runner.run(brew, ['install', 'cocoapods'], onLine: ctx.report.log, timeout: const Duration(minutes: 30));
    if (!r.ok) throw InstallException('Homebrew could not install CocoaPods: ${r.stderr.trim().split('\n').last}');
    ctx.report.log('CocoaPods installed.');
  }

  Future<String?> _findBrew(InstallContext ctx) async {
    for (final c in ['/opt/homebrew/bin/brew', '/usr/local/bin/brew']) {
      if (await File(c).exists()) return c;
    }
    return ctx.runner.which('brew');
  }
}

