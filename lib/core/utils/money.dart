import 'package:intl/intl.dart';

import '../config/app_config.dart';

/// Immutable money value stored as **integer paise** (1 rupee = 100 paise).
///
/// All monetary amounts in the system are integers to eliminate floating-point
/// rounding errors — money is never a `double`. Formatting to rupees happens
/// only at the display edge.
extension type const Money(int paise) implements Object {
  /// Builds [Money] from a rupee amount (e.g. `Money.fromRupees(199.50)`).
  factory Money.fromRupees(num rupees) => Money((rupees * 100).round());

  static const Money zero = Money(0);

  double get rupees => paise / 100;

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  Money operator *(int qty) => Money(paise * qty);

  bool operator >(Money other) => paise > other.paise;
  bool operator <(Money other) => paise < other.paise;
  bool operator >=(Money other) => paise >= other.paise;
  bool operator <=(Money other) => paise <= other.paise;

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;

  /// Applies a percentage discount, rounding to the nearest paise.
  Money percentOff(double percent) =>
      Money((paise * (1 - percent / 100)).round());

  /// `₹1,299.00` — Indian-locale grouped currency string for receipts/UI.
  String get formatted => _formatter.format(rupees);

  /// `1,299.00` without the currency symbol (useful for aligned tables).
  String get formattedPlain => _plainFormatter.format(rupees);

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: AppConfig.currencySymbol,
    decimalDigits: 2,
  );

  static final NumberFormat _plainFormatter = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: '',
    decimalDigits: 2,
  );
}
