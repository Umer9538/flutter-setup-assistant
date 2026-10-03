enum DoctorSeverity { ok, warning, error, info }

/// One category line from `flutter doctor -v` plus its detail lines.
class DoctorCategory {
  DoctorCategory({required this.title, required this.severity, required this.summary});
  final String title;
  final DoctorSeverity severity;
  final String summary;
  final List<String> details = [];
  final List<String> problems = [];
}

/// A problem the assistant understands, with a plain-language fix.
class DoctorIssue {
  DoctorIssue({
    required this.key,
    required this.category,
    required this.title,
    required this.explanation,
    required this.rawMessage,
    this.severity = DoctorSeverity.error,
    this.autoFixable = false,
    this.manualSteps = const [],
    this.link,
  });

  final String key;
  final String category;
  final String title;
  final String explanation;
  final String rawMessage;
  final DoctorSeverity severity;
  final bool autoFixable;
  final List<String> manualSteps;
  final String? link;
}

class DoctorReport {
  DoctorReport({required this.categories, required this.issues, required this.raw, required this.ranAt});
  final List<DoctorCategory> categories;
  final List<DoctorIssue> issues;
  final String raw;
  final DateTime ranAt;

  bool get isHealthy => issues.where((i) => i.severity == DoctorSeverity.error).isEmpty;
  int get errorCount => issues.where((i) => i.severity == DoctorSeverity.error).length;
  int get warningCount => issues.where((i) => i.severity == DoctorSeverity.warning).length;
}
