import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/daos/bills_dao.dart';
import '../../../data/local/daos/customers_dao.dart';
import '../../../data/local/daos/users_dao.dart';
import '../domain/bill_receipt.dart';
import '../domain/cart.dart';
import '../domain/bill_repository.dart';

/// Local implementation: a checkout is one atomic transaction that writes the
/// bill, its items and any customer — so a sale is all-or-nothing and fully
/// offline.
class BillRepositoryImpl implements BillRepository {
  BillRepositoryImpl({
    required AppDatabase db,
    required BillsDao billsDao,
    required CustomersDao customersDao,
    required UsersDao usersDao,
  })  : _db = db,
        _billsDao = billsDao,
        _customersDao = customersDao,
        _usersDao = usersDao;

  final AppDatabase _db;
  final BillsDao _billsDao;
  final CustomersDao _customersDao;
  final UsersDao _usersDao;

  @override
  Future<Result<BillReceipt>> checkout({
    required Cart cart,
    required String cashierId,
    required String cashierName,
  }) async {
    if (cart.isEmpty) {
      return const Result.failure(ValidationFailure('The cart is empty.'));
    }

    try {
      final receipt = await _db.transaction(() async {
        final invoiceNo = await _billsDao.nextInvoiceNo();

        final customerId = await _customersDao.resolveForSale(
          name: cart.customerName,
          phone: cart.customerPhone,
          walkInRef: 'Walk-in $invoiceNo',
        );

        final bill = await _billsDao.insertBill(
          BillsCompanion.insert(
            invoiceNo: invoiceNo,
            cashierId: cashierId,
            customerId: Value(customerId),
            subtotalPaise: Value(cart.subtotal.paise),
            discountPaise: Value(cart.totalDiscount.paise),
            gstPaise: Value(cart.gst.paise),
            grandTotalPaise: Value(cart.grandTotal.paise),
            paymentMethod: cart.paymentMethod,
          ),
        );

        final receiptLines = <ReceiptLine>[];
        for (final line in cart.lines) {
          await _billsDao.insertItem(
            BillItemsCompanion.insert(
              billId: bill.id,
              productId: line.productId,
              nameSnapshot: line.name,
              qty: Value(line.qty),
              ratePaise: Value(line.unitPrice.paise),
              discountPaise: Value(line.discount.paise),
              amountPaise: Value(line.amount.paise),
            ),
          );

          receiptLines.add(
            ReceiptLine(
              name: line.name,
              qty: line.qty,
              unitPrice: line.unitPrice,
              discount: line.discount,
              amount: line.amount,
            ),
          );
        }

        return BillReceipt(
          id: bill.id,
          invoiceNo: invoiceNo,
          billedAt: bill.billedAt,
          cashierName: cashierName,
          lines: receiptLines,
          subtotal: cart.subtotal,
          discount: cart.totalDiscount,
          gst: cart.gst,
          grandTotal: cart.grandTotal,
          paymentMethod: cart.paymentMethod,
          customerName: cart.customerName,
          customerPhone: cart.customerPhone,
        );
      });

      return Result.success(receipt);
    } catch (e, st) {
      AppLogger.e('Checkout failed', error: e, stackTrace: st);
      return const Result.failure(
        StorageFailure('Could not complete the sale. Please try again.'),
      );
    }
  }

  @override
  Future<BillReceipt?> receiptFor(String billId) async {
    final data = await _billsDao.getWithItems(billId);
    if (data == null) return null;
    final bill = data.bill;

    final cashier = await _usersDao.getById(bill.cashierId);
    String? customerName;
    String? customerPhone;
    if (bill.customerId != null) {
      final c = await _customersDao.getById(bill.customerId!);
      customerName = c?.name;
      customerPhone = c?.phone;
    }

    return BillReceipt(
      id: bill.id,
      invoiceNo: bill.invoiceNo,
      billedAt: bill.billedAt,
      cashierName: cashier?.name ?? '',
      lines: data.items
          .map(
            (it) => ReceiptLine(
              name: it.nameSnapshot,
              qty: it.qty,
              unitPrice: Money(it.ratePaise),
              discount: Money(it.discountPaise),
              amount: Money(it.amountPaise),
            ),
          )
          .toList(),
      subtotal: Money(bill.subtotalPaise),
      discount: Money(bill.discountPaise),
      gst: Money(bill.gstPaise),
      grandTotal: Money(bill.grandTotalPaise),
      paymentMethod: bill.paymentMethod,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  @override
  Stream<List<BillSummary>> watchRecent({int limit = 25}) {
    return _billsDao.watchRecent(limit: limit).map(
          (rows) => rows
              .map(
                (b) => BillSummary(
                  id: b.id,
                  invoiceNo: b.invoiceNo,
                  billedAt: b.billedAt,
                  grandTotal: Money(b.grandTotalPaise),
                  paymentMethod: b.paymentMethod,
                  status: b.status,
                ),
              )
              .toList(),
        );
  }
}
