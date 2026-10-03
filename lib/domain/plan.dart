import 'component.dart';

enum PlanAction { skip, install, installAlongside, repair, configure, manual }

extension PlanActionX on PlanAction {
  String get label => switch (this) {
        PlanAction.skip => 'Already ready',
        PlanAction.install => 'Install',
        PlanAction.installAlongside => 'Install compatible version',
        PlanAction.repair => 'Repair',
        PlanAction.configure => 'Configure',
        PlanAction.manual => 'Manual step',
      };

  bool get changesSystem => this != PlanAction.skip && this != PlanAction.manual;
}

/// One line of the "what will happen" plan the user approves before anything
/// is written to disk.
class PlanItem {
  PlanItem({
    required this.id,
    required this.action,
    required this.reason,
    this.selected = true,
    this.targetVersion,
    this.canToggle = true,
  });

  final ComponentId id;
  final PlanAction action;
  final String reason;
  final String? targetVersion;
  bool selected;
  final bool canToggle;

  ComponentInfo get info => componentInfo(id);
  bool get willRun => selected && action.changesSystem;
}
