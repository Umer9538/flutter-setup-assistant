import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_info.dart';
import 'process_runner.dart';

const kManagedBlockStart = '# >>> Flutter Environment Setup Assistant (managed, safe to delete) >>>';
const kManagedBlockEnd = '# <<< Flutter Environment Setup Assistant <<<';

/// Desired persistent environment: variables and PATH entries.
class EnvSpec {
  EnvSpec({required this.variables, required this.pathEntries});
  final Map<String, String> variables;
  final List<String> pathEntries;
}

/// Applies environment changes safely and idempotently.
///
/// macOS: a clearly delimited block is written to the user's shell profile.
/// The original file is backed up first and re-runs replace the block.
///
/// Windows: user-scope variables are set through the .NET API, which never
/// truncates PATH (unlike `setx`) and broadcasts the change to Explorer.
class ShellEnvironment {
  ShellEnvironment({required this.platform, required this.runner, required this.backupDir});
  final PlatformInfo platform;
  final ProcessRunner runner;
  final String backupDir;

  /// Builds the managed block text used on macOS. Pure, so it is unit-testable.
  static String renderBlock(EnvSpec spec) {
    final b = StringBuffer()..writeln(kManagedBlockStart);
    for (final e in spec.variables.entries) {
      b.writeln('export ${e.key}="${e.value}"');
    }
    if (spec.pathEntries.isNotEmpty) {
      b.writeln('export PATH="\$PATH:${spec.pathEntries.join(':')}"');
    }
    b.writeln(kManagedBlockEnd);
    return b.toString();
  }

  /// Replaces or appends the managed block in [content]. Pure.
  static String applyBlock(String content, String block) {
    final start = content.indexOf(kManagedBlockStart);
    final end = content.indexOf(kManagedBlockEnd);
    if (start >= 0 && end > start) {
      final after = end + kManagedBlockEnd.length;
      final trailing = content.substring(after).startsWith('\n') ? after + 1 : after;
      return content.substring(0, start) + block + content.substring(trailing);
    }
    final sep = content.isEmpty || content.endsWith('\n') ? '' : '\n';
    return '$content$sep\n$block';
  }

  List<String> profileFiles() {
    final shell = p.basename(platform.shell);
    final files = <String>{p.join(platform.home, '.zprofile')};
    if (shell == 'bash') files.add(p.join(platform.home, '.bash_profile'));
    if (shell == 'zsh') files.add(p.join(platform.home, '.zshrc'));
    return files.toList();
  }

  Future<List<String>> apply(EnvSpec spec, {void Function(String)? log}) async {
    if (platform.isWindows) return _applyWindows(spec, log);
    return _applyUnix(spec, log);
  }

  Future<List<String>> _applyUnix(EnvSpec spec, void Function(String)? log) async {
    final block = renderBlock(spec);
    final touched = <String>[];
    await Directory(backupDir).create(recursive: true);
    for (final path in profileFiles()) {
      final f = File(path);
      final existing = await f.exists() ? await f.readAsString() : '';
      if (existing.isNotEmpty) {
        final backup = p.join(backupDir, '${p.basename(path)}.${_stamp()}.bak');
        await f.copy(backup);
        log?.call('Backed up $path to $backup');
      }
      final updated = applyBlock(existing, block);
      if (updated != existing) {
        await f.writeAsString(updated);
        log?.call('Updated $path');
        touched.add(path);
      }
    }
    return touched;
  }

  Future<List<String>> _applyWindows(EnvSpec spec, void Function(String)? log) async {
    await Directory(backupDir).create(recursive: true);
    final snapshot = await runner.powershell(
      r"[Environment]::GetEnvironmentVariable('Path','User'); 'JAVA_HOME=' + [Environment]::GetEnvironmentVariable('JAVA_HOME','User'); 'ANDROID_HOME=' + [Environment]::GetEnvironmentVariable('ANDROID_HOME','User')",
    );
    final backup = p.join(backupDir, 'user-environment.${_stamp()}.txt');
    await File(backup).writeAsString(snapshot.stdout);
    log?.call('Saved a copy of your current user environment to $backup');

    final vars = spec.variables.entries
        .map((e) => "[Environment]::SetEnvironmentVariable('${_ps(e.key)}', '${_ps(e.value)}', 'User')")
        .join('; ');
    final entries = spec.pathEntries.map((e) => "'${_ps(e)}'").join(',');
    final script = '''
\$ErrorActionPreference = 'Stop'
$vars
\$current = [Environment]::GetEnvironmentVariable('Path','User')
if (\$null -eq \$current) { \$current = '' }
\$parts = [System.Collections.Generic.List[string]](\$current -split ';' | Where-Object { \$_ -ne '' })
foreach (\$entry in @($entries)) {
  if (-not (\$parts -contains \$entry)) { \$parts.Add(\$entry) }
}
[Environment]::SetEnvironmentVariable('Path', (\$parts -join ';'), 'User')
Write-Output 'OK'
''';
    final r = await runner.powershell(script, onLine: log);
    if (!r.ok) throw Exception('Could not update environment variables: ${r.stderr.trim()}');
    return ['HKEY_CURRENT_USER\\Environment'];
  }

  /// Environment to hand to child processes right now, before the user opens
  /// a new terminal.
  Map<String, String> liveEnvironment(EnvSpec spec) {
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(spec.variables);
    final key = platform.isWindows ? (env.keys.firstWhere((k) => k.toUpperCase() == 'PATH', orElse: () => 'Path')) : 'PATH';
    final sep = platform.isWindows ? ';' : ':';
    env[key] = '${env[key] ?? ''}$sep${spec.pathEntries.join(sep)}';
    return env;
  }

  static String _stamp() => DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  static String _ps(String s) => s.replaceAll("'", "''");

  String describe(EnvSpec spec) => const JsonEncoder.withIndent('  ').convert({'variables': spec.variables, 'path': spec.pathEntries});
}
