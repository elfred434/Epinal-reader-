import 'package:epinal_reader/book_picker.dart';
import 'package:epinal_reader/reader_actions.dart';
import 'package:epinal_reader/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('outils de lecture défilants et action identifiable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ReaderAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<ReaderAction>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const ReaderActionsSheet(
                    speaking: false,
                    modeLabel: 'Long strip',
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
    expect(find.text('Rechercher dans le livre'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Mode de lecture'), findsOneWidget);
    await tester.tap(find.text('Mode de lecture'));
    await tester.pumpAndSettle();
    expect(result, ReaderAction.mode);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sélection de destination filtrable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<Book>(
                context: context,
                builder: (_) => BookPickerDialog(
                  books: [
                    Book(id: '1', title: 'La mer', author: 'Alice'),
                    Book(id: '2', title: 'Le ciel', author: 'Bob'),
                  ],
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
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pumpAndSettle();
    expect(find.text('La mer'), findsNothing);
    expect(find.text('Le ciel'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'absent');
    await tester.pumpAndSettle();
    expect(find.text('Aucun livre trouvé.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sélecteur reste utilisable avec clavier et texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<Book>(
                context: context,
                builder: (_) => BookPickerDialog(
                  books: [Book(id: '1', title: 'Roman', author: 'Auteur')],
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
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
