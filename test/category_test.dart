import 'package:epinal_reader/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ancienne bibliothèque sans champ categories reste lisible', () {
    final b = Book.fromJson({'id': '1', 'title': 'Ancien', 'progress': .5});
    expect(b.categories, isEmpty);
    expect(Book.fromJson(b.toJson()).progress, .5);
  });
  test(
    'création, classification multiple, renommage et suppression sont sauvegardés',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = Library()..prefs = await SharedPreferences.getInstance();
      final first = Book(id: '1', title: 'Un', author: 'A');
      final second = Book(id: '2', title: 'Deux', author: 'B');
      library.books = [first, second];
      await library.createCategory('  Romans ');
      await library.createCategory('Études');
      expect(() => library.validateCategory('romans'), throwsFormatException);
      await library.classify(first, ['Romans', 'Études']);
      await library.classify(second, ['Romans']);
      expect(first.categories, containsAll(['Romans', 'Études']));
      await library.renameCategory('Romans', 'Fiction');
      expect(first.categories, contains('Fiction'));
      expect(second.categories, contains('Fiction'));
      expect(first.categories, isNot(contains('Romans')));
      await library.deleteCategory('Fiction');
      expect(first.categories, ['Études']);
      expect(second.categories, isEmpty);
      expect(library.books.length, 2);
      expect(library.prefs.getStringList('categories.v1'), ['Études']);
      expect(library.prefs.getString('library.v2'), contains('Études'));
    },
  );
}
