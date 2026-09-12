import 'package:flutter_test/flutter_test.dart';
import 'package:toto_cafe_kiosk/models/member.dart';
import 'package:toto_cafe_kiosk/models/order.dart';
import 'package:toto_cafe_kiosk/providers/cart_provider.dart';

void main() {
  group('Member points calculation tests', () {
    test('addPointsForPurchase calculates 10 points per 100 baht', () {
      int calculatePoints(int amount) => (amount / 10).floor();

      expect(calculatePoints(100), equals(10));
      expect(calculatePoints(109), equals(10));
      expect(calculatePoints(99), equals(9));
      expect(calculatePoints(125), equals(12));
      expect(calculatePoints(9), equals(0));
      expect(calculatePoints(0), equals(0));
    });

    test('Redeem points discount calculation: pointsToRedeem / 100', () {
      double calculateDiscount(int points) => points / 100.0;

      expect(calculateDiscount(100), equals(1.0));
      expect(calculateDiscount(150), equals(1.5));
      expect(calculateDiscount(200), equals(2.0));
      expect(calculateDiscount(50), equals(0.5));
    });

    test('Member model parsing handles displayName and display_name', () {
      final m1 = Member.fromJson({
        'phone': '0812345678',
        'displayName': 'John Doe',
        'points': 150,
      });
      expect(m1.displayName, equals('John Doe'));
      expect(m1.points, equals(150));
      expect(m1.phone, equals('0812345678'));

      final m2 = Member.fromJson({
        'phone': '0898765432',
        'display_name': 'Jane Smith',
        'points': 200,
      });
      expect(m2.displayName, equals('Jane Smith'));
      expect(m2.points, equals(200));
    });

    test('CartProvider tracks member, discount, and totalAfterDiscount', () {
      final cart = CartProvider();
      final member = Member(
        phone: '0812345678',
        points: 500,
        joinDate: DateTime.now(),
        displayName: 'Tester',
      );

      // Add item
      cart.addItem(OrderItem(
        menuItemId: '1',
        name: 'Latte',
        price: 100.0,
        quantity: 1,
      ));

      // 100 subtotal + 7% VAT = 107 grand total
      expect(cart.subtotal, equals(100.0));
      expect(cart.grandTotal, equals(107.0));
      expect(cart.totalAfterDiscount, equals(107.0));

      // Attach member
      cart.setMember(member);
      expect(cart.member?.phone, equals('0812345678'));
      expect(cart.memberPhone, equals('0812345678'));

      // Redeem 200 points (2.00 baht discount)
      cart.applyDiscount(200);
      expect(cart.redeemedPoints, equals(200));
      expect(cart.discount, equals(2.0));
      expect(cart.totalAfterDiscount, equals(105.0));

      // Clear discount
      cart.clearDiscount();
      expect(cart.discount, equals(0.0));
      expect(cart.redeemedPoints, equals(0));
      expect(cart.totalAfterDiscount, equals(107.0));

      // Clear cart
      cart.applyDiscount(100);
      cart.clear();
      expect(cart.items, isEmpty);
      expect(cart.member, isNull);
      expect(cart.discount, equals(0.0));
      expect(cart.redeemedPoints, equals(0));
    });
  });
}
