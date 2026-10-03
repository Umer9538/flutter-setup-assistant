enum ComponentId {
  git,
  flutter,
  jdk,
  androidStudio,
  androidSdk,
  emulator,
  vscode,
  vscodeExtensions,
  xcode,
  cocoapods,
  chrome,
  visualStudio,
  environment,
  licenses,
}

enum ComponentStatus { missing, installed, outdated, incompatible, partial, unknown }

extension ComponentStatusX on ComponentStatus {
  String get label => switch (this) {
        ComponentStatus.missing => 'Not installed',
        ComponentStatus.installed => 'Ready',
        ComponentStatus.outdated => 'Outdated',
        ComponentStatus.incompatible => 'Incompatible',
        ComponentStatus.partial => 'Needs attention',
        ComponentStatus.unknown => 'Unknown',
      };

  bool get isHealthy => this == ComponentStatus.installed;
}

/// Static description of a component the assistant knows how to manage.
class ComponentInfo {
  const ComponentInfo({
    required this.id,
    required this.name,
    required this.description,
    this.required = true,
    this.autoInstallable = true,
    this.macOnly = false,
    this.windowsOnly = false,
  });

  final ComponentId id;
  final String name;
  final String description;
  final bool required;
  final bool autoInstallable;
  final bool macOnly;
  final bool windowsOnly;
}

const List<ComponentInfo> kComponents = [
  ComponentInfo(id: ComponentId.git, name: 'Git', description: 'Version control. Flutter uses it to manage its own SDK.'),
  ComponentInfo(id: ComponentId.flutter, name: 'Flutter SDK', description: 'The framework, Dart, and the flutter command line tool.'),
  ComponentInfo(id: ComponentId.jdk, name: 'Java JDK 17', description: 'Required by the Android build tools (Gradle).'),
  ComponentInfo(id: ComponentId.androidStudio, name: 'Android Studio', description: 'Official Android IDE; also provides the Android emulator engine.'),
  ComponentInfo(id: ComponentId.androidSdk, name: 'Android SDK', description: 'Platform, build tools and command line tools for building Android apps.'),
  ComponentInfo(id: ComponentId.emulator, name: 'Android emulator', description: 'A virtual phone to run and test your apps on.'),
  ComponentInfo(id: ComponentId.vscode, name: 'Visual Studio Code', description: 'Lightweight editor with first class Flutter support.'),
  ComponentInfo(id: ComponentId.vscodeExtensions, name: 'VS Code Flutter extensions', description: 'Dart and Flutter extensions for VS Code.'),
  ComponentInfo(id: ComponentId.xcode, name: 'Xcode', description: 'Needed for iOS and macOS apps. Installed from the App Store.', required: false, autoInstallable: false, macOnly: true),
  ComponentInfo(id: ComponentId.cocoapods, name: 'CocoaPods', description: 'Dependency manager used by iOS and macOS builds.', required: false, macOnly: true),
  ComponentInfo(id: ComponentId.chrome, name: 'Google Chrome', description: 'Only needed for Flutter web development.', required: false, autoInstallable: false),
  ComponentInfo(id: ComponentId.visualStudio, name: 'Visual Studio (C++ workload)', description: 'Only needed for Windows desktop apps, not for mobile.', required: false, autoInstallable: false, windowsOnly: true),
  ComponentInfo(id: ComponentId.environment, name: 'Environment variables', description: 'PATH, JAVA_HOME and ANDROID_HOME so tools find each other.'),
  ComponentInfo(id: ComponentId.licenses, name: 'Android SDK licenses', description: 'Google requires the SDK licenses to be accepted once.'),
];

ComponentInfo componentInfo(ComponentId id) => kComponents.firstWhere((c) => c.id == id);

/// Result of looking for a component on this machine.
class DetectedComponent {
  const DetectedComponent({
    required this.id,
    required this.status,
    this.version,
    this.path,
    this.note,
  });

  final ComponentId id;
  final ComponentStatus status;
  final String? version;
  final String? path;

  /// Plain-language explanation shown to the user.
  final String? note;

  ComponentInfo get info => componentInfo(id);

  DetectedComponent copyWith({ComponentStatus? status, String? version, String? path, String? note}) =>
      DetectedComponent(id: id, status: status ?? this.status, version: version ?? this.version, path: path ?? this.path, note: note ?? this.note);
}
