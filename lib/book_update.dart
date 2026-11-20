import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

const _maxArchiveBytes = 50 * 1024 * 1024;
const _maxExpandedBytes = 80 * 1024 * 1024;
const _maxEntryBytes = 20 * 1024 * 1024;

class EditionConflict {
  final String path;
  final String title;
  final bool chapter;
  final String oldExcerpt;
  final String newExcerpt;
  const EditionConflict({
    required this.path,
    required this.title,
    required this.chapter,
    required this.oldExcerpt,
    required this.newExcerpt,
  });
}

class EditionComparison {
  final String oldHash;
  final String incomingHash;
  final String incomingTitle;
  final List<String> added;
  final List<EditionConflict> conflicts;
  const EditionComparison({
    required this.oldHash,
    required this.incomingHash,
    this.incomingTitle = '',
    required this.added,
    required this.conflicts,
  });
}

class _ManifestItem {
  final String id, path, media, properties;
  const _ManifestItem(this.id, this.path, this.media, this.properties);
}

class _Edition {
  final Archive archive;
  final String packagePath;
  final String title;
  final Map<String, _ManifestItem> items;
  final List<_ManifestItem> spine;
  final String? ncxId;
  const _Edition(
    this.archive,
    this.packagePath,
    this.title,
    this.items,
    this.spine,
    this.ncxId,
  );
}

Iterable<XmlElement> _elements(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);
String _text(ArchiveFile f) => utf8.decode(f.content as List<int>);
String _digest(List<int> bytes) => sha256.convert(bytes).toString();

String _safePath(String value) {
  if (value.isEmpty ||
      value.startsWith('/') ||
      value.contains('\\') ||
      value.contains('\u0000') ||
      value.split('/').contains('..')) {
    throw const FormatException('Chemin EPUB non sûr.');
  }
  final normalized = path.posix.normalize(value);
  if (normalized == '.' || normalized.startsWith('../'))
    throw const FormatException('Chemin EPUB non sûr.');
  return normalized;
}

_Edition _readEdition(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > _maxArchiveBytes)
    throw const FormatException(
      'Chaque EPUB doit faire moins de 50 Mo pour cette comparaison.',
    );
  try {
    final directory = ZipDirectory.read(InputStream(bytes));
    final names = <String>{};
    var expanded = 0;
    if (directory.fileHeaders.length > 5000)
      throw const FormatException('EPUB trop complexe.');
    for (final entry in directory.fileHeaders) {
      final clean = _safePath(entry.filename);
      if (!names.add(clean))
        throw const FormatException('Fichier EPUB en double.');
      if ((entry.versionMadeBy >> 8) == 3 &&
          (((entry.externalFileAttributes ?? 0) >> 16) & 0xF000) == 0xA000)
        throw const FormatException('Liens symboliques non pris en charge.');
      if ((entry.generalPurposeBitFlag & 1) != 0)
        throw const FormatException('EPUB chiffré non pris en charge.');
      final size = entry.uncompressedSize ?? 0;
      expanded += size;
      if (size < 0 || size > _maxEntryBytes || expanded > _maxExpandedBytes)
        throw const FormatException('EPUB décompressé trop volumineux.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.any((f) => f.isSymbolicLink))
      throw const FormatException('EPUB non pris en charge.');
    if (archive.findFile('META-INF/encryption.xml') != null)
      throw const FormatException('EPUB chiffré non pris en charge.');
    final mime = archive.findFile('mimetype');
    if (mime == null || _text(mime).trim() != 'application/epub+zip')
      throw const FormatException('EPUB invalide.');
    final container = archive.findFile('META-INF/container.xml');
    if (container == null)
      throw const FormatException('Structure EPUB absente.');
    final rootfiles = _elements(
      XmlDocument.parse(_text(container)),
      'rootfile',
    ).toList();
    if (rootfiles.length != 1)
      throw const FormatException(
        'EPUB à plusieurs rendus non pris en charge.',
      );
    final packagePath = _safePath(
      rootfiles.single.getAttribute('full-path') ?? '',
    );
    final packageFile = archive.findFile(packagePath);
    if (packageFile == null)
      throw const FormatException('Sommaire EPUB absent.');
    final package = XmlDocument.parse(_text(packageFile));
    final manifestElements = _elements(package, 'manifest').toList();
    final spineElements = _elements(package, 'spine').toList();
    if (manifestElements.length != 1 || spineElements.length != 1)
      throw const FormatException('Structure EPUB non prise en charge.');
    final items = <String, _ManifestItem>{};
    final itemPaths = <String>{};
    for (final e in manifestElements.single.childElements.where(
      (e) => e.name.local == 'item',
    )) {
      final id = e.getAttribute('id') ?? '';
      final href = e.getAttribute('href') ?? '';
      final uri = Uri.tryParse(href);
      if (id.isEmpty ||
          uri == null ||
          uri.hasScheme ||
          uri.hasAuthority ||
          uri.hasQuery ||
          uri.hasFragment)
        throw const FormatException('Ressource EPUB non prise en charge.');
      final rawPath = Uri.decodeComponent(uri.path);
      if (rawPath.startsWith('/') || rawPath.contains('\\'))
        throw const FormatException('Chemin EPUB non sûr.');
      final fullPath = _safePath(
        path.posix.normalize(
          path.posix.join(path.posix.dirname(packagePath), rawPath),
        ),
      );
      if (items.containsKey(id) ||
          !itemPaths.add(fullPath) ||
          archive.findFile(fullPath) == null)
        throw const FormatException('Ressources EPUB ambiguës ou manquantes.');
      items[id] = _ManifestItem(
        id,
        fullPath,
        e.getAttribute('media-type') ?? '',
        e.getAttribute('properties') ?? '',
      );
    }
    final spineNode = spineElements.single;
    final spine = <_ManifestItem>[];
    final seen = <String>{};
    for (final e in spineNode.childElements.where(
      (e) => e.name.local == 'itemref',
    )) {
      final id = e.getAttribute('idref') ?? '';
      final item = items[id];
      // Non-linear and repeated spine items need semantic matching we cannot do safely.
      if (item == null || !seen.add(id) || e.getAttribute('linear') == 'no')
        throw const FormatException(
          'Ordre de lecture EPUB non pris en charge.',
        );
      spine.add(item);
    }
    if (spine.isEmpty)
      throw const FormatException('Aucune section de lecture trouvée.');
    final title =
        _elements(package, 'metadata').firstOrNull?.childElements
            .where((e) => e.name.local == 'title')
            .firstOrNull
            ?.innerText
            .trim() ??
        '';
    return _Edition(
      archive,
      packagePath,
      title,
      items,
      spine,
      spineNode.getAttribute('toc'),
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Impossible d’analyser cet EPUB.');
  }
}

String? _plainText(ArchiveFile file) {
  try {
    final doc = XmlDocument.parse(_text(file));
    final body = _elements(doc, 'body').firstOrNull;
    return (body ?? doc).innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
  } catch (_) {
    return null;
  }
}

(String, String) _excerpts(ArchiveFile before, ArchiveFile after) {
  final a = _plainText(before), b = _plainText(after);
  if (a == null || b == null)
    return (
      '(Aperçu du texte indisponible.)',
      '(Aperçu du texte indisponible.)',
    );
  var difference = 0;
  final limit = a.length < b.length ? a.length : b.length;
  while (difference < limit &&
      a.codeUnitAt(difference) == b.codeUnitAt(difference)) {
    difference++;
  }
  if (a == b) difference = 0;
  String excerpt(String text) {
    final start = (difference - 180).clamp(0, text.length);
    final end = (start + 900).clamp(0, text.length);
    return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
  }

  return (excerpt(a), excerpt(b));
}

String _title(ArchiveFile file) {
  try {
    final doc = XmlDocument.parse(_text(file));
    final heading = doc.descendants
        .whereType<XmlElement>()
        .where((e) => ['h1', 'h2', 'title'].contains(e.name.local))
        .firstOrNull;
    final text =
        heading?.innerText.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (text.isNotEmpty)
      return text.length > 100 ? '${text.substring(0, 100)}…' : text;
  } catch (_) {}
  return path.posix.basename(file.name);
}

/// Compare only when the old spine is a stable prefix and all old resources
/// still exist in the same manifest slots. Unsafe rearrangements are rejected.
EditionComparison compareEditions(List<Uint8List> pair) {
  final old = _readEdition(pair[0]);
  final incoming = _readEdition(pair[1]);
  if (old.packagePath != incoming.packagePath ||
      old.spine.length > incoming.spine.length) {
    throw const FormatException(
      'Les fichiers ont une structure différente : comparaison automatique impossible. Votre livre reste intact.',
    );
  }
  for (var i = 0; i < old.spine.length; i++) {
    final a = old.spine[i], b = incoming.spine[i];
    if (a.id != b.id || a.path != b.path || a.media != b.media) {
      throw const FormatException(
        'Les anciennes sections ont été déplacées ou renommées. Comparaison automatique impossible ; votre livre reste intact.',
      );
    }
  }
  final chapterPaths = old.spine.map((e) => e.path).toSet();
  final conflicts = <EditionConflict>[];
  for (final item in old.items.values) {
    final newItem = incoming.items[item.id];
    if (newItem == null ||
        item.path != newItem.path ||
        item.media != newItem.media) {
      throw const FormatException(
        'Une ancienne ressource a été déplacée ou supprimée. Comparaison automatique impossible ; votre livre reste intact.',
      );
    }
    // The new navigation documents must describe the extended spine.
    if (item.id == old.ncxId ||
        item.properties.split(RegExp(r'\s+')).contains('nav'))
      continue;
    final before = old.archive.findFile(item.path)!;
    final after = incoming.archive.findFile(item.path)!;
    if (_digest(before.content as List<int>) ==
        _digest(after.content as List<int>))
      continue;
    final chapter = chapterPaths.contains(item.path);
    final excerpts = chapter ? _excerpts(before, after) : ('', '');
    conflicts.add(
      EditionConflict(
        path: item.path,
        title: chapter ? _title(before) : path.posix.basename(item.path),
        chapter: chapter,
        oldExcerpt: excerpts.$1,
        newExcerpt: excerpts.$2,
      ),
    );
  }
  // Also protect non-manifest files that an imperfect EPUB may reference.
  final declared = old.items.values.map((item) => item.path).toSet();
  for (final before in old.archive.files) {
    if (!before.isFile ||
        declared.contains(before.name) ||
        before.name == 'mimetype' ||
        before.name == old.packagePath ||
        before.name.startsWith('META-INF/'))
      continue;
    final after = incoming.archive.findFile(before.name);
    if (after == null || !after.isFile)
      throw const FormatException(
        'Un ancien fichier a disparu. Comparaison automatique impossible ; votre livre reste intact.',
      );
    if (_digest(before.content as List<int>) !=
        _digest(after.content as List<int>)) {
      conflicts.add(
        EditionConflict(
          path: before.name,
          title: path.posix.basename(before.name),
          chapter: false,
          oldExcerpt: '',
          newExcerpt: '',
        ),
      );
    }
  }
  final existingContent = <String>{};
  final existingText = <String>{};
  void remember(_Edition edition, _ManifestItem item) {
    final file = edition.archive.findFile(item.path)!;
    existingContent.add(_digest(file.content as List<int>));
    final text = _plainText(file);
    if (text != null && text.length >= 80)
      existingText.add(_digest(utf8.encode(text)));
  }

  for (var i = 0; i < old.spine.length; i++) {
    remember(old, old.spine[i]);
    remember(incoming, incoming.spine[i]);
  }
  for (final item in incoming.spine.skip(old.spine.length)) {
    final file = incoming.archive.findFile(item.path)!;
    final hash = _digest(file.content as List<int>);
    final text = _plainText(file);
    final textHash = text != null && text.length >= 80
        ? _digest(utf8.encode(text))
        : null;
    if (!existingContent.add(hash) ||
        (textHash != null && !existingText.add(textHash))) {
      throw const FormatException(
        'Une nouvelle section semble être un doublon. Comparaison automatique interrompue ; votre livre reste intact.',
      );
    }
  }
  final added = incoming.spine
      .skip(old.spine.length)
      .map((e) => _title(incoming.archive.findFile(e.path)!))
      .toList();
  return EditionComparison(
    oldHash: _digest(pair[0]),
    incomingHash: _digest(pair[1]),
    incomingTitle: incoming.title,
    added: added,
    conflicts: conflicts,
  );
}

class EditionBuildInput {
  final Uint8List oldBytes, newBytes;
  final EditionComparison comparison;

  /// Paths of conflicts explicitly chosen as old; all others must be explicit new choices.
  final Map<String, bool> keepOld;
  const EditionBuildInput(
    this.oldBytes,
    this.newBytes,
    this.comparison,
    this.keepOld,
  );
}

Uint8List buildUpdatedEdition(EditionBuildInput input) {
  if (_digest(input.oldBytes) != input.comparison.oldHash ||
      _digest(input.newBytes) != input.comparison.incomingHash)
    throw const FormatException(
      'Un fichier a changé depuis la comparaison. Recommencez.',
    );
  final current = compareEditions([input.oldBytes, input.newBytes]);
  final paths = current.conflicts.map((c) => c.path).toSet();
  if (input.keepOld.length != paths.length ||
      !input.keepOld.keys.toSet().containsAll(paths))
    throw const FormatException(
      'Choisissez une version pour chaque modification.',
    );
  if (current.added.isEmpty && current.conflicts.isEmpty)
    throw const FormatException('Aucune nouveauté détectée.');
  final old = _readEdition(input.oldBytes),
      updated = _readEdition(input.newBytes);
  final result = Archive();
  final mime = updated.archive.findFile('mimetype')!;
  result.addFile(
    ArchiveFile.noCompress('mimetype', mime.size, mime.content as List<int>),
  );
  for (final file in updated.archive.files) {
    if (!file.isFile || file.name == 'mimetype') continue;
    final selected = input.keepOld[file.name] == true
        ? old.archive.findFile(file.name)!
        : file;
    final data = selected.content as List<int>;
    result.addFile(ArchiveFile(file.name, data.length, data));
  }
  final encoded = ZipEncoder().encode(result);
  if (encoded == null || encoded.length > _maxArchiveBytes)
    throw const FormatException('Le livre obtenu est trop volumineux.');
  return Uint8List.fromList(encoded);
}
