import 'shop_profile.dart';

/// Contract for reading and writing the single shop-profile/settings row.
abstract interface class SettingsRepository {
  /// Live shop profile (emits defaults until a row exists).
  Stream<ShopProfile> watch();

  /// Reads the current profile, creating the row with defaults if needed.
  Future<ShopProfile> get();

  /// Persists the editable shop profile (name, address, phone, receipt, footer).
  Future<void> save(ShopProfile profile);

  /// Saves (or clears, with nulls) the default Bluetooth printer.
  Future<void> setPrinter({String? name, String? address});
}
