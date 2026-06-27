import '../../../core/enums.dart';

/// Fine-grained permissions, decoupled from roles so new roles can be added
/// later by composing capabilities — no changes needed at call sites.
enum Capability {
  // Cashier-level
  createBill,
  printBill,
  searchProducts,

  // Owner-level
  manageProducts,
  viewReports,
  viewSalesHistory,
  manageSettings,
  manageUsers,
  manageBackups,
  deleteData,
}

const Set<Capability> _staffCapabilities = {
  Capability.createBill,
  Capability.printBill,
  Capability.searchProducts,
};

/// The capabilities granted to a [role]. Owner gets everything.
Set<Capability> capabilitiesFor(UserRole role) => switch (role) {
      UserRole.owner => Capability.values.toSet(),
      UserRole.staff => _staffCapabilities,
    };
