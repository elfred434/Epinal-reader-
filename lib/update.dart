import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdate {
  final int build;
  final String version;
  final Uri asset;
  final String digest;
  AppUpdate(this.build, this.version, this.asset, this.digest);
}

class Updater {
  static const api =
      'https://api.github.com/repos/elfred434/Epinal-reader-/releases/latest';
  static const windowsApi =
      'https://api.github.com/repos/elfred434/Epinal-reader-/releases';
  static const native = MethodChannel('com.epinal.reader/native');
  static Future<AppUpdate?> check() async {
    final info = await PackageInfo.fromPlatform();
    final installed = installedBuild(
      info.version,
      info.buildNumber,
      windows: Platform.isWindows,
    );
    if (Platform.isWindows) {
      final client = http.Client();
      try {
        return await checkWindowsReleases(client, installedBuild: installed);
      } finally {
        client.close();
      }
    }
    // Android retains its existing stable `latest` release channel.
    final r = await http
        .get(Uri.parse(api), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw Exception('GitHub indisponible (${r.statusCode}).');
    }
    return parseRelease(
      jsonDecode(r.body) as Map<String, dynamic>,
      installedBuild: installed,
      windows: false,
    );
  }

  /// Windows has independent releases and never changes Android's latest tag.
  /// Scan bounded pages rather than assuming the latest GitHub release is
  /// Windows; malformed matching releases fail closed instead of being ignored.
  static Future<AppUpdate?> checkWindowsReleases(
    http.Client client, {
    required int installedBuild,
  }) async {
    Map<String, dynamic>? best;
    var bestBuild = installedBuild;
    for (var page = 1; page <= 10; page++) {
      final response = await client
          .get(
            Uri.parse('$windowsApi?per_page=100&page=$page'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw Exception('GitHub indisponible (${response.statusCode}).');
      }
      final items = jsonDecode(response.body) as List;
      for (final item in items) {
        if (item is! Map<String, dynamic> ||
            item['draft'] == true ||
            item['prerelease'] == true)
          continue;
        final tag = item['tag_name'];
        if (tag is! String) continue;
        final match = RegExp(r'^windows-v1\.0\.(\d+)$').firstMatch(tag);
        if (match == null) continue;
        final build = int.tryParse(match.group(1)!);
        if (build != null && build > bestBuild) {
          best = item;
          bestBuild = build;
        }
      }
      if (items.length < 100) break;
    }
    return best == null
        ? null
        : parseRelease(best, installedBuild: installedBuild, windows: true);
  }

  /// Windows VERSIONINFO contains a dotted product version without +build.
  static int installedBuild(
    String version,
    String buildNumber, {
    required bool windows,
  }) {
    if (!windows) return int.tryParse(buildNumber) ?? 0;
    final match = RegExp(r'^1\.0\.(\d+)(?:\.\d+)?$').firstMatch(version);
    return match == null
        ? (int.tryParse(buildNumber) ?? 0)
        : int.parse(match.group(1)!);
  }

  static AppUpdate? parseRelease(
    Map<String, dynamic> j, {
    required int installedBuild,
    required bool windows,
  }) {
    final version = j['tag_name'] as String? ?? '';
    final match =
        (windows
                ? RegExp(r'^(?:windows-)?v1\.0\.(\d+)$')
                : RegExp(r'^v1\.0\.(\d+)$'))
            .firstMatch(version);
    if (match == null) throw Exception('Version GitHub non reconnue.');
    final build = int.parse(match.group(1)!);
    if (build <= installedBuild) return null;
    final assets = j['assets'] as List;
    final fileName = windows ? 'Epinal-Setup-x64.exe' : 'Epinal.apk';
    final asset = assets.where((a) => a['name'] == fileName).firstOrNull;
    if (asset == null)
      throw Exception(
        windows
            ? 'La version Windows de cette publication n’est pas encore disponible.'
            : 'APK absent de la version publiée.',
      );
    final url = Uri.parse(asset['browser_download_url'] as String);
    if (url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.startsWith('/elfred434/Epinal-reader-/releases/download/')) {
      throw Exception('Adresse de téléchargement incorrecte.');
    }
    final digest = asset['digest'] as String? ?? '';
    if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(digest)) {
      throw Exception('Empreinte SHA-256 absente ou invalide.');
    }
    return AppUpdate(build, version, url, digest.substring(7));
  }

  /// On Windows users download the setup from GitHub and confirm installation.
  static Future<void> openWindowsRelease(AppUpdate update) async {
    if (!Platform.isWindows) throw UnsupportedError('Windows uniquement');
    // The tag was validated against the Windows release pattern.
    final page =
        'https://github.com/elfred434/Epinal-reader-/releases/tag/${update.version}';
    await Process.start('explorer.exe', [page]);
  }

  static Future<void> download(AppUpdate update) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/updates',
    );
    await directory.create(recursive: true);
    final part = File('${directory.path}/Epinal.part');
    final dest = File('${directory.path}/Epinal.apk');
    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', update.asset))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200)
        throw Exception('Téléchargement impossible (${response.statusCode}).');
      sink = part.openWrite();
      int size = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        size += chunk.length;
        if (size > 200 * 1024 * 1024) throw Exception('APK trop volumineux.');
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      final hash = (await sha256.bind(part.openRead()).first).toString();
      if (hash != update.digest)
        throw Exception('L’empreinte de l’APK ne correspond pas.');
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
    } finally {
      await sink?.close();
      client.close();
      if (await part.exists()) await part.delete();
    }
  }

  static Future<String?> install() =>
      native.invokeMethod<String>('installUpdate');
}
