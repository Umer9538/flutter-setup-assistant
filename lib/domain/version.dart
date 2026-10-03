/// Minimal semantic version used for compatibility checks.
class Version implements Comparable<Version> {
  const Version(this.major, [this.minor = 0, this.patch = 0]);

  final int major;
  final int minor;
  final int patch;

  /// Parses the first `x.y.z`, `x.y` or `x` found in [text]. Returns null when absent.
  static Version? parse(String? text) {
    if (text == null) return null;
    final m = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(text);
    if (m == null) return null;
    return Version(int.parse(m.group(1)!), int.tryParse(m.group(2) ?? '') ?? 0, int.tryParse(m.group(3) ?? '') ?? 0);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(Version o) => compareTo(o) < 0;
  bool operator >(Version o) => compareTo(o) > 0;
  bool operator >=(Version o) => compareTo(o) >= 0;
  bool operator <=(Version o) => compareTo(o) <= 0;

  @override
  bool operator ==(Object other) => other is Version && compareTo(other) == 0;
  @override
  int get hashCode => Object.hash(major, minor, patch);
  @override
  String toString() => '$major.$minor.$patch';
}
