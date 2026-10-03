import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RunResult {
  RunResult({required this.exitCode, required this.stdout, required this.stderr, this.timedOut = false});
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  bool get ok => exitCode == 0 && !timedOut;
  String get combined => '$stdout\n$stderr'.trim();
}

/// Runs external commands, streaming their output line by line.
class ProcessRunner {
  ProcessRunner({this.onCommand});

  /// Called with a human readable description of every command executed.
  final void Function(String line)? onCommand;

  Future<RunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
    String? stdinText,
    void Function(String line)? onLine,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    onCommand?.call('\$ $executable ${args.join(' ')}');
    final needsShell = Platform.isWindows &&
        (executable.toLowerCase().endsWith('.bat') || executable.toLowerCase().endsWith('.cmd'));
    final Process process;
    try {
      process = await Process.start(
        executable,
        args,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: needsShell,
      );
    } on ProcessException catch (e) {
      return RunResult(exitCode: 127, stdout: '', stderr: e.message);
    }

    final out = StringBuffer();
    final err = StringBuffer();
    final outDone = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
      out.writeln(l);
      onLine?.call(l);
    }).asFuture<void>();
    final errDone = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
      err.writeln(l);
      onLine?.call(l);
    }).asFuture<void>();

    if (stdinText != null) {
      try {
        process.stdin.write(stdinText);
        await process.stdin.flush();
        await process.stdin.close();
      } catch (_) {
        // Process may have exited before consuming stdin; that is fine.
      }
    }

    var timedOut = false;
    final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
      return -1;
    });
    await Future.wait([outDone, errDone]).timeout(const Duration(seconds: 5), onTimeout: () => []);
    return RunResult(exitCode: exitCode, stdout: out.toString(), stderr: err.toString(), timedOut: timedOut);
  }

  /// Runs a PowerShell script (Windows only) without profile or prompts.
  Future<RunResult> powershell(String script, {void Function(String line)? onLine, Duration? timeout}) {
    return run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
      onLine: onLine,
      timeout: timeout ?? const Duration(minutes: 30),
    );
  }

  /// Finds an executable on PATH. Returns null when absent.
  Future<String?> which(String name) async {
    final r = Platform.isWindows ? await run('where.exe', [name]) : await run('/usr/bin/which', [name]);
    if (!r.ok) return null;
    final first = r.stdout.trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).firstOrNull;
    return first;
  }
}
