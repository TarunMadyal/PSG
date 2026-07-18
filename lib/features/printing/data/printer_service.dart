import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/app_logger.dart';
import '../../billing/domain/bill_receipt.dart';
import '../../reports/domain/report_filter.dart';
import '../../reports/domain/report_models.dart';
import '../../reports/domain/report_range.dart';
import '../../settings/domain/shop_profile.dart';
import '../domain/printer_device.dart';
import 'receipt_builder.dart';

/// Talks to a Bluetooth thermal printer: lists bonded devices, connects and
/// sends ESC/POS bytes. Every sale is saved before printing, so a printer
/// failure here never loses a bill — the cashier can simply reprint.
class PrinterService {
  PrinterService({ReceiptBuilder? builder})
      : _builder = builder ?? const ReceiptBuilder();

  final ReceiptBuilder _builder;

  /// Requests the runtime Bluetooth permissions needed on Android 12+.
  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
  }

  Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  /// The Bluetooth devices already paired with this phone/tablet.
  Future<List<PrinterDevice>> pairedDevices() async {
    await requestPermissions();
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list
        .map((b) => PrinterDevice(name: b.name, address: b.macAdress))
        .toList();
  }

  /// Prints a completed bill to the shop's saved printer.
  Future<Result<void>> printReceipt(BillReceipt receipt, ShopProfile shop) {
    return _printBytes(shop, () => _builder.build(receipt, shop));
  }

  /// Prints a short test page to confirm the printer is working.
  Future<Result<void>> testPrint(ShopProfile shop) {
    return _printBytes(shop, () => _builder.buildTestPage(shop));
  }

  /// Prints a sales report for the given range and GST scope (owner).
  Future<Result<void>> printReport(
    ReportDashboard data,
    ReportRange range,
    ShopProfile shop, {
    GstFilter filter = GstFilter.all,
  }) {
    return _printBytes(
      shop,
      () => _builder.buildReport(
        data,
        range,
        shop,
        DateTime.now(),
        filter: filter,
      ),
    );
  }

  Future<Result<void>> _printBytes(
    ShopProfile shop,
    Future<List<int>> Function() makeBytes,
  ) async {
    if (!shop.hasPrinter) {
      return const Result.failure(
        PrinterFailure('No printer set up yet. Go to Settings → Printer.'),
      );
    }

    try {
      await requestPermissions();

      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        return const Result.failure(
          PrinterFailure('Bluetooth is off. Turn it on and try again.'),
        );
      }

      final connected = await _ensureConnected(shop.printerAddress!);
      if (!connected) {
        return Result.failure(
          PrinterFailure(
            'Could not connect to "${shop.printerName ?? 'printer'}". '
            'Make sure it is on and in range.',
          ),
        );
      }

      final bytes = await makeBytes();
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) {
        return const Result.failure(
          PrinterFailure('The printer rejected the job. Check paper and retry.'),
        );
      }
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Print failed', error: e, stackTrace: st);
      return const Result.failure(
        PrinterFailure('Printing failed. Please try again.'),
      );
    }
  }

  Future<bool> _ensureConnected(String address) async {
    if (await PrintBluetoothThermal.connectionStatus) return true;
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }
}
