import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:epinal_reader/book_export.dart';
import 'package:epinal_reader/update.dart';
import 'package:flutter_epub_viewer/src/platform/windows_reader_assets.dart';
import 'package:flutter_test/flutter_test.dart';

class LocalHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('mise à jour Windows choisit le setup et compare la version exécutable', () {
    final release = {
      'tag_name': 'v1.0.21',
      'assets': [
        {
          'name': 'Epinal.apk',
          'browser_download_url':
              'https://github.com/elfred434/Epinal-reader-/releases/download/v1.0.21/Epinal.apk',
          'digest': 'sha256:${'a' * 64}',
        },
        {
          'name': 'Epinal-Setup-x64.exe',
          'browser_download_url':
              'https://github.com/elfred434/Epinal-reader-/releases/download/v1.0.21/Epinal-Setup-x64.exe',
          'digest': 'sha256:${'b' * 64}',
        },
      ],
    };
    expect(Updater.installedBuild('1.0.19', '', windows: true), 19);
    expect(Updater.installedBuild('1.0.19.19', '', windows: true), 19);
    expect(Updater.installedBuild('1.0.19', '19', windows: false), 19);
    final windows = Updater.parseRelease(
      release,
      installedBuild: 19,
      windows: true,
    )!;
    expect(windows.asset.path, endsWith('Epinal-Setup-x64.exe'));
    expect(windows.digest, 'b' * 64);
    expect(
      Updater.parseRelease(release, installedBuild: 21, windows: true),
      isNull,
    );
    expect(
      Updater.parseRelease(
        release,
        installedBuild: 19,
        windows: false,
      )!.asset.path,
      endsWith('Epinal.apk'),
    );
    expect(exportFileName('CON.epub'), 'Livre CON.epub');
  });
  test('canal Windows indépendant, Android et préversions ignorés', () async {
    Map<String, dynamic> release(String tag, {bool prerelease = false}) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': prerelease,
      'assets': [
        {
          'name': 'Epinal-Setup-x64.exe',
          'browser_download_url':
              'https://github.com/elfred434/Epinal-reader-/releases/download/$tag/Epinal-Setup-x64.exe',
          'digest': 'sha256:${'a' * 64}',
        },
      ],
    };
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.queryParameters['page'], '$requests');
      if (requests == 1) {
        // A full first page ensures pagination is exercised.
        return http.Response(
          jsonEncode([
            release('v1.0.900'),
            release('windows-v1.0.99', prerelease: true),
            release('windows-v1.0.29'),
            ...List.generate(97, (_) => {'tag_name': 'unrelated'}),
          ]),
          200,
        );
      }
      return http.Response(jsonEncode([release('windows-v1.0.30')]), 200);
    });
    try {
      final update = await Updater.checkWindowsReleases(
        client,
        installedBuild: 27,
      );
      expect(update!.version, 'windows-v1.0.30');
      expect(update.build, 30);
      expect(requests, 2);
      expect(update.asset.path, contains('/windows-v1.0.30/'));
    } finally {
      client.close();
    }
    final empty = MockClient(
      (_) async => http.Response(
        jsonEncode([
          release('v1.0.100'),
          release('windows-v1.0.30', prerelease: true),
        ]),
        200,
      ),
    );
    try {
      expect(
        await Updater.checkWindowsReleases(empty, installedBuild: 27),
        isNull,
      );
    } finally {
      empty.close();
    }
  });
  test(
    'serveur local livre uniquement les ressources attendues',
    () async => HttpOverrides.runWithHttpOverrides(() async {
      final server = await WindowsReaderAssets.start();
      final client = HttpClient();
      try {
        final request = await client.getUrl(server.reader);
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.contentType!.mimeType, 'text/html');
        final page = await response
            .transform(const SystemEncoding().decoder)
            .join();
        expect(page, contains('epubView.js'));
        final bad = await client.getUrl(
          server.reader.replace(path: '/incorrect/html/swipe.html'),
        );
        expect((await bad.close()).statusCode, HttpStatus.notFound);
        final missing = await client.getUrl(
          server.reader.resolve('../html/not-found.js'),
        );
        expect((await missing.close()).statusCode, HttpStatus.notFound);
      } finally {
        client.close(force: true);
        await server.close();
      }
    }, LocalHttpOverrides()),
  );
}
