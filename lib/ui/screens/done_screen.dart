import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/setup_controller.dart';
import '../app_shell.dart';
import '../widgets/common.dart';

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final healthy = ctrl.doctor?.isHealthy ?? false;
    final emulator = ctrl.catalog.emulatorName;
    final isWin = ctrl.platform?.isWindows ?? false;

    return ScreenBody(
      children: [
        ScreenHeader(
          title: healthy ? 'You are ready to build' : 'Setup finished with notes',
          subtitle: healthy
              ? 'Flutter, Android tooling and your editor are installed and configured.'
              : 'Some items still need attention. Go back to Diagnosis any time to repair them.',
        ),
        const SizedBox(height: 24),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next steps', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _step(context, 1, isWin ? 'Open a new PowerShell or Terminal window so the new PATH takes effect.' : 'Open a new Terminal window so the new PATH takes effect.'),
              _step(context, 2, 'Create your first app:', code: 'flutter create my_app\ncd my_app'),
              _step(context, 3, 'Start the virtual device, then run the app:', code: 'flutter emulators --launch $emulator\nflutter run'),
              _step(context, 4, 'Or open the folder in VS Code and press F5.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (ctrl.environmentSummary.isNotEmpty)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Environment that was configured', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: ctrl.environmentSummary));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(10)),
                  child: Text(ctrl.environmentSummary, style: const TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Consolas', 'monospace'], fontSize: 12)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (ctrl.log.filePath != null)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.file(File(ctrl.log.filePath!).parent.path)),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Open log folder'),
              ),
            OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('https://docs.flutter.dev/get-started/codelab')), icon: const Icon(Icons.school_outlined), label: const Text('First app codelab')),
            OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('https://docs.flutter.dev')), icon: const Icon(Icons.menu_book_outlined), label: const Text('Flutter docs')),
          ],
        ),
      ],
      footer: Row(
        children: [
          TextButton(onPressed: () => ctrl.goTo(Stage.doctor), child: const Text('Back to diagnosis')),
          const Spacer(),
          FilledButton.icon(onPressed: ctrl.restart, icon: const Icon(Icons.replay_rounded), label: const Text('Start over')),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, int n, String text, {String? code}) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (code != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(child: Text(code, style: const TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Consolas', 'monospace'], fontSize: 12.5))),
                        IconButton(iconSize: 16, icon: const Icon(Icons.copy_rounded), onPressed: () => Clipboard.setData(ClipboardData(text: code))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
