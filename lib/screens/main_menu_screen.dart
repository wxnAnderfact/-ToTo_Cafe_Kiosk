import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/menu_item.dart' as model;
import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../services/menu_service.dart';
import '../utils/customization_rules.dart';
import '../widgets/item_customization_modal.dart';
import '../widgets/language_toggle.dart';
import 'checkout_screen.dart';

/// หน้า 2: Main Menu
///
/// 3-column layout (portrait tablet / kiosk):
///   Left  (~180px) — Category navigation
///   Center (flex)  — Product card grid (max 3 per row)
///   Right  (~300px) — Order summary / cart panel
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  // ── State ───────────────────────────────────────────────────────────────
  int _selectedCategoryIndex = 0;

  // Category definitions — keys match Firestore `category` field values
  static const _categories = [
    _Category(key: 'hot_coffee', label: 'Hot Coffee', icon: Icons.coffee),
    _Category(key: 'cold_brew', label: 'Cold Brew', icon: Icons.local_cafe),
    _Category(key: 'non_coffee', label: 'Non-Coffee', icon: Icons.emoji_food_beverage),
    _Category(key: 'bakery', label: 'Bakery', icon: Icons.bakery_dining),
  ];

  String get _selectedCategoryKey =>
      _categories[_selectedCategoryIndex].key;

  Stream<List<model.MenuItem>>? _menuStream;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
    // Delay slightly to ensure context is fully ready for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _updateStream();
      });
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 1), _onInactivityTimeout);
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 1), _onInactivityTimeout);
  }

  void _onInactivityTimeout() {
    if (!mounted) return;
    // Only return to home if MainMenuScreen is currently the active top route
    if (ModalRoute.of(context)?.isCurrent != true) {
      _inactivityTimer?.cancel();
      return;
    }
    // Dismiss any open modal/dialog first
    try {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    } catch (_) {}
    // Clear cart and return to standby screen
    context.read<CartProvider>().clear();
    try {
      context.go('/kiosk');
    } catch (_) {
      Navigator.of(context).pushReplacementNamed('/kiosk');
    }
  }

  Future<void> _onBackToHome(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final locale = context.read<LocaleProvider>();

    if (cart.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(locale.t('ย้อนกลับหน้าแรก?', 'Return to Home?')),
          content: Text(
            locale.t(
              'รายการในตะกร้าจะถูกยกเลิก ต้องการกลับสู่หน้าแรกใช่หรือไม่?',
              'Your cart items will be cleared. Do you want to return to home screen?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(locale.t('อยู่ต่อ', 'Stay')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(locale.t('กลับหน้าแรก', 'Return to Home')),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _inactivityTimer?.cancel();
    if (!context.mounted) return;
    context.read<CartProvider>().clear();
    try {
      context.go('/kiosk');
    } catch (_) {
      Navigator.of(context).pushReplacementNamed('/kiosk');
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _updateStream() {
    _menuStream = context.read<MenuService>().watchByCategory(_selectedCategoryKey);
  }

  String _getCategoryLabel(LocaleProvider locale, String key) {
    switch (key) {
      case 'hot_coffee':
        return locale.t('กาแฟร้อน', 'Hot Coffee');
      case 'cold_brew':
        return locale.t('โคลด์บรู', 'Cold Brew');
      case 'non_coffee':
        return locale.t('ไม่มีกาแฟ', 'Non-Coffee');
      case 'bakery':
        return locale.t('เบเกอรี่', 'Bakery');
      default:
        return key;
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  Future<void> _onProceedToPayment() async {
    _inactivityTimer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CheckoutScreen(),
      ),
    );
    if (mounted) {
      _startInactivityTimer();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      onPointerUp: (_) => _resetInactivityTimer(),
      child: Scaffold(
        body: Row(
          children: [
            // ═══════════════════════════════════════════════════════════════
            // LEFT COLUMN — Category Navigation (~160px on iPad)
            // ═══════════════════════════════════════════════════════════════
            SizedBox(
              width: 160,
              child: _buildCategoryNav(locale),
            ),

            // Vertical divider
            const VerticalDivider(width: 1),

            // ═══════════════════════════════════════════════════════════════
            // CENTER COLUMN — Product Grid (flexible fill)
            // ═══════════════════════════════════════════════════════════════
            Expanded(
              child: _buildProductGrid(locale),
            ),

            // Vertical divider
            const VerticalDivider(width: 1),

            // ═══════════════════════════════════════════════════════════════
            // RIGHT COLUMN — Cart / Order Summary (~280px on iPad)
            // ═══════════════════════════════════════════════════════════════
            SizedBox(
              width: 280,
              child: _buildCartPanel(locale),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left: Category Nav ──────────────────────────────────────────────────

  Widget _buildCategoryNav(LocaleProvider locale) {
    return Container(
      color: kColorSurface,
      child: Column(
        children: [
          // Header / logo area + Back to Home button
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF3F5F35), width: 2),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logo_toto.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "ToTo's Cafe",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A2F1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _onBackToHome(context),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: Text(
                      locale.t('กลับหน้าแรก', 'Home'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A2F1E),
                      backgroundColor: const Color(0xFFEDE5D4),
                      side: const BorderSide(color: Color(0xFFCBB89F), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Category list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: kSpace8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return _CategoryItem(
                  label: _getCategoryLabel(locale, _categories[index].key),
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                      _updateStream();
                    });
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Back to Home button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _onBackToHome(context),
                icon: const Icon(Icons.home_outlined, size: 20),
                label: Text(
                  locale.t('กลับหน้าแรก', 'Back to Home'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6B4A35),
                  side: const BorderSide(color: Color(0xFFD5C4B1), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Center: Product Grid (Firestore-backed) ─────────────────────────────

  Widget _buildProductGrid(LocaleProvider locale) {

    return Container(
      color: kColorBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpace24,
              kSpace24,
              kSpace24,
              kSpace16,
            ),
            child: Text(
              _getCategoryLabel(locale, _selectedCategoryKey),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),

          // Product grid — real-time Firestore stream
          Expanded(
            child: StreamBuilder<List<model.MenuItem>>(
              stream: _menuStream,
              builder: (context, snapshot) {
                // ── Loading state ──────────────────────────────────────
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kColorPrimary),
                  );
                }

                // ── Error state ───────────────────────────────────────
                if (snapshot.hasError) {
                  // If we already have data, keep showing it and just
                  // notify the user with a non-destructive SnackBar.
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connection issue: ${snapshot.error}'),
                            duration: const Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    });
                    // Fall through to render data below
                  } else {
                    // No cached data at all — show full-screen error
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(kSpace24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: kColorTextMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: kSpace12),
                            Text(
                              locale.t('โหลดเมนูไม่สำเร็จ', 'Failed to load menu'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: kColorTextMuted),
                            ),
                            const SizedBox(height: kSpace8),
                            Text(
                              '${snapshot.error}',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }

                final items = snapshot.data ?? [];

                // ── Empty state ───────────────────────────────────────
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 48,
                          color: kColorTextMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: kSpace12),
                        Text(
                          locale.t('ไม่มีสินค้าในหมวดหมู่นี้', 'No items in this category'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: kColorTextMuted),
                        ),
                      ],
                    ),
                  );
                }

                // ── Data state ────────────────────────────────────────
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace24,
                    vertical: kSpace8,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: kSpace16,
                    crossAxisSpacing: kSpace16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final menuItem = items[index];
                    return _ProductCard(
                      name: menuItem.name,
                      price: menuItem.price,
                      imagePath: menuItem.imageUrl ??
                          'assets/images/hot_coffee.png',
                      onAddToCart: () async {
                        _inactivityTimer?.cancel();
                        final item = await ItemCustomizationModal.show(
                          context,
                          menuItemId: menuItem.id ?? '',
                          name: menuItem.name,
                          price: menuItem.price,
                          imagePath: menuItem.imageUrl ??
                              'assets/images/hot_coffee.png',
                          category: menuItem.category,
                          description: menuItem.description,
                        );
                        if (item != null && context.mounted) {
                          context.read<CartProvider>().addItem(item);
                        }
                        if (mounted) {
                          _startInactivityTimer();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Right: Cart Panel ───────────────────────────────────────────────────

  Widget _buildCartPanel(LocaleProvider locale) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final theme = Theme.of(context);

        return Container(
          color: kColorSurface,
          child: Column(
            children: [
              // Cart header
              Padding(
                padding: const EdgeInsets.all(kSpace16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        locale.t('ตะกร้า', 'Cart'),
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: kSpace8),
                    // Item count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpace12,
                        vertical: kSpace4,
                      ),
                      decoration: BoxDecoration(
                        color: kColorBg,
                        borderRadius: BorderRadius.circular(kRadiusPill),
                      ),
                      child: Text(
                        '${cart.totalQuantity} ${locale.t("ชิ้น", "items")}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: kSpace8),
                    const LanguageToggle(),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Cart items list
              Expanded(
                child: cart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 48,
                              color: kColorTextMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: kSpace12),
                            Text(
                              locale.t('ตะกร้าว่าง', 'Cart is empty'),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: kColorTextMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(kSpace16),
                        itemCount: cart.items.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: kSpace12),
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return _CartLineItem(
                            item: item,
                            onIncrement: () => cart.incrementQuantity(index),
                            onDecrement: () => cart.decrementQuantity(index),
                            onRemove: () => cart.removeItemAt(index),
                          );
                        },
                      ),
              ),

              // ── Totals & CTA ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(kSpace16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: kColorBorder)),
                ),
                child: Column(
                  children: [
                    // Grand total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          locale.t('ยอดรวม', 'Total'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '฿${cart.grandTotal.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace16),
                    // Proceed button (secondary CTA — dark brown pill)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            cart.isNotEmpty ? _onProceedToPayment : null,
                        child: Text(locale.t('ดำเนินการชำระเงิน', 'Proceed to Payment')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private data class for category definitions
// ═════════════════════════════════════════════════════════════════════════════

/// Maps a display label to a Firestore category key.
class _Category {
  const _Category({
    required this.key,
    required this.label,
    required this.icon,
  });

  /// Firestore `category` field value (e.g. "hot_coffee").
  final String key;

  /// Display label shown in the sidebar (e.g. "Hot Coffee").
  final String label;

  /// Icon shown alongside the label.
  final IconData icon;
}

// ═════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

/// A single item in the category sidebar.
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace8,
        vertical: kSpace4,
      ),
      child: Material(
        color: isSelected ? kColorPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace16,
              vertical: kSpace12,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isSelected ? kColorWhite : kColorTextBody,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A product card in the center grid.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.imagePath,
    required this.onAddToCart,
  });

  final String name;
  final double price;
  final String imagePath;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(kRadiusCard),
              ),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.coffee, color: kCoffee500, size: 40),
                ),
              ),
            ),
          ),

          // Info section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpace12,
                vertical: kSpace8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '฿${price.toStringAsFixed(0)}',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: kSpace8),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: onAddToCart,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kSpace12,
                            ),
                            textStyle: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          child: Text(locale.t('เพิ่ม', 'Add')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single cart line item in the right panel.
class _CartLineItem extends StatelessWidget {
  const _CartLineItem({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final OrderItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(kSpace12),
      decoration: BoxDecoration(
        color: kColorBg,
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: kSpace4),
                Builder(
                  builder: (context) {
                    final modSummary = CustomizationRules.getModifierSummary(item);
                    if (modSummary == null) return const SizedBox.shrink();
                    return Text(
                      modSummary,
                      style: theme.textTheme.bodySmall,
                    );
                  },
                ),
                const SizedBox(height: kSpace8),
                Text(
                  '฿${item.lineTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Quantity stepper
          Column(
            children: [
              // Remove button
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: kColorTextMuted.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: kSpace8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kColorBorder),
                  borderRadius: BorderRadius.circular(kRadiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepperButton(
                      icon: Icons.remove,
                      onTap: onDecrement,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: kSpace8),
                      child: Text(
                        '${item.quantity}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _StepperButton(
                      icon: Icons.add,
                      onTap: item.quantity < 99 ? onIncrement : null,
                      disabled: item.quantity >= 99,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small circular +/− button for the quantity stepper.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? kColorTextMuted.withValues(alpha: 0.3) : kColorTextBody,
        ),
      ),
    );
  }
}
