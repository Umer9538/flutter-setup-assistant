import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/downloader.dart';
import '../core/extractor.dart';
import '../core/install_paths.dart';
import '../core/platform_info.dart';
import '../core/process_runner.dart';
import '../core/shell_env.dart';
import '../domain/component.dart';
import '../domain/doctor.dart';
import '../domain/plan.dart';
import '../domain/setup_step.dart';
import '../domain/version_catalog.dart';
import '../services/detection/environment_detector.dart';
import '../services/doctor/doctor_runner.dart';
import '../services/installers/environment_installer.dart';
import '../services/installers/installer.dart';
import '../services/release_resolver.dart';
import '../services/setup_orchestrator.dart';

enum Stage { welcome, scan, plan, install, doctor, done }

/// Single source of truth for the UI. Owns services and drives the flow.
class SetupController extends ChangeNotifier {
  SetupController() {
    runner = ProcessRunner(onCommand: log.add);
    downloader = Downloader();
    extractor = Extractor(runner);
  }

  final AppLog log = AppLog.instance;
  late final ProcessRunner runner;
  late final Downloader downloader;
  late final Extractor extractor;
  final VersionCatalog catalog = const VersionCatalog();

  PlatformInfo? platform;
  InstallPaths? paths;
  ShellEnvironment? shellEnv;
  SetupOrchestrator? orchestrator;

  Stage stage = Stage.welcome;
  String? fatalError;

  // Scan
  bool scanning = false;
  String scanStatus = '';
  EnvironmentScan? scan;
  ResolvedVersions? versions;

  // Plan
  List<PlanItem> plan = [];

  // Install
  List<SetupStep> steps = [];
  bool installing = false;
  bool _cancelRequested = false;
  InstallContext? _ctx;
  final _StepReporter _reporter = _StepReporter();

  // Doctor
  DoctorReport? doctor;
  bool doctorRunning = false;
  String? doctorError;
  String? fixingKey;
  List<SetupStep> fixSteps = [];

  Future<void> init() async {
    try {
      platform = await PlatformInfo.detect(runner);
      paths = InstallPaths.defaults(platform!);
      await log.attachFile(paths!.logsDir);
      _rebuildServices();
      log.add('Flutter Environment Setup Assistant started on ${platform!.osLabel} ${platform!.osVersion} (${platform!.archLabel})');
    } catch (e) {
      fatalError = 'Could not inspect this computer: $e';
    }
    notifyListeners();
  }

  void _rebuildServices() {
    shellEnv = ShellEnvironment(platform: platform!, runner: runner, backupDir: paths!.backupsDir);
    orchestrator = SetupOrchestrator(platform!);
  }

  bool get isSupported => platform != null && (platform!.isMac || platform!.isWindows);

  void setInstallRoot(String root) {
    if (platform == null || root.trim().isEmpty) return;
    paths = paths!.withRoot(root.trim());
    _rebuildServices();
    notifyListeners();
  }

  void goTo(Stage s) {
    stage = s;
    notifyListeners();
  }

  // ---- Scan ----------------------------------------------------------------

  Future<void> startScan() async {
    if (scanning || platform == null) return;
    scanning = true;
    scan = null;
    stage = Stage.scan;
    scanStatus = 'Looking for installed tools…';
    notifyListeners();

    final detector = EnvironmentDetector(platform: platform!, paths: paths!, runner: runner, catalog: catalog);
    final resolver = ReleaseResolver(platform: platform!, catalog: catalog, downloader: downloader);
    try {
      final results = await Future.wait([
        detector.scan(log: (m) {
          scanStatus = m;
          log.add(m);
          notifyListeners();
        }),
        resolver.resolve(log: log.add),
      ]);
      scan = results[0] as EnvironmentScan;
      versions = results[1] as ResolvedVersions;
      for (final w in versions!.warnings) {
        log.add('Warning: $w');
      }
      plan = orchestrator!.buildPlan(scan!);
      scanStatus = 'Scan complete';
    } catch (e) {
      scanStatus = 'Scan failed: $e';
      log.add(scanStatus);
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  int get readyCount => scan?.components.values.where((c) => c.status == ComponentStatus.installed).length ?? 0;
  int get actionCount => plan.where((p) => p.willRun).length;

  void togglePlanItem(PlanItem item, bool value) {
    if (!item.canToggle) return;
    item.selected = value;
    notifyListeners();
  }

  // ---- Install -------------------------------------------------------------

  InstallContext _newContext() => InstallContext(
        platform: platform!,
        paths: paths!,
        catalog: catalog,
        versions: versions!,
        runner: runner,
        downloader: downloader,
        extractor: extractor,
        shellEnv: shellEnv!,
        scan: scan!,
        report: _reporter,
      );

  Future<void> startInstall() async {
    if (installing || scan == null || versions == null) return;
    steps = orchestrator!.buildSteps(plan);
    stage = Stage.install;
    if (steps.isEmpty) {
      notifyListeners();
      return;
    }
    installing = true;
    _cancelRequested = false;
    _ctx = _newContext();
    _reporter.onChange = notifyListeners;
    _reporter.logSink = log.add;
    notifyListeners();
    await Directory(paths!.cache).create(recursive: true);
    await orchestrator!.run(
      steps,
      (step) {
        _reporter.step = step;
        return _ctx!;
      },
      onChange: notifyListeners,
      isCancelled: () => _cancelRequested,
    );
    installing = false;
    notifyListeners();
  }

  void cancelInstall() {
    _cancelRequested = true;
    notifyListeners();
  }

  bool get installSucceeded => steps.isNotEmpty && steps.every((s) => s.state == SetupStepState.done);
  int get failedSteps => steps.where((s) => s.state == SetupStepState.failed || s.state == SetupStepState.manual).length;

  // ---- Doctor --------------------------------------------------------------

  String? get flutterBin {
    final fromCtx = _ctx?.flutterSdk;
    if (fromCtx != null) return _ctx!.flutterBin;
    final scanned = scan?[ComponentId.flutter];
    if (scanned?.path != null) {
      return p.join(scanned!.path!, 'bin', platform!.isWindows ? 'flutter.bat' : 'flutter');
    }
    return File(paths!.flutterBin).existsSync() ? paths!.flutterBin : null;
  }

  Future<void> runDoctor() async {
    if (doctorRunning || platform == null) return;
    stage = Stage.doctor;
    doctorRunning = true;
    doctorError = null;
    notifyListeners();
    try {
      _ctx ??= versions != null && scan != null ? _newContext() : null;
      final bin = flutterBin;
      if (bin == null) throw Exception('Flutter is not installed yet. Go back and run the installation first.');
      final env = _ctx?.childEnv;
      doctor = await DoctorRunner(platform: platform!, runner: runner).run(bin, environment: env, onLine: log.add);
      log.add('flutter doctor finished: ${doctor!.errorCount} errors, ${doctor!.warningCount} warnings');
    } catch (e) {
      doctorError = e.toString();
    } finally {
      doctorRunning = false;
      notifyListeners();
    }
  }

  static const _fixMap = <String, List<ComponentId>>{
    'android.cmdline-tools': [ComponentId.androidSdk, ComponentId.environment, ComponentId.licenses],
    'android.sdk': [ComponentId.androidSdk, ComponentId.environment, ComponentId.licenses],
    'android.generic': [ComponentId.androidSdk, ComponentId.environment, ComponentId.licenses],
    'android.sdk.update': [ComponentId.androidSdk, ComponentId.licenses],
    'android.licenses': [ComponentId.licenses],
    'android.studio': [ComponentId.androidStudio],
    'java.missing': [ComponentId.jdk, ComponentId.environment],
    'cocoapods': [ComponentId.cocoapods],
    'git': [ComponentId.git],
  };

  bool canFix(DoctorIssue issue) => issue.autoFixable && _fixMap.containsKey(issue.key);

  Future<void> applyFix(DoctorIssue issue) async {
    if (fixingKey != null || scan == null || versions == null) return;
    final ids = _fixMap[issue.key];
    if (ids == null) return;
    fixingKey = issue.key;
    _ctx ??= _newContext();
    if (_ctx!.jdkHome == null && !ids.contains(ComponentId.jdk) && (ids.contains(ComponentId.androidSdk) || ids.contains(ComponentId.licenses))) {
      ids.insert(0, ComponentId.jdk);
    }
    fixSteps = [
      for (final id in ids.toSet())
        SetupStep(id: id, title: '${id == ComponentId.environment || id == ComponentId.licenses ? 'Configure' : 'Repair'} ${componentInfo(id).name}', subtitle: 'Fix for: ${issue.title}'),
    ];
    _reporter.onChange = notifyListeners;
    _reporter.logSink = log.add;
    _cancelRequested = false;
    notifyListeners();
    await orchestrator!.run(fixSteps, (step) {
      _reporter.step = step;
      return _ctx!;
    }, onChange: notifyListeners);
    fixingKey = null;
    notifyListeners();
    await runDoctor();
  }

  // ---- Done ----------------------------------------------------------------

  String get environmentSummary {
    if (_ctx == null || shellEnv == null) return '';
    return shellEnv!.describe(EnvironmentInstaller.buildSpec(_ctx!));
  }

  void restart() {
    stage = Stage.welcome;
    scan = null;
    plan = [];
    steps = [];
    doctor = null;
    _ctx = null;
    notifyListeners();
  }

  @override
  void dispose() {
    downloader.close();
    super.dispose();
  }
}

class _StepReporter implements StepReporter {
  SetupStep? step;
  VoidCallback? onChange;
  void Function(String)? logSink;

  @override
  void log(String line) {
    step?.log.add(line);
    if (step != null && step!.log.length > 400) step!.log.removeRange(0, 100);
    logSink?.call(line);
    onChange?.call();
  }

  @override
  void progress(double? fraction, [String? detail]) {
    step?.progress = fraction;
    if (detail != null) step?.detail = detail;
    onChange?.call();
  }

  @override
  void detail(String text) {
    step?.detail = text;
    onChange?.call();
  }
}
