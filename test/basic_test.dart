import 'package:flutter_test/flutter_test.dart';
import 'package:epinal_reader/storage.dart';

void main() {
  test('book metadata and reading position round trip', () {
    final original = Book(
      id: 'abc',
      title: 'Livre',
      author: 'Auteur',
      cfi: 'epubcfi(/6/2)',
      progress: .42,
      hasCover: true,
    );
    final copy = Book.fromJson(original.toJson());
    expect(copy.title, 'Livre');
    expect(copy.id, 'abc');
    expect(copy.cfi, 'epubcfi(/6/2)');
    expect(copy.progress, .42);
    expect(copy.hasCover, isTrue);
  });
}
