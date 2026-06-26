import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A clean, touch-friendly numeric keypad used for PIN entry. Emits individual
/// digits and backspace; the parent owns the entered value.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.maxWidth = 320,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.6,
        children: [
          for (var i = 1; i <= 9; i++)
            _KeypadButton(label: '$i', onTap: () => onDigit('$i')),
          const SizedBox.shrink(),
          _KeypadButton(label: '0', onTap: () => onDigit('0')),
          _KeypadButton(
            icon: Icons.backspace_outlined,
            onTap: onBackspace,
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 26, color: scheme.onSurfaceVariant)
              : Text(
                  label!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
        ),
      ),
    );
  }
}

/// A row of dots indicating how many PIN digits have been entered.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.filled = 0});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: i < filled ? scheme.primary : scheme.outline,
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}
