// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../utils/customization_rules.dart';
import '../utils/printer.dart';
import '../utils/vat_calculator.dart';
import '../widgets/item_customization_modal.dart';

// ---------------------------------------------------------------------------
// PromptPay ID — injected via --dart-define:
//   flutter run --dart-define=PROMPTPAY_ID=0812345678
// ---------------------------------------------------------------------------
const String _kPromptPayId =
    String.fromEnvironment('PROMPTPAY_ID', defaultValue: '');

enum PosFilter { all, cash, qr }

/// หน้า 4: Cashier POS
///
/// Landscape layout for staff iPad:
///   Left  — เมนูยอดฮิตสั่งให้ลูกค้าได้เร็ว + สั่งอาหารแทนลูกค้าหน้าเคาน์เตอร์
///   Right — ส่วนจัดการออร์เดอร์จาก Kiosk (cash / QR pending approval)
///
/// Features:
///   - กดยืนยันรับเงินจากออร์เดอร์ Kiosk ที่เลือกจ่ายเงินสด
///   - ยืนยันการโอนจาก QR code (Approve)
///   - เลือกออกใบเสร็จแบบดิจิทัลหรือพิมพ์กระดาษ (Web print)
///   - เมนูสั่งอาหารแทนลูกค้าหน้าเคาน์เตอร์ (New Counter Order)
class CashierPosScreen extends StatefulWidget {
  const CashierPosScreen({super.key});

  @override
  State<CashierPosScreen> createState() => _CashierPosScreenState();
}

class _CashierPosScreenState extends State<CashierPosScreen> {
  final _orderService = OrderService();
  final _menuService = MenuService();
  PosFilter _selectedFilter = PosFilter.all;

  Future<void> _showReceiptDialog(BuildContext context, Order order) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReceiptDialog(order: order),
    );
  }

  void _openNewCounterOrder(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CounterOrderDialog(
        onQrOrderCreated: (created) {
          _showCounterQrBottomSheet(context, created);
        },
        onCashOrderCreated: (created) async {
          await _showReceiptDialog(context, created);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('สร้างออร์เดอร์สำเร็จ คิวที่ ${created.queueNumber}'),
                backgroundColor: kColorPrimary,
              ),
            );
          }
        },
      ),
    );
  }

  void _showReceiptBottomSheet(BuildContext context, Order order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);
        final queueStr = order.queueNumber.toString().padLeft(3, '0');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: kSpace24, vertical: kSpace16),
          decoration: BoxDecoration(
            color: kColorSurface,
            borderRadius: BorderRadius.circular(kRadiusCard),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4)),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(kSpace24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Shop header
                  Center(
                    child: Text(
                      'ToTo Cafe',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      'RECEIPT / ใบเสร็จรับเงิน',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kColorTextMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace12),
                  const Divider(thickness: 1),

                  // Order metadata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('คิวที่ / Queue:', style: theme.textTheme.bodySmall),
                      Text(
                        '#$queueStr',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: kColorPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('วันที่ / Date:', style: theme.textTheme.bodySmall),
                      Text(
                        order.createdAt != null
                            ? '${order.createdAt!.day.toString().padLeft(2, '0')}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.year} ${order.createdAt!.hour.toString().padLeft(2, '0')}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
                            : DateTime.now().toString().substring(0, 16),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('วิธีชำระ / Payment:', style: theme.textTheme.bodySmall),
                      Text(
                        order.paymentMethod == PaymentMethod.qr
                            ? 'QR PromptPay'
                            : 'เงินสด (Cash)',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace12),
                  const Divider(thickness: 1),

                  // Itemized list (Monospace thermal style)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: order.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.name} x${item.quantity}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '฿${item.lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Builder(
                                  builder: (context) {
                                    final modSummary = CustomizationRules.getModifierSummary(item, includeLabels: false);
                                    if (modSummary == null) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8.0, top: 2),
                                      child: Text(
                                        '($modSummary)',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: kColorTextMuted,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: kSpace12),
                  const Divider(thickness: 1),

                  // Financial summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ราคาก่อนภาษี (Subtotal):',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      Text('฿${order.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ภาษีมูลค่าเพิ่ม 7% (VAT):',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      Text('฿${order.vat.toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(thickness: 1),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยอดสุทธิ (Total):',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '฿${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace16),
                  Center(
                    child: Text(
                      'Thank you for your visit!',
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: kSpace24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            printReceipt();
                          },
                          icon: const Icon(Icons.print, size: 20),
                          label: const Text('พิมพ์ใบเสร็จ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kColorPrimary,
                            foregroundColor: kColorWhite,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpace12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(bottomSheetContext).pop(),
                          child: const Text('ปิด'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCounterQrBottomSheet(BuildContext context, Order order) {
    final grandTotalStr = order.total.toStringAsFixed(2);
    final queueStr = order.queueNumber.toString();

    final amountSatang = (order.total * 100).round();
    final String payload;
    if (_kPromptPayId.isNotEmpty) {
      if (_kPromptPayId.length == 13) {
        payload = promptPayNationalId(_kPromptPayId, amountSatang: amountSatang);
      } else {
        payload = promptPayMobile(_kPromptPayId, amountSatang: amountSatang);
      }
    } else {
      payload = '';
    }

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: kSpace24, vertical: kSpace16),
          decoration: BoxDecoration(
            color: kColorSurface,
            borderRadius: BorderRadius.circular(kRadiusCard),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4)),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(kSpace24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'QR PromptPay — คิวที่ $queueStr',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: kColorPrimary,
                    ),
                  ),
                  const SizedBox(height: kSpace12),
                  const Divider(thickness: 1),
                  const SizedBox(height: kSpace12),
                  Center(
                    child: Text(
                      '฿$grandTotalStr',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: kColorSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace8),
                  Center(
                    child: Text(
                      'ให้ลูกค้าสแกน QR แล้วกด Approve เมื่อลูกค้าโอนแล้ว',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: kColorTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(kSpace12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(kRadiusCard),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: payload.isNotEmpty
                          ? QrImageView(
                              data: payload,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                            )
                          : Container(
                              width: 200,
                              height: 200,
                              alignment: Alignment.center,
                              child: const Text(
                                'ยังไม่ได้ตั้งค่า PROMPTPAY_ID\n(รันแอปด้วย --dart-define=PROMPTPAY_ID=...)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: kSpace24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (order.id != null) {
                          await _orderService.approveOrder(order.id!);
                        }
                        if (bottomSheetContext.mounted) {
                          Navigator.of(bottomSheetContext).pop();
                        }
                        if (context.mounted) {
                          await _showReceiptDialog(context, order);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ชำระเงินสำเร็จ คิวที่ $queueStr'),
                              backgroundColor: kColorPrimary,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kColorPrimary,
                        foregroundColor: kColorWhite,
                      ),
                      child: const Text('Approve — รับเงินแล้ว'),
                    ),
                  ),
                  const SizedBox(height: kSpace8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        if (order.id != null) {
                          await _orderService.deleteOrder(order.id!);
                        }
                        if (bottomSheetContext.mounted) {
                          Navigator.of(bottomSheetContext).pop();
                        }
                      },
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // ═════════════════════════════════════════════════════════════════
          // LEFT — Quick Menu + New Order for walk-in customers
          // ═════════════════════════════════════════════════════════════════
          Expanded(
            flex: 3,
            child: _buildQuickMenuPanel(theme),
          ),

          const VerticalDivider(width: 1),

          // ═════════════════════════════════════════════════════════════════
          // RIGHT — Incoming Kiosk Orders (pending cash / QR approval)
          // ═════════════════════════════════════════════════════════════════
          Expanded(
            flex: 2,
            child: _buildOrderManagementPanel(theme),
          ),
        ],
      ),
    );
  }

  // ── Left: Quick Menu Panel ──────────────────────────────────────────────

  Widget _buildQuickMenuPanel(ThemeData theme) {
    return Container(
      color: kColorBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(kSpace16),
            decoration: const BoxDecoration(
              color: kColorSurface,
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Row(
              children: [
                Text('ToTo Cafe', style: theme.textTheme.headlineMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace12,
                    vertical: kSpace4,
                  ),
                  decoration: BoxDecoration(
                    color: kGreen100,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Text(
                    '● On Shift',
                    style: theme.textTheme.bodySmall?.copyWith(color: kColorPrimary),
                  ),
                ),
              ],
            ),
          ),

          // Quick-order section label
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpace24,
              kSpace24,
              kSpace24,
              kSpace16,
            ),
            child: Text(
              'POPULAR ITEMS',
              style: theme.textTheme.labelMedium,
            ),
          ),

          // Quick-order grid from Firestore
          Expanded(
            child: StreamBuilder<List<MenuItem>>(
              stream: _menuService.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No items available',
                      style: theme.textTheme.bodyMedium?.copyWith(color: kColorTextMuted),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: kSpace12,
                    crossAxisSpacing: kSpace12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _QuickMenuItem(
                      name: item.name,
                      price: item.price,
                      imageUrl: item.imageUrl,
                      onTap: () => _openNewCounterOrder(context),
                    );
                  },
                );
              },
            ),
          ),

          // New counter order button
          Padding(
            padding: const EdgeInsets.all(kSpace16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _openNewCounterOrder(context),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('New Counter Order'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right: Order Management Panel ───────────────────────────────────────

  Widget _buildOrderManagementPanel(ThemeData theme) {
    final PaymentMethod? methodFilter;
    if (_selectedFilter == PosFilter.cash) {
      methodFilter = PaymentMethod.cash;
    } else if (_selectedFilter == PosFilter.qr) {
      methodFilter = PaymentMethod.qr;
    } else {
      methodFilter = null;
    }

    return Container(
      color: kColorSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Filter Chips
          Container(
            padding: const EdgeInsets.all(kSpace16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Incoming Orders',
                    style: theme.textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildFilterChip('All', PosFilter.all, theme),
                const SizedBox(width: kSpace8),
                _buildFilterChip('Cash', PosFilter.cash, theme),
                const SizedBox(width: kSpace8),
                _buildFilterChip('QR', PosFilter.qr, theme),
              ],
            ),
          ),

          // Order list
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: _orderService.watchPendingOrders(paymentMethod: methodFilter),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(kSpace24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48, color: kColorTextMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: kSpace12),
                          Text(
                            'No pending orders',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: kColorTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(kSpace16),
                  itemCount: orders.length,
                  separatorBuilder: (context, _) => const SizedBox(height: kSpace12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderCard(
                      queueNumber: order.queueNumber.toString().padLeft(3, '0'),
                      status:
                          'Pending ${order.paymentMethod == PaymentMethod.qr ? "QR Approval" : "Cash"}',
                      paymentMethod: order.paymentMethod,
                      total: order.total,
                      onApprove: () async {
                        try {
                          await _orderService.approveOrder(order.id!);
                          if (context.mounted) {
                            await _showReceiptDialog(context, order);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order #${order.queueNumber} approved!'),
                                backgroundColor: kColorPrimary,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error approving order: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      onReceipt: () => _showReceiptBottomSheet(context, order),
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

  Widget _buildFilterChip(String label, PosFilter filter, ThemeData theme) {
    final isSelected = _selectedFilter == filter;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
      selectedColor: kColorPrimary,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: isSelected ? kColorWhite : kColorTextBody,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

/// A quick-tap menu item tile for the POS left panel.
class _QuickMenuItem extends StatelessWidget {
  const _QuickMenuItem({
    required this.name,
    required this.price,
    this.imageUrl,
    required this.onTap,
  });

  final String name;
  final double price;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Padding(
          padding: const EdgeInsets.all(kSpace12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusBadge),
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? Image.asset(
                        imageUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.coffee, color: kCoffee500, size: 40),
                      )
                    : const Icon(Icons.coffee, color: kCoffee500, size: 40),
              ),
              const SizedBox(height: kSpace8),
              Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '฿${price.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single order card in the POS right panel.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.queueNumber,
    required this.status,
    required this.paymentMethod,
    required this.total,
    required this.onApprove,
    required this.onReceipt,
  });

  final String queueNumber;
  final String status;
  final PaymentMethod paymentMethod;
  final double total;
  final VoidCallback? onApprove;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCash = paymentMethod == PaymentMethod.cash;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(kSpace16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue number & status
            Row(
              children: [
                Text(
                  'Queue #$queueNumber',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace12,
                    vertical: kSpace4,
                  ),
                  decoration: BoxDecoration(
                    color: kTan,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(color: kColorSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace8),

            // Payment method badge & total
            Row(
              children: [
                // Brown badge for Cash, Green badge for QR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace4),
                  decoration: BoxDecoration(
                    color: isCash ? kColorSecondary.withValues(alpha: 0.12) : kGreen100,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                    border: Border.all(
                      color: isCash
                          ? kColorSecondary.withValues(alpha: 0.3)
                          : kColorPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCash ? Icons.payments_outlined : Icons.qr_code,
                        size: 14,
                        color: isCash ? kColorSecondary : kColorPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCash ? 'เงินสด' : 'QR PromptPay',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCash ? kColorSecondary : kColorPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '฿${total.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kColorPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace12),

            // Action buttons
            Row(
              children: [
                if (onApprove != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      child: const Text('Approve'),
                    ),
                  ),
                if (onApprove != null && onReceipt != null)
                  const SizedBox(width: kSpace8),
                if (onReceipt != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReceipt,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Receipt'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Counter Order Modal Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _CounterOrderDialog extends StatefulWidget {
  const _CounterOrderDialog({
    this.onQrOrderCreated,
    this.onCashOrderCreated,
  });

  final ValueChanged<Order>? onQrOrderCreated;
  final ValueChanged<Order>? onCashOrderCreated;

  @override
  State<_CounterOrderDialog> createState() => _CounterOrderDialogState();
}

class _CounterOrderDialogState extends State<_CounterOrderDialog> {
  final _menuService = MenuService();
  final _orderService = OrderService();
  final List<OrderItem> _posCart = [];
  bool _isSubmitting = false;
  String? _submittingMethod;

  double get _subtotal => _posCart.fold<double>(0, (sum, i) => sum + i.lineTotal);
  double get _vat => calculateVat(_subtotal);
  double get _total => calculateGrandTotal(_subtotal);

  void _addItem(OrderItem item) {
    setState(() {
      final idx = _posCart.indexWhere((ci) =>
          ci.menuItemId == item.menuItemId &&
          ci.sweetness == item.sweetness &&
          ci.milkType == item.milkType);
      if (idx >= 0) {
        final existing = _posCart[idx];
        _posCart[idx] = existing.copyWith(quantity: existing.quantity + item.quantity);
      } else {
        _posCart.add(item);
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = _posCart[index];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _posCart.removeAt(index);
      } else {
        _posCart[index] = item.copyWith(quantity: newQty);
      }
    });
  }

  Future<void> _submitCashOrder() async {
    if (_posCart.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _submittingMethod = 'cash';
    });

    try {
      final queueNumber = await _orderService.nextQueueNumber();
      final order = Order(
        items: List.from(_posCart),
        status: OrderStatus.paid, // Counter orders are immediately paid
        paymentMethod: PaymentMethod.cash,
        queueNumber: queueNumber,
        subtotal: _subtotal,
        vat: _vat,
        total: _total,
      );

      final created = await _orderService.createOrder(order);

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onCashOrderCreated != null) {
          widget.onCashOrderCreated!(created);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('สร้างออร์เดอร์สำเร็จ คิวที่ $queueNumber'),
              backgroundColor: kColorPrimary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสร้างออร์เดอร์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitQrOrder() async {
    if (_posCart.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _submittingMethod = 'qr';
    });

    try {
      final queueNumber = await _orderService.nextQueueNumber();
      final order = Order(
        items: List.from(_posCart),
        status: OrderStatus.awaitingApproval, // Counter QR orders await cashier approval
        paymentMethod: PaymentMethod.qr,
        queueNumber: queueNumber,
        subtotal: _subtotal,
        vat: _vat,
        total: _total,
      );

      final created = await _orderService.createOrder(order);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onQrOrderCreated?.call(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสร้างออร์เดอร์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusCard)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: SizedBox(
          width: 960,
          height: 640,
          child: Column(
            children: [
              // Modal Title Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kSpace24, vertical: kSpace12),
                color: kColorSurface,
                child: Row(
                  children: [
                    const Icon(Icons.point_of_sale, color: kColorPrimary),
                    const SizedBox(width: kSpace8),
                    Text(
                      'New Counter Order (สั่งอาหารหน้าเคาน์เตอร์)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content Split
              Expanded(
                child: Row(
                  children: [
                    // ── Left: Menu Grid ─────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: kColorBg,
                        child: StreamBuilder<List<MenuItem>>(
                          stream: _menuService.watchAll(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final items = snapshot.data ?? [];
                            if (items.isEmpty) {
                              return Center(
                                child: Text('No menu items', style: theme.textTheme.bodyMedium),
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(kSpace16),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                mainAxisSpacing: kSpace12,
                                crossAxisSpacing: kSpace12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () async {
                                      final customized = await ItemCustomizationModal.show(
                                        context,
                                        menuItemId: item.id ?? '',
                                        name: item.name,
                                        price: item.price,
                                        imagePath: item.imageUrl ?? 'assets/images/hot_coffee.png',
                                        category: item.category,
                                        description: item.description,
                                      );
                                      if (customized != null) {
                                        _addItem(customized);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(kSpace8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: kTan.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(kRadiusBadge),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                                                  ? Image.asset(
                                                      item.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      errorBuilder: (context, error, stackTrace) =>
                                                          const Icon(Icons.coffee, color: kCoffee500, size: 40),
                                                    )
                                                  : const Icon(Icons.coffee, size: 40, color: kCoffee500),
                                            ),
                                          ),
                                          const SizedBox(height: kSpace8),
                                          Text(
                                            item.name,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '฿${item.price.toStringAsFixed(0)}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: kColorPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    const VerticalDivider(width: 1),

                    // ── Right: POS Cart Summary ─────────────────────────
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: kColorSurface,
                        padding: const EdgeInsets.all(kSpace16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'รายการในออร์เดอร์ (${_posCart.length})',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (_posCart.isNotEmpty)
                                  TextButton(
                                    onPressed: () => setState(() => _posCart.clear()),
                                    child: const Text('ล้าง'),
                                  ),
                              ],
                            ),
                            const Divider(),

                            // Cart items
                            Expanded(
                              child: _posCart.isEmpty
                                  ? Center(
                                      child: Text(
                                        'แตะเมนูด้านซ้ายเพื่อเพิ่มรายการ',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: kColorTextMuted,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _posCart.length,
                                      separatorBuilder: (context, _) => const Divider(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = _posCart[index];
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.name,
                                                      style: theme.textTheme.bodyMedium
                                                          ?.copyWith(fontWeight: FontWeight.w600)),
                                                  Text(
                                                    '${item.sweetness.label} • ${item.milkType.label}',
                                                    style: theme.textTheme.bodySmall
                                                        ?.copyWith(color: kColorTextMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline,
                                                      size: 20),
                                                  onPressed: () => _updateQuantity(index, -1),
                                                ),
                                                Text('${item.quantity}',
                                                    style: theme.textTheme.bodyMedium),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline,
                                                      size: 20),
                                                  onPressed: () => _updateQuantity(index, 1),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              width: 64,
                                              child: Text(
                                                '฿${item.lineTotal.toStringAsFixed(0)}',
                                                textAlign: TextAlign.end,
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),

                            const Divider(),
                            // Subtotal, VAT, Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal:', style: theme.textTheme.bodySmall),
                                Text('฿${_subtotal.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('VAT 7%:', style: theme.textTheme.bodySmall),
                                Text('฿${_vat.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Grand Total:',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  '฿${_total.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: kColorPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: kSpace16),

                            // Pay with Cash or QR PromptPay
                            Row(
                              children: [
                                // Button 1 — Cash
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _posCart.isEmpty || _isSubmitting
                                          ? null
                                          : _submitCashOrder,
                                      icon: _isSubmitting && _submittingMethod == 'cash'
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.payments_outlined),
                                      label: Text(
                                        _isSubmitting && _submittingMethod == 'cash'
                                            ? 'กำลังบันทึก...'
                                            : 'ชำระเงินสด (฿${_total.toStringAsFixed(2)})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kColorSecondary,
                                        foregroundColor: kColorWhite,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: kSpace12),
                                // Button 2 — QR PromptPay
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: _posCart.isEmpty || _isSubmitting
                                          ? null
                                          : _submitQrOrder,
                                      icon: _isSubmitting && _submittingMethod == 'qr'
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.qr_code_2),
                                      label: Text(
                                        _isSubmitting && _submittingMethod == 'qr'
                                            ? 'กำลังบันทึก...'
                                            : 'จ่ายด้วย QR (฿${_total.toStringAsFixed(2)})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kColorPrimary,
                                        foregroundColor: kColorWhite,
                                      ),
                                    ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Thermal Receipt Dialog after Payment Approval
// ═════════════════════════════════════════════════════════════════════════════

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = order.createdAt ?? DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final paymentMethodStr =
        order.paymentMethod == PaymentMethod.qr ? 'QR PromptPay' : 'เงินสด';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(kSpace16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title: "ชำระเงินสำเร็จ ✓"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: kColorPrimary, size: 22),
                  const SizedBox(width: kSpace8),
                  Text(
                    'ชำระเงินสำเร็จ ✓',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: kColorPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpace16),

              // Thermal receipt paper container
              Container(
                padding: const EdgeInsets.all(kSpace16),
                decoration: BoxDecoration(
                  color: kCream,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  border: Border.all(color: kTan),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Centered: "ToTo Cafe" (Noto Serif Thai, bold)
                    Center(
                      child: Text(
                        'ToTo Cafe',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: 'Noto Serif Thai',
                          fontWeight: FontWeight.bold,
                          color: kCoffee900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Centered: "================================"
                    const Center(
                      child: Text(
                        '================================',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: kCoffee700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Queue number: "คิวที่ {queueNumber}" & Date/Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'คิวที่ ${order.queueNumber}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: kCoffee900,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: kCoffee700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: kCoffee500, height: 1),
                    const SizedBox(height: 8),

                    // List of items: "{name} x{qty}  ฿{lineTotal}"
                    ...order.items.map((item) {
                      final modSummary =
                          CustomizationRules.getModifierSummary(item, includeLabels: false);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.name} x${item.quantity}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kCoffee900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '฿${item.lineTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kCoffee900,
                                  ),
                                ),
                              ],
                            ),
                            // Modifier line if applicable: "  {sweetness} • {milkType}" (smaller, muted)
                            if (modSummary != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 1),
                                child: Text(
                                  '  $modSummary',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: kCoffee700.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    const Divider(color: kCoffee500, height: 1),
                    const SizedBox(height: 8),

                    // Subtotal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal:',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: kCoffee700),
                        ),
                        Text(
                          '฿${order.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kCoffee700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // VAT 7%
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'VAT 7%:',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: kCoffee700),
                        ),
                        Text(
                          '฿${order.vat.toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kCoffee700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // รวมทั้งหมด: ฿{total} (bold)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'รวมทั้งหมด:',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kCoffee900,
                          ),
                        ),
                        Text(
                          '฿${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kCoffee900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Payment method: "ชำระด้วย: {QR PromptPay / เงินสด}"
                    Text(
                      'ชำระด้วย: $paymentMethodStr',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: kCoffee700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Centered: "ขอบคุณที่ใช้บริการ"
                    const Center(
                      child: Text(
                        'ขอบคุณที่ใช้บริการ',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kCoffee900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpace16),

              // Two buttons at bottom:
              // 1. "🖨️ พิมพ์ใบเสร็จ" → calls window.print() via dart:html, then closes dialog
              // 2. "ปิด (ไม่พิมพ์)" → closes dialog only
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    html.window.print();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kColorPrimary,
                    foregroundColor: kColorWhite,
                  ),
                  child: const Text('🖨️ พิมพ์ใบเสร็จ'),
                ),
              ),
              const SizedBox(height: kSpace8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด (ไม่พิมพ์)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

