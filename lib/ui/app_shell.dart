import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/setup_controller.dart';
import 'screens/doctor_screen.dart';
import 'screens/done_screen.dart';
import 'screens/install_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/welcome_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _stages = [
    (Stage.welcome, 'Welcome', Icons.waving_hand_rounded),
    (Stage.scan, 'Scan', Icons.search_rounded),
    (Stage.plan, 'Plan', Icons.checklist_rounded),
    (Stage.install, 'Install', Icons.download_rounded),
    (Stage.doctor, 'Diagnose', Icons.health_and_safety_rounded),
    (Stage.done, 'Finish', Icons.rocket_launch_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final currentIndex = _stages.indexWhere((s) => s.$1 == ctrl.stage);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: c.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.tertiary]), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.flutter_dash, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Flutter Setup\nAssistant', style: TextStyle(fontWeight: FontWeight.w700, height: 1.15))),
                  ],
                ),
                const SizedBox(height: 32),
                for (var i = 0; i < _stages.length; i++) _StageTile(index: i, label: _stages[i].$2, icon: _stages[i].$3, state: i < currentIndex ? 2 : i == currentIndex ? 1 : 0),
                const Spacer(),
                if (ctrl.platform != null)
                  Text('${ctrl.platform!.osLabel} · ${ctrl.platform!.archLabel}', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
                if (ctrl.log.filePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Log: ${ctrl.log.filePath}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: c.outline)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(ctrl.stage),
                child: switch (ctrl.stage) {
                  Stage.welcome => const WelcomeScreen(),
                  Stage.scan => const ScanScreen(),
                  Stage.plan => const PlanScreen(),
                  Stage.install => const InstallScreen(),
                  Stage.doctor => const DoctorScreen(),
                  Stage.done => const DoneScreen(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.index, required this.label, required this.icon, required this.state});
  final int index;
  final String label;
  final IconData icon;

  /// 0 upcoming, 1 current, 2 done
  final int state;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final active = state == 1;
    final done = state == 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: active ? c.primaryContainer : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? const Color(0xFF1B8A4C) : active ? c.primary : c.surfaceContainerHighest,
            ),
            child: Icon(done ? Icons.check_rounded : icon, size: 15, color: done || active ? Colors.white : c.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? c.onPrimaryContainer : c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Standard scrolling content column used by screens.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.children, this.footer});
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(40, 36, 40, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
        if (footer != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)))),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: footer),
          ),
      ],
    );
  }
}
