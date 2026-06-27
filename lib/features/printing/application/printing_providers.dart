import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/printer_service.dart';
import '../domain/printer_device.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

/// The Bluetooth printers already paired with this device, for the Settings
/// picker. Re-fetched each time it's watched fresh.
final pairedPrintersProvider = FutureProvider<List<PrinterDevice>>(
  (ref) => ref.watch(printerServiceProvider).pairedDevices(),
);
