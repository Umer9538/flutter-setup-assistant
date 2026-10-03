import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/doctor.dart';
import '../../state/setup_controller.dart';
import '../app_shell.dart';
import '../widgets/common.dart';

class DoctorScreen extends StatefulWidget {
  const DoctorScreen({super.key});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<SetupController>();
    if (ctrl.doctor == null && !ctrl.doctorRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.runDoctor());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SetupController>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final report = ctrl.doctor;
    final fixing = ctrl.fixingKey != null;

    final String subtitle;
    if (ctrl.doctorRunning) {
      subtitle = 'Running flutter doctor -v. This takes 10-60 seconds the first time.';
    } else if (fixing) {
      subtitle = 'Applying the fix. Diagnosis will run again automatically when it finishes.';
    } else if (report == null) {
      subtitle = ctrl.doctorError ?? 'Press "Run again" to start.';
    } else if (report.isHealthy) {
      subtitle = report.warningCount == 0 ? 'No issues found. Your Flutter environment is ready.' : 'No blocking issues. ${report.warningCount} optional item${report.warningCount == 1 ? '' : 's'} listed below.';
    } else {
      subtitle = '${report.errorCount} issue${report.errorCount == 1 ? '' : 's'} to fix. Each one is explained below with a one-click repair where possible.';
    }

    return ScreenBody(
      children: [
        ScreenHeader(
          title: 'Diagnosis',
          subtitle: subtitle,
          trailing: ctrl.doctorRunning || fixing ? const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))) : null,
        ),
        const SizedBox(height: 24),
        if (ctrl.doctorError != null) ...[
          InfoBanner(text: ctrl.doctorError!, icon: Icons.error_outline, color: c.error),
          const SizedBox(height: 16),
        ],
        if (fixing) ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in ctrl.fixSteps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        StepStateIcon(s.state, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${s.title}  ·  ${s.detail}', style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                AnimatedBuilder(animation: ctrl.log, builder: (_, __) => LogConsole(lines: ctrl.log.lines, height: 160)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (report != null) ...[
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in report.categories)
                  StatusChip(
                    label: cat.title,
                    icon: switch (cat.severity) {
                      DoctorSeverity.ok => Icons.check_rounded,
                      DoctorSeverity.warning => Icons.priority_high_rounded,
                      DoctorSeverity.error => Icons.close_rounded,
                      DoctorSeverity.info => Icons.info_outline,
                    },
                    color: switch (cat.severity) {
                      DoctorSeverity.ok => const Color(0xFF1B8A4C),
                      DoctorSeverity.warning => const Color(0xFFC77700),
                      DoctorSeverity.error => c.error,
                      DoctorSeverity.info => c.outline,
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (report.issues.isEmpty)
            const InfoBanner(text: 'flutter doctor is happy. Open a new terminal and run "flutter create my_app" to start building.', icon: Icons.celebration_rounded, color: Color(0xFF1B8A4C)),
          for (final issue in report.issues) _IssueCard(issue: issue, canFix: ctrl.canFix(issue) && !fixing && !ctrl.doctorRunning, onFix: () => ctrl.applyFix(issue)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showRaw = !_showRaw),
            icon: Icon(_showRaw ? Icons.expand_less : Icons.expand_more),
            label: Text(_showRaw ? 'Hide raw flutter doctor output' : 'Show raw flutter doctor output'),
          ),
          if (_showRaw) LogConsole(lines: report.raw.split('\n'), height: 300),
        ],
        if (report == null && ctrl.doctorRunning) ...[
          Text('Live output', style: t.titleSmall),
          const SizedBox(height: 8),
          AnimatedBuilder(animation: ctrl.log, builder: (_, __) => LogConsole(lines: ctrl.log.lines, height: 300)),
        ],
      ],
      footer: Row(
        children: [
          TextButton(onPressed: ctrl.doctorRunning || fixing ? null : () => ctrl.goTo(Stage.install), child: const Text('Back')),
          const Spacer(),
          OutlinedButton.icon(onPressed: ctrl.doctorRunning || fixing ? null : ctrl.runDoctor, icon: const Icon(Icons.refresh_rounded), label: const Text('Run again')),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: ctrl.doctorRunning || fixing || report == null ? null : () => ctrl.goTo(Stage.done),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue, required this.canFix, required this.onFix});
  final DoctorIssue issue;
  final bool canFix;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = switch (issue.severity) {
      DoctorSeverity.error => c.error,
      DoctorSeverity.warning => const Color(0xFFC77700),
      _ => c.outline,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(issue.severity == DoctorSeverity.error ? Icons.error_rounded : issue.severity == DoctorSeverity.warning ? Icons.warning_rounded : Icons.info_rounded, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                          StatusChip(label: issue.category, color: c.outline),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(issue.explanation),
                      if (issue.manualSteps.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (var i = 0; i < issue.manualSteps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}.  ', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
                                Expanded(child: Text(issue.manualSteps[i], style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Text(issue.rawMessage.split('\n').first, style: TextStyle(fontSize: 11.5, color: c.outline, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (issue.link != null)
                  TextButton.icon(onPressed: () => launchUrl(Uri.parse(issue.link!)), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('Open download page')),
                if (issue.autoFixable) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(onPressed: canFix ? onFix : null, icon: const Icon(Icons.auto_fix_high_rounded, size: 18), label: const Text('Fix automatically')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
