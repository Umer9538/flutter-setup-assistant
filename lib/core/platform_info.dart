import 'dart:io';

import 'process_runner.dart';

enum HostOs { macos, windows, other }

enum HostArch { arm64, x64 }

/// Facts about the machine the assistant is running on.
class PlatformInfo {
  PlatformInfo({
    required this.os,
    required this.arch,
    required this.home,
    required this.osVersion,
    required this.shell,
    required this.localAppData,
  });

  final HostOs os;
  final HostArch arch;
  final String home;
  final String osVersion;
  final String shell;

  /// Windows `%LOCALAPPDATA%`; empty on other platforms.
  final String localAppData;

  bool get isMac => os == HostOs.macos;
  bool get isWindows => os == HostOs.windows;
  bool get isArm => arch == HostArch.arm64;

  String get osLabel => switch (os) {
        HostOs.macos => 'macOS',
        HostOs.windows => 'Windows',
        HostOs.other => Platform.operatingSystem,
      };

  String get archLabel => isArm ? 'arm64' : 'x64';

  static Future<PlatformInfo> detect(ProcessRunner runner) async {
    final env = Platform.environment;
    final os = Platform.isMacOS
        ? HostOs.macos
        : Platform.isWindows
            ? HostOs.windows
            : HostOs.other;

    var arch = Platform.version.contains('arm64') ? HostArch.arm64 : HostArch.x64;
    if (os == HostOs.macos) {
      // The app itself may run under Rosetta; ask the kernel instead.
      final r = await runner.run('sysctl', ['-n', 'hw.optional.arm64']);
      if (r.exitCode == 0 && r.stdout.trim() == '1') arch = HostArch.arm64;
    } else if (os == HostOs.windows) {
      final a = (env['PROCESSOR_ARCHITEW6432'] ?? env['PROCESSOR_ARCHITECTURE'] ?? '').toUpperCase();
      arch = a.contains('ARM64') ? HostArch.arm64 : HostArch.x64;
    }

    final home = env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
    return PlatformInfo(
      os: os,
      arch: arch,
      home: home,
      osVersion: Platform.operatingSystemVersion,
      shell: env['SHELL'] ?? (os == HostOs.windows ? 'powershell' : '/bin/zsh'),
      localAppData: env['LOCALAPPDATA'] ?? '',
    );
  }
}
