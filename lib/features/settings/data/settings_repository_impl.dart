import 'package:drift/drift.dart';

import '../../../core/utils/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/daos/settings_dao.dart';
import '../domain/settings_repository.dart';
import '../domain/shop_profile.dart';

/// Local implementation backed by [SettingsDao] (a single settings row).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dao);

  final SettingsDao _dao;

  @override
  Stream<ShopProfile> watch() =>
      _dao.watch().map((row) => row == null ? ShopProfile.defaults : _toProfile(row));

  @override
  Future<ShopProfile> get() async => _toProfile(await _dao.get());

  @override
  Future<void> save(ShopProfile profile) async {
    await _dao.save(
      AppSettingsCompanion(
        shopName: Value(profile.shopName.trim()),
        address: Value(_clean(profile.address)),
        phone: Value(_clean(profile.phone)),
        receiptWidth: Value(profile.receiptWidth),
        footerText: Value(_clean(profile.footerText)),
        gstNumber: Value(_clean(profile.gstNumber)),
        gstCashLimitPaise: Value(profile.gstCashLimit.paise),
        upiId: Value(_clean(profile.upiId)),
        upiName: Value(_clean(profile.upiName)),
        showUpiQr: Value(profile.printUpiQr),
      ),
    );
  }

  @override
  Future<void> setPrinter({String? name, String? address}) async {
    await _dao.save(
      AppSettingsCompanion(
        printerName: Value(_clean(name)),
        printerAddress: Value(_clean(address)),
      ),
    );
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  ShopProfile _toProfile(AppSetting row) => ShopProfile(
        shopName: row.shopName,
        address: row.address,
        phone: row.phone,
        receiptWidth: row.receiptWidth,
        footerText: row.footerText,
        printerName: row.printerName,
        printerAddress: row.printerAddress,
        gstNumber: row.gstNumber,
        gstCashLimit: Money(row.gstCashLimitPaise),
        upiId: row.upiId,
        upiName: row.upiName,
        printUpiQr: row.showUpiQr,
      );
}
