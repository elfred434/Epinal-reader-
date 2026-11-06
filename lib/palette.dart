import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

/// Colour tokens from DESIGN.md. Reading-mode indices retain their old values.
abstract final class EpinalPalette {
  static const garance = Color(0xffc83e2d);
  static const primary = Color(0xffa62518);
  static const outremer = Color(0xff1e3a5f);
  static const gold = Color(0xffe5a93c);
  static const highlightAmber = Color(0xfffde68a);
  static const highlightVermillon = Color(0xfffecaca);
  static const highlightUltramarine = Color(0xffbfdbfe);
  static const velin = Color(0xfffaf9f6);
  static const velinInk = Color(0xff1a1a1a);
  static const sepia = Color(0xfffbf7ee);
  static const sepiaInk = Color(0xff2d241e);
  static const night = Color(0xff141619);
  static const nightCard = Color(0xff1e2226);
  static const nightInk = Color(0xffd8d4cf);
  static const nightBorder = Color(0xff2e3339);

  static Color readingPaper(int index) => switch (index) {
    1 || 3 => sepia,
    2 => night,
    _ => velin,
  };
  static Color readingInk(int index) => switch (index) {
    1 || 3 => sepiaInk,
    2 => nightInk,
    _ => velinInk,
  };

  static EpubTheme epubTheme(int index) => EpubTheme.custom(
    backgroundDecoration: BoxDecoration(color: readingPaper(index)),
    foregroundColor: readingInk(index),
    // Preserve the extra line spacing in the existing eye-comfort option.
    customCss: index == 3
        ? {
            'body': {'line-height': '1.7'},
            'p': {'line-height': '1.7'},
          }
        : null,
  );

  static ColorScheme scheme(String appearance) {
    final dark = appearance == 'dark';
    if (dark) {
      return ColorScheme.fromSeed(
        seedColor: garance,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xffffb4a8),
        onPrimary: const Color(0xff410100),
        primaryContainer: const Color(0xff8e1308),
        onPrimaryContainer: const Color(0xffffdad4),
        secondary: const Color(0xffadc8f5),
        onSecondary: const Color(0xff001c3b),
        secondaryContainer: const Color(0xff2d486d),
        onSecondaryContainer: const Color(0xffd5e3ff),
        tertiary: gold,
        onTertiary: const Color(0xff281900),
        surface: night,
        onSurface: nightInk,
        onSurfaceVariant: const Color(0xffc8c1ba),
        surfaceContainerLowest: const Color(0xff0e1012),
        surfaceContainerLow: nightCard,
        surfaceContainer: nightCard,
        surfaceContainerHigh: const Color(0xff272c31),
        surfaceContainerHighest: const Color(0xff30363b),
        outline: const Color(0xffa79d99),
        outlineVariant: nightBorder,
        inverseSurface: const Color(0xffeee0d7),
        onInverseSurface: const Color(0xff382e28),
        inversePrimary: primary,
        surfaceTint: garance,
      );
    }
    final comfort = appearance == 'comfort';
    return ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: garance,
      onPrimaryContainer: const Color(0xfffff1ee),
      secondary: const Color(0xff455f87),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xffb5d0fd),
      onSecondaryContainer: const Color(0xff3e5980),
      tertiary: const Color(0xff744f00),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xff946600),
      onTertiaryContainer: const Color(0xfffff1e1),
      surface: comfort ? sepia : const Color(0xfffff8f5),
      onSurface: comfort ? sepiaInk : const Color(0xff221a14),
      onSurfaceVariant: const Color(0xff59413d),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: comfort
          ? const Color(0xfff5efe2)
          : const Color(0xfffff1e9),
      surfaceContainer: comfort
          ? const Color(0xfff0e8d9)
          : const Color(0xfffcebe1),
      surfaceContainerHigh: comfort
          ? const Color(0xffebe2d2)
          : const Color(0xfff6e5db),
      surfaceContainerHighest: comfort
          ? const Color(0xffe8dec9)
          : const Color(0xfff0dfd6),
      outline: const Color(0xff8d706c),
      outlineVariant: comfort
          ? const Color(0xffe8dec9)
          : const Color(0xffe1bfb9),
      inverseSurface: const Color(0xff382e28),
      onInverseSurface: const Color(0xffffede4),
      inversePrimary: const Color(0xffffb4a8),
      surfaceTint: const Color(0xffb02d1e),
      error: const Color(0xffba1a1a),
      onError: Colors.white,
      errorContainer: const Color(0xffffdad6),
      onErrorContainer: const Color(0xff93000a),
    );
  }
}
