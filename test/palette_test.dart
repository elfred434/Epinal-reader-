import 'dart:typed_data';
import 'package:epinal_reader/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_epub_viewer/src/platform/epub_web_view_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class CaptureBridge implements EpubWebViewController {
  String? name;
  List<dynamic>? args;
  @override
  Future<dynamic> callMethod(
    String name, [
    List<dynamic> args = const [],
  ]) async {
    this.name = name;
    this.args = args;
  }

  @override
  Future<dynamic> callAsync(
    String name, [
    List<dynamic> args = const [],
  ]) async => null;
  @override
  void addHandler(String name, EpubJsHandler callback) {}
  @override
  Future<Uint8List?> captureViewport() async => null;
  @override
  void dispose() {}
}

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return (first > second ? first + .05 : second + .05) /
      (first < second ? first + .05 : second + .05);
}

void main() {
  test('reading themes match design tokens with AAA body text contrast', () {
    expect(EpinalPalette.readingPaper(0), const Color(0xfffaf9f6));
    expect(EpinalPalette.readingInk(0), const Color(0xff1a1a1a));
    expect(EpinalPalette.readingPaper(1), const Color(0xfffbf7ee));
    expect(EpinalPalette.readingInk(1), const Color(0xff2d241e));
    expect(EpinalPalette.readingPaper(2), const Color(0xff141619));
    expect(EpinalPalette.readingInk(2), const Color(0xffd8d4cf));
    expect(EpinalPalette.readingPaper(3), EpinalPalette.readingPaper(1));
    for (var index = 0; index < 4; index++) {
      expect(
        contrast(
          EpinalPalette.readingInk(index),
          EpinalPalette.readingPaper(index),
        ),
        greaterThanOrEqualTo(7),
      );
      final theme = EpinalPalette.epubTheme(index);
      expect(
        (theme.backgroundDecoration as BoxDecoration).color,
        EpinalPalette.readingPaper(index),
      );
      expect(theme.foregroundColor, EpinalPalette.readingInk(index));
    }
    expect(EpinalPalette.epubTheme(3).customCss?['body']['line-height'], '1.7');
  });

  test('application surface palettes have readable text', () {
    for (final mode in ['light', 'comfort', 'dark']) {
      final scheme = EpinalPalette.scheme(mode);
      expect(
        contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(7),
      );
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(EpinalPalette.scheme('light').surface, const Color(0xfffff8f5));
    expect(EpinalPalette.scheme('comfort').surface, EpinalPalette.sepia);
    expect(EpinalPalette.scheme('dark').surface, EpinalPalette.night);
    expect(
      EpinalPalette.scheme('dark').surfaceContainerLow,
      EpinalPalette.nightCard,
    );
  });

  test('EPUB bridge applies paper and ink when changing theme', () async {
    final bridge = CaptureBridge();
    final controller = EpubController()..setWebViewController(bridge);
    await controller.updateTheme(theme: EpinalPalette.epubTheme(3));
    expect(bridge.name, 'updateTheme');
    expect(bridge.args![0], '#fbf7ee');
    expect(bridge.args![1], '#2d241e');
    expect(bridge.args![2]['body']['line-height'], '1.7');
    await controller.updateTheme(theme: EpinalPalette.epubTheme(2));
    expect(bridge.args![0], '#141619');
    expect(bridge.args![1], '#d8d4cf');
  });
}
