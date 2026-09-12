import 'package:flutter_test/flutter_test.dart';
import 'package:toto_cafe_kiosk/models/order.dart';

void main() {
  group('OrderStatus Enum and Serialization Mapping', () {
    test('OrderStatus values map to correct Firestore strings', () {
      expect(OrderStatus.pendingPayment.value, 'pending_payment');
      expect(OrderStatus.awaitingApproval.value, 'awaiting_approval');
      expect(OrderStatus.paid.value, 'paid');
      expect(OrderStatus.preparing.value, 'preparing');
      expect(OrderStatus.ready.value, 'ready');
      expect(OrderStatus.completed.value, 'completed');
    });

    test('OrderStatus.fromString parses Firestore strings correctly', () {
      expect(OrderStatus.fromString('pending_payment'), OrderStatus.pendingPayment);
      expect(OrderStatus.fromString('awaiting_approval'), OrderStatus.awaitingApproval);
      expect(OrderStatus.fromString('paid'), OrderStatus.paid);
      expect(OrderStatus.fromString('preparing'), OrderStatus.preparing);
      expect(OrderStatus.fromString('ready'), OrderStatus.ready);
      expect(OrderStatus.fromString('completed'), OrderStatus.completed);
    });

    test('Order serialization preserves pending_payment status', () {
      final order = Order(
        items: [],
        status: OrderStatus.pendingPayment,
        paymentMethod: PaymentMethod.qr,
        queueNumber: 1,
        subtotal: 100,
        vat: 7,
        total: 107,
        createdAt: DateTime.now(),
      );

      final json = order.toJson();
      expect(json['status'], 'pending_payment');

      final deserialized = Order.fromJson(json, id: 'test_order_1');
      expect(deserialized.status, OrderStatus.pendingPayment);
      expect(deserialized.id, 'test_order_1');
    });

    test('In-memory sorting of orders by createdAt ascending', () {
      final now = DateTime.now();
      final order1 = Order(
        id: '1',
        items: [],
        status: OrderStatus.pendingPayment,
        paymentMethod: PaymentMethod.qr,
        queueNumber: 1,
        subtotal: 100,
        vat: 7,
        total: 107,
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      final order2 = Order(
        id: '2',
        items: [],
        status: OrderStatus.pendingPayment,
        paymentMethod: PaymentMethod.qr,
        queueNumber: 2,
        subtotal: 100,
        vat: 7,
        total: 107,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );
      final order3 = Order(
        id: '3',
        items: [],
        status: OrderStatus.pendingPayment,
        paymentMethod: PaymentMethod.cash,
        queueNumber: 3,
        subtotal: 100,
        vat: 7,
        total: 107,
        createdAt: now,
      );

      final orders = [order1, order2, order3];
      orders.sort((a, b) {
        final aCreated = a.createdAt ?? DateTime.now();
        final bCreated = b.createdAt ?? DateTime.now();
        return aCreated.compareTo(bCreated);
      });

      expect(orders.map((o) => o.id).toList(), ['2', '1', '3']);
    });
  });
}
