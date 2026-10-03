import 'component.dart';

enum SetupStepState { pending, running, done, failed, skipped, manual }

/// Live progress of one installation step shown in the installer UI.
class SetupStep {
  SetupStep({required this.id, required this.title, required this.subtitle});

  final ComponentId id;
  final String title;
  final String subtitle;

  SetupStepState state = SetupStepState.pending;

  /// 0..1, or null when indeterminate.
  double? progress;
  String detail = '';
  String? error;
  final List<String> log = [];
  DateTime? startedAt;
  DateTime? endedAt;

  bool get isActive => state == SetupStepState.running;
  bool get isFinished => state == SetupStepState.done || state == SetupStepState.failed || state == SetupStepState.skipped || state == SetupStepState.manual;
}
