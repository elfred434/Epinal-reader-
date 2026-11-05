import 'package:epinal_reader/reading_mode.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('long strip is the default and uses continuous scrolling', () {
    expect(ReadingMode.fromStorage(null), ReadingMode.longStrip);
    expect(ReadingMode.fromStorage('invalid'), ReadingMode.longStrip);
    expect(ReadingMode.longStrip.flow, EpubFlow.scrolled);
    expect(pageTurnForSwipe(ReadingMode.longStrip, 0, -.9), isNull);
  });
  test('modes persist and paginated directions are distinct', () {
    for (final mode in ReadingMode.values) {
      expect(ReadingMode.fromStorage(mode.name), mode);
    }
    expect(ReadingMode.leftToRight.flow, EpubFlow.paginated);
    expect(ReadingMode.rightToLeft.direction, EpubDefaultDirection.rtl);
    expect(pageTurnForSwipe(ReadingMode.leftToRight, -.5, 0), PageTurn.next);
    expect(pageTurnForSwipe(ReadingMode.leftToRight, .5, 0), PageTurn.previous);
    expect(pageTurnForSwipe(ReadingMode.rightToLeft, .5, 0), PageTurn.next);
    expect(
      pageTurnForSwipe(ReadingMode.rightToLeft, -.5, 0),
      PageTurn.previous,
    );
    expect(pageTurnForSwipe(ReadingMode.vertical, 0, -.5), PageTurn.next);
    expect(pageTurnForSwipe(ReadingMode.vertical, 0, .5), PageTurn.previous);
    expect(pageTurnForSwipe(ReadingMode.vertical, .5, .5), isNull);
    expect(pageTurnForSwipe(ReadingMode.leftToRight, -.01, 0), isNull);
  });
}
