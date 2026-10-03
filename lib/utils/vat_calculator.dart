/// VAT calculation utilities for ToTo Cafe.
///
/// Separated from UI so it can be unit-tested independently,
/// per project rules in AGENTS.md:
///   "แยกฟังก์ชันคำนวณ VAT ออกมาต่างหาก ต้องเทสต์ได้อิสระจาก UI"
library;
/// The VAT rate used across the application (0% when VAT is disabled).
const double kVatRate = 0.0;

/// Calculate VAT amount from a subtotal (returns 0.0 when VAT is disabled).
double calculateVat(double subtotal) {
  return 0.0;
}

/// Calculate the grand total (subtotal + VAT).
double calculateGrandTotal(double subtotal) {
  return double.parse(subtotal.toStringAsFixed(2));
}

/// A breakdown of an order's pricing.
class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotal,
    required this.vat,
    required this.grandTotal,
  });

  final double subtotal;
  final double vat;
  final double grandTotal;

  /// Compute a full price breakdown from a subtotal.
  factory PriceBreakdown.fromSubtotal(double subtotal) {
    final roundedSubtotal = double.parse(subtotal.toStringAsFixed(2));
    return PriceBreakdown(
      subtotal: roundedSubtotal,
      vat: 0.0,
      grandTotal: roundedSubtotal,
    );
  }
}
