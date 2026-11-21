import 'dart:io';
import 'package:epinal_reader/reader.dart';
import 'package:epinal_reader/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows : un EPUB charge et le lecteur devient opérationnel', (
    tester,
  ) async {
    expect(Platform.isWindows, isTrue);
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('epinal-reader-smoke-');
    final library = Library()
      ..dir = dir
      ..prefs = await SharedPreferences.getInstance();
    final book = Book(id: 'abc123', title: 'Un livre', author: 'Auteur');
    library.books = [book];
    await File('test/fixtures/with_cover.epub').copy(library.file(book).path);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(library: library, book: book),
        ),
      );
      bool isReady() {
        final finder = find.byTooltip('Confort de lecture');
        return finder.evaluate().isNotEmpty &&
            tester.widget<IconButton>(finder).onPressed != null;
      }

      for (var i = 0; i < 90 && !isReady(); i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        isReady(),
        isTrue,
        reason: 'Le WebView2 et le moteur EPUB doivent charger le livre.',
      );
      await tester.tap(find.byTooltip('Sommaire'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('Sommaire'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
