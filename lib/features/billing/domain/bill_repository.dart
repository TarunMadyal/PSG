import '../../../core/error/result.dart';
import 'bill_receipt.dart';
import 'cart.dart';

/// Contract for creating and reading bills.
abstract interface class BillRepository {
  /// Completes a sale: persists the bill + line items, decrements stock via the
  /// inventory ledger, and links/creates the customer — all atomically and
  /// offline. Returns the receipt on success.
  Future<Result<BillReceipt>> checkout({
    required Cart cart,
    required String cashierId,
    required String cashierName,
  });

  /// Rebuilds a saved bill's receipt (for viewing/reprinting from history).
  Future<BillReceipt?> receiptFor(String billId);

  /// Live recent-transactions list.
  Stream<List<BillSummary>> watchRecent({int limit});
}
