import '../../core/platform_info.dart';
import '../../core/process_runner.dart';
import '../../domain/doctor.dart';
import 'doctor_parser.dart';
import 'fix_catalog.dart';

class DoctorRunner {
  DoctorRunner({required this.platform, required this.runner});
  final PlatformInfo platform;
  final ProcessRunner runner;

  Future<DoctorReport> run(String flutterBin, {Map<String, String>? environment, void Function(String)? onLine}) async {
    final r = await runner.run(
      flutterBin,
      ['doctor', '-v', '--no-version-check'],
      environment: environment,
      onLine: onLine,
      timeout: const Duration(minutes: 10),
    );
    final raw = r.combined;
    if (r.exitCode == 127) {
      throw Exception('Could not start Flutter at $flutterBin: ${r.stderr}');
    }
    final categories = DoctorParser.parse(raw);
    final issues = FixCatalog(platform).explain(categories);
    return DoctorReport(categories: categories, issues: issues, raw: raw, ranAt: DateTime.now());
  }
}
