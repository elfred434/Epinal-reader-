import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'page_corner_painter.dart';

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

  Future<ui.Image> _decode(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        1200 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
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
      pending = await _decode(bytes);
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
                return CustomPaint(
                  painter: PageCornerPainter(
                    image: image!,
                    pageColor: widget.pageColor,
                    progress: Curves.easeInOut.transform(animation.value),
                    forward: forward,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
    ],
  );
}
