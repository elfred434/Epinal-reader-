import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Geometry for a sheet folding about the perpendicular bisector of its
/// original corner and the animated corner position. Coordinates are mirrored
/// for previous/next, while the original page bitmap is never mirrored.
class _PaperFold {
  final Size size;
  final Offset crease;
  final Offset normal;
  final List<Offset> fixed;
  final List<Offset> revealed;
  final List<Offset> reflected;

  _PaperFold(
    this.size,
    this.crease,
    this.normal,
    this.fixed,
    this.revealed,
    this.reflected,
  );

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  factory _PaperFold.calculate(
    Size size,
    double progress,
    bool forward,
    bool fromTop,
  ) {
    final t = progress.clamp(0.0, 1.0);
    final w = size.width, h = size.height;
    final start = Offset(forward ? w : 0, fromTop ? 0 : h);
    final verticalLift = h * .20 * math.sin(math.pi * t);
    final destination = Offset(
      forward ? w - 2 * w * t : 2 * w * t,
      fromTop ? verticalLift : h - verticalLift,
    );
    final displacement = start - destination;
    final length = displacement.distance;
    final normal = length < .00001
        ? Offset(forward ? 1 : -1, 0)
        : displacement / length;
    final midpoint = (start + destination) / 2;
    final rectangle = [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];
    double distance(Offset p) => _dot(p - midpoint, normal);

    List<Offset> clip(bool keepFixed) {
      final result = <Offset>[];
      for (var i = 0; i < rectangle.length; i++) {
        final a = rectangle[i], b = rectangle[(i + 1) % rectangle.length];
        final da = distance(a), db = distance(b);
        final insideA = keepFixed ? da <= 0 : da >= 0;
        final insideB = keepFixed ? db <= 0 : db >= 0;
        if (insideA) result.add(a);
        if (insideA != insideB) result.add(a + (b - a) * (da / (da - db)));
      }
      return result;
    }

    final revealed = clip(false);
    final folded = revealed
        .map((point) => point - normal * (2 * distance(point)))
        .toList();
    return _PaperFold(size, midpoint, normal, clip(true), revealed, folded);
  }
}

Path _polygon(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  path.close();
  return path;
}

/// Visible portion of the outgoing page, exposed for geometry regression tests.
Path remainingPagePath(
  Size size,
  double progress, {
  required bool forward,
  bool fromTop = false,
}) => _polygon(_PaperFold.calculate(size, progress, forward, fromTop).fixed);

/// Folio-inspired paper fold, painted over the newly displayed live EPUB page.
/// A blank shaded back represents the opposite face: no mirrored text is shown.
class PageCornerPainter extends CustomPainter {
  final ui.Image image;
  final Color pageColor;
  final double progress;
  final bool forward;
  final bool fromTop;

  PageCornerPainter({
    required this.image,
    required this.pageColor,
    required this.progress,
    required this.forward,
    this.fromTop = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    if (t >= 1) return;
    final fold = _PaperFold.calculate(size, t, forward, fromTop);
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);

    // The outgoing page remains stationary while its outside corner folds.
    canvas.save();
    canvas.clipPath(_polygon(fold.fixed));
    canvas.drawRect(rect, Paint()..color = pageColor);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    if (t > .0001 && fold.reflected.isNotEmpty) {
      final width = math.min(size.width * .12, 48.0) * math.sin(math.pi * t);
      if (width > .01) {
        // Diffuse shadow over the newly revealed page next to the crease.
        final shade = ui.Gradient.linear(
          fold.crease,
          fold.crease + fold.normal * width,
          [Colors.black.withValues(alpha: .23), Colors.transparent],
        );
        canvas.save();
        canvas.clipPath(_polygon(fold.revealed), doAntiAlias: false);
        // The shadow fades over the revealed page, just beyond the crease.
        canvas.drawRect(rect, Paint()..shader = shade);
        canvas.restore();
        shade.dispose();
      }

      // Reflection of the peeled piece forms the physical reverse face.
      final back = _polygon(fold.reflected);
      canvas.drawPath(back, Paint()..color = pageColor);
      final depth = math.max(1.0, math.min(size.width * .35, 120.0));
      final dark = pageColor.computeLuminance() < .2;
      final lighting = ui.Gradient.linear(
        fold.crease - fold.normal * depth,
        fold.crease,
        [
          Colors.transparent,
          (dark ? Colors.white : Colors.black).withValues(alpha: .06),
          Colors.black.withValues(alpha: dark ? .12 : .24),
        ],
        [0, .65, 1],
      );
      canvas.drawPath(back, Paint()..shader = lighting);
      lighting.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PageCornerPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.pageColor != pageColor ||
      oldDelegate.progress != progress ||
      oldDelegate.forward != forward ||
      oldDelegate.fromTop != fromTop;
}
