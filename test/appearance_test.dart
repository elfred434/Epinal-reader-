import 'package:epinal_reader/main.dart';
import 'package:epinal_reader/palette.dart';
import 'package:epinal_reader/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'apparence sombre puis confort mémorisée et appliquée aux livres',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Épinal',
        packageName: 'com.epinal.reader',
        version: '1.0.6',
        buildNumber: '6',
        buildSignature: '',
      );
      final library = Library()..prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(Epinal(library: library));
      await tester.pump();
      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apparence'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sombre'));
      await tester.pumpAndSettle();
      expect(library.prefs.getString('app.appearance'), 'dark');
      expect(library.prefs.getInt('reader.theme'), 2);
      expect(
        Theme.of(tester.element(find.text('Paramètres'))).colorScheme.surface,
        EpinalPalette.night,
      );
      expect(
        Theme.of(tester.element(find.text('Paramètres'))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.text('Apparence'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confort visuel'));
      await tester.pumpAndSettle();
      expect(library.prefs.getString('app.appearance'), 'comfort');
      expect(library.prefs.getInt('reader.theme'), 3);
      expect(
        Theme.of(tester.element(find.text('Paramètres'))).colorScheme.surface,
        EpinalPalette.sepia,
      );
      expect(
        Theme.of(tester.element(find.text('Paramètres'))).brightness,
        Brightness.light,
      );
    },
  );
  testWidgets('filtrer les livres par catégorie et sans catégorie', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Épinal',
      packageName: 'com.epinal.reader',
      version: '1.0.6',
      buildNumber: '6',
      buildSignature: '',
    );
    final library = Library()..prefs = await SharedPreferences.getInstance();
    library.categories = ['Romans'];
    library.books = [
      Book(id: '1', title: 'Livre classé', author: '', categories: ['Romans']),
      Book(id: '2', title: 'Livre libre', author: ''),
    ];
    await tester.pumpWidget(Epinal(library: library));
    await tester.pumpAndSettle();
    expect(find.text('Livre classé'), findsOneWidget);
    expect(find.text('Livre libre'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Romans'));
    await tester.pumpAndSettle();
    expect(find.text('Livre classé'), findsOneWidget);
    expect(find.text('Livre libre'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sans catégorie'));
    await tester.pumpAndSettle();
    expect(find.text('Livre classé'), findsNothing);
    expect(find.text('Livre libre'), findsOneWidget);
  });
  testWidgets('bascule liste/cartes mémorisée et options du livre', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Épinal',
      packageName: 'com.epinal.reader',
      version: '1.0.10',
      buildNumber: '10',
      buildSignature: '',
    );
    final library = Library()..prefs = await SharedPreferences.getInstance();
    library.books = [Book(id: '1', title: 'Roman', author: 'Auteur')];
    await tester.pumpWidget(Epinal(library: library));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);
    await tester.tap(find.byTooltip('Vue cartes'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(library.prefs.getBool('library.grid'), isTrue);
    await tester.tap(find.byTooltip('Options du livre'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir une image de couverture'), findsOneWidget);
    expect(find.text('Restaurer la couverture EPUB'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Vue liste'));
    await tester.pumpAndSettle();
    expect(library.prefs.getBool('library.grid'), isFalse);
    await tester.tap(find.byTooltip('Vue cartes'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(Epinal(library: library));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
  });
  testWidgets('bibliothèque en cartes adaptée à un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'library.grid': true});
    PackageInfo.setMockInitialValues(
      appName: 'Épinal',
      packageName: 'com.epinal.reader',
      version: '1.0.10',
      buildNumber: '10',
      buildSignature: '',
    );
    final library = Library()..prefs = await SharedPreferences.getInstance();
    library.books = [
      Book(
        id: '1',
        title: 'Un très long titre de roman qui doit rester lisible',
        author: 'Auteur',
      ),
    ];
    await tester.pumpWidget(Epinal(library: library));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
