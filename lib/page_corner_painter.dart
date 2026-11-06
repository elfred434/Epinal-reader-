import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Shape of the still-visible old page. A bottom corner lifts first; the
/// curved diagonal travels from the outside edge toward the opposite edge.
/// Geometry is mirrored, never the image, so text is readable in both turns.
Path remainingPagePath(Size size, double progress, {required bool forward}) {
  final t = progress.clamp(0.0, 1.0);
  final width = size.width, height = size.height;
  final diagonal = .55 * width * math.sin(math.pi * t);
  final top = (width * (1 - t) + diagonal).clamp(0.0, width);
  final bottom = (width * (1 - t) - diagonal).clamp(0.0, width);
  double x(double value) => forward ? value : width - value;
  return Path()
    ..moveTo(x(0), 0)
    ..lineTo(x(top), 0)
    ..quadraticBezierTo(x(top), height * .58, x(bottom), height)
    ..lineTo(x(0), height)
    ..close();
}

/// Paints a captured outgoing page, revealing the live EPUB under a corner
/// curl. The screenshot is ephemeral; the painter does not take ownership.
class PageCornerPainter extends CustomPainter {
  final ui.Image image;
  final Color pageColor;
  final double progress;
  final bool forward;

  PageCornerPainter({
    required this.image,
    required this.pageColor,
    required this.progress,
    required this.forward,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    if (t >= 1) return;
    final width = size.width, height = size.height;
    final visible = remainingPagePath(size, t, forward: forward);
    canvas.save();
    canvas.clipPath(visible);
    canvas.drawRect(Offset.zero & size, Paint()..color = pageColor);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );

    if (t > 0) {
      final diagonal = .55 * width * math.sin(math.pi * t);
      final top = (width * (1 - t) + diagonal).clamp(0.0, width);
      final bottom = (width * (1 - t) - diagonal).clamp(0.0, width);
      final foldWidth = math.min(width * .14, 72.0) * math.sin(math.pi * t);
      double x(double value) => forward ? value : width - value;
      // Follow the curved seam with short shaded segments. The flap tapers
      // toward the top so the lower corner is visibly lifted first.
      const segments = 24;
      final brightness = pageColor.computeLuminance();
      final shine = brightness > .3 ? Colors.white : Colors.white24;
      Offset seam(double u) => Offset(
        top + (bottom - top) * u * u,
        height * (2 * (1 - u) * u * .58 + u * u),
      );
      for (var i = 0; i < segments; i++) {
        final u0 = i / segments, u1 = (i + 1) / segments;
        final a = seam(u0), b = seam(u1);
        final width0 = foldWidth * (.18 + .82 * u0);
        final width1 = foldWidth * (.18 + .82 * u1);
        final flap = Path()
          ..moveTo(x(a.dx), a.dy)
          ..lineTo(x(b.dx), b.dy + .5)
          ..lineTo(x(b.dx - width1), b.dy + .5)
          ..lineTo(x(a.dx - width0), a.dy)
          ..close();
        final middle = (a.dx + b.dx) / 2;
        final stripWidth = (width0 + width1) / 2;
        final gradient = ui.Gradient.linear(
          Offset(x(middle - stripWidth), a.dy),
          Offset(x(middle), a.dy),
          [
            Colors.black.withValues(alpha: .14),
            pageColor,
            shine.withValues(alpha: .65),
            Colors.black.withValues(alpha: .23),
          ],
          [0, .3, .72, 1],
        );
        canvas.drawPath(flap, Paint()..shader = gradient);
        gradient.dispose();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PageCornerPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.pageColor != pageColor ||
      oldDelegate.progress != progress ||
      oldDelegate.forward != forward;
}
