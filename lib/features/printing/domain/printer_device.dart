/// A bonded Bluetooth thermal printer the shop can print to.
class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

  final String name;

  /// The Bluetooth MAC address, used to (re)connect.
  final String address;
}
