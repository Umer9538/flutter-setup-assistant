import '../../core/platform_info.dart';
import '../../domain/doctor.dart';

/// Maps raw `flutter doctor` messages to plain-language explanations and,
/// where safe, an automatic repair.
class FixCatalog {
  FixCatalog(this.platform);
  final PlatformInfo platform;

  List<DoctorIssue> explain(List<DoctorCategory> categories) {
    final issues = <DoctorIssue>[];
    for (final cat in categories) {
      if (cat.severity == DoctorSeverity.ok) continue;
      final matched = <String>{};
      for (final problem in cat.problems) {
        final issue = _match(cat, problem);
        if (issue != null && matched.add(issue.key)) issues.add(issue);
      }
      if (cat.problems.isEmpty || issues.where((i) => i.category == cat.title).isEmpty) {
        final generic = _categoryFallback(cat);
        if (generic != null) issues.add(generic);
      }
    }
    return issues;
  }

  DoctorIssue? _match(DoctorCategory cat, String problem) {
    final text = problem.toLowerCase();
    final sev = cat.severity == DoctorSeverity.warning ? DoctorSeverity.warning : DoctorSeverity.error;
    DoctorIssue make(String key, String title, String explanation, {bool auto = false, List<String> steps = const [], String? link, DoctorSeverity? severity}) =>
        DoctorIssue(key: key, category: cat.title, title: title, explanation: explanation, rawMessage: problem, severity: severity ?? sev, autoFixable: auto, manualSteps: steps, link: link);

    if (text.contains('cmdline-tools component is missing')) {
      return make('android.cmdline-tools', 'Android command line tools are missing',
          'Flutter uses Google\'s command line tools to manage the Android SDK and accept licenses. They were not found in your SDK folder.',
          auto: true);
    }
    if (text.contains('license status unknown') || text.contains('licenses not accepted') || text.contains('not all android licenses')) {
      return make('android.licenses', 'Android SDK licenses are not accepted',
          'Google requires you to accept the SDK licenses once before Android apps can be built. The assistant can accept them for you.',
          auto: true);
    }
    if (text.contains('unable to locate android sdk') || text.contains('android sdk not found') || text.contains('no android sdk')) {
      return make('android.sdk', 'Android SDK not found',
          'Flutter cannot find the Android SDK, which contains the tools needed to build Android apps.',
          auto: true);
    }
    if (text.contains('android studio not installed') || text.contains('unable to find android studio')) {
      return make('android.studio', 'Android Studio is not installed',
          'Android Studio provides the Android emulator and SDK manager. Flutter projects build fine without it, but the emulator needs it.',
          auto: true);
    }
    if (text.contains('no java development kit') || text.contains('unable to find bundled java') || text.contains('java binary') || text.contains('could not find java')) {
      return make('java.missing', 'Java Development Kit not found',
          'The Android build system (Gradle) runs on Java. A compatible JDK 17 will be installed and Flutter pointed at it.',
          auto: true);
    }
    if (text.contains('xcode installation is incomplete') || text.contains('xcode not installed') || text.contains('xcode-select') || text.contains('xcode is not installed')) {
      return make('xcode.missing', 'Xcode is not fully installed',
          'Xcode is Apple\'s toolchain and is only needed for iOS and macOS apps. Apple only distributes it through the App Store, so this step is manual.',
          steps: ['Open the App Store and install "Xcode" (about 12 GB).', 'Open Xcode once and accept the license.', 'Run "sudo xcode-select --switch /Applications/Xcode.app" in Terminal.', 'Re-run diagnosis here.'],
          link: 'https://apps.apple.com/app/xcode/id497799835',
          severity: DoctorSeverity.warning);
    }
    if (text.contains('cocoapods not installed') || text.contains('cocoapods installed but not working') || text.contains('cocoapods') && text.contains('out of date')) {
      return make('cocoapods', 'CocoaPods is missing or out of date',
          'CocoaPods manages native iOS dependencies. It is needed as soon as you add plugins to an iOS app.',
          auto: true, steps: ['If automatic install fails: run "brew install cocoapods" or "sudo gem install cocoapods" in Terminal.']);
    }
    if (text.contains('visual studio not installed') || text.contains('visual studio is missing necessary components') || text.contains('the current visual studio installation is incomplete')) {
      return make('visualstudio', 'Visual Studio C++ tools are missing',
          'Only needed to build Windows desktop apps. Android, iOS and web development work without it.',
          steps: ['Download Visual Studio Community from the link.', 'Select the "Desktop development with C++" workload during install.'],
          link: 'https://visualstudio.microsoft.com/downloads/',
          severity: DoctorSeverity.warning);
    }
    if (text.contains('chrome') && (text.contains('cannot find') || text.contains('not installed') || text.contains('unable to locate'))) {
      return make('chrome', 'Google Chrome not found',
          'Chrome is only needed to run and debug Flutter web apps.',
          steps: ['Install Chrome from the link if you plan to build for the web.'],
          link: 'https://www.google.com/chrome/',
          severity: DoctorSeverity.warning);
    }
    if (text.contains('git') && (text.contains('not found') || text.contains('unable to find git') || text.contains('is not installed'))) {
      return make('git', 'Git is not installed',
          'Flutter uses Git to manage its own SDK and to download packages.',
          auto: true);
    }
    if (text.contains('network') || text.contains('could not resolve') || text.contains('timed out')) {
      return make('network', 'A network resource could not be reached',
          'Flutter checks a few Google and GitHub servers. A firewall, proxy or offline machine causes this.',
          steps: ['Check your connection, VPN or proxy and re-run diagnosis.'],
          severity: DoctorSeverity.warning);
    }
    if (text.contains('no devices') || text.contains('no connected devices') || text.contains('browsing on the local area network')) {
      return make('devices', 'No device is connected',
          'This is informational. Start the emulator or plug in a phone with USB debugging enabled when you are ready to run an app.',
          severity: DoctorSeverity.info);
    }
    if (text.contains('flutter plugin not installed') || text.contains('dart plugin not installed')) {
      return make('ide.plugins', 'IDE plugins not detected',
          'Recent IDEs install the Flutter and Dart plugins through their marketplace. Open the IDE, go to Plugins and search for "Flutter".',
          severity: DoctorSeverity.info);
    }
    if (text.contains('android sdk') && (text.contains('version') || text.contains('out of date') || text.contains('platform-tools'))) {
      return make('android.sdk.update', 'Android SDK components need an update',
          'Part of the Android SDK is older than Flutter expects. The assistant can install the current platform and build tools.',
          auto: true);
    }
    return null;
  }

  DoctorIssue? _categoryFallback(DoctorCategory cat) {
    final title = cat.title.toLowerCase();
    if (title.contains('android toolchain')) {
      return DoctorIssue(key: 'android.generic', category: cat.title, title: 'Android toolchain needs attention', explanation: 'Flutter reported a problem with the Android SDK that the assistant can usually repair by reinstalling the SDK components and accepting licenses.', rawMessage: cat.problems.join('\n'), autoFixable: true, severity: cat.severity);
    }
    if (cat.severity == DoctorSeverity.ok || cat.severity == DoctorSeverity.info) return null;
    if (cat.problems.isEmpty && cat.title.toLowerCase().contains('connected device')) return null;
    return DoctorIssue(
      key: 'generic.${cat.title}',
      category: cat.title,
      title: '${cat.title}: ${cat.severity == DoctorSeverity.warning ? 'warning' : 'problem'}',
      explanation: cat.problems.isEmpty ? cat.summary : cat.problems.first.split('\n').first,
      rawMessage: cat.problems.join('\n'),
      severity: cat.severity,
    );
  }
}
