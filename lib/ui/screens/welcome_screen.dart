import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/setup_controller.dart';
import '../app_shell.dart';
import '../widgets/common.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TextEditingController _root;

  @override
  void initState() {
    super.initState();
    _root = TextEditingController(text: context.read<SetupController>().paths?.root ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    if (_root.text.isEmpty && ctrl.paths != null) _root.text = ctrl.paths!.root;

    return ScreenBody(
      children: [
        const ScreenHeader(
          title: 'Set up Flutter in one click',
          subtitle: 'From a fresh computer to a ready-to-code Flutter environment. No tutorials, no manual PATH edits.',
        ),
        const SizedBox(height: 28),
        if (ctrl.fatalError != null) InfoBanner(text: ctrl.fatalError!, icon: Icons.error_outline, color: c.error),
        if (ctrl.platform != null && !ctrl.isSupported)
          InfoBanner(text: 'This assistant supports macOS and Windows. ${ctrl.platform!.osLabel} is not supported yet.', icon: Icons.error_outline, color: c.error),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What the assistant does', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    for (final item in const [
                      (Icons.search_rounded, 'Scans your computer for Flutter, Git, Java, Android Studio, the Android SDK, emulators and editors.'),
                      (Icons.rule_rounded, 'Picks versions that are known to work together and shows you the plan before changing anything.'),
                      (Icons.download_rounded, 'Downloads official builds, verifies checksums and installs into your user folder. No administrator password.'),
                      (Icons.settings_suggest_rounded, 'Configures PATH, JAVA_HOME and ANDROID_HOME, accepts licenses and creates a virtual device.'),
                      (Icons.healing_rounded, 'Runs flutter doctor, explains every issue in plain language and repairs it for you.'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$1, size: 18, color: c.primary),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item.$2)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 260,
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This computer', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _kv('System', ctrl.platform == null ? '…' : '${ctrl.platform!.osLabel} ${ctrl.platform!.osVersion.split(' ').take(2).join(' ')}'),
                    _kv('Processor', ctrl.platform?.archLabel == 'arm64' ? 'ARM (Apple Silicon / ARM64)' : 'x64 (Intel / AMD)'),
                    _kv('Home folder', ctrl.platform?.home ?? '…'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where to install SDKs', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Flutter and the JDK go here. The Android SDK uses the standard location so Android Studio finds it. Avoid paths with spaces.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: _root,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.folder_outlined), hintText: '~/development'),
                onChanged: ctrl.setInstallRoot,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const InfoBanner(
          text: 'Safe by design: existing tools are never deleted. Incompatible versions are left alone and a compatible copy is installed next to them. Shell profiles are backed up before they are edited.',
          icon: Icons.shield_outlined,
        ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: ctrl.isSupported && !ctrl.scanning ? ctrl.startScan : null,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Scan my computer'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            Text(v, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );

  @override
  void dispose() {
    _root.dispose();
    super.dispose();
  }
}
