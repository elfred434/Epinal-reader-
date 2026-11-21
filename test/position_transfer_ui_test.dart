import 'package:epinal_reader/position_transfer_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('copier puis coller le code sur petit écran', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    const code = 'EPINAL1.exemple.abcdef123456';
    String? clipboard, received;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = call.arguments['text'] as String;
        return null;
      }
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => const PositionCodeDialog(code: code),
                  ),
                  child: const Text('Émettre'),
                ),
                TextButton(
                  onPressed: () async {
                    received = await showDialog<String>(
                      context: context,
                      builder: (_) => const PositionImportDialog(),
                    );
                  },
                  child: const Text('Recevoir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Émettre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copier le code'));
    await tester.pumpAndSettle();
    expect(clipboard, code);
    await tester.tap(find.text('Recevoir'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coller'));
    await tester.tap(find.text('Coller'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      code,
    );
    await tester.ensureVisible(find.text('Appliquer'));
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(received, code);
    expect(tester.takeException(), isNull);
  });
}
