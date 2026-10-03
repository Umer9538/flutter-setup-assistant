import 'package:flutter_setup_assistant/domain/version.dart';
import 'package:flutter_setup_assistant/domain/version_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses versions from noisy strings', () {
    expect(Version.parse('git version 2.50.1 (Apple Git-155)'), const Version(2, 50, 1));
    expect(Version.parse('Xcode 27.0\nBuild version 27A266a'), const Version(27, 0, 0));
    expect(Version.parse('AndroidStudio2025.3.3'), const Version(2025, 3, 3));
    expect(Version.parse(null), isNull);
  });

  test('compares versions', () {
    expect(const Version(3, 24, 0) < const Version(3, 47, 6), isTrue);
    expect(const Version(2024, 1, 0) >= const Version(2024, 1, 0), isTrue);
  });

  test('catalog compatibility rules', () {
    const c = VersionCatalog();
    expect(c.jdkCompatibilityIssue(17), isNull);
    expect(c.jdkCompatibilityIssue(21), isNull);
    expect(c.jdkCompatibilityIssue(11), contains('too old'));
    expect(c.jdkCompatibilityIssue(25), contains('newer'));
    expect(c.flutterCompatibilityIssue(const Version(3, 10, 0)), isNotNull);
    expect(c.flutterCompatibilityIssue(const Version(3, 47, 6)), isNull);
  });
}
