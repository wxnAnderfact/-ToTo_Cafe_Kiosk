import 'package:flutter_test/flutter_test.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import 'package:toto_cafe_kiosk/models/order.dart';
import 'package:toto_cafe_kiosk/services/menu_service.dart';
import 'package:toto_cafe_kiosk/utils/vat_calculator.dart';

void main() {
  group('Task 1: Local Image Assets Mapping', () {
    test('menuImageMap contains all 9 items with local assets/images/ paths', () {
      expect(menuImageMap['Americano'], 'assets/images/americano.png');
      expect(menuImageMap['Cappuccino'], 'assets/images/cappuccino.png');
      expect(menuImageMap['Hot Latte'], 'assets/images/hot_coffee.png');
      expect(menuImageMap['Classic Cold Brew'], 'assets/images/cold_brew.png');
      expect(menuImageMap['Iced Mocha'], 'assets/images/iced_mocha.png');
      expect(menuImageMap['Matcha Latte'], 'assets/images/matcha_latte.png');
      expect(menuImageMap['Thai Tea'], 'assets/images/thai_tea.png');
      expect(menuImageMap['Almond Croissant'], 'assets/images/almond_croissant.png');
      expect(menuImageMap['Banana Bread'], 'assets/images/banana_bread.png');
      expect(menuImageMap.length, 9);
    });
  });

  group('Task 2: Counter Order Payment Logic', () {
    test('Counter Cash order has paymentMethod cash and status paid immediately', () {
      final subtotal = 100.0;
      final vat = calculateVat(subtotal);
      final total = calculateGrandTotal(subtotal);

      final order = Order(
        items: const [],
        status: OrderStatus.paid,
        paymentMethod: PaymentMethod.cash,
        queueNumber: 1,
        subtotal: subtotal,
        vat: vat,
        total: total,
      );

      expect(order.paymentMethod, PaymentMethod.cash);
      expect(order.status, OrderStatus.paid);
      expect(order.toJson()['payment_method'], 'cash');
      expect(order.toJson()['status'], 'paid');
    });

    test('Counter QR order has paymentMethod qr and status awaiting_approval', () {
      final subtotal = 100.0;
      final vat = calculateVat(subtotal);
      final total = calculateGrandTotal(subtotal);

      final order = Order(
        items: const [],
        status: OrderStatus.awaitingApproval,
        paymentMethod: PaymentMethod.qr,
        queueNumber: 2,
        subtotal: subtotal,
        vat: vat,
        total: total,
      );

      expect(order.paymentMethod, PaymentMethod.qr);
      expect(order.status, OrderStatus.awaitingApproval);
      expect(order.toJson()['payment_method'], 'qr');
      expect(order.toJson()['status'], 'awaiting_approval');
    });

    test('PromptPay payload generates correctly for mobile and national ID', () {
      final total = 107.0;
      final amountSatang = (total * 100).round();

      // Mobile format (10 digits converts to 0066... in EMVCo standard)
      final mobilePayload = promptPayMobile('0812345678', amountSatang: amountSatang);
      expect(mobilePayload, contains('0066812345678'));
      expect(mobilePayload, contains('107.00'));

      // National ID format (13 digits with valid checksum)
      final idPayload = promptPayNationalId('1100100000018', amountSatang: amountSatang);
      expect(idPayload, contains('1100100000018'));
      expect(idPayload, contains('107.00'));
    });
  });
}
