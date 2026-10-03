import 'version.dart';

/// Known-good versions and compatibility rules.
///
/// Live versions are resolved online at runtime; these values are the pinned
/// fallbacks that are used when the network is unavailable, and the rules
/// that decide whether an already-installed tool is compatible.
class VersionCatalog {
  const VersionCatalog();

  // Flutter
  String get flutterChannel => 'stable';
  String get flutterFallbackVersion => '3.47.6';
  Version get minimumFlutter => const Version(3, 24, 0);

  // Java
  int get jdkFeatureVersion => 17;
  int get minJdk => 17;
  int get maxJdk => 21;

  // Android
  int get androidApiLevel => 36;
  String get buildToolsVersion => '36.0.0';
  String get cmdlineToolsFallbackBuild => '15641748';
  Version get minimumAndroidStudio => const Version(2024, 1, 0);
  String get androidStudioFallbackVersion => '2026.2.1.8';
  String get androidStudioFallbackSlug => 'rabbit1';

  // Editors
  List<String> get vscodeExtensions => const ['Dart-Code.dart-code', 'Dart-Code.flutter'];

  String emulatorSystemImage(bool arm) => 'system-images;android-$androidApiLevel;google_apis;${arm ? 'arm64-v8a' : 'x86_64'}';
  String get emulatorDevice => 'pixel_7';
  String get emulatorName => 'Flutter_Pixel_7';

  List<String> sdkPackages(bool arm) => [
        'platform-tools',
        'platforms;android-$androidApiLevel',
        'build-tools;$buildToolsVersion',
        'emulator',
        emulatorSystemImage(arm),
      ];

  /// Plain-language compatibility verdict for an installed JDK.
  String? jdkCompatibilityIssue(int? major) {
    if (major == null) return 'Could not determine the Java version.';
    if (major < minJdk) return 'Java $major is too old. Android builds need Java $minJdk or newer.';
    if (major > maxJdk) return 'Java $major is newer than the Android Gradle plugin supports. A side-by-side Java $jdkFeatureVersion will be installed and used for Flutter.';
    return null;
  }

  String? flutterCompatibilityIssue(Version? v) {
    if (v == null) return 'Could not read the Flutter version.';
    if (v < minimumFlutter) return 'Flutter $v is older than $minimumFlutter. Newer Android tooling needs a recent SDK.';
    return null;
  }

  String? androidStudioCompatibilityIssue(Version? v) {
    if (v == null) return null;
    if (v < minimumAndroidStudio) return 'Android Studio $v is older than the version Flutter currently supports.';
    return null;
  }
}
