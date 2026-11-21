import 'storage.dart';

/// Suggest a portable file name while keeping the EPUB extension intact.
String exportFileName(String title) {
  var name = title
      .replaceAll(RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.toLowerCase().endsWith('.epub')) {
    name = name.substring(0, name.length - 5).trim();
  }
  name = name.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (name.isEmpty) name = 'Livre';
  // Limit by Unicode characters, without splitting surrogate pairs.
  if (name.runes.length > 80)
    name = String.fromCharCodes(name.runes.take(80)).trim();
  return '$name.epub';
}

/// Exports the currently installed edition, not the original imported file.
/// Returns false when the Android document picker was cancelled.
Future<bool> exportBook(Library library, Book book) async {
  if (!await library.file(book).exists()) {
    throw const FormatException('Le fichier de ce livre est introuvable.');
  }
  return await Library.native.invokeMethod<bool>('exportBook', {
        'bookId': book.id,
        'fileName': exportFileName(book.title),
      }) ??
      false;
}
