import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:epinal_reader/position_transfer.dart';
import 'package:epinal_reader/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('code validé, checksum et bornes', () {
    final p = ReadingPositionCode(
      epubHash: 'a' * 64,
      cfi: 'epubcfi(/6/4!/4/2:11)',
      progress: .63,
    );
    final code = p.encode();
    final decoded = ReadingPositionCode.decode('  $code\n');
    expect(decoded.epubHash, p.epubHash);
    expect(decoded.cfi, p.cfi);
    expect(decoded.progress, p.progress);
    expect(
      () =>
          ReadingPositionCode.decode('${code.substring(0, code.length - 1)}x'),
      throwsFormatException,
    );
    expect(
      () => ReadingPositionCode.decode('autre code'),
      throwsFormatException,
    );
    expect(
      () => ReadingPositionCode.decode('x' * 12001),
      throwsFormatException,
    );
    expect(
      () => ReadingPositionCode(
        epubHash: 'a' * 64,
        cfi: 'non-cfi',
        progress: .5,
      ).encode(),
      throwsFormatException,
    );
    expect(
      () => ReadingPositionCode(
        epubHash: 'a' * 64,
        cfi: 'epubcfi(/6/2)',
        progress: double.nan,
      ).encode(),
      throwsFormatException,
    );
    final malformed = base64Url.encode(utf8.encode('{')).replaceAll('=', '');
    final checksum = sha256
        .convert(utf8.encode('EPINAL1.$malformed'))
        .toString()
        .substring(0, 12);
    expect(
      () => ReadingPositionCode.decode('EPINAL1.$malformed.$checksum'),
      throwsFormatException,
    );
  });
  test(
    'même EPUB : transfert exact, vérification et sauvegarde sans toucher aux autres données',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('epinal-position-');
      final library = Library()
        ..dir = dir
        ..prefs = await SharedPreferences.getInstance();
      final android = Book(
        id: 'a',
        title: 'Roman',
        author: 'Auteur',
        cfi: 'epubcfi(/6/4!/4/2:11)',
        progress: .63,
      );
      final otherDevice = Book(
        id: 'b',
        title: 'Roman',
        author: 'Auteur',
        cfi: 'epubcfi(/6/2!/4/2:1)',
        progress: .1,
        categories: ['Romans'],
      );
      library.books = [android, otherDevice];
      final bytes = await File('test/fixtures/with_cover.epub').readAsBytes();
      try {
        await library.file(android).writeAsBytes(bytes);
        await library.file(otherDevice).writeAsBytes(bytes);
        await library.putEntries('marks', otherDevice, [
          {'cfi': 'un signet'},
        ]);
        final code = await createReadingPositionCode(library, android);
        await applyReadingPositionCode(library, otherDevice, code);
        expect(otherDevice.cfi, android.cfi);
        expect(otherDevice.progress, .63);
        final saved =
            jsonDecode(library.prefs.getString('library.v2')!) as List;
        expect(saved[1]['cfi'], android.cfi);
        expect(saved[1]['progress'], .63);
        expect(otherDevice.categories, ['Romans']);
        expect(library.entries('marks', otherDevice), hasLength(1));
        // Different bytes with the same title must never change the position.
        await library.file(otherDevice).writeAsBytes([...bytes, 0]);
        final before = library.prefs.getString('library.v2');
        await expectLater(
          applyReadingPositionCode(library, otherDevice, code),
          throwsFormatException,
        );
        expect(otherDevice.cfi, android.cfi);
        expect(library.prefs.getString('library.v2'), before);
        await expectLater(
          applyReadingPositionCode(library, otherDevice, 'invalide'),
          throwsFormatException,
        );
        expect(library.prefs.getString('library.v2'), before);
        android.cfi = null;
        await expectLater(
          createReadingPositionCode(library, android),
          throwsFormatException,
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
