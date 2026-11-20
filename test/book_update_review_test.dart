import 'package:epinal_reader/book_update.dart';
import 'package:epinal_reader/book_update_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'conflicts require explicit decisions and show excerpts on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const compare = EditionComparison(
        oldHash: 'a',
        incomingHash: 'b',
        added: ['Nouveau'],
        conflicts: [
          EditionConflict(
            path: 'one.xhtml',
            title: 'Chapitre 1',
            chapter: true,
            oldExcerpt: 'Avant',
            newExcerpt: 'Après',
          ),
          EditionConflict(
            path: 'style.css',
            title: 'style.css',
            chapter: false,
            oldExcerpt: '',
            newExcerpt: '',
          ),
        ],
      );
      Map<String, bool>? outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  outcome = await Navigator.push<Map<String, bool>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookUpdateReview(
                        bookTitle: 'Roman',
                        comparison: compare,
                      ),
                    ),
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Appliquer'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Comparer les extraits'));
      await tester.tap(find.text('Comparer les extraits'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Avant'), findsOneWidget);
      expect(find.text('Après'), findsOneWidget);
      await tester.ensureVisible(find.text('Garder').first);
      await tester.tap(find.text('Garder').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Appliquer'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Remplacer').last);
      await tester.tap(find.text('Remplacer').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Appliquer'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(outcome, {'one.xhtml': true, 'style.css': false});
      expect(tester.takeException(), isNull);
    },
  );
}
