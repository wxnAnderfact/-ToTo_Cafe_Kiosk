import 'package:flutter_test/flutter_test.dart';
import 'package:toto_cafe_kiosk/models/order.dart';
import 'package:toto_cafe_kiosk/utils/customization_rules.dart';

void main() {
  group('CustomizationRules tests', () {
    test('showSweetness returns false for bakery items and true for drinks', () {
      expect(CustomizationRules.showSweetness('bakery'), isFalse);
      expect(CustomizationRules.showSweetness('Bakery'), isFalse);
      expect(CustomizationRules.showSweetness('', 'Almond Croissant'), isFalse);
      expect(CustomizationRules.showSweetness('', 'Banana Bread'), isFalse);

      expect(CustomizationRules.showSweetness('hot_coffee'), isTrue);
      expect(CustomizationRules.showSweetness('cold_brew'), isTrue);
      expect(CustomizationRules.showSweetness('non_coffee'), isTrue);
      expect(CustomizationRules.showSweetness('hot_coffee', 'Americano'), isTrue);
    });

    test('showMilkTypeForItem excludes drinks without milk and bakery', () {
      expect(CustomizationRules.showMilkTypeForItem('Americano'), isFalse);
      expect(CustomizationRules.showMilkTypeForItem('Classic Cold Brew'), isFalse);
      expect(CustomizationRules.showMilkTypeForItem('Thai Tea'), isFalse);
      expect(CustomizationRules.showMilkTypeForItem('Matcha Latte'), isFalse);
      expect(CustomizationRules.showMilkTypeForItem('Almond Croissant'), isFalse);
      expect(CustomizationRules.showMilkTypeForItem('Banana Bread'), isFalse);

      expect(CustomizationRules.showMilkTypeForItem('Hot Latte'), isTrue);
      expect(CustomizationRules.showMilkTypeForItem('Cappuccino'), isTrue);
      expect(CustomizationRules.showMilkTypeForItem('Iced Mocha'), isTrue);
    });

    test('getModifierSummary formats only applicable modifiers', () {
      final latte = OrderItem(
        menuItemId: '1',
        name: 'Hot Latte',
        price: 45,
        quantity: 1,
        sweetness: SweetnessLevel.fifty,
        milkType: MilkType.oat,
      );
      expect(
        CustomizationRules.getModifierSummary(latte),
        'Sweetness: 50% • Milk: Oat Milk',
      );

      final americano = OrderItem(
        menuItemId: '2',
        name: 'Americano',
        price: 40,
        quantity: 1,
        sweetness: SweetnessLevel.zero,
        milkType: MilkType.regular,
      );
      expect(
        CustomizationRules.getModifierSummary(americano),
        'Sweetness: 0%',
      );

      final croissant = OrderItem(
        menuItemId: '3',
        name: 'Almond Croissant',
        price: 65,
        quantity: 1,
        sweetness: SweetnessLevel.hundred,
        milkType: MilkType.regular,
      );
      expect(
        CustomizationRules.getModifierSummary(croissant),
        isNull,
      );
    });
  });
}
