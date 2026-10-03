import 'dart:io';

import 'package:path/path.dart' as p;

import 'process_runner.dart';

class ExtractException implements Exception {
  ExtractException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Extracts archives using the operating system's own tools. They are far
/// faster than pure Dart for multi-gigabyte SDKs and preserve symlinks, which
/// the Flutter SDK and macOS app bundles depend on.
class Extractor {
  Extractor(this.runner);
  final ProcessRunner runner;

  Future<void> extract(String archive, String destination, {void Function(String line)? onLine}) async {
    await Directory(destination).create(recursive: true);
    final lower = archive.toLowerCase();
    RunResult r;
    if (Platform.isWindows) {
      // bsdtar ships with Windows 10 1803+ and understands zip, tar.gz and tar.xz.
      r = await runner.run('tar.exe', ['-xf', archive, '-C', destination], onLine: onLine);
      if (!r.ok && lower.endsWith('.zip')) {
        r = await runner.powershell(
          "Expand-Archive -LiteralPath '${_ps(archive)}' -DestinationPath '${_ps(destination)}' -Force",
          onLine: onLine,
        );
      }
    } else if (lower.endsWith('.zip')) {
      r = await runner.run('/usr/bin/ditto', ['-x', '-k', archive, destination], onLine: onLine);
    } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      r = await runner.run('/usr/bin/tar', ['-xzf', archive, '-C', destination], onLine: onLine);
    } else if (lower.endsWith('.tar.xz')) {
      r = await runner.run('/usr/bin/tar', ['-xJf', archive, '-C', destination], onLine: onLine);
    } else {
      throw ExtractException('Unknown archive type: ${p.basename(archive)}');
    }
    if (!r.ok) {
      throw ExtractException('Could not extract ${p.basename(archive)}: ${r.stderr.trim().split('\n').last}');
    }
  }

  /// Mounts a macOS disk image, copies the single `.app` inside to
  /// `/Applications`, then unmounts. Returns the installed app path.
  Future<String> installDmgApp(String dmg, {String applications = '/Applications', void Function(String line)? onLine}) async {
    final attach = await runner.run('/usr/bin/hdiutil', ['attach', '-nobrowse', '-noverify', '-readonly', dmg], onLine: onLine);
    if (!attach.ok) throw ExtractException('Could not open disk image: ${attach.stderr.trim()}');
    final mount = RegExp(r'(/Volumes/[^\n]+)$', multiLine: true).allMatches(attach.stdout).map((m) => m.group(1)!.trim()).lastOrNull;
    if (mount == null) throw ExtractException('Disk image mounted but no volume path was reported.');
    try {
      final apps = await Directory(mount).list().where((e) => e.path.endsWith('.app')).toList();
      if (apps.isEmpty) throw ExtractException('No application found inside ${p.basename(dmg)}.');
      final src = apps.first.path;
      final dest = p.join(applications, p.basename(src));
      if (await Directory(dest).exists()) {
        await Directory(dest).delete(recursive: true);
      }
      final cp = await runner.run('/usr/bin/ditto', [src, dest], onLine: onLine);
      if (!cp.ok) throw ExtractException('Could not copy ${p.basename(src)} to $applications: ${cp.stderr.trim()}');
      // Clear the quarantine flag so Gatekeeper does not block a freshly copied app.
      await runner.run('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', dest]);
      return dest;
    } finally {
      await runner.run('/usr/bin/hdiutil', ['detach', mount, '-quiet']);
    }
  }

  static String _ps(String s) => s.replaceAll("'", "''");
}
