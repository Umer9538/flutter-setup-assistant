import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/setup_step.dart';
import '../../state/setup_controller.dart';
import '../app_shell.dart';
import '../widgets/common.dart';

class InstallScreen extends StatelessWidget {
  const InstallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final done = ctrl.steps.where((s) => s.isFinished).length;
    final total = ctrl.steps.length;
    final finished = !ctrl.installing && total > 0 && done == total;

    final String subtitle;
    if (ctrl.installing) {
      subtitle = 'Step ${done + 1} of $total. You can keep using your computer; this window will update as it goes.';
    } else if (finished && ctrl.failedSteps == 0) {
      subtitle = 'All $total steps completed. Next, run flutter doctor to confirm everything works.';
    } else if (finished) {
      subtitle = '${ctrl.failedSteps} step${ctrl.failedSteps == 1 ? '' : 's'} need attention. Expand them for details, or continue to diagnosis to repair.';
    } else {
      subtitle = 'Nothing to install.';
    }

    return ScreenBody(
      children: [
        ScreenHeader(title: ctrl.installing ? 'Installing…' : 'Installation', subtitle: subtitle),
        const SizedBox(height: 16),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8, backgroundColor: c.surfaceContainerHighest),
          ),
        const SizedBox(height: 20),
        for (final step in ctrl.steps) _StepCard(step: step),
        const SizedBox(height: 12),
        AnimatedBuilder(animation: ctrl.log, builder: (_, __) => LogConsole(lines: ctrl.log.lines)),
      ],
      footer: Row(
        children: [
          if (ctrl.installing)
            TextButton.icon(onPressed: ctrl.cancelInstall, icon: const Icon(Icons.stop_circle_outlined), label: const Text('Stop after current step'))
          else
            TextButton(onPressed: () => ctrl.goTo(Stage.plan), child: const Text('Back to plan')),
          const Spacer(),
          FilledButton.icon(
            onPressed: ctrl.installing ? null : ctrl.runDoctor,
            icon: const Icon(Icons.health_and_safety_rounded),
            label: const Text('Run flutter doctor'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});
  final SetupStep step;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final duration = step.startedAt == null ? null : (step.endedAt ?? DateTime.now()).difference(step.startedAt!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        color: step.isActive ? c.primaryContainer.withValues(alpha: 0.3) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StepStateIcon(step.state),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(step.isFinished || step.isActive ? step.detail : step.subtitle, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (duration != null && step.isFinished)
                  Text('${duration.inMinutes}m ${duration.inSeconds % 60}s', style: TextStyle(fontSize: 12, color: c.outline)),
              ],
            ),
            if (step.isActive) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: step.progress, minHeight: 6)),
            ],
            if (step.error != null) ...[
              const SizedBox(height: 10),
              InfoBanner(text: step.error!, icon: Icons.error_outline, color: step.state == SetupStepState.manual ? const Color(0xFFC77700) : c.error),
            ],
          ],
        ),
      ),
    );
  }
}
