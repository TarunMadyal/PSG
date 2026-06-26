import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The high-level sync state shown to the user so they always trust where their
/// data is. Backed by the real sync engine in Phase 8; static for now.
enum SyncStatus { synced, pending, offline, syncing }

/// A subtle, always-visible chip communicating cloud-sync state.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, this.status = SyncStatus.offline});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      SyncStatus.synced => (AppColors.success, Icons.cloud_done_outlined, 'Synced'),
      SyncStatus.pending => (AppColors.warning, Icons.cloud_upload_outlined, 'Pending'),
      SyncStatus.syncing => (AppColors.info, Icons.sync, 'Syncing'),
      SyncStatus.offline => (
          Theme.of(context).colorScheme.onSurfaceVariant,
          Icons.cloud_off_outlined,
          'Offline',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
