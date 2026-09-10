import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
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
