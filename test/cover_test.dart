import 'dart:io';
import 'dart:typed_data';
import 'package:epinal_reader/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'une image choisie devient la couverture sans modifier le fichier original',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('epinal_test_');
      try {
        final library = Library()
          ..prefs = await SharedPreferences.getInstance()
          ..dir = directory;
        final book = Book(id: 'abc', title: 'Livre', author: '');
        library.books = [book];
        final original = File('${directory.path}/source.png');
        final bytes = Uint8List.fromList(img.encodePng(img.Image(80, 120)));
        await original.writeAsBytes(bytes);
        await library.setCustomCover(book, original);
        expect(book.hasCover, isTrue);
        expect(await original.readAsBytes(), bytes);
        expect(await library.cover(book).exists(), isTrue);
        final saved = img.decodeJpg(await library.cover(book).readAsBytes());
        expect(saved?.width, 80);
        expect(saved?.height, 120);
        expect(library.prefs.getString('library.v2'), contains('"cover":true'));
        final bad = File('${directory.path}/bad.jpg');
        await bad.writeAsBytes([1, 2, 3]);
        final previousCover = await library.cover(book).readAsBytes();
        await expectLater(
          library.setCustomCover(book, bad),
          throwsA(isA<FormatException>()),
        );
        expect(await library.cover(book).readAsBytes(), previousCover);
        // Restaurer réellement la couverture intégrée d'un petit EPUB valide.
        await File(
          'test/fixtures/with_cover.epub',
        ).copy(library.file(book).path);
        await library.restoreOriginalCover(book);
        final restored = img.decodeJpg(await library.cover(book).readAsBytes());
        expect(book.hasCover, isTrue);
        expect(restored?.width, 24);
        expect(restored?.height, 36);
        expect(await original.readAsBytes(), bytes);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
