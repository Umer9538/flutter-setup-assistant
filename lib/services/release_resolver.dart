import 'dart:convert';

import '../core/downloader.dart';
import '../core/platform_info.dart';
import '../domain/version_catalog.dart';

class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.url, this.sha256, this.fromFallback = false});
  final String version;
  final String url;
  final String? sha256;
  final bool fromFallback;
}

/// Latest compatible versions of every component, resolved from the official
/// release feeds with pinned fallbacks for offline use.
class ResolvedVersions {
  ResolvedVersions({
    required this.flutter,
    required this.jdk,
    required this.androidStudio,
    required this.cmdlineTools,
    required this.vscode,
    required this.gitForWindows,
    required this.warnings,
  });

  final ReleaseInfo flutter;
  final ReleaseInfo jdk;
  final ReleaseInfo androidStudio;
  final ReleaseInfo cmdlineTools;
  final ReleaseInfo vscode;
  final ReleaseInfo? gitForWindows;
  final List<String> warnings;
}

class ReleaseResolver {
  ReleaseResolver({required this.platform, required this.catalog, required this.downloader});
  final PlatformInfo platform;
  final VersionCatalog catalog;
  final Downloader downloader;

  Future<ResolvedVersions> resolve({void Function(String)? log}) async {
    final warnings = <String>[];

    Future<ReleaseInfo> attempt(String name, Future<ReleaseInfo> Function() live, ReleaseInfo fallback) async {
      try {
        final r = await live();
        log?.call('$name: latest is ${r.version}');
        return r;
      } catch (e) {
        warnings.add('Could not check the latest $name online (${_short(e)}). Using the known-good version ${fallback.version}.');
        return fallback;
      }
    }

    final results = await Future.wait([
      attempt('Flutter', _flutter, _flutterFallback()),
      attempt('Java JDK', _jdk, _jdkFallback()),
      attempt('Android Studio', _androidStudio, _studioFallback()),
      attempt('Android command line tools', _cmdlineTools, _cmdlineFallback(catalog.cmdlineToolsFallbackBuild)),
      attempt('VS Code', _vscode, _vscodeFallback()),
      if (platform.isWindows) attempt('Git for Windows', _gitForWindows, _gitFallback()),
    ]);

    return ResolvedVersions(
      flutter: results[0],
      jdk: results[1],
      androidStudio: results[2],
      cmdlineTools: results[3],
      vscode: results[4],
      gitForWindows: platform.isWindows ? results[5] : null,
      warnings: warnings,
    );
  }

  // ---- Flutter -------------------------------------------------------------

  String get _flutterOs => platform.isWindows ? 'windows' : 'macos';

  Future<ReleaseInfo> _flutter() async {
    final json = await downloader.fetchJson('https://storage.googleapis.com/flutter_infra_release/releases/releases_$_flutterOs.json');
    final base = json['base_url'] as String;
    final hash = (json['current_release'] as Map)[catalog.flutterChannel] as String;
    final wantArch = platform.isMac && platform.isArm ? 'arm64' : 'x64';
    final releases = (json['releases'] as List).cast<Map<String, dynamic>>();
    final match = releases.firstWhere(
      (r) => r['hash'] == hash && (r['dart_sdk_arch'] ?? 'x64') == wantArch,
      orElse: () => releases.firstWhere((r) => r['hash'] == hash),
    );
    return ReleaseInfo(version: match['version'] as String, url: '$base/${match['archive']}', sha256: match['sha256'] as String?);
  }

  ReleaseInfo _flutterFallback() {
    final v = catalog.flutterFallbackVersion;
    final name = platform.isWindows
        ? 'flutter_windows_$v-stable.zip'
        : platform.isArm
            ? 'flutter_macos_arm64_$v-stable.zip'
            : 'flutter_macos_$v-stable.zip';
    return ReleaseInfo(version: v, url: 'https://storage.googleapis.com/flutter_infra_release/releases/stable/$_flutterOs/$name', fromFallback: true);
  }

  // ---- JDK -----------------------------------------------------------------

  String get _jdkOs => platform.isWindows ? 'windows' : 'mac';
  String get _jdkArch => platform.isMac && platform.isArm ? 'aarch64' : 'x64';

  Future<ReleaseInfo> _jdk() async {
    final feature = catalog.jdkFeatureVersion;
    final text = await downloader.fetchText(
      'https://api.adoptium.net/v3/assets/latest/$feature/hotspot?architecture=$_jdkArch&image_type=jdk&os=$_jdkOs&vendor=eclipse',
    );
    final list = jsonDecode(text) as List;
    final first = list.first as Map<String, dynamic>;
    final pkg = (first['binary'] as Map)['package'] as Map;
    return ReleaseInfo(version: (first['version'] as Map)['semver'] as String, url: pkg['link'] as String, sha256: pkg['checksum'] as String?);
  }

  ReleaseInfo _jdkFallback() => ReleaseInfo(
        version: '${catalog.jdkFeatureVersion} (latest build)',
        url: 'https://api.adoptium.net/v3/binary/latest/${catalog.jdkFeatureVersion}/ga/$_jdkOs/$_jdkArch/jdk/hotspot/normal/eclipse',
        fromFallback: true,
      );

  // ---- Android Studio ------------------------------------------------------

  String get _studioSuffix => platform.isWindows
      ? '-windows.zip'
      : platform.isArm
          ? '-mac_arm.dmg'
          : '-mac.dmg';

  Future<ReleaseInfo> _androidStudio() async {
    final json = await downloader.fetchJson('https://jb.gg/android-studio-releases-list.json');
    final items = ((json['content'] as Map)['item'] as List).cast<Map<String, dynamic>>();
    final release = items.firstWhere((i) => (i['channel'] as String?)?.toLowerCase() == 'release');
    final downloads = (release['download'] as List).cast<Map<String, dynamic>>();
    final dl = downloads.firstWhere((d) => (d['link'] as String).endsWith(_studioSuffix));
    final checksum = dl['checksum'] as String?;
    return ReleaseInfo(
      version: release['version'] as String,
      url: dl['link'] as String,
      sha256: checksum != null && checksum.length == 64 ? checksum : null,
    );
  }

  ReleaseInfo _studioFallback() {
    final v = catalog.androidStudioFallbackVersion;
    final slug = catalog.androidStudioFallbackSlug;
    final folder = platform.isWindows ? 'ide-zips' : 'install';
    return ReleaseInfo(version: v, url: 'https://edgedl.me.gvt1.com/android/studio/$folder/$v/android-studio-$slug$_studioSuffix', fromFallback: true);
  }

  // ---- Android command line tools -----------------------------------------

  String get _cmdOs => platform.isWindows ? 'win' : 'mac';

  Future<ReleaseInfo> _cmdlineTools() async {
    final xml = await downloader.fetchText('https://dl.google.com/android/repository/repository2-3.xml');
    final builds = RegExp('commandlinetools-$_cmdOs-(\\d+)_latest\\.zip').allMatches(xml).map((m) => int.parse(m.group(1)!)).toList();
    if (builds.isEmpty) throw Exception('no builds listed');
    builds.sort();
    return _cmdlineFallback(builds.last.toString(), fallback: false);
  }

  ReleaseInfo _cmdlineFallback(String build, {bool fallback = true}) => ReleaseInfo(
        version: build,
        url: 'https://dl.google.com/android/repository/commandlinetools-$_cmdOs-${build}_latest.zip',
        fromFallback: fallback,
      );

  // ---- VS Code -------------------------------------------------------------

  String get _vscodePlatform => platform.isWindows ? (platform.isArm ? 'win32-arm64-user' : 'win32-x64-user') : 'darwin-universal';

  Future<ReleaseInfo> _vscode() async {
    final json = await downloader.fetchJson('https://update.code.visualstudio.com/api/update/$_vscodePlatform/stable/latest');
    return ReleaseInfo(version: json['productVersion'] as String, url: json['url'] as String, sha256: json['sha256hash'] as String?);
  }

  ReleaseInfo _vscodeFallback() =>
      ReleaseInfo(version: 'latest', url: 'https://update.code.visualstudio.com/latest/$_vscodePlatform/stable', fromFallback: true);

  // ---- Git for Windows -----------------------------------------------------

  Future<ReleaseInfo> _gitForWindows() async {
    final json = await downloader.fetchJson('https://api.github.com/repos/git-for-windows/git/releases/latest');
    final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
    final asset = assets.firstWhere((a) => (a['name'] as String).endsWith('-64-bit.exe'));
    return ReleaseInfo(version: json['tag_name'] as String, url: asset['browser_download_url'] as String);
  }

  ReleaseInfo _gitFallback() => const ReleaseInfo(
        version: 'v2.56.0.windows.1',
        url: 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.1/Git-2.56.0-64-bit.exe',
        fromFallback: true,
      );

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}
