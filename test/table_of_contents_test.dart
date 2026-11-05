import 'package:epinal_reader/table_of_contents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

EpubChapter chapter(
  String title,
  String href, [
  List<EpubChapter> children = const [],
]) => EpubChapter(title: title, href: href, id: href, subitems: children);

void main() {
  test('recherche insensible à la casse, aux accents et ligatures', () {
    expect(normalizeChapterSearch('  ŒUVRE ÉTÉ  '), 'oeuvre ete');
    expect(normalizeChapterSearch('ChApItRe  125'), 'chapitre 125');
  });
  testWidgets('sommaire filtré, hiérarchique et navigation', (tester) async {
    String? opened;
    final chapters = [
      chapter('Partie I', 'part1', [
        chapter('Chapitre 12 : Été', 'c12'),
        chapter('Chapitre 125', 'c125'),
      ]),
      chapter('Partie II', 'part2'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TableOfContentsSheet(
                  chapters: chapters,
                  onOpen: (value) => opened = value,
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Chapitre 12 : Été'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ete');
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('Chapitre 12 : Été'), findsOneWidget);
    expect(find.text('Chapitre 125'), findsNothing);
    await tester.enterText(find.byType(TextField), '125');
    await tester.pumpAndSettle();
    expect(find.text('Chapitre 125'), findsOneWidget);
    await tester.tap(find.text('Chapitre 125'));
    await tester.pumpAndSettle();
    expect(opened, 'c125');
  });
}
