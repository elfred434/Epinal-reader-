import 'dart:ui' as ui;
import 'package:epinal_reader/page_corner_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('next page first reveals the lower right corner then moves left', () {
    const size = Size(100, 100);
    final start = remainingPagePath(size, 0, forward: true);
    final corner = remainingPagePath(size, .2, forward: true);
    final finish = remainingPagePath(size, 1, forward: true);
    expect(start.contains(const Offset(99, 99)), isTrue);
    expect(corner.contains(const Offset(99, 99)), isFalse);
    expect(corner.contains(const Offset(99, 1)), isTrue);
    expect(corner.contains(const Offset(10, 50)), isTrue);
    expect(finish.contains(const Offset(10, 50)), isFalse);
  });
  test(
    'previous page first reveals the lower left corner then moves right',
    () {
      const size = Size(100, 100);
      final start = remainingPagePath(size, 0, forward: false);
      final corner = remainingPagePath(size, .2, forward: false);
      final finish = remainingPagePath(size, 1, forward: false);
      expect(start.contains(const Offset(1, 99)), isTrue);
      expect(corner.contains(const Offset(1, 99)), isFalse);
      expect(corner.contains(const Offset(1, 1)), isTrue);
      expect(corner.contains(const Offset(90, 50)), isTrue);
      expect(finish.contains(const Offset(90, 50)), isFalse);
    },
  );
  testWidgets(
    'rendered corner reveals correct side without mirroring page content',
    (tester) async {
      await tester.runAsync(() async {
        const size = Size(100, 100);
        final sourceRecorder = ui.PictureRecorder();
        final sourceCanvas = Canvas(sourceRecorder);
        sourceCanvas.drawRect(
          const Rect.fromLTWH(0, 0, 50, 100),
          Paint()..color = const Color(0xffff0000),
        );
        sourceCanvas.drawRect(
          const Rect.fromLTWH(50, 0, 50, 100),
          Paint()..color = const Color(0xff008000),
        );
        final sourcePicture = sourceRecorder.endRecording();
        final source = await sourcePicture.toImage(100, 100);
        sourcePicture.dispose();
        try {
          for (final forward in [true, false]) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            canvas.drawRect(
              Offset.zero & size,
              Paint()..color = const Color(0xff0000ff),
            );
            PageCornerPainter(
              image: source,
              pageColor: Colors.white,
              progress: .2,
              forward: forward,
            ).paint(canvas, size);
            final picture = recorder.endRecording();
            final frame = await picture.toImage(100, 100);
            final bytes = (await frame.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            List<int> pixel(int x, int y) =>
                List.generate(4, (i) => bytes.getUint8((y * 100 + x) * 4 + i));
            expect(pixel(10, 1), [255, 0, 0, 255]);
            expect(pixel(90, 1), [0, 128, 0, 255]);
            expect(pixel(forward ? 95 : 5, 95), [0, 0, 255, 255]);
            expect(
              pixel(forward ? 5 : 95, 95),
              forward ? [255, 0, 0, 255] : [0, 128, 0, 255],
            );
            frame.dispose();
            picture.dispose();
          }
        } finally {
          source.dispose();
        }
      });
    },
  );
}
