import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Shop profile, printer config, users and backups (owner only).
/// Implemented across Phases 3, 6, 8 and 9.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String title = 'Settings';

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.settings_outlined,
      title: 'Settings',
      description:
          'Shop profile, GST, logo, receipt and printer configuration, user '
          'management and backups — all in one place.',
      phaseLabel: 'Arriving in Phases 3, 6, 8 & 9 · Settings',
    );
  }
}
