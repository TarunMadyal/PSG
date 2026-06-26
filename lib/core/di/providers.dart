import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../security/pin_hasher.dart';

/// Application-wide singletons wired through Riverpod.
///
/// Keeping these here (rather than scattered globals) makes them overridable in
/// tests — e.g. injecting an in-memory database.

/// The local Drift database. Single instance for the app's lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// PIN/password hasher.
final pinHasherProvider = Provider<PinHasher>((ref) => const PinHasher());
