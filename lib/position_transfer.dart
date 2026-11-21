import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'storage.dart';

/// Manual, offline position transfer; the hash identifies the exact EPUB bytes.
class ReadingPositionCode {
  const ReadingPositionCode({
    required this.epubHash,
    required this.cfi,
    required this.progress,
  });
  final String epubHash;
  final String cfi;
  final double progress;
  static const _prefix = 'EPINAL1';
  static const _limit = 12000;

  String encode() {
    _validate(epubHash, cfi, progress);
    final payload = base64Url
        .encode(
          utf8.encode(jsonEncode({'h': epubHash, 'c': cfi, 'p': progress})),
        )
        .replaceAll('=', '');
    final sum = sha256
        .convert(utf8.encode('$_prefix.$payload'))
        .toString()
        .substring(0, 12);
    final code = '$_prefix.$payload.$sum';
    if (code.length > _limit) {
      throw const FormatException(
        'La position est trop longue pour être transférée.',
      );
    }
    return code;
  }

  static ReadingPositionCode decode(String raw) {
    if (raw.length > _limit) throw const FormatException('Code trop long.');
    final input = raw.replaceAll(RegExp(r'\s+'), '');
    final parts = input.split('.');
    if (parts.length != 3 ||
        parts[0] != _prefix ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(parts[1]) ||
        !RegExp(r'^[a-f0-9]{12}$').hasMatch(parts[2])) {
      throw const FormatException('Code de lecture invalide.');
    }
    final check = sha256
        .convert(utf8.encode('${parts[0]}.${parts[1]}'))
        .toString()
        .substring(0, 12);
    if (check != parts[2])
      throw const FormatException(
        'Code incomplet ou modifié. Copiez-le à nouveau.',
      );
    try {
      final value = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (value is! Map ||
          value['h'] is! String ||
          value['c'] is! String ||
          value['p'] is! num) {
        throw const FormatException('Code de lecture invalide.');
      }
      final hash = value['h'] as String, cfi = value['c'] as String;
      final progress = (value['p'] as num).toDouble();
      _validate(hash, cfi, progress);
      return ReadingPositionCode(epubHash: hash, cfi: cfi, progress: progress);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Code de lecture invalide.');
    }
  }

  static void _validate(String hash, String cfi, double progress) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        cfi.length > 4096 ||
        !cfi.startsWith('epubcfi(') ||
        !cfi.endsWith(')') ||
        cfi.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        !progress.isFinite ||
        progress < 0 ||
        progress > 1) {
      throw const FormatException('Position de lecture invalide.');
    }
  }
}

Future<String> _fileHash(File file) async {
  if (!await file.exists())
    throw const FormatException('Le fichier EPUB de ce livre est introuvable.');
  return (await sha256.bind(file.openRead()).first).toString();
}

Future<String> createReadingPositionCode(Library library, Book book) async {
  final cfi = book.cfi;
  if (cfi == null || cfi.isEmpty) {
    throw const FormatException(
      'Ouvrez d’abord ce livre et avancez jusqu’à votre position de lecture.',
    );
  }
  final hash = await _fileHash(library.file(book));
  return ReadingPositionCode(
    epubHash: hash,
    cfi: cfi,
    progress: book.progress,
  ).encode();
}

/// Verify first; never overwrite the recipient position on a mismatch.
Future<void> applyReadingPositionCode(
  Library library,
  Book book,
  String input,
) async {
  final code = ReadingPositionCode.decode(input);
  if (await _fileHash(library.file(book)) != code.epubHash) {
    throw const FormatException(
      'Ce code ne correspond pas à ce fichier EPUB. Utilisez exactement la même édition sur les deux appareils.',
    );
  }
  final oldCfi = book.cfi, oldProgress = book.progress;
  book.cfi = code.cfi;
  book.progress = code.progress;
  try {
    await library.save();
  } catch (_) {
    book.cfi = oldCfi;
    book.progress = oldProgress;
    rethrow;
  }
}
