/// Static application metadata and environment configuration.
///
/// Secrets (e.g. Supabase URL/anon key) are intentionally NOT hard-coded here.
/// They are injected at build time via --dart-define and read lazily so the
/// repository never contains credentials. See [SupabaseEnv] for usage.
abstract final class AppConfig {
  const AppConfig._();

  static const String appName = 'PSG Padmashree Garments';
  static const String shortName = 'PSG POS';

  /// Stored money is always in integer paise; this is the display currency.
  static const String currencySymbol = '₹'; // ₹
  static const String currencyLocale = 'en_IN';

  /// Whether cloud sync is enabled. Off until Phase 8 wires Supabase.
  static const bool cloudSyncEnabled =
      bool.fromEnvironment('PSG_CLOUD_SYNC', defaultValue: false);
}

/// Supabase environment, supplied via --dart-define at build time.
abstract final class SupabaseEnv {
  const SupabaseEnv._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
