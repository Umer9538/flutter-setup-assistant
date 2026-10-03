import '../domain/component.dart';
import '../domain/plan.dart';
import '../domain/setup_step.dart';
import 'detection/environment_detector.dart';
import 'installers/android_installers.dart';
import 'installers/editor_installers.dart';
import 'installers/environment_installer.dart';
import 'installers/installer.dart';
import 'installers/toolchain_installers.dart';
import '../core/platform_info.dart';

/// Builds the plan from a scan and runs the selected steps in dependency order.
class SetupOrchestrator {
  SetupOrchestrator(this.platform);
  final PlatformInfo platform;

  static const _order = [
    ComponentId.git,
    ComponentId.flutter,
    ComponentId.jdk,
    ComponentId.androidStudio,
    ComponentId.androidSdk,
    ComponentId.emulator,
    ComponentId.vscode,
    ComponentId.vscodeExtensions,
    ComponentId.cocoapods,
    ComponentId.environment,
    ComponentId.licenses,
  ];

  static const _dependsOn = <ComponentId, List<ComponentId>>{
    ComponentId.flutter: [ComponentId.git],
    ComponentId.androidSdk: [ComponentId.jdk],
    ComponentId.emulator: [ComponentId.androidSdk],
    ComponentId.vscodeExtensions: [ComponentId.vscode],
    ComponentId.environment: [ComponentId.flutter],
    ComponentId.licenses: [ComponentId.flutter, ComponentId.androidSdk],
  };

  final Map<ComponentId, Installer> _installers = {
    for (final i in [
      GitInstaller(),
      FlutterInstaller(),
      JdkInstaller(),
      AndroidStudioInstaller(),
      AndroidSdkInstaller(),
      EmulatorInstaller(),
      VsCodeInstaller(),
      VsCodeExtensionsInstaller(),
      CocoaPodsInstaller(),
      EnvironmentInstaller(),
      LicensesInstaller(),
    ])
      i.id: i,
  };

  /// Turns scan results into the proposal the user reviews.
  List<PlanItem> buildPlan(EnvironmentScan scan) {
    final items = <PlanItem>[];
    for (final info in kComponents) {
      if (info.macOnly && !platform.isMac) continue;
      if (info.windowsOnly && !platform.isWindows) continue;
      final d = scan[info.id];
      final status = d?.status ?? ComponentStatus.unknown;
      items.add(_itemFor(info, status, d, scan));
    }
    return items;
  }

  PlanItem _itemFor(ComponentInfo info, ComponentStatus status, DetectedComponent? d, EnvironmentScan scan) {
    final version = d?.version == null ? '' : ' (${d!.version})';
    if (!info.autoInstallable) {
      if (status == ComponentStatus.installed) return PlanItem(id: info.id, action: PlanAction.skip, reason: 'Installed$version', canToggle: false);
      return PlanItem(id: info.id, action: PlanAction.manual, reason: d?.note ?? 'Optional. Flutter will tell you how to install it if you need it.', selected: false, canToggle: false);
    }
    switch (info.id) {
      case ComponentId.cocoapods:
        if (status == ComponentStatus.installed) return PlanItem(id: info.id, action: PlanAction.skip, reason: 'Installed$version', canToggle: false);
        final xcode = scan[ComponentId.xcode]?.status == ComponentStatus.installed;
        return PlanItem(id: info.id, action: PlanAction.install, reason: xcode ? 'Needed for iOS plugins. Installed with Homebrew.' : 'Only useful once Xcode is installed. Skipped for now.', selected: xcode);
      case ComponentId.environment:
        if (status == ComponentStatus.installed) return PlanItem(id: info.id, action: PlanAction.configure, reason: 'Re-check PATH, ANDROID_HOME and JAVA_HOME.', canToggle: true);
        return PlanItem(id: info.id, action: PlanAction.configure, reason: d?.note ?? 'Add Flutter and Android tools to PATH, set ANDROID_HOME and JAVA_HOME.', canToggle: false);
      case ComponentId.licenses:
        if (status == ComponentStatus.installed) return PlanItem(id: info.id, action: PlanAction.skip, reason: 'Already accepted', canToggle: false);
        return PlanItem(id: info.id, action: PlanAction.configure, reason: 'Accept the Android SDK licenses automatically.', canToggle: false);
      default:
        break;
    }
    switch (status) {
      case ComponentStatus.installed:
        return PlanItem(id: info.id, action: PlanAction.skip, reason: 'Installed$version${d?.path != null ? ' at ${d!.path}' : ''}', canToggle: false);
      case ComponentStatus.missing:
        return PlanItem(id: info.id, action: PlanAction.install, reason: d?.note ?? 'Not found on this computer.');
      case ComponentStatus.partial:
        return PlanItem(id: info.id, action: PlanAction.repair, reason: d?.note ?? 'Installed but incomplete.');
      case ComponentStatus.outdated:
        return PlanItem(id: info.id, action: PlanAction.install, reason: d?.note ?? 'Installed version is too old.');
      case ComponentStatus.incompatible:
        return PlanItem(id: info.id, action: PlanAction.installAlongside, reason: d?.note ?? 'Installed version is not compatible. Your existing copy is left untouched.');
      case ComponentStatus.unknown:
        return PlanItem(id: info.id, action: PlanAction.install, reason: d?.note ?? 'Could not be checked; it will be (re)installed to be safe.');
    }
  }

  /// Converts the approved plan to runnable steps in dependency order.
  List<SetupStep> buildSteps(List<PlanItem> plan) {
    final selected = {for (final p in plan.where((p) => p.willRun)) p.id: p};
    return [
      for (final id in _order)
        if (selected.containsKey(id))
          SetupStep(id: id, title: '${selected[id]!.action.label} ${componentInfo(id).name}', subtitle: selected[id]!.reason),
    ];
  }

  /// Runs steps sequentially. A step whose dependency failed is skipped with a
  /// clear reason instead of failing with a confusing error.
  Future<void> run(
    List<SetupStep> steps,
    InstallContext Function(SetupStep step) contextFor, {
    required void Function() onChange,
    bool Function()? isCancelled,
  }) async {
    final failed = <ComponentId>{};
    for (final step in steps) {
      if (isCancelled?.call() ?? false) {
        step.state = SetupStepState.skipped;
        step.detail = 'Cancelled';
        onChange();
        continue;
      }
      final blockedBy = (_dependsOn[step.id] ?? const []).where(failed.contains).toList();
      if (blockedBy.isNotEmpty) {
        step.state = SetupStepState.skipped;
        step.detail = 'Skipped because ${blockedBy.map((b) => componentInfo(b).name).join(' and ')} did not finish.';
        failed.add(step.id);
        onChange();
        continue;
      }
      step
        ..state = SetupStepState.running
        ..startedAt = DateTime.now();
      onChange();
      try {
        final ctx = contextFor(step);
        final installer = _installers[step.id];
        if (installer == null) throw InstallException('No installer for ${step.id.name}');
        await installer.install(ctx);
        step
          ..state = SetupStepState.done
          ..progress = 1
          ..detail = step.detail.isEmpty ? 'Done' : step.detail;
      } on InstallException catch (e) {
        step
          ..state = e.hint != null && e.message.contains('cannot be installed automatically') ? SetupStepState.manual : SetupStepState.failed
          ..error = e.toString()
          ..detail = e.message;
        failed.add(step.id);
      } catch (e) {
        step
          ..state = SetupStepState.failed
          ..error = e.toString()
          ..detail = 'Unexpected error';
        failed.add(step.id);
      }
      step.endedAt = DateTime.now();
      onChange();
    }
  }
}
