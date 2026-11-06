import 'package:epinal_reader/reading_mode.dart';
import 'package:epinal_reader/reading_mode_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mode picker scrolls and selects animated book on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ReadingMode? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<ReadingMode>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ReadingModePicker(
                      selected: ReadingMode.longStrip,
                    ),
                  );
                },
                child: const Text('Modes'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Modes'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Livre animé'));
      await tester.pumpAndSettle();
      expect(result, ReadingMode.flipBook);
      expect(tester.takeException(), isNull);
    },
  );
}
