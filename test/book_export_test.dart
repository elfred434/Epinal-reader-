import 'dart:io';
import 'package:epinal_reader/book_export.dart';
import 'package:epinal_reader/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'book_update_test.dart' show makeBook, entry;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('noms de fichiers portables et extension EPUB', () {
    expect(
      exportFileName('  Mon / roman : suite.epub  '),
      'Mon roman suite.epub',
    );
    expect(exportFileName('...'), 'Livre.epub');
    expect(exportFileName('📚' * 100).runes.length, 85);
  });

  test(
    'exporte l’édition courante après fusion et respecte l’annulation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('epinal-export-');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final library = Library()
        ..dir = dir
        ..prefs = await SharedPreferences.getInstance();
      final book = Book(id: 'abc123', title: 'Mon roman', author: 'Auteur');
      library.books = [book];
      final old = makeBook(),
          incoming = makeBook(first: 'Correction', extra: true);
      final source = File('${dir.path}/source.epub');
      final exported = File('${dir.path}/exported.epub');
      try {
        await library.file(book).writeAsBytes(old);
        await source.writeAsBytes(incoming);
        final comparison = await library.compareUpdate(book, source);
        await library.applyUpdate(book, source, comparison, {
          for (final c in comparison.conflicts) c.path: true,
        });
        messenger.setMockMethodCallHandler(Library.native, (call) async {
          expect(call.method, 'exportBook');
          expect(call.arguments['bookId'], 'abc123');
          expect(call.arguments['fileName'], 'Mon roman.epub');
          // The native document picker/copy is mocked, not exercised here.
          await library.file(book).copy(exported.path);
          return true;
        });
        expect(await exportBook(library, book), isTrue);
        final result = await exported.readAsBytes();
        expect(result, await library.file(book).readAsBytes());
        expect(entry(result, 'OEBPS/one.xhtml'), contains('Version originale'));
        expect(entry(result, 'OEBPS/three.xhtml'), contains('Texte ajouté'));
        expect(await source.readAsBytes(), incoming);
        messenger.setMockMethodCallHandler(Library.native, (_) async => false);
        expect(await exportBook(library, book), isFalse);
        messenger.setMockMethodCallHandler(
          Library.native,
          (_) async => throw PlatformException(code: 'write'),
        );
        await expectLater(
          exportBook(library, book),
          throwsA(isA<PlatformException>()),
        );
        await library.file(book).delete();
        await expectLater(exportBook(library, book), throwsFormatException);
      } finally {
        messenger.setMockMethodCallHandler(Library.native, null);
        await dir.delete(recursive: true);
      }
    },
  );
}
