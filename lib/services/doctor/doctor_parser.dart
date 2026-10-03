import '../../domain/doctor.dart';

/// Parses the text output of `flutter doctor -v` on macOS and Windows.
///
/// Category lines look like `[✓] Flutter (...)`, `[!] Android toolchain ...`
/// or `[✗] Xcode ...`. Windows uses `[√]`, `[!]` and `[X]`. Detail lines are
/// indented and start with `•`, `✗`, `!` or `X`.
class DoctorParser {
  static const _okMarks = {'✓', '√'};
  static const _warnMarks = {'!'};
  static const _errMarks = {'✗', 'X', 'x'};

  static List<DoctorCategory> parse(String output) {
    final categories = <DoctorCategory>[];
    DoctorCategory? current;
    for (final raw in output.split('\n')) {
      final line = raw.replaceAll('\r', '');
      final cat = RegExp(r'^\[(.)\]\s+(.+?)(?:\s+\[[\d,.]+ ?m?s\])?$').firstMatch(line);
      if (cat != null) {
        final mark = cat.group(1)!;
        final text = cat.group(2)!;
        final title = text.split(RegExp(r'\s+[-(]')).first.trim();
        if (title == 'Doctor found issues' || title.startsWith('No issues found')) continue;
        current = DoctorCategory(title: title, severity: _severity(mark), summary: text);
        categories.add(current);
        continue;
      }
      if (current == null) continue;
      final detail = RegExp(r'^\s+([•✗!Xx])\s+(.*)$').firstMatch(line);
      if (detail != null) {
        final mark = detail.group(1)!;
        final text = detail.group(2)!.trim();
        current.details.add(text);
        if (_errMarks.contains(mark) || _warnMarks.contains(mark)) current.problems.add(text);
        continue;
      }
      // Continuation lines belong to the most recent problem.
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && current.problems.isNotEmpty && line.startsWith('      ')) {
        current.problems[current.problems.length - 1] = '${current.problems.last}\n$trimmed';
      }
    }
    return categories;
  }

  static DoctorSeverity _severity(String mark) {
    if (_okMarks.contains(mark)) return DoctorSeverity.ok;
    if (_warnMarks.contains(mark)) return DoctorSeverity.warning;
    if (_errMarks.contains(mark)) return DoctorSeverity.error;
    return DoctorSeverity.info;
  }
}
