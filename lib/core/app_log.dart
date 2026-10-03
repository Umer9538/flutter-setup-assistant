import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// In-memory log that also mirrors to a file so users can share it when
/// something goes wrong.
class AppLog extends ChangeNotifier {
  AppLog._();
  static final AppLog instance = AppLog._();

  final List<String> lines = [];
  IOSink? _sink;
  String? filePath;

  Future<void> attachFile(String directory) async {
    try {
      await Directory(directory).create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      filePath = p.join(directory, 'setup-$stamp.log');
      _sink = File(filePath!).openWrite();
      for (final l in lines) {
        _sink!.writeln(l);
      }
    } catch (_) {
      // Logging must never break the setup flow.
    }
  }

  void add(String line) {
    final stamped = '${DateTime.now().toIso8601String().substring(11, 19)}  $line';
    lines.add(stamped);
    if (lines.length > 5000) lines.removeRange(0, 1000);
    _sink?.writeln(stamped);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }
}
