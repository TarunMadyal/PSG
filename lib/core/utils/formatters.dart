import 'package:intl/intl.dart';

/// Shared date/time formatters for the UI and printed receipts.
abstract final class Formatters {
  const Formatters._();

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _time = DateFormat('hh:mm a');

  /// Compact form for narrow thermal receipts, e.g. "17-07-26 06:38 PM".
  /// Short enough to never wrap on 58mm paper.
  static final DateFormat _receiptDateTime = DateFormat('dd-MM-yy hh:mm a');

  static String date(DateTime dt) => _date.format(dt.toLocal());
  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());
  static String time(DateTime dt) => _time.format(dt.toLocal());
  static String receiptDateTime(DateTime dt) =>
      _receiptDateTime.format(dt.toLocal());
}
