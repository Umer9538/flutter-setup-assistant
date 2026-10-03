import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/shell_env.dart';
import '../../domain/component.dart';
import 'installer.dart';

/// Persists PATH / JAVA_HOME / ANDROID_HOME and points Flutter at the SDKs.
class EnvironmentInstaller implements Installer {
  @override
  ComponentId get id => ComponentId.environment;

  static EnvSpec buildSpec(InstallContext ctx) {
    final flutterBinDir = p.join(ctx.flutterSdk ?? ctx.paths.flutterSdk, 'bin');
    final sdk = ctx.sdkRoot;
    final vars = <String, String>{
      'ANDROID_HOME': sdk,
    };
    final existingJavaHome = Platform.environment['JAVA_HOME'];
    if (ctx.jdkHome != null && (ctx.jdkInstalledByAssistant || existingJavaHome == null || existingJavaHome.isEmpty)) {
      vars['JAVA_HOME'] = ctx.jdkHome!;
    }
    final path = <String>[
      flutterBinDir,
      p.join(sdk, 'platform-tools'),
      p.join(sdk, 'emulator'),
      p.join(sdk, 'cmdline-tools', 'latest', 'bin'),
      if (ctx.gitCmdDir != null) ctx.gitCmdDir!,
    ];
    return EnvSpec(variables: vars, pathEntries: path);
  }

  @override
  Future<void> install(InstallContext ctx) async {
    final spec = buildSpec(ctx);
    ctx.report.progress(null, 'Writing environment variables…');
    ctx.report.log('Applying:\n${ctx.shellEnv.describe(spec)}');
    final touched = await ctx.shellEnv.apply(spec, log: ctx.report.log);
    ctx.report.log('Updated: ${touched.join(', ')}');

    if (await File(ctx.flutterBin).exists()) {
      ctx.report.progress(null, 'Telling Flutter where the Android SDK is…');
      await _flutterConfig(ctx, ['--android-sdk', ctx.sdkRoot]);
      if (ctx.jdkHome != null && spec.variables.containsKey('JAVA_HOME')) {
        await _flutterConfig(ctx, ['--jdk-dir', ctx.jdkHome!]);
      }
    }
    ctx.report.log('Environment configured. Open a new terminal window for the changes to take effect.');
  }

  Future<void> _flutterConfig(InstallContext ctx, List<String> args) async {
    final r = await ctx.runner.run(ctx.flutterBin, ['config', ...args], environment: ctx.childEnv, timeout: const Duration(minutes: 5));
    if (!r.ok) ctx.report.log('Warning: flutter config ${args.join(' ')} failed: ${r.stderr.trim()}');
  }
}
