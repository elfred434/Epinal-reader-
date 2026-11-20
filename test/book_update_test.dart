import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:epinal_reader/book_update.dart';
import 'package:epinal_reader/storage.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List makeBook({
  String first = 'Version originale',
  bool extra = false,
  String css = 'body{color:black}',
  bool reverse = false,
  bool duplicate = false,
}) {
  final contents = <String, String>{
    'META-INF/container.xml':
        '''<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''',
    'OEBPS/content.opf':
        '''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bookid"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Roman</dc:title><dc:language>fr</dc:language><dc:identifier id="bookid">test</dc:identifier></metadata><manifest><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/><item id="css" href="style.css" media-type="text/css"/>${extra ? '<item id="three" href="three.xhtml" media-type="application/xhtml+xml"/>' : ''}</manifest><spine toc="ncx">${reverse ? '<itemref idref="two"/><itemref idref="one"/>' : '<itemref idref="one"/><itemref idref="two"/>'}${extra ? '<itemref idref="three"/>' : ''}</spine></package>''',
    'OEBPS/toc.ncx':
        '''<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="test"/></head><docTitle><text>Roman</text></docTitle><navMap><navPoint id="p1" playOrder="1"><navLabel><text>Chapitre 1</text></navLabel><content src="one.xhtml"/></navPoint><navPoint id="p2" playOrder="2"><navLabel><text>Chapitre 2</text></navLabel><content src="two.xhtml"/></navPoint>${extra ? '<navPoint id="p3" playOrder="3"><navLabel><text>Chapitre 3</text></navLabel><content src="three.xhtml"/></navPoint>' : ''}</navMap></ncx>''',
    'OEBPS/one.xhtml':
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapitre 1</title><link rel="stylesheet" href="style.css"/></head><body><h1>Chapitre 1</h1><p>$first</p></body></html>',
    'OEBPS/two.xhtml':
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapitre 2</title></head><body><h1>Chapitre 2</h1><p>Suite ancienne.</p></body></html>',
    'OEBPS/style.css': css,
  };
  if (extra)
    contents['OEBPS/three.xhtml'] = duplicate
        ? contents['OEBPS/two.xhtml']!
        : '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapitre 3</title></head><body><h1>Chapitre 3</h1><p>Texte ajouté.</p></body></html>';
  final archive = Archive();
  final mime = utf8.encode('application/epub+zip');
  archive.addFile(ArchiveFile.noCompress('mimetype', mime.length, mime));
  for (final item in contents.entries) {
    final data = utf8.encode(item.value);
    archive.addFile(ArchiveFile(item.key, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String entry(Uint8List bytes, String name) => utf8.decode(
  ZipDecoder().decodeBytes(bytes).findFile(name)!.content as List<int>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'compare additions and request decisions for modified text and resources',
    () async {
      final old = makeBook(),
          incoming = makeBook(
            first: 'Texte corrigé',
            extra: true,
            css: 'body{color:blue}',
          );
      final result = compareEditions([old, incoming]);
      expect(result.added, ['Chapitre 3']);
      expect(result.conflicts.length, 2);
      expect(result.conflicts.first.oldExcerpt, contains('Version originale'));
      expect(result.conflicts.first.newExcerpt, contains('Texte corrigé'));
      expect(
        () => buildUpdatedEdition(EditionBuildInput(old, incoming, result, {})),
        throwsFormatException,
      );
      final choices = {
        for (final change in result.conflicts) change.path: true,
      };
      final merged = buildUpdatedEdition(
        EditionBuildInput(old, incoming, result, choices),
      );
      expect(entry(merged, 'OEBPS/one.xhtml'), contains('Version originale'));
      expect(entry(merged, 'OEBPS/style.css'), contains('black'));
      expect(entry(merged, 'OEBPS/three.xhtml'), contains('Texte ajouté'));
      expect(entry(merged, 'OEBPS/toc.ncx'), contains('Chapitre 3'));
      expect((await EpubReader.openBook(merged)).Title, 'Roman');
      choices['OEBPS/one.xhtml'] = false;
      final replaced = buildUpdatedEdition(
        EditionBuildInput(old, incoming, result, choices),
      );
      expect(entry(replaced, 'OEBPS/one.xhtml'), contains('Texte corrigé'));
      expect(entry(replaced, 'OEBPS/style.css'), contains('black'));
    },
  );

  test(
    'refuse reordered, missing and duplicated sections, and stale selections',
    () {
      final old = makeBook();
      expect(
        () => compareEditions([old, makeBook(reverse: true)]),
        throwsFormatException,
      );
      expect(
        () => compareEditions([old, makeBook(extra: true, duplicate: true)]),
        throwsFormatException,
      );
      final result = compareEditions([old, makeBook(extra: true)]);
      expect(
        () => buildUpdatedEdition(
          EditionBuildInput(
            old,
            makeBook(first: 'autre', extra: true),
            result,
            {},
          ),
        ),
        throwsFormatException,
      );
      final unchanged = compareEditions([old, old]);
      expect(unchanged.added, isEmpty);
      expect(unchanged.conflicts, isEmpty);
    },
  );

  test('find a change deep inside a section', () {
    final prefix = List.filled(1300, 'x').join();
    final result = compareEditions([
      makeBook(first: '$prefix ancien'),
      makeBook(first: '$prefix corrigé', extra: true),
    ]);
    expect(result.conflicts.single.oldExcerpt, contains('ancien'));
    expect(result.conflicts.single.newExcerpt, contains('corrigé'));
    expect(result.conflicts.single.oldExcerpt.startsWith('…'), isTrue);
  });

  test('reject unsafe archive paths and corrupted source', () {
    final bad = Archive();
    final bytes = utf8.encode('evil');
    bad.addFile(ArchiveFile('../outside.xhtml', bytes.length, bytes));
    final badZip = Uint8List.fromList(ZipEncoder().encode(bad)!);
    expect(() => compareEditions([makeBook(), badZip]), throwsFormatException);
    expect(
      () => compareEditions([
        makeBook(),
        Uint8List.fromList([1, 2, 3]),
      ]),
      throwsFormatException,
    );
  });

  test(
    'atomic update retains library identity and restores previous version',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('epinal-update-');
      try {
        final lib = Library()
          ..prefs = await SharedPreferences.getInstance()
          ..dir = dir;
        final book = Book(
          id: 'bookid',
          title: 'Roman',
          author: 'Auteur',
          cfi: 'epubcfi(/6/2!/4/2)',
          progress: .4,
          categories: ['Roman'],
        );
        lib.books = [book];
        final old = makeBook(),
            incoming = makeBook(first: 'Nouvelle version', extra: true);
        await lib.file(book).writeAsBytes(old);
        final source = File('${dir.path}/incoming.epub');
        await source.writeAsBytes(incoming);
        await lib.putEntries('marks', book, [
          {'cfi': 'epubcfi(/6/2!/4/2)'},
        ]);
        await lib.prefs.setString('locations.bookid', 'cache périmé');
        final preview = await lib.compareUpdate(book, source);
        // An incomplete review or changed source must not alter the live book.
        await expectLater(
          lib.applyUpdate(book, source, preview, {}),
          throwsFormatException,
        );
        expect(await lib.file(book).readAsBytes(), old);
        expect(await lib.previousEdition(book).exists(), isFalse);
        expect(lib.prefs.getString('locations.bookid'), 'cache périmé');
        await source.writeAsBytes(makeBook(first: 'autre', extra: true));
        await expectLater(
          lib.applyUpdate(book, source, preview, {
            for (final c in preview.conflicts) c.path: true,
          }),
          throwsFormatException,
        );
        expect(await lib.file(book).readAsBytes(), old);
        await source.writeAsBytes(incoming);
        await lib.applyUpdate(book, source, preview, {
          for (final c in preview.conflicts) c.path: true,
        });
        expect(await source.readAsBytes(), incoming);
        expect(await lib.previousEdition(book).readAsBytes(), old);
        expect(
          entry(await lib.file(book).readAsBytes(), 'OEBPS/three.xhtml'),
          contains('Texte ajouté'),
        );
        expect(lib.prefs.getString('locations.bookid'), isNull);
        expect(book.id, 'bookid');
        expect(book.categories, ['Roman']);
        expect(book.cfi, 'epubcfi(/6/2!/4/2)');
        expect(lib.entries('marks', book), hasLength(1));
        book.cfi = 'nouvelle-position';
        book.progress = .8;
        await lib.restorePreviousEdition(book);
        expect(await lib.file(book).readAsBytes(), old);
        expect(book.cfi, 'epubcfi(/6/2!/4/2)');
        expect(book.progress, .4);
        expect(lib.entries('marks', book), hasLength(1));
        expect(await lib.previousEdition(book).exists(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
