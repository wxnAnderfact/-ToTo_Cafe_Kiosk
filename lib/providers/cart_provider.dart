import 'package:flutter/foundation.dart';
import '../models/member.dart';
import '../models/order.dart';
import '../utils/vat_calculator.dart';

/// Manages cart state for the Kiosk ordering flow.
///
/// Provides add/remove/update operations and automatically computes
/// Subtotal, VAT 7%, and Grand Total via the separated [vat_calculator].
class CartProvider extends ChangeNotifier {
  final List<OrderItem> _items = [];
  Member? _member;
  String? _memberPhone;
  double _discount = 0.0;
  int _redeemedPoints = 0;

  // ── Getters ─────────────────────────────────────────────────────────────

  /// Unmodifiable view of the current cart items.
  List<OrderItem> get items => List.unmodifiable(_items);

  /// Number of distinct line items in the cart.
  int get itemCount => _items.length;

  /// Total number of individual units across all line items.
  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  /// Whether the cart has at least one item.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Whether the cart is empty.
  bool get isEmpty => _items.isEmpty;

  /// Sum of all line totals (before tax).
  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// VAT 7% computed from [subtotal].
  double get vat => calculateVat(subtotal);

  /// Grand total (subtotal + VAT).
  double get grandTotal => calculateGrandTotal(subtotal);

  /// Grand total after member points discount.
  double get totalAfterDiscount =>
      (grandTotal - _discount).clamp(0.0, double.infinity);

  /// Full price breakdown as a value object.
  PriceBreakdown get priceBreakdown => PriceBreakdown.fromSubtotal(subtotal);

  /// Attached member for points earning/redemption.
  Member? get member => _member;

  /// Attached member phone number.
  String? get memberPhone => _memberPhone ?? _member?.phone;

  /// Applied discount amount in THB.
  double get discount => _discount;

  /// Points redeemed for discount.
  int get redeemedPoints => _redeemedPoints;

  // ── Mutations ───────────────────────────────────────────────────────────

  /// Add an item to the cart.
  ///
  /// If an item with the same [menuItemId], [sweetness], and [milkType]
  /// already exists, its quantity is incremented instead of adding a
  /// duplicate line item.
  void addItem(OrderItem item) {
    final existingIndex = _items.indexWhere(
      (existing) =>
          existing.menuItemId == item.menuItemId &&
          existing.sweetness == item.sweetness &&
          existing.milkType == item.milkType,
    );

    if (existingIndex >= 0) {
      final newQty = (_items[existingIndex].quantity + item.quantity).clamp(1, 99);
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: newQty,
      );
    } else {
      _items.add(item.copyWith(quantity: item.quantity.clamp(1, 99)));
    }
    notifyListeners();
  }

  /// Remove a line item at the given [index].
  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  /// Update the quantity of the item at [index].
  ///
  /// If [newQuantity] is ≤ 0, the item is removed. Maximum is 99.
  void updateQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) return;

    if (newQuantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQuantity.clamp(1, 99));
    }
    notifyListeners();
  }

  /// Increment the quantity of the item at [index] by 1 (max 99).
  void incrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      if (_items[index].quantity >= 99) return;
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + 1,
      );
      notifyListeners();
    }
  }

  /// Decrement the quantity of the item at [index] by 1.
  /// Removes the item if quantity reaches 0.
  void decrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      final current = _items[index].quantity;
      if (current <= 1) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: current - 1);
      }
      notifyListeners();
    }
  }

  /// Set or clear member.
  void setMember(Member? member, {String? phone}) {
    _member = member;
    _memberPhone = phone ?? member?.phone;
    if (member == null) {
      _discount = 0.0;
      _redeemedPoints = 0;
    }
    notifyListeners();
  }

  /// Apply points discount. Rate: 1 point = 1 baht (1 point = 1 THB).
  void applyDiscount(int pointsToRedeem) {
    _redeemedPoints = pointsToRedeem;
    _discount = pointsToRedeem.toDouble();
    notifyListeners();
  }

  /// Remove member points discount.
  void clearDiscount() {
    _discount = 0.0;
    _redeemedPoints = 0;
    notifyListeners();
  }

  /// Remove all items and member state from the cart.
  void clear() {
    _items.clear();
    _member = null;
    _memberPhone = null;
    _discount = 0.0;
    _redeemedPoints = 0;
    notifyListeners();
  }
}
