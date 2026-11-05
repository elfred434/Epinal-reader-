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
  final Uri apk;
  final String digest;
  AppUpdate(this.build, this.version, this.apk, this.digest);
}

class Updater {
  static const api =
      'https://api.github.com/repos/elfred434/Epinal-reader-/releases/latest';
  static const native = MethodChannel('com.epinal.reader/native');
  static Future<AppUpdate?> check() async {
    final r = await http
        .get(Uri.parse(api), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200)
      throw Exception('GitHub indisponible (${r.statusCode}).');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final version = j['tag_name'] as String? ?? '';
    final match = RegExp(r'^v1\.0\.(\d+)$').firstMatch(version);
    if (match == null) throw Exception('Version GitHub non reconnue.');
    final build = int.parse(match.group(1)!);
    final installed =
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    if (build <= installed) return null;
    final assets = j['assets'] as List;
    final asset = assets.where((a) => a['name'] == 'Epinal.apk').firstOrNull;
    if (asset == null) throw Exception('APK absent de la version publiée.');
    final url = Uri.parse(asset['browser_download_url'] as String);
    if (url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.startsWith('/elfred434/Epinal-reader-/releases/download/'))
      throw Exception('Adresse de téléchargement incorrecte.');
    final digest = asset['digest'] as String? ?? '';
    if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(digest))
      throw Exception('Empreinte SHA-256 absente ou invalide.');
    return AppUpdate(build, version, url, digest.substring(7));
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
          .send(http.Request('GET', update.apk))
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
