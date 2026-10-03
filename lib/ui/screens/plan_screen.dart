import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/component.dart';
import '../../domain/plan.dart';
import '../../state/setup_controller.dart';
import '../app_shell.dart';
import '../widgets/common.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final v = ctrl.versions;
    final actions = ctrl.plan.where((p) => p.action.changesSystem).toList();
    final ready = ctrl.plan.where((p) => p.action == PlanAction.skip).toList();
    final manual = ctrl.plan.where((p) => p.action == PlanAction.manual).toList();

    return ScreenBody(
      children: [
        ScreenHeader(
          title: 'Here is the plan',
          subtitle: actions.isEmpty
              ? 'Everything required is already installed. You can go straight to diagnosis.'
              : '${ctrl.actionCount} step${ctrl.actionCount == 1 ? '' : 's'} will run. Untick anything you want to handle yourself.',
        ),
        const SizedBox(height: 24),
        if (v != null)
          SectionCard(
            color: c.primaryContainer.withValues(alpha: 0.35),
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _ver('Flutter', v.flutter.version, v.flutter.fromFallback),
                _ver('Java JDK', v.jdk.version, v.jdk.fromFallback),
                _ver('Android Studio', v.androidStudio.version, v.androidStudio.fromFallback),
                _ver('Android API', '${ctrl.catalog.androidApiLevel}', false),
                _ver('Command line tools', v.cmdlineTools.version, v.cmdlineTools.fromFallback),
                _ver('VS Code', v.vscode.version, v.vscode.fromFallback),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (actions.isNotEmpty) ...[
          Text('Will be installed or configured', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const Divider(),
                  _PlanRow(item: actions[i], onChanged: (val) => ctrl.togglePlanItem(actions[i], val)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (manual.isNotEmpty) ...[
          Text('Manual or optional', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < manual.length; i++) ...[
                  if (i > 0) const Divider(),
                  _PlanRow(item: manual[i], onChanged: null),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (ready.isNotEmpty) ...[
          Text('Already ready', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final r in ready) StatusChip(label: _readyLabel(r), color: const Color(0xFF1B8A4C), icon: Icons.check_rounded)],
            ),
          ),
          const SizedBox(height: 16),
        ],
        InfoBanner(
          text: 'Downloads go to ${ctrl.paths?.cache}. Large items (Flutter ~1 GB, Android Studio ~1.3 GB, system image ~1.5 GB) are resumed from cache if you need to retry.',
          icon: Icons.cloud_download_outlined,
        ),
      ],
      footer: Row(
        children: [
          TextButton(onPressed: () => ctrl.goTo(Stage.scan), child: const Text('Back')),
          const Spacer(),
          if (actions.isEmpty)
            FilledButton.icon(onPressed: ctrl.runDoctor, icon: const Icon(Icons.health_and_safety_rounded), label: const Text('Run diagnosis'))
          else
            FilledButton.icon(
              onPressed: ctrl.actionCount == 0 ? null : ctrl.startInstall,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start installation (${ctrl.actionCount})'),
            ),
        ],
      ),
    );
  }

  static String _readyLabel(PlanItem r) {
    final start = r.reason.indexOf('(');
    final end = r.reason.indexOf(')');
    final version = start >= 0 && end > start ? ' ${r.reason.substring(start, end + 1)}' : '';
    return '${componentInfo(r.id).name}$version';
  }

  Widget _ver(String name, String version, bool fallback) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Row(
            children: [
              Text(version, style: const TextStyle(fontSize: 14)),
              if (fallback) ...[const SizedBox(width: 4), const Tooltip(message: 'Offline: pinned known-good version', child: Icon(Icons.wifi_off_rounded, size: 13))],
            ],
          ),
        ],
      );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item, required this.onChanged});
  final PlanItem item;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final actionColor = switch (item.action) {
      PlanAction.install || PlanAction.installAlongside => c.primary,
      PlanAction.repair => const Color(0xFFC77700),
      PlanAction.configure => c.tertiary,
      PlanAction.manual => c.outline,
      PlanAction.skip => const Color(0xFF1B8A4C),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: item.selected,
            onChanged: onChanged == null || !item.canToggle ? null : (v) => onChanged!(v ?? false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.info.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    StatusChip(label: item.action.label, color: actionColor),
                    if (!item.info.required) ...[const SizedBox(width: 6), StatusChip(label: 'Optional', color: c.outline)],
                  ],
                ),
                const SizedBox(height: 3),
                Text(item.reason, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
