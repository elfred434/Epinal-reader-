import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows : une réponse JS absente ne ferme pas le lecteur', (
    tester,
  ) async {
    expect(Platform.isWindows, isTrue);
    final epub = File('test/fixtures/with_cover.epub');
    final controller = EpubController();
    var loaded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubViewer(
            epubController: controller,
            epubSource: EpubSource.fromFile(epub),
            onEpubLoaded: () => loaded = true,
          ),
        ),
      ),
    );
    for (var i = 0; i < 90 && !loaded; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(loaded, isTrue, reason: 'Le lecteur EPUB doit démarrer.');

    // There is deliberately no handler with this name. In plugin 0.7.0-beta.3,
    // Dart's method reply is a native nullptr, not an EncodableValue holding
    // null. The old callback dereferenced it and terminated the process.
    var completed = false;
    Object? value;
    Object? failure;
    unawaited(
      controller.webViewController!
          .callAsync('eval', [
            "window.flutter_inappwebview.callHandler('epinalUnregisteredProbe')",
          ])
          .then((v) {
            value = v;
            completed = true;
          })
          .catchError((Object e) {
            failure = e;
            completed = true;
          }),
    );
    for (var i = 0; i < 30 && !completed; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(completed, isTrue, reason: 'Le pont JS doit répondre.');
    expect(failure, isNull);
    expect(value, isNull);
    await tester.pump(const Duration(seconds: 5));
    // A distinctive marker helps distinguish a successful regression test
    // from Flutter's unrelated Windows teardown/listener cleanup failure.
    // ignore: avoid_print
    print('EPINAL_NULL_REPLY_OK');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
