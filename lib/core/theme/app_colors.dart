import 'package:flutter/material.dart';

/// Brand palette for PSG Padmashree Garments.
///
/// A refined deep-teal primary with warm neutral surfaces — premium and calm,
/// not the loud red/blue of cheap POS apps. Kept in one place so the whole app
/// stays visually consistent.
abstract final class AppColors {
  const AppColors._();

  // Brand
  static const Color brand = Color(0xFF0F766E); // deep teal
  static const Color brandDark = Color(0xFF115E59);
  static const Color accent = Color(0xFFB45309); // warm amber accent

  // Semantic
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);
  static const Color info = Color(0xFF1D4ED8);

  // Neutrals (light)
  static const Color surfaceLight = Color(0xFFFAFAF9);
  static const Color surfaceContainerLight = Color(0xFFF1F0EC);

  // Neutrals (dark)
  static const Color surfaceDark = Color(0xFF12110F);
  static const Color surfaceContainerDark = Color(0xFF1C1B18);
}
