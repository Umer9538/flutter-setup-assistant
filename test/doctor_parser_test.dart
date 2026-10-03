import 'package:flutter_setup_assistant/core/platform_info.dart';
import 'package:flutter_setup_assistant/domain/doctor.dart';
import 'package:flutter_setup_assistant/services/doctor/doctor_parser.dart';
import 'package:flutter_setup_assistant/services/doctor/fix_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const macOutput = '''
[✓] Flutter (Channel stable, 3.47.6, on macOS 27.0 26A428 darwin-arm64, locale en) [638ms]
    • Flutter version 3.47.6 on channel stable at /Users/me/development/flutter
    • Dart version 3.13.5

[!] Android toolchain - develop for Android devices (Android SDK version 36.1.0) [958ms]
    • Android SDK at /Users/me/Library/Android/sdk
    ✗ cmdline-tools component is missing.
      Try installing or updating Android Studio.
    ✗ Android license status unknown.
      Run `flutter doctor --android-licenses` to accept the SDK licenses.

[✗] Xcode - develop for iOS and macOS
    ✗ Xcode installation is incomplete; a full installation is necessary for iOS and macOS development.

[✓] Chrome - develop for the web [5ms]
    • Chrome at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

[✓] Connected device (2 available) [7.3s]
    • macOS (desktop) • macos  • darwin-arm64   • macOS 27.0
    ! Error: Browsing on the local area network for iPhone.

! Doctor found issues in 2 categories.
''';

const winOutput = '''
[√] Flutter (Channel stable, 3.47.6, on Microsoft Windows [Version 10.0.22631.4037], locale en-US)
    • Flutter version 3.47.6 on channel stable at C:\\Users\\me\\development\\flutter
[X] Android toolchain - develop for Android devices
    X Unable to locate Android SDK.
      Install Android Studio from: https://developer.android.com/studio/index.html
[X] Visual Studio - develop Windows apps
    X Visual Studio not installed; this is necessary to develop Windows apps.
[!] Android Studio (not installed)
    • Android Studio not found; download from https://developer.android.com/studio/index.html
''';

PlatformInfo _mac() => PlatformInfo(os: HostOs.macos, arch: HostArch.arm64, home: '/Users/me', osVersion: '27', shell: '/bin/zsh', localAppData: '');
PlatformInfo _win() => PlatformInfo(os: HostOs.windows, arch: HostArch.x64, home: r'C:\Users\me', osVersion: '11', shell: 'powershell', localAppData: r'C:\Users\me\AppData\Local');

void main() {
  test('parses macOS categories and problems', () {
    final cats = DoctorParser.parse(macOutput);
    expect(cats.map((c) => c.title), ['Flutter', 'Android toolchain', 'Xcode', 'Chrome', 'Connected device']);
    expect(cats[0].severity, DoctorSeverity.ok);
    expect(cats[1].severity, DoctorSeverity.warning);
    expect(cats[1].problems.length, 2);
    expect(cats[1].problems.first, startsWith('cmdline-tools component is missing.'));
    expect(cats[1].problems.first, contains('Try installing'));
    expect(cats[2].severity, DoctorSeverity.error);
  });

  test('explains macOS problems with auto fixes', () {
    final issues = FixCatalog(_mac()).explain(DoctorParser.parse(macOutput));
    final keys = issues.map((i) => i.key).toList();
    expect(keys, containsAll(['android.cmdline-tools', 'android.licenses', 'xcode.missing']));
    expect(issues.firstWhere((i) => i.key == 'android.licenses').autoFixable, isTrue);
    expect(issues.firstWhere((i) => i.key == 'xcode.missing').autoFixable, isFalse);
    expect(issues.firstWhere((i) => i.key == 'xcode.missing').manualSteps, isNotEmpty);
  });

  test('parses Windows markers', () {
    final cats = DoctorParser.parse(winOutput);
    expect(cats[0].severity, DoctorSeverity.ok);
    expect(cats[1].severity, DoctorSeverity.error);
    expect(cats[1].problems.single, startsWith('Unable to locate Android SDK.'));
    final issues = FixCatalog(_win()).explain(cats);
    expect(issues.map((i) => i.key), containsAll(['android.sdk', 'visualstudio']));
    expect(issues.firstWhere((i) => i.key == 'android.sdk').autoFixable, isTrue);
    expect(issues.firstWhere((i) => i.key == 'visualstudio').severity, DoctorSeverity.warning);
  });
}
