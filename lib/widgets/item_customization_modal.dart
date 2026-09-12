import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';
import '../models/order.dart';
import '../utils/customization_rules.dart';

/// Item customization modal — DESIGN.md §6 "Modal (item customization)".
///
/// Layout:
///   - Hero image full-width at top, rounded top corners only (supports network & asset URLs)
///   - Eyebrow label → serif product name → muted description
///   - Smart Option groups based on CustomizationRules:
///     - Sweetness (Drinks)
///     - Milk Type (Drinks with milk)
///     - "ไม่มีตัวเลือกเพิ่มเติม" note for Bakery / no-option items
///     - Quantity selector
///   - Sticky footer button: full-width primary pill, "เพิ่มลงตะกร้า" left / price right
///
/// Returns an [OrderItem] if the user confirms, or `null` if dismissed.
class ItemCustomizationModal extends StatefulWidget {
  const ItemCustomizationModal({
    super.key,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.imagePath,
    required this.category,
    this.description,
  });

  final String menuItemId;
  final String name;
  final double price;
  final String imagePath;
  final String category;
  final String? description;

  /// Show the modal and return the configured [OrderItem], or `null`.
  static Future<OrderItem?> show(
    BuildContext context, {
    required String menuItemId,
    required String name,
    required double price,
    required String imagePath,
    required String category,
    String? description,
  }) {
    return showDialog<OrderItem>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ItemCustomizationModal(
        menuItemId: menuItemId,
        name: name,
        price: price,
        imagePath: imagePath,
        category: category,
        description: description,
      ),
    );
  }

  static List<String> getMilkOptions(String itemName) {
    if (itemName == 'Thai Tea') {
      return ['นมข้นหวาน', 'นมสด', 'นมข้นจืด'];
    }
    if (itemName == 'Matcha Latte') {
      return ['นมสด', 'นมโอ๊ต', 'นมอัลมอนด์'];
    }
    // Default coffee milk options:
    return ['Regular', 'นมโอ๊ต', 'นมอัลมอนด์'];
  }

  @override
  State<ItemCustomizationModal> createState() =>
      _ItemCustomizationModalState();
}

class _ItemCustomizationModalState extends State<ItemCustomizationModal> {
  // ── State ───────────────────────────────────────────────────────────────
  SweetnessLevel _selectedSweetness = SweetnessLevel.hundred;
  late String _selectedMilk;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    final options = ItemCustomizationModal.getMilkOptions(widget.name);
    _selectedMilk = options.first;
  }

  String _getMilkLabel(LocaleProvider locale, String milk) {
    switch (milk) {
      case 'Regular':
        return locale.t('นมสด', 'Regular Milk');
      case 'นมโอ๊ต':
        return locale.t('นมโอ๊ต', 'Oat Milk');
      case 'นมอัลมอนด์':
        return locale.t('นมอัลมอนด์', 'Almond Milk');
      case 'นมข้นหวาน':
        return locale.t('นมข้นหวาน', 'Condensed Milk');
      case 'นมสด':
        return locale.t('นมสด', 'Fresh Milk');
      case 'นมข้นจืด':
        return locale.t('นมข้นจืด', 'Evaporated Milk');
      default:
        return milk;
    }
  }

  void _onConfirm() {
    final showSweetness = CustomizationRules.showSweetness(widget.category, widget.name);
    final showMilk = CustomizationRules.showMilkTypeForItem(widget.name);

    final item = OrderItem(
      menuItemId: widget.menuItemId,
      name: widget.name,
      price: widget.price,
      quantity: _quantity,
      sweetness: showSweetness ? _selectedSweetness : SweetnessLevel.hundred,
      milkType: showMilk ? MilkType.fromString(_selectedMilk) : MilkType.regular,
    );
    Navigator.of(context).pop(item);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();
    final showSweetness = CustomizationRules.showSweetness(widget.category, widget.name);
    final showMilk = CustomizationRules.showMilkTypeForItem(widget.name);
    final isBakeryOrNoOptions = !showSweetness && !showMilk;

    return Center(
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        margin: const EdgeInsets.all(kSpace24),
        decoration: BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.circular(kRadiusModal),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusModal),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Hero image + close button ───────────────────────────
                _buildHeroImage(theme),

                // ── Content (scrollable) ────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace24,
                      kSpace16,
                      kSpace24,
                      kSpace8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Eyebrow label
                        Text(
                          isBakeryOrNoOptions
                              ? locale.t('ปรับแต่งรายการ', 'CUSTOMIZE YOUR FOOD')
                              : locale.t('ปรับแต่งเครื่องดื่ม', 'CUSTOMIZE YOUR DRINK'),
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: kSpace8),

                        // Product name (serif)
                        Text(
                          widget.name,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: kSpace4),

                        // Description (muted)
                        if (widget.description != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: kSpace16),
                            child: Text(
                              widget.description!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),

                        const SizedBox(height: kSpace16),

                        // ── If Bakery / No options: show notice ─────────
                        if (isBakeryOrNoOptions) ...[
                          Container(
                            padding: const EdgeInsets.all(kSpace12),
                            decoration: BoxDecoration(
                              color: kColorBg,
                              borderRadius: BorderRadius.circular(kRadiusBadge),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 20, color: kColorTextMuted),
                                const SizedBox(width: kSpace8),
                                Text(
                                  locale.t('ไม่มีตัวเลือกเพิ่มเติม', 'No extra options'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: kColorTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: kSpace16),
                        ],

                        // ── Sweetness group ─────────────────────────────
                        if (showSweetness) ...[
                          _buildOptionGroup(
                            theme: theme,
                            label: locale.t('ระดับความหวาน', 'SWEETNESS'),
                            child: Wrap(
                              spacing: kSpace8,
                              runSpacing: kSpace8,
                              children: SweetnessLevel.values.map((level) {
                                final isSelected = _selectedSweetness == level;
                                return _OptionChip(
                                  label: level.label,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() => _selectedSweetness = level);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: kSpace24),
                        ],

                        // ── Milk type group ─────────────────────────────
                        if (showMilk) ...[
                          _buildOptionGroup(
                            theme: theme,
                            label: locale.t('ชนิดนม', 'MILK TYPE'),
                            child: Wrap(
                              spacing: kSpace8,
                              runSpacing: kSpace8,
                              children: ItemCustomizationModal.getMilkOptions(widget.name).map((milkOption) {
                                final isSelected = _selectedMilk == milkOption;
                                return _OptionChip(
                                  label: _getMilkLabel(locale, milkOption),
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() => _selectedMilk = milkOption);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: kSpace24),
                        ],

                        // ── Quantity Selector ────────────────────────────
                        _buildOptionGroup(
                          theme: theme,
                          label: locale.t('จำนวน', 'QUANTITY'),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                iconSize: 28,
                                color: kColorPrimary,
                              ),
                              Container(
                                width: 48,
                                alignment: Alignment.center,
                                child: Text(
                                  '$_quantity',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _quantity++),
                                icon: const Icon(Icons.add_circle_outline),
                                iconSize: 28,
                                color: kColorPrimary,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: kSpace16),
                      ],
                    ),
                  ),
                ),

                // ── Sticky footer CTA ───────────────────────────────────
                _buildFooterButton(theme, locale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero image with close button ────────────────────────────────────────

  Widget _buildHeroImage(ThemeData theme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kRadiusModal),
          ),
          child: Image.asset(
            widget.imagePath,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: double.infinity,
              height: 200,
              color: kTan,
              child: const Icon(Icons.coffee, size: 40, color: kCoffee500),
            ),
          ),
        ),

        // Close (×) button — top-right, circular, subtle bg
        Positioned(
          top: kSpace12,
          right: kSpace12,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: kColorWhite,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Option group (eyebrow label + chips row) ────────────────────────────

  Widget _buildOptionGroup({
    required ThemeData theme,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: kSpace12),
        child,
      ],
    );
  }

  // ── Sticky footer button (primary pill, label left / price right) ──────

  Widget _buildFooterButton(ThemeData theme, LocaleProvider locale) {
    final lineTotal = widget.price * _quantity;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        kSpace24,
        kSpace12,
        kSpace24,
        kSpace24,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _onConfirm,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(locale.t('เพิ่มลงตะกร้า', 'Add to Cart')),
              Text('฿${lineTotal.toStringAsFixed(0)}'),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace16,
          vertical: kSpace12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? kColorPrimary : Colors.transparent,
          border: Border.all(
            color: isSelected ? kColorPrimary : kColorBorder,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected ? kColorWhite : kColorTextBody,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }
}
