import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import '../models/order.dart';

/// Service for creating and updating orders in the `orders` Firestore
/// collection, following the schema defined in AGENTS.md.
class OrderService {
  OrderService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('orders');

  // ── Writes ───────────────────────────────────────────────────────────────

  /// Create a new order document in Firestore.
  ///
  /// Returns the [Order] with its new Firestore document [id] populated.
  Future<Order> createOrder(Order order) async {
    final ref = await _collection.add(order.toJson());
    return order.copyWith(id: ref.id);
  }

  /// Update the [status] field on an existing order.
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    await _collection.doc(orderId).update({'status': status.value});
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  /// Real-time stream of a single order document.
  ///
  /// Emits every time the order is updated — used by the kiosk to react
  /// when a cashier approves a QR payment.
  Stream<Order?> watchOrder(String orderId) {
    return _collection
        .doc(orderId)
        .snapshots()
        .map((snap) => snap.exists ? Order.fromSnapshot(snap) : null);
  }

  /// Stream all orders with status in [pendingPayment, awaitingApproval],
  /// ordered by createdAt ascending. Optionally filters by [paymentMethod] (e.g. Cash or QR).
  Stream<List<Order>> watchPendingOrders({PaymentMethod? paymentMethod}) {
    return _collection
        .where(
          'status',
          whereIn: [
            OrderStatus.pendingPayment.value,
            OrderStatus.awaitingApproval.value,
          ],
        )
        .snapshots()
        .map((snap) {
      var orders =
          snap.docs.map((doc) => Order.fromSnapshot(doc)).toList();
      if (paymentMethod != null) {
        orders = orders.where((o) => o.paymentMethod == paymentMethod).toList();
      }
      orders.sort((a, b) {
        final aCreated = a.createdAt ?? DateTime.now();
        final bCreated = b.createdAt ?? DateTime.now();
        return aCreated.compareTo(bCreated);
      });
      debugPrint('[POS] watchPendingOrders snapshot: ${orders.length} orders');
      return orders;
    });
  }

  /// Update order status to paid
  Future<void> approveOrder(String orderId) async {
    debugPrint('[POS] approveOrder called for $orderId');
    await updateStatus(orderId, OrderStatus.paid);
  }

  /// Update order status to paid and record cash payment details.
  Future<void> approveCashOrder(
    String orderId, {
    required double receivedAmount,
    required double changeAmount,
  }) async {
    debugPrint('[POS] approveCashOrder called for $orderId: received=$receivedAmount, change=$changeAmount');
    await _collection.doc(orderId).update({
      'status': OrderStatus.paid.value,
      'received_amount': receivedAmount,
      'change_amount': changeAmount,
    });
  }

  /// Delete an order document from Firestore (e.g. canceled counter QR order).
  Future<void> deleteOrder(String orderId) async {
    debugPrint('[POS] deleteOrder called for $orderId');
    await _collection.doc(orderId).delete();
  }

  /// Cancel an order by updating status to cancelled.
  Future<void> cancelOrder(String orderId) async {
    debugPrint('[OrderService] cancelOrder called for $orderId');
    await updateStatus(orderId, OrderStatus.cancelled);
  }

  /// Get the next queue number by counting existing orders for today.
  ///
  /// A simple incrementing queue; for production you would use a
  /// Firestore transaction or Cloud Function counter.
  Future<int> nextQueueNumber() async {
    final todayStart = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
    );

    final snap = await _collection
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .count()
        .get();

    return (snap.count ?? 0) + 1;
  }
}
