import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

typedef ViewportCapture = Future<Uint8List?> Function();

/// Shows a temporary, in-memory curl over the EPUB viewport. The EPUB engine
/// still owns navigation, positions and annotations; screenshots are not saved.
class PageFlipLayer extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Color pageColor;
  const PageFlipLayer({
    super.key,
    required this.child,
    required this.enabled,
    required this.pageColor,
  });
  @override
  State<PageFlipLayer> createState() => PageFlipLayerState();
}

class PageFlipLayerState extends State<PageFlipLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  ui.Image? image;
  bool forward = true, busy = false;
  int generation = 0;

  @override
  void didUpdateWidget(covariant PageFlipLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) cancel();
  }

  void _removeImage() {
    final previous = image;
    image = null;
    if (previous != null) {
      // An already scheduled frame may still paint the image; release after it.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void cancel() {
    generation++;
    animation.stop();
    busy = false;
    _removeImage();
  }

  @override
  void dispose() {
    generation++;
    animation.dispose();
    image?.dispose();
    image = null;
    super.dispose();
  }

  Future<ui.Image> _decode(Uint8List bytes, bool mirror) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    late final ui.Image original;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        1200 / math.max(descriptor.width, descriptor.height),
      );
      final width = math.max(1, (descriptor.width * scale).round());
      final height = math.max(1, (descriptor.height * scale).round());
      codec = await descriptor.instantiateCodec(
        targetWidth: width,
        targetHeight: height,
      );
      original = (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
    if (!mirror) return original;
    final w = original.width;
    final h = original.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (mirror) {
      canvas.translate(w.toDouble(), 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      original,
      Rect.fromLTWH(
        0,
        0,
        original.width.toDouble(),
        original.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } finally {
      picture.dispose();
      original.dispose();
    }
  }

  /// A swipe or button can request one turn; errors fall back to ordinary
  /// navigation. Repeated requests are ignored until the animation completes.
  Future<void> turn({
    required bool isForward,
    required ViewportCapture capture,
    required VoidCallback navigate,
  }) async {
    if (busy) return;
    if (!widget.enabled ||
        MediaQuery.maybeOf(context)?.disableAnimations == true) {
      navigate();
      return;
    }
    busy = true;
    final ticket = ++generation;
    ui.Image? pending;
    var navigated = false;
    void navigateOnce() {
      navigated = true;
      navigate();
    }

    try {
      final bytes = await capture().timeout(const Duration(milliseconds: 1200));
      if (!mounted || ticket != generation) return;
      if (bytes == null || bytes.isEmpty) {
        navigateOnce();
        return;
      }
      // CurlOverlay peels left-to-right. Mirror both bitmap and surface for a
      // forward page so the text remains readable, without reversing the page.
      pending = await _decode(bytes, isForward);
      if (!mounted || ticket != generation) return;
      setState(() {
        image = pending;
        pending = null;
        forward = isForward;
        animation.value = 0;
      });
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || ticket != generation) return;
      navigateOnce();
      // Give the WebView a moment to lay out the next page behind the curl.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || ticket != generation) return;
      await animation.forward(from: 0).orCancel;
    } catch (_) {
      // If capture failed, preserve navigation rather than blocking reading.
      if (mounted && ticket == generation && !navigated) navigateOnce();
    } finally {
      pending?.dispose();
      if (mounted && ticket == generation) {
        setState(() {
          _removeImage();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.hardEdge,
    children: [
      widget.child,
      if (image != null)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                Widget overlay = CurlOverlay(
                  progress: Curves.easeInOut.transform(animation.value),
                  pageImage: image,
                  pageColor: widget.pageColor,
                );
                if (forward)
                  overlay = Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(-1, 1, 1),
                    child: overlay,
                  );
                return overlay;
              },
            ),
          ),
        ),
    ],
  );
}
