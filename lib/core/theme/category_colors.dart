import 'package:flutter/material.dart';

/// Soft, distinct tile colours assigned **deterministically** per category, so
/// the same category always shows the same colour everywhere in the app.
///
/// This is a deliberate usability aid: staff who aren't comfortable reading
/// quickly can bill by recognising colours ("blue = shirts, green = pants").
/// No configuration needed — every category gets a stable colour automatically.
abstract final class CategoryColors {
  const CategoryColors._();

  /// (background, accent) pairs. Backgrounds are light enough for dark text.
  static const List<(Color, Color)> _palette = [
    (Color(0xFFE3F2FD), Color(0xFF1565C0)), // blue
    (Color(0xFFE8F5E9), Color(0xFF2E7D32)), // green
    (Color(0xFFFFF3E0), Color(0xFFE65100)), // orange
    (Color(0xFFF3E5F5), Color(0xFF6A1B9A)), // purple
    (Color(0xFFFCE4EC), Color(0xFFC2185B)), // pink
    (Color(0xFFE0F7FA), Color(0xFF00838F)), // cyan
    (Color(0xFFFFF8E1), Color(0xFFF9A825)), // amber
    (Color(0xFFEFEBE9), Color(0xFF4E342E)), // brown
    (Color(0xFFE8EAF6), Color(0xFF283593)), // indigo
    (Color(0xFFFBE9E7), Color(0xFFD84315)), // deep orange
    (Color(0xFFF1F8E9), Color(0xFF558B2F)), // lime
    (Color(0xFFE0F2F1), Color(0xFF00695C)), // teal
  ];

  static const (Color, Color) _neutral =
      (Color(0xFFF2F2F2), Color(0xFF616161));

  static (Color, Color) _pair(String? category) {
    final key = category?.trim().toLowerCase();
    if (key == null || key.isEmpty) return _neutral;
    final hash =
        key.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    return _palette[hash % _palette.length];
  }

  /// Light background tint for a product/category tile.
  static Color background(String? category) => _pair(category).$1;

  /// Saturated accent (for the colour dot, chips and the category header).
  static Color accent(String? category) => _pair(category).$2;
}
