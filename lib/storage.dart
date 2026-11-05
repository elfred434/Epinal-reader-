import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Book {
  final String id;
  final String title;
  final String author;
  bool hasCover;
  String? cfi;
  double progress;
  List<String> categories;
  Book({
    required this.id,
    required this.title,
    required this.author,
    this.hasCover = false,
    this.cfi,
    this.progress = 0,
    List<String>? categories,
  }) : categories = categories ?? [];
  factory Book.fromJson(Map<String, dynamic> m) => Book(
    id: m['id'] as String,
    title: m['title'] as String,
    author: m['author'] as String? ?? '',
    hasCover: m['cover'] as bool? ?? false,
    cfi: m['cfi'] as String?,
    progress: (m['progress'] as num?)?.toDouble() ?? 0,
    categories: (m['categories'] as List?)?.whereType<String>().toList() ?? [],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'cover': hasCover,
    'cfi': cfi,
    'progress': progress,
    'categories': categories,
  };
}

class Library {
  static const native = MethodChannel('com.epinal.reader/native');
  late SharedPreferences prefs;
  late Directory dir;
  List<Book> books = [];
  List<String> categories = [];
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    categories = prefs.getStringList('categories.v1') ?? [];
    dir = Directory('${(await getApplicationDocumentsDirectory()).path}/books');
    await dir.create(recursive: true);
    try {
      books = (jsonDecode(prefs.getString('library.v2') ?? '[]') as List)
          .map((v) => Book.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
    } catch (_) {
      books = [];
    }
    if (!(prefs.getBool('legacy.migrated') ?? false)) await migrate();
  }

  File file(Book b) => File('${dir.path}/${b.id}.epub');
  File cover(Book b) => File('${dir.path}/${b.id}.jpg');
  Future<void> save() async => prefs.setString(
    'library.v2',
    jsonEncode(books.map((b) => b.toJson()).toList()),
  );

  /// Category names are unique ignoring case and surrounding whitespace.
  String validateCategory(String name, {String? except}) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty)
      throw const FormatException('Saisissez un nom de catégorie.');
    if (clean.length > 40)
      throw const FormatException(
        'Le nom doit contenir 40 caractères maximum.',
      );
    if (categories.any(
      (c) => c != except && c.toLowerCase() == clean.toLowerCase(),
    )) {
      throw const FormatException('Cette catégorie existe déjà.');
    }
    return clean;
  }

  Future<void> createCategory(String name) async {
    final clean = validateCategory(name);
    categories.add(clean);
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await prefs.setStringList('categories.v1', categories);
  }

  Future<void> renameCategory(String oldName, String name) async {
    final clean = validateCategory(name, except: oldName);
    final index = categories.indexOf(oldName);
    if (index == -1) return;
    categories[index] = clean;
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final book in books) {
      book.categories = book.categories
          .map((c) => c == oldName ? clean : c)
          .toList();
    }
    await save();
    await prefs.setStringList('categories.v1', categories);
  }

  Future<void> deleteCategory(String name) async {
    categories.remove(name);
    for (final book in books) {
      book.categories.removeWhere((c) => c == name);
    }
    await save();
    await prefs.setStringList('categories.v1', categories);
  }

  Future<void> classify(Book book, Iterable<String> selected) async {
    final choices = selected.toSet();
    book.categories = categories.where(choices.contains).toList();
    await save();
  }

  Future<void> migrate() async {
    try {
      final data = await native.invokeMapMethod<String, dynamic>('legacyBooks');
      if (data == null) return;
      final old = jsonDecode(data['books'] as String) as List;
      bool complete = true;
      for (final item in old) {
        final id = (item as Map)['id'] as String?;
        if (id == null || !RegExp(r'^[a-f0-9-]+$').hasMatch(id)) {
          complete = false;
          continue;
        }
        final f = File('${data['filesDir']}/$id.epub');
        if (!await f.exists()) {
          complete = false;
          continue;
        }
        try {
          await importFile(f);
        } catch (_) {
          complete = false;
        }
      }
      if (complete) await prefs.setBool('legacy.migrated', true);
    } catch (_) {
      /* Retry migration on the next launch. */
    }
  }

  Future<Book> importFile(File source) async {
    final length = await source.length();
    if (length == 0 || length > 100 * 1024 * 1024)
      throw const FormatException('Le fichier doit faire moins de 100 Mo.');
    final bytes = await source.readAsBytes();
    final id = sha256.convert(bytes).toString();
    for (final b in books) {
      if (b.id == id) return b;
    }
    final epub = await EpubReader.openBook(bytes);
    final title = (epub.Title ?? '').trim();
    final b = Book(
      id: id,
      title: title.isEmpty ? 'Livre sans titre' : title,
      author: (epub.Author ?? '').trim(),
    );
    await file(b).writeAsBytes(bytes, flush: true);
    try {
      final image = await epub.readCover();
      if (image != null) {
        await cover(b).writeAsBytes(img.encodeJpg(image, quality: 80));
        b.hasCover = true;
      }
    } catch (_) {
      /* A missing cover does not prevent reading. */
    }
    books.insert(0, b);
    await save();
    return b;
  }

  Future<void> remove(Book b) async {
    books.removeWhere((v) => v.id == b.id);
    await save();
    await prefs.remove('marks.${b.id}');
    await prefs.remove('highlights.${b.id}');
    await prefs.remove('locations.${b.id}');
    if (await file(b).exists()) await file(b).delete();
    if (await cover(b).exists()) await cover(b).delete();
  }

  List<Map<String, dynamic>> entries(String kind, Book b) {
    try {
      return (jsonDecode(prefs.getString('$kind.${b.id}') ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> putEntries(
    String kind,
    Book b,
    List<Map<String, dynamic>> entries,
  ) async => prefs.setString('$kind.${b.id}', jsonEncode(entries));
}
