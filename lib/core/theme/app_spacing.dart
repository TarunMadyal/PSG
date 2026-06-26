/// Consistent spacing scale (8pt grid) used across the app for clean,
/// well-spaced layouts. Use these instead of magic numbers.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard corner radius for cards, buttons and surfaces.
  static const double radius = 14;
  static const double radiusSm = 10;
  static const double radiusLg = 20;
}
