import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/component.dart';
import '../../domain/setup_step.dart';

/// Page header used by every screen.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle, style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(color: color, child: Padding(padding: padding, child: child));
}

Color statusColor(BuildContext context, ComponentStatus s) {
  final c = Theme.of(context).colorScheme;
  return switch (s) {
    ComponentStatus.installed => const Color(0xFF1B8A4C),
    ComponentStatus.missing => c.error,
    ComponentStatus.outdated || ComponentStatus.partial => const Color(0xFFC77700),
    ComponentStatus.incompatible => c.error,
    ComponentStatus.unknown => c.outline,
  };
}

IconData statusIcon(ComponentStatus s) => switch (s) {
      ComponentStatus.installed => Icons.check_circle_rounded,
      ComponentStatus.missing => Icons.cancel_rounded,
      ComponentStatus.outdated || ComponentStatus.partial => Icons.error_rounded,
      ComponentStatus.incompatible => Icons.warning_rounded,
      ComponentStatus.unknown => Icons.help_rounded,
    };

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class StepStateIcon extends StatelessWidget {
  const StepStateIcon(this.state, {super.key, this.size = 22});
  final SetupStepState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return switch (state) {
      SetupStepState.pending => Icon(Icons.radio_button_unchecked, size: size, color: c.outline),
      SetupStepState.running => SizedBox(width: size, height: size, child: const CircularProgressIndicator(strokeWidth: 2.5)),
      SetupStepState.done => Icon(Icons.check_circle_rounded, size: size, color: const Color(0xFF1B8A4C)),
      SetupStepState.failed => Icon(Icons.error_rounded, size: size, color: c.error),
      SetupStepState.skipped => Icon(Icons.remove_circle_outline_rounded, size: size, color: c.outline),
      SetupStepState.manual => Icon(Icons.pan_tool_alt_rounded, size: size, color: const Color(0xFFC77700)),
    };
  }
}

/// Scrollable monospace log that sticks to the bottom.
class LogConsole extends StatefulWidget {
  const LogConsole({super.key, required this.lines, this.height = 220});
  final List<String> lines;
  final double height;

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(color: c.inverseSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 16, color: c.onInverseSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text('Activity log', style: TextStyle(color: c.onInverseSurface.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy log',
                  iconSize: 16,
                  color: c.onInverseSurface.withValues(alpha: 0.7),
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.lines.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log copied to clipboard')));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              itemCount: widget.lines.length,
              itemBuilder: (_, i) => Text(
                widget.lines[i],
                style: TextStyle(fontFamily: 'Menlo', fontFamilyFallback: const ['Consolas', 'monospace'], fontSize: 11.5, color: c.onInverseSurface, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.color});
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
