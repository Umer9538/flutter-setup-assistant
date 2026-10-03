import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/component.dart';
import '../../state/setup_controller.dart';
import '../app_shell.dart';
import '../widgets/common.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final scan = ctrl.scan;
    final components = kComponents.where((i) => !(i.macOnly && !ctrl.platform!.isMac) && !(i.windowsOnly && !ctrl.platform!.isWindows)).toList();

    return ScreenBody(
      children: [
        ScreenHeader(
          title: ctrl.scanning ? 'Scanning your computer…' : 'Scan results',
          subtitle: ctrl.scanning ? ctrl.scanStatus : '${ctrl.readyCount} of ${components.length} components are ready. Nothing has been changed yet.',
          trailing: ctrl.scanning ? const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))) : null,
        ),
        const SizedBox(height: 24),
        if (ctrl.versions != null && ctrl.versions!.warnings.isNotEmpty) ...[
          InfoBanner(text: ctrl.versions!.warnings.join('\n'), icon: Icons.wifi_off_rounded, color: const Color(0xFFC77700)),
          const SizedBox(height: 16),
        ],
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < components.length; i++) ...[
                if (i > 0) const Divider(),
                _ComponentRow(info: components[i], detected: scan?[components[i].id], scanning: ctrl.scanning),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!ctrl.scanning && scan == null) InfoBanner(text: ctrl.scanStatus, icon: Icons.error_outline, color: c.error),
      ],
      footer: Row(
        children: [
          TextButton(onPressed: ctrl.scanning ? null : () => ctrl.goTo(Stage.welcome), child: const Text('Back')),
          const Spacer(),
          OutlinedButton.icon(onPressed: ctrl.scanning ? null : ctrl.startScan, icon: const Icon(Icons.refresh_rounded), label: const Text('Scan again')),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: ctrl.scanning || scan == null ? null : () => ctrl.goTo(Stage.plan),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Review plan'),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.info, required this.detected, required this.scanning});
  final ComponentInfo info;
  final DetectedComponent? detected;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final d = detected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: d == null
                ? (scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.help_outline, color: c.outline))
                : Icon(statusIcon(d.status), color: statusColor(context, d.status)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(info.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (!info.required) ...[const SizedBox(width: 8), StatusChip(label: 'Optional', color: c.outline)],
                  ],
                ),
                const SizedBox(height: 2),
                Text(d?.note ?? info.description, style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
                if (d?.path != null) Text(d!.path!, style: TextStyle(fontSize: 11, color: c.outline), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (d != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(label: d.status.label, color: statusColor(context, d.status)),
                if (d.version != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(d.version!, style: TextStyle(fontSize: 12, color: c.onSurfaceVariant))),
              ],
            ),
        ],
      ),
    );
  }
}
