import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/settings_repository_impl.dart';
import '../domain/settings_repository.dart';
import '../domain/shop_profile.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepositoryImpl(db.settingsDao);
});

/// Live shop profile (name, address, footer, saved printer). Emits defaults
/// until the settings row is first read/created.
final shopProfileProvider = StreamProvider<ShopProfile>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
