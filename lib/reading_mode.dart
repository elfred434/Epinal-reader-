import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

/// The mode affects gestures / presentation, not the EPUB's embedded scripts.
enum ReadingMode {
  leftToRight(
    'Left to Right',
    'Pages horizontales : glisser vers la gauche pour avancer.',
  ),
  rightToLeft(
    'Right to Left',
    'Pages horizontales : glisser vers la droite pour avancer.',
  ),
  vertical('Vertical', 'Page par page : glisser vers le haut pour avancer.'),
  longStrip('Long strip', 'Défilement vertical continu entre les chapitres.'),
  flipBook('Livre animé', 'Tournez les pages avec un effet de livre.');

  const ReadingMode(this.label, this.description);
  final String label;
  final String description;
  bool get isContinuous => this == ReadingMode.longStrip;
  EpubFlow get flow => isContinuous ? EpubFlow.scrolled : EpubFlow.paginated;
  EpubDefaultDirection get direction => this == ReadingMode.rightToLeft
      ? EpubDefaultDirection.rtl
      : EpubDefaultDirection.ltr;

  static ReadingMode fromStorage(String? value) =>
      ReadingMode.values.where((mode) => mode.name == value).firstOrNull ??
      ReadingMode.longStrip;
}

enum PageTurn { previous, next }

/// Normalized screen coordinates; ignore short or diagonal gestures.
PageTurn? pageTurnForSwipe(ReadingMode mode, double dx, double dy) {
  if (mode.isContinuous) return null;
  if (mode == ReadingMode.vertical) {
    if (dy.abs() < .12 || dy.abs() < dx.abs() * 1.3) return null;
    return dy < 0 ? PageTurn.next : PageTurn.previous;
  }
  if (dx.abs() < .12 || dx.abs() < dy.abs() * 1.3) return null;
  final next = mode == ReadingMode.rightToLeft ? dx > 0 : dx < 0;
  return next ? PageTurn.next : PageTurn.previous;
}
