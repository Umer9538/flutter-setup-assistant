import 'package:path/path.dart' as p;

import 'platform_info.dart';

/// Where everything gets installed. All locations are user-writable, so the
/// assistant never needs administrator rights.
class InstallPaths {
  InstallPaths({required this.platform, required this.root});

  final PlatformInfo platform;

  /// Root for SDKs, e.g. `~/development` or `C:\Users\me\development`.
  final String root;

  static InstallPaths defaults(PlatformInfo platform) =>
      InstallPaths(platform: platform, root: p.join(platform.home, 'development'));

  InstallPaths withRoot(String newRoot) => InstallPaths(platform: platform, root: newRoot);

  String get flutterSdk => p.join(root, 'flutter');
  String get flutterBin => p.join(flutterSdk, 'bin', platform.isWindows ? 'flutter.bat' : 'flutter');
  String get dartBin => p.join(flutterSdk, 'bin', platform.isWindows ? 'dart.bat' : 'dart');

  /// Folder that holds the JDK. On macOS the real home is `Contents/Home`.
  String get jdkDir => p.join(root, 'jdk-17');
  String get jdkHome => platform.isMac ? p.join(jdkDir, 'Contents', 'Home') : jdkDir;

  String get androidSdk => platform.isWindows
      ? p.join(platform.localAppData.isNotEmpty ? platform.localAppData : p.join(platform.home, 'AppData', 'Local'), 'Android', 'Sdk')
      : p.join(platform.home, 'Library', 'Android', 'sdk');

  String get cmdlineToolsBin => p.join(androidSdk, 'cmdline-tools', 'latest', 'bin');
  String get sdkManager => p.join(cmdlineToolsBin, platform.isWindows ? 'sdkmanager.bat' : 'sdkmanager');
  String get avdManager => p.join(cmdlineToolsBin, platform.isWindows ? 'avdmanager.bat' : 'avdmanager');
  String get platformTools => p.join(androidSdk, 'platform-tools');
  String get emulatorDir => p.join(androidSdk, 'emulator');

  String get androidStudio => platform.isWindows
      ? p.join(_programs, 'Android Studio')
      : '/Applications/Android Studio.app';

  String get vscode => platform.isWindows
      ? p.join(_programs, 'Microsoft VS Code')
      : '/Applications/Visual Studio Code.app';

  String get vscodeCli => platform.isWindows
      ? p.join(vscode, 'bin', 'code.cmd')
      : p.join(vscode, 'Contents', 'Resources', 'app', 'bin', 'code');

  String get cache => p.join(root, '.setup-assistant', 'downloads');
  String get stateDir => p.join(root, '.setup-assistant');
  String get logsDir => p.join(stateDir, 'logs');
  String get backupsDir => p.join(stateDir, 'backups');

  String get _programs => p.join(platform.localAppData.isNotEmpty ? platform.localAppData : p.join(platform.home, 'AppData', 'Local'), 'Programs');
}
