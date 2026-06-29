import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The PSG Padmashree Garments brand mark.
///
/// Renders the real logo asset (`assets/logo/psg_mark.png`). If the asset can't
/// be loaded for any reason, it falls back to a clean painted "PSG" monogram so
/// the UI always looks finished.
///
/// To use your own exact logo, replace the PNG files in `assets/logo/` — no code
/// change is needed.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.showWordmark = false});

  final double size;

  /// When true, shows the full logo lockup (mark + "PADAMSHREE GARMENTS").
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    if (showWordmark) {
      return Image.asset(
        'assets/logo/psg_logo.png',
        height: size * 2.1,
        fit: BoxFit.contain,
        errorBuilder: (context, _, __) => _Fallback(size: size, wordmark: true),
      );
    }
    return Image.asset(
      'assets/logo/psg_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, _, __) => _Fallback(size: size, wordmark: false),
    );
  }
}

/// Painted fallback used only if the logo asset fails to load.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.size, required this.wordmark});

  final double size;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'PSG',
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (!wordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: AppSpacing.sm),
        Text(
          'PADAMSHREE GARMENTS',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
        ),
      ],
    );
  }
}
