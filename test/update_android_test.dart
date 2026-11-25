import 'package:epinal_reader/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la mise à jour Android choisit l’APK et respecte la version installée', () {
    final release = <String, dynamic>{
      'tag_name': 'v1.0.21',
      'assets': [
        {
          'name': 'Epinal.apk',
          'browser_download_url':
              'https://github.com/elfred434/Epinal-reader-/releases/download/v1.0.21/Epinal.apk',
          'digest': 'sha256:${'a' * 64}',
        },
      ],
    };
    final update = Updater.parseRelease(release, installedBuild: 19)!;
    expect(update.asset.path, endsWith('Epinal.apk'));
    expect(update.digest, 'a' * 64);
    expect(Updater.parseRelease(release, installedBuild: 21), isNull);
    expect(
      () => Updater.parseRelease({'tag_name': 'bad'}, installedBuild: 0),
      throwsException,
    );
  });
}
