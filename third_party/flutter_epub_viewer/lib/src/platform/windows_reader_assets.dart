import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';

/// Serves only bundled reader assets to WebView2 on a loopback, ephemeral port.
/// A per-process token prevents ordinary local pages from guessing asset URLs.
class WindowsReaderAssets {
  WindowsReaderAssets._(this.server, this.token);
  final HttpServer server;
  final String token;
  Uri get reader =>
      Uri.parse('http://127.0.0.1:${server.port}/$token/html/swipe.html');

  static Future<WindowsReaderAssets> start() async {
    final random = Random.secure();
    final token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.defaultResponseHeaders.clear();
    final result = WindowsReaderAssets._(server, token);
    server.listen(result._handle);
    return result;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final segments = request.uri.pathSegments;
      if ((request.method != 'GET' && request.method != 'HEAD') ||
          segments.length < 3 ||
          segments.first != token ||
          !['html', 'bundle'].contains(segments[1]) ||
          segments
              .skip(1)
              .any(
                (part) =>
                    !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(part) ||
                    part == '.' ||
                    part == '..',
              )) {
        response.statusCode = HttpStatus.notFound;
      } else {
        final path =
            'packages/flutter_epub_viewer/lib/assets/webpage/${segments.skip(1).join('/')}';
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        response.headers.contentType = _contentType(segments.last);
        response.headers.set('X-Content-Type-Options', 'nosniff');
        response.contentLength = bytes.length;
        if (request.method == 'GET') response.add(bytes);
      }
    } catch (_) {
      response.statusCode = HttpStatus.notFound;
    } finally {
      await response.close();
    }
  }

  static ContentType _contentType(String file) {
    if (file.endsWith('.html')) return ContentType.html;
    if (file.endsWith('.css'))
      return ContentType('text', 'css', charset: 'utf-8');
    if (file.endsWith('.js'))
      return ContentType('text', 'javascript', charset: 'utf-8');
    return ContentType.binary;
  }

  Future<void> close() => server.close(force: true);
}
