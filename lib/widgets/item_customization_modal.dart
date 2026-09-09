import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/order.dart';

/// Item customization modal — DESIGN.md §6 "Modal (item customization)".
///
/// Layout:
///   - Hero image full-width at top, rounded top corners only
///   - Eyebrow label → serif product name → muted description
///   - Option groups (Sweetness, Milk Type): eyebrow label, then row of pill chips
///   - Sticky footer button: full-width primary pill, label left / price right
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

  @override
  State<ItemCustomizationModal> createState() =>
      _ItemCustomizationModalState();
}

class _ItemCustomizationModalState extends State<ItemCustomizationModal> {
  // ── State ───────────────────────────────────────────────────────────────
  SweetnessLevel _selectedSweetness = SweetnessLevel.hundred;
  MilkType _selectedMilkType = MilkType.regular;

  void _onConfirm() {
    final item = OrderItem(
      menuItemId: widget.menuItemId,
      name: widget.name,
      price: widget.price,
      quantity: 1,
      sweetness: _selectedSweetness,
      milkType: _selectedMilkType,
    );
    Navigator.of(context).pop(item);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                          'CUSTOMIZE YOUR DRINK',
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
                            padding:
                                const EdgeInsets.only(bottom: kSpace16),
                            child: Text(
                              widget.description!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),

                        const SizedBox(height: kSpace24),

                        if (['hot_coffee', 'cold_brew', 'non_coffee'].contains(widget.category)) ...[
                          // ── Sweetness group ─────────────────────────────
                          _buildOptionGroup(
                            theme: theme,
                            label: 'SWEETNESS',
                            child: Wrap(
                              spacing: kSpace8,
                              runSpacing: kSpace8,
                              children: SweetnessLevel.values.map((level) {
                                final isSelected =
                                    _selectedSweetness == level;
                                return _OptionChip(
                                  label: level.label,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(
                                        () => _selectedSweetness = level);
                                  },
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: kSpace24),

                          // ── Milk type group ─────────────────────────────
                          _buildOptionGroup(
                            theme: theme,
                            label: 'MILK TYPE',
                            child: Wrap(
                              spacing: kSpace8,
                              runSpacing: kSpace8,
                              children: MilkType.values.map((milk) {
                                final isSelected =
                                    _selectedMilkType == milk;
                                return _OptionChip(
                                  label: milk.label,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(
                                        () => _selectedMilkType = milk);
                                  },
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: kSpace16),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Sticky footer CTA ───────────────────────────────────
                _buildFooterButton(theme),
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
        // Hero image — full width, rounded top corners only
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kRadiusModal),
          ),
          child: Image.asset(
            widget.imagePath,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
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

  Widget _buildFooterButton(ThemeData theme) {
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
              const Text('Add to Cart'),
              Text('฿${widget.price.toStringAsFixed(0)}'),
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

/// A pill-shaped option chip matching DESIGN.md §6 "Chips":
///
/// - **Unselected**: transparent bg, `--color-border` outline,
///   `--color-text-body` text, pill radius.
/// - **Selected**: `--color-primary` bg, white text, pill radius.
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
