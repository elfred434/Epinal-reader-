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
  Book({
    required this.id,
    required this.title,
    required this.author,
    this.hasCover = false,
    this.cfi,
    this.progress = 0,
  });
  factory Book.fromJson(Map<String, dynamic> m) => Book(
    id: m['id'] as String,
    title: m['title'] as String,
    author: m['author'] as String? ?? '',
    hasCover: m['cover'] as bool? ?? false,
    cfi: m['cfi'] as String?,
    progress: (m['progress'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'cover': hasCover,
    'cfi': cfi,
    'progress': progress,
  };
}

class Library {
  static const native = MethodChannel('com.epinal.reader/native');
  late SharedPreferences prefs;
  late Directory dir;
  List<Book> books = [];
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
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
