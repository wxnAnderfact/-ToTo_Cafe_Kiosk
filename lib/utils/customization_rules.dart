import '../models/order.dart';

enum ItemCategory { hotCoffee, coldBrew, nonCoffee, bakery }

class CustomizationRules {
  /// Items that belong to bakery (no sweetness, no milk).
  static const bakeryItems = [
    'Almond Croissant',
    'Banana Bread',
  ];

  /// Items that do NOT use milk at all.
  static const noMilkItems = [
    'Americano',
    'Classic Cold Brew',
    'Thai Tea',
    'Matcha Latte',
    'Almond Croissant',
    'Banana Bread',
  ];

  /// Show sweetness for drinks (hot coffee, cold brew, non-coffee).
  /// Hide for bakery items.
  static bool showSweetness(String category, [String? itemName]) {
    final cat = category.toLowerCase().replaceAll(' ', '_');
    if (cat == 'bakery') return false;
    if (itemName != null && bakeryItems.contains(itemName)) return false;
    return true;
  }

  /// Show milk options ONLY for coffee drinks that use milk.
  static bool showMilkTypeForItem(String itemName) {
    return !noMilkItems.contains(itemName);
  }

  /// Formats modifier string for an order item, omitting non-applicable options.
  /// E.g.:
  /// - Hot Latte: "Sweetness: 100% • Milk: Regular"
  /// - Americano: "Sweetness: 100%" (no milk)
  /// - Almond Croissant: null (no modifiers)
  static String? getModifierSummary(
    OrderItem item, {
    bool includeLabels = true,
  }) {
    final hasSweetness = showSweetness('', item.name);
    final hasMilk = showMilkTypeForItem(item.name);

    if (!hasSweetness && !hasMilk) return null;

    final parts = <String>[];
    if (hasSweetness) {
      parts.add(includeLabels ? 'Sweetness: ${item.sweetness.label}' : item.sweetness.label);
    }
    if (hasMilk) {
      parts.add(includeLabels ? 'Milk: ${item.milkType.label}' : item.milkType.label);
    }

    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }
}
