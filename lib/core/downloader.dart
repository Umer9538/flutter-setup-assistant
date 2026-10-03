import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class DownloadProgress {
  DownloadProgress(this.received, this.total);
  final int received;
  final int? total;
  double? get fraction => total == null || total == 0 ? null : received / total!;
}

class DownloadException implements Exception {
  DownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Streams files to a cache directory, verifies checksums and reuses files
/// that were already downloaded and verified.
class Downloader {
  Downloader({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> fetchText(String url, {Duration timeout = const Duration(seconds: 20)}) async {
    final r = await _client.get(Uri.parse(url), headers: {'User-Agent': 'flutter-setup-assistant'}).timeout(timeout);
    if (r.statusCode != 200) throw DownloadException('HTTP ${r.statusCode} from $url');
    return utf8.decode(r.bodyBytes);
  }

  Future<Map<String, dynamic>> fetchJson(String url) async => jsonDecode(await fetchText(url)) as Map<String, dynamic>;

  /// Downloads [url] into [cacheDir]. Returns the local file path.
  Future<String> download(
    String url, {
    required String cacheDir,
    String? fileName,
    String? sha256Hex,
    void Function(DownloadProgress p)? onProgress,
  }) async {
    await Directory(cacheDir).create(recursive: true);
    final name = fileName ?? _fileNameFromUrl(url);
    final target = File(p.join(cacheDir, name));
    final partial = File('${target.path}.part');

    if (await target.exists()) {
      if (sha256Hex == null || await _matches(target, sha256Hex)) return target.path;
      await target.delete();
    }

    final request = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = 'flutter-setup-assistant';
    final response = await _client.send(request).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw DownloadException('Download failed (HTTP ${response.statusCode}) for $url');
    }
    final total = response.contentLength;
    final sink = partial.openWrite();
    final digestSink = _DigestSink();
    final chunked = sha256.startChunkedConversion(digestSink);
    var received = 0;
    var lastReport = DateTime.now();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        chunked.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastReport).inMilliseconds > 150) {
          lastReport = now;
          onProgress?.call(DownloadProgress(received, total));
        }
      }
    } finally {
      await sink.close();
    }
    chunked.close();
    onProgress?.call(DownloadProgress(received, total));

    if (sha256Hex != null && digestSink.value.toString().toLowerCase() != sha256Hex.toLowerCase()) {
      await partial.delete();
      throw DownloadException('Checksum mismatch for $name. The download was corrupted; please retry.');
    }
    await partial.rename(target.path);
    return target.path;
  }

  Future<bool> _matches(File f, String sha256Hex) async {
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString().toLowerCase() == sha256Hex.toLowerCase();
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final last = uri.pathSegments.isEmpty ? 'download.bin' : uri.pathSegments.last;
    return Uri.decodeComponent(last);
  }

  void close() => _client.close();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
