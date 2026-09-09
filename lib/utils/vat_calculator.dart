/// VAT calculation utilities for ToTo Cafe.
///
/// Separated from UI so it can be unit-tested independently,
/// per project rules in AGENTS.md:
///   "แยกฟังก์ชันคำนวณ VAT ออกมาต่างหาก ต้องเทสต์ได้อิสระจาก UI"
library;
/// The VAT rate used across the application (7%).
const double kVatRate = 0.07;

/// Calculate VAT amount from a subtotal (price before tax).
///
/// Returns the VAT portion only (not the grand total).
double calculateVat(double subtotal) {
  return double.parse((subtotal * kVatRate).toStringAsFixed(2));
}

/// Calculate the grand total (subtotal + VAT).
double calculateGrandTotal(double subtotal) {
  return double.parse((subtotal + calculateVat(subtotal)).toStringAsFixed(2));
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
    final vat = calculateVat(subtotal);
    return PriceBreakdown(
      subtotal: subtotal,
      vat: vat,
      grandTotal: double.parse((subtotal + vat).toStringAsFixed(2)),
    );
  }
}
