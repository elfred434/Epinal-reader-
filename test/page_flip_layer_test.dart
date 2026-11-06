import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:epinal_reader/page_flip_layer.dart';
import 'package:epinal_reader/reading_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epinal_reader/page_corner_painter.dart';

void main() {
  test('animated book retains paginated left-to-right gestures', () {
    expect(ReadingMode.fromStorage('flipBook'), ReadingMode.flipBook);
    expect(ReadingMode.flipBook.isContinuous, isFalse);
    expect(pageTurnForSwipe(ReadingMode.flipBook, -.5, 0), PageTurn.next);
    expect(pageTurnForSwipe(ReadingMode.flipBook, .5, 0), PageTurn.previous);
    expect(pageTurnForSwipe(ReadingMode.flipBook, 0, -.5), isNull);
  });

  testWidgets('failed capture falls back and repeated gestures are locked', (
    tester,
  ) async {
    final key = GlobalKey<PageFlipLayerState>();
    await tester.pumpWidget(
      MaterialApp(
        home: PageFlipLayer(
          key: key,
          enabled: true,
          pageColor: Colors.white,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final capture = Completer<Uint8List?>();
    var navigations = 0;
    final first = key.currentState!.turn(
      isForward: true,
      capture: () => capture.future,
      navigate: () => navigations++,
    );
    await key.currentState!.turn(
      isForward: true,
      capture: () async => null,
      navigate: () => navigations++,
    );
    expect(navigations, 0);
    capture.complete(null);
    await first;
    await tester.pump();
    expect(navigations, 1);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageCornerPainter,
      ),
      findsNothing,
    );
  });

  testWidgets('reduced motion navigates without capturing', (tester) async {
    final key = GlobalKey<PageFlipLayerState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: PageFlipLayer(
            key: key,
            enabled: true,
            pageColor: Colors.white,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    var captures = 0, navigations = 0;
    await key.currentState!.turn(
      isForward: true,
      capture: () async {
        captures++;
        return null;
      },
      navigate: () => navigations++,
    );
    expect(captures, 0);
    expect(navigations, 1);
  });

  testWidgets('mode change cancels a pending capture', (tester) async {
    final key = GlobalKey<PageFlipLayerState>();
    Widget screen(bool enabled) => MaterialApp(
      home: PageFlipLayer(
        key: key,
        enabled: enabled,
        pageColor: Colors.white,
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(screen(true));
    final capture = Completer<Uint8List?>();
    var navigations = 0;
    final turn = key.currentState!.turn(
      isForward: true,
      capture: () => capture.future,
      navigate: () => navigations++,
    );
    await tester.pumpWidget(screen(false));
    capture.complete(null);
    await turn;
    expect(navigations, 0);
  });

  for (final isForward in [false, true]) {
    testWidgets('valid capture animates with forward=$isForward', (
      tester,
    ) async {
      final key = GlobalKey<PageFlipLayerState>();
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipLayer(
            key: key,
            enabled: true,
            pageColor: Colors.white,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAIAAAACUFjqAAAAFUlEQVR4nGP8//8/A27AhEduBEsDAKXjAxF9kqZqAAAAAElFTkSuQmCC',
      );
      var navigations = 0;
      final turn = key.currentState!.turn(
        isForward: isForward,
        fromTopCorner: isForward,
        capture: () async => png,
        navigate: () => navigations++,
      );
      // Image decoding uses the engine's asynchronous codec.
      for (
        var attempt = 0;
        attempt < 20 &&
            find
                .byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is PageCornerPainter,
                )
                .evaluate()
                .isEmpty;
        attempt++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PageCornerPainter,
        ),
        findsOneWidget,
      );
      expect(navigations, 1);
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PageCornerPainter,
        ),
      );
      expect((paint.painter! as PageCornerPainter).forward, isForward);
      expect((paint.painter! as PageCornerPainter).fromTop, isForward);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();
      await turn;
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PageCornerPainter,
        ),
        findsNothing,
      );
    });
  }
}
