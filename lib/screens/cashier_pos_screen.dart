// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';
import '../models/member.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/locale_provider.dart';
import '../services/member_service.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../utils/customization_rules.dart';
import '../utils/printer.dart';
import '../utils/vat_calculator.dart';
import '../widgets/item_customization_modal.dart';
import '../widgets/language_toggle.dart';

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
  StreamSubscription<List<Order>>? _incomingSub;
  int? _lastKnownCount;

  @override
  void initState() {
    super.initState();
    _incomingSub = _orderService.watchPendingOrders().listen((orders) {
      if (_lastKnownCount != null && orders.length > _lastKnownCount!) {
        final newOrder = orders.last;
        if (mounted) {
          final locale = context.read<LocaleProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                locale.t(
                  'มีออร์เดอร์ใหม่! คิวที่ ${newOrder.queueNumber}',
                  'New order! Queue #${newOrder.queueNumber}',
                ),
              ),
              backgroundColor: kColorSecondary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      _lastKnownCount = orders.length;
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }

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
            final locale = context.read<LocaleProvider>();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  locale.t(
                    'สร้างออร์เดอร์สำเร็จ คิวที่ ${created.queueNumber}',
                    'Order created! Queue #${created.queueNumber}',
                  ),
                ),
                backgroundColor: kColorPrimary,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _showManualPointsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _ManualPointsDialog(),
    );
  }

  void _showReceiptBottomSheet(BuildContext context, Order order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);
        final locale = bottomSheetContext.watch<LocaleProvider>();
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
                      locale.t('ใบเสร็จรับเงิน', 'RECEIPT'),
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
                      Text('${locale.t('คิวที่', 'Queue')}:', style: theme.textTheme.bodySmall),
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
                      Text('${locale.t('วันที่', 'Date')}:', style: theme.textTheme.bodySmall),
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
                      Text(locale.t('ชำระด้วย:', 'Payment:'), style: theme.textTheme.bodySmall),
                      Text(
                        order.paymentMethod == PaymentMethod.qr
                            ? 'QR PromptPay'
                            : locale.t('เงินสด', 'Cash'),
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
                      Text('${locale.t('ราคาก่อนภาษี', 'Subtotal')}:',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      Text('฿${order.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('VAT 7%:',
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
                      Text(
                        '${locale.t('ยอดสุทธิ', 'Grand Total')}:',
                        style: const TextStyle(
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
                      locale.t('ขอบคุณที่ใช้บริการ', 'Thank you for your visit'),
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
                          label: Text(locale.t('🖨️ พิมพ์ใบเสร็จ', '🖨️ Print Receipt')),
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
                          child: Text(locale.t('ปิด', 'Close')),
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
        final locale = bottomSheetContext.watch<LocaleProvider>();

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
                    '${locale.t('QR PromptPay — คิวที่', 'QR PromptPay — Queue')} $queueStr',
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
                      locale.t(
                        'ให้ลูกค้าสแกน QR แล้วกด Approve เมื่อลูกค้าโอนแล้ว',
                        'Ask customer to scan QR, then tap Approve after transfer',
                      ),
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
                              child: Text(
                                locale.t(
                                  'ยังไม่ได้ตั้งค่า PROMPTPAY_ID\n(รันแอปด้วย --dart-define=PROMPTPAY_ID=...)',
                                  'PROMPTPAY_ID not configured\n(Run app with --dart-define=PROMPTPAY_ID=...)',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
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
                          final loc = context.read<LocaleProvider>();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                loc.t(
                                  'ชำระเงินสำเร็จ คิวที่ $queueStr',
                                  'Payment successful! Queue #$queueStr',
                                ),
                              ),
                              backgroundColor: kColorPrimary,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kColorPrimary,
                        foregroundColor: kColorWhite,
                      ),
                      child: Text(locale.t('Approve — รับเงินแล้ว', 'Approve — Payment Received')),
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
                      child: Text(locale.t('ยกเลิก', 'Cancel')),
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
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      body: Row(
        children: [
          // ═════════════════════════════════════════════════════════════════
          // LEFT — Quick Menu + New Order for walk-in customers
          // ═════════════════════════════════════════════════════════════════
          Expanded(
            flex: 3,
            child: _buildQuickMenuPanel(theme, locale),
          ),

          const VerticalDivider(width: 1),

          // ═════════════════════════════════════════════════════════════════
          // RIGHT — Incoming Kiosk Orders (pending cash / QR approval)
          // ═════════════════════════════════════════════════════════════════
          Expanded(
            flex: 2,
            child: _buildOrderManagementPanel(theme, locale),
          ),
        ],
      ),
    );
  }

  // ── Left: Quick Menu Panel ──────────────────────────────────────────────

  Widget _buildQuickMenuPanel(ThemeData theme, LocaleProvider locale) {
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
                OutlinedButton.icon(
                  onPressed: () => _showManualPointsDialog(context),
                  icon: const Icon(Icons.stars, size: 18, color: kColorPrimary),
                  label: Text(
                    locale.t('เพิ่มแต้มสมาชิก (กรณีลืมที่ตู้)', 'Add Member Points'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kColorPrimary,
                    side: const BorderSide(color: kColorPrimary),
                    padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace8),
                  ),
                ),
                const SizedBox(width: kSpace8),
                IconButton(
                  icon: const Icon(Icons.auto_fix_high, size: 20, color: kColorTextMuted),
                  tooltip: locale.t('ลบเมนูที่ซ้ำในระบบ', 'Deduplicate menu items in Firestore'),
                  onPressed: () async {
                    try {
                      final deleted = await _menuService.deduplicateMenuItems();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            deleted > 0
                                ? 'ลบเมนูที่ซ้ำสำเร็จ: $deleted รายการ'
                                : 'ไม่มีเมนูซ้ำในระบบ (No duplicates found)',
                          ),
                          backgroundColor: kColorPrimary,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(width: kSpace12),
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
                    locale.t('● กำลังทำงาน', '● On Shift'),
                    style: theme.textTheme.bodySmall?.copyWith(color: kColorPrimary),
                  ),
                ),
                const SizedBox(width: kSpace12),
                const LanguageToggle(),
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
              locale.t('เมนูยอดนิยม', 'POPULAR ITEMS'),
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
                      locale.t('ไม่มีรายการเมนู', 'No menu items'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }

                final popularItems = items.take(8).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(kSpace16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: kSpace12,
                    mainAxisSpacing: kSpace12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: popularItems.length,
                  itemBuilder: (context, index) {
                    final item = popularItems[index];
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
                label: Text(locale.t('สั่งอาหารหน้าเคาน์เตอร์', 'New Counter Order')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right: Order Management Panel ───────────────────────────────────────

  Widget _buildOrderManagementPanel(ThemeData theme, LocaleProvider locale) {
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
                    locale.t('ออร์เดอร์ที่เข้ามา', 'Incoming Orders'),
                    style: theme.textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildFilterChip(locale.t('ทั้งหมด', 'All'), PosFilter.all, theme),
                const SizedBox(width: kSpace8),
                _buildFilterChip(locale.t('เงินสด', 'Cash'), PosFilter.cash, theme),
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
                            locale.t('ไม่มีออร์เดอร์รอดำเนินการ', 'No pending orders'),
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
                      status: order.paymentMethod == PaymentMethod.qr
                          ? locale.t('รอยืนยัน QR', 'Pending QR Approval')
                          : locale.t('รอรับเงินสด', 'Pending Cash'),
                      paymentMethod: order.paymentMethod,
                      total: order.total,
                      onApprove: () async {
                        await _orderService.approveOrder(order.id!);
                        if (order.paymentMethod == PaymentMethod.qr) {
                          // QR: receipt shown on kiosk side
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.read<LocaleProvider>().t(
                                    'ยืนยันการชำระเงิน QR สำเร็จ',
                                    'QR payment approved',
                                  ),
                                ),
                              ),
                            );
                          }
                        } else {
                          // Cash: show receipt dialog on POS
                          if (context.mounted) {
                            await _showReceiptDialog(context, order);
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
    final locale = context.watch<LocaleProvider>();
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
                  '${locale.t('คิวที่ ', 'Queue #')}$queueNumber',
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
                        isCash ? locale.t('เงินสด', 'Cash') : 'QR PromptPay',
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
                      child: Text(locale.t('ยืนยัน', 'Approve')),
                    ),
                  ),
                if (onApprove != null && onReceipt != null)
                  const SizedBox(width: kSpace8),
                if (onReceipt != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReceipt,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(locale.t('ใบเสร็จ', 'Receipt')),
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

  String _counterMemberPhone = '';
  Member? _counterMember;
  bool _isSearchingMember = false;
  bool _memberNotFound = false;
  double _memberDiscount = 0.0;
  int _redeemedPoints = 0;

  double get _subtotal => _posCart.fold<double>(0, (sum, i) => sum + i.lineTotal);
  double get _vat => calculateVat(_subtotal);
  double get _grandTotalBeforeDiscount => calculateGrandTotal(_subtotal);
  double get _finalTotal => (_grandTotalBeforeDiscount - _memberDiscount).clamp(0.0, double.infinity);

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
        if (_posCart.isEmpty) {
          _memberDiscount = 0.0;
          _redeemedPoints = 0;
        }
      } else {
        _posCart[index] = item.copyWith(quantity: newQty);
      }
    });
  }

  Future<void> _onSearchCounterMember() async {
    final phone = _counterMemberPhone.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearchingMember = true;
      _memberNotFound = false;
    });

    try {
      final member = await MemberService().getMemberByPhone(phone);
      if (!mounted) return;
      setState(() {
        _isSearchingMember = false;
        if (member != null) {
          _counterMember = member;
          _memberNotFound = false;
        } else {
          _counterMember = null;
          _memberNotFound = true;
          _memberDiscount = 0.0;
          _redeemedPoints = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingMember = false;
        _memberNotFound = true;
        _counterMember = null;
        _memberDiscount = 0.0;
        _redeemedPoints = 0;
      });
    }
  }

  Widget _buildCounterNumpadDigitButton(String digit) {
    return Material(
      color: const Color(0xFF3D5A3E),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (_counterMemberPhone.length < 10) {
            setState(() {
              _counterMemberPhone += digit;
              _memberNotFound = false;
            });
          }
        },
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterNumpadClearButton() {
    return Material(
      color: Colors.grey.shade400,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _counterMemberPhone = '';
            _memberNotFound = false;
            _counterMember = null;
            _memberDiscount = 0.0;
            _redeemedPoints = 0;
          });
        },
        child: const Center(
          child: Text(
            'ล้าง',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterNumpadBackspaceButton() {
    return Material(
      color: Colors.grey.shade400,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (_counterMemberPhone.isNotEmpty) {
            setState(() {
              _counterMemberPhone = _counterMemberPhone.substring(
                0,
                _counterMemberPhone.length - 1,
              );
              _memberNotFound = false;
            });
          }
        },
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _showCounterRedeemDialog(BuildContext context, Member member) async {
    final locale = context.read<LocaleProvider>();
    final maxRedeemablePoints = min(member.points, (_grandTotalBeforeDiscount * 100).toInt());

    if (maxRedeemablePoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.t(
              'ไม่มีแต้มสะสมเพียงพอสำหรับใช้เป็นส่วนลด',
              'Not enough points available for discount',
            ),
          ),
        ),
      );
      return;
    }

    int currentSelection = _redeemedPoints > 0
        ? min(_redeemedPoints, maxRedeemablePoints)
        : maxRedeemablePoints;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final discountValue = currentSelection / 100.0;
            final totalAfter = (_grandTotalBeforeDiscount - discountValue).clamp(0.0, double.infinity);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.stars, color: kGold),
                  const SizedBox(width: kSpace8),
                  Text(locale.t('ใช้แต้มเป็นส่วนลด', 'Redeem Points for Discount')),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${locale.t('แต้มสะสมทั้งหมด', 'Total points')}: ${member.points} ${locale.t('แต้ม', 'points')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: kSpace4),
                    Text(
                      '${locale.t('สามารถใช้ได้สูงสุดสำหรับออร์เดอร์นี้', 'Max points for this order')}: $maxRedeemablePoints ${locale.t('แต้ม', 'points')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kColorTextMuted),
                    ),
                    const SizedBox(height: kSpace16),

                    // Slider
                    Slider(
                      value: currentSelection.toDouble(),
                      min: 0,
                      max: maxRedeemablePoints.toDouble(),
                      divisions: maxRedeemablePoints > 0 ? max(1, min(maxRedeemablePoints, 100)) : 1,
                      label: '$currentSelection ${locale.t('แต้ม', 'pts')}',
                      activeColor: kColorPrimary,
                      onChanged: (val) {
                        setDialogState(() {
                          currentSelection = val.round();
                        });
                      },
                    ),

                    // Preset chips
                    Wrap(
                      spacing: kSpace8,
                      runSpacing: kSpace4,
                      children: [
                        if (maxRedeemablePoints >= 50)
                          ActionChip(
                            label: const Text('50 แต้ม'),
                            onPressed: () => setDialogState(() => currentSelection = 50),
                          ),
                        if (maxRedeemablePoints >= 100)
                          ActionChip(
                            label: const Text('100 แต้ม'),
                            onPressed: () => setDialogState(() => currentSelection = 100),
                          ),
                        if (maxRedeemablePoints >= 200)
                          ActionChip(
                            label: const Text('200 แต้ม'),
                            onPressed: () => setDialogState(() => currentSelection = 200),
                          ),
                        ActionChip(
                          label: Text(locale.t('ใช้แต้มสูงสุด', 'Use Max')),
                          onPressed: () => setDialogState(() => currentSelection = maxRedeemablePoints),
                        ),
                      ],
                    ),

                    const SizedBox(height: kSpace16),
                    const Divider(),
                    const SizedBox(height: kSpace12),

                    // Calculation Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(locale.t('แต้มที่จะใช้', 'Points to redeem')),
                        Text(
                          '$currentSelection ${locale.t('แต้ม', 'points')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(locale.t('ส่วนลดที่จะได้รับ', 'Discount amount')),
                        Text(
                          '-฿${discountValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kColorPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(locale.t('ยอดรวมหลังหักส่วนลด', 'Total after discount')),
                        Text(
                          '฿${totalAfter.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(locale.t('ยกเลิก', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _redeemedPoints = currentSelection;
                      _memberDiscount = currentSelection / 100.0;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kColorPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(locale.t('ยืนยัน', 'Apply')),
                ),
              ],
            );
          },
        );
      },
    );
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
        total: _finalTotal,
        discount: _memberDiscount,
        memberPhone: _counterMember != null && _counterMemberPhone.isNotEmpty
            ? _counterMemberPhone
            : null,
      );

      final created = await _orderService.createOrder(order);

      // Redeem points if discount was applied
      if (_counterMember != null && _redeemedPoints > 0) {
        try {
          await MemberService().redeemPoints(_counterMemberPhone, _redeemedPoints);
        } catch (e) {
          debugPrint('Error redeeming points for counter cash order: $e');
        }
      }

      // Add points for purchase automatically
      if (_counterMember != null && _counterMemberPhone.isNotEmpty) {
        try {
          await MemberService().addPointsForPurchase(
            _counterMemberPhone,
            _finalTotal.toInt(),
          );
        } catch (e) {
          debugPrint('Error adding points for counter cash order: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onCashOrderCreated != null) {
          widget.onCashOrderCreated!(created);
        } else {
          final locale = context.read<LocaleProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                locale.t(
                  'สร้างออร์เดอร์สำเร็จ คิวที่ $queueNumber',
                  'Order created! Queue #$queueNumber',
                ),
              ),
              backgroundColor: kColorPrimary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final locale = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${locale.t('เกิดข้อผิดพลาดในการสร้างออร์เดอร์', 'Error creating order')}: $e',
            ),
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
        total: _finalTotal,
        discount: _memberDiscount,
        memberPhone: _counterMember != null && _counterMemberPhone.isNotEmpty
            ? _counterMemberPhone
            : null,
      );

      final created = await _orderService.createOrder(order);

      // Redeem points if discount was applied
      if (_counterMember != null && _redeemedPoints > 0) {
        try {
          await MemberService().redeemPoints(_counterMemberPhone, _redeemedPoints);
        } catch (e) {
          debugPrint('Error redeeming points for counter QR order: $e');
        }
      }

      // Add points for purchase automatically
      if (_counterMember != null && _counterMemberPhone.isNotEmpty) {
        try {
          await MemberService().addPointsForPurchase(
            _counterMemberPhone,
            _finalTotal.toInt(),
          );
        } catch (e) {
          debugPrint('Error adding points for counter QR order: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onQrOrderCreated?.call(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final locale = context.read<LocaleProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${locale.t('เกิดข้อผิดพลาดในการสร้างออร์เดอร์', 'Error creating order')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

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
                      locale.t('สั่งอาหารหน้าเคาน์เตอร์', 'New Counter Order'),
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
                                child: Text(
                                  locale.t('ไม่มีรายการเมนู', 'No menu items'),
                                  style: theme.textTheme.bodyMedium,
                                ),
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
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${locale.t('รายการในออร์เดอร์', 'Order Items')} (${_posCart.length})',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_posCart.isNotEmpty)
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _posCart.clear();
                                        _memberDiscount = 0.0;
                                        _redeemedPoints = 0;
                                      }),
                                      child: Text(locale.t('ล้าง', 'Clear')),
                                    ),
                                ],
                              ),
                              const Divider(),

                              // Cart items
                              if (_posCart.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: kSpace16),
                                  child: Center(
                                    child: Text(
                                      locale.t(
                                        'แตะเมนูด้านซ้ายเพื่อเพิ่มรายการ',
                                        'Tap menu on the left to add items',
                                      ),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: kColorTextMuted,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
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

                              const Divider(),
                              const SizedBox(height: kSpace8),

                              // ═══════════════════════════════════════════════════════════
                              // SECTION: สมาชิก ToTo Cafe (ถ้ามี)
                              // ═══════════════════════════════════════════════════════════
                              Container(
                                padding: const EdgeInsets.all(kSpace12),
                                decoration: BoxDecoration(
                                  color: kColorBg,
                                  borderRadius: BorderRadius.circular(kRadiusCard),
                                  border: Border.all(color: kColorBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.loyalty_outlined, color: kColorPrimary, size: 20),
                                        const SizedBox(width: kSpace8),
                                        Text(
                                          locale.t('สมาชิก ToTo Cafe (ถ้ามี)', 'ToTo Cafe Member (Optional)'),
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: kColorTextHeading,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: kSpace8),

                                    // 1. Display box showing _counterMemberPhone
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: kColorSurface,
                                        borderRadius: BorderRadius.circular(kRadiusCard),
                                        border: Border.all(color: kColorBorder),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _counterMemberPhone.isEmpty ? '- - - - - - - -' : _counterMemberPhone,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 3,
                                            color: Color(0xFF3D5A3E),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: kSpace12),

                                    // 2. 3x4 On-Screen Numpad
                                    Center(
                                      child: SizedBox(
                                        width: 192,
                                        height: 254,
                                        child: GridView.count(
                                          crossAxisCount: 3,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 12,
                                          physics: const NeverScrollableScrollPhysics(),
                                          children: [
                                            _buildCounterNumpadDigitButton('1'),
                                            _buildCounterNumpadDigitButton('2'),
                                            _buildCounterNumpadDigitButton('3'),
                                            _buildCounterNumpadDigitButton('4'),
                                            _buildCounterNumpadDigitButton('5'),
                                            _buildCounterNumpadDigitButton('6'),
                                            _buildCounterNumpadDigitButton('7'),
                                            _buildCounterNumpadDigitButton('8'),
                                            _buildCounterNumpadDigitButton('9'),
                                            _buildCounterNumpadClearButton(),
                                            _buildCounterNumpadDigitButton('0'),
                                            _buildCounterNumpadBackspaceButton(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: kSpace12),

                                    // 3. Full-width "ค้นหา" Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed: _isSearchingMember ? null : _onSearchCounterMember,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF3D5A3E),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(kRadiusCard),
                                          ),
                                        ),
                                        child: _isSearchingMember
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                locale.t('ค้นหา', 'Search'),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),

                                    // 5. When not found
                                    if (_memberNotFound) ...[
                                      const SizedBox(height: kSpace8),
                                      Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 14, color: kColorTextMuted),
                                          const SizedBox(width: kSpace4),
                                          Text(
                                            locale.t('ไม่พบเบอร์นี้ในระบบ', 'No member found with this phone number'),
                                            style: theme.textTheme.bodySmall?.copyWith(color: kColorTextMuted),
                                          ),
                                        ],
                                      ),
                                    ],

                                    // 4. When member found: show card with name + current points + redeem button
                                    if (_counterMember != null) ...[
                                      const SizedBox(height: kSpace12),
                                      Container(
                                        padding: const EdgeInsets.all(kSpace12),
                                        decoration: BoxDecoration(
                                          color: kColorSurface,
                                          borderRadius: BorderRadius.circular(kRadiusCard),
                                          border: Border.all(color: kColorPrimary.withValues(alpha: 0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: kGreen100,
                                                  child: const Icon(Icons.person, color: kColorPrimary, size: 20),
                                                ),
                                                const SizedBox(width: kSpace8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        (_counterMember!.displayName != null &&
                                                                _counterMember!.displayName!.isNotEmpty)
                                                            ? _counterMember!.displayName!
                                                            : 'สมาชิก (${_counterMember!.phone})',
                                                        style: theme.textTheme.titleSmall?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: kColorTextHeading,
                                                        ),
                                                      ),
                                                      Text(
                                                        _counterMember!.phone,
                                                        style: theme.textTheme.bodySmall
                                                            ?.copyWith(color: kColorTextMuted),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _counterMember = null;
                                                      _counterMemberPhone = '';
                                                      _memberDiscount = 0.0;
                                                      _redeemedPoints = 0;
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: kColorTextMuted,
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                  ),
                                                  child: Text(locale.t('เปลี่ยน', 'Change')),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: kSpace8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: kSpace8, vertical: kSpace4),
                                              decoration: BoxDecoration(
                                                color: kGreen100.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(kRadiusCard),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.stars, color: kGold, size: 16),
                                                  const SizedBox(width: kSpace4),
                                                  Expanded(
                                                    child: Text(
                                                      '${locale.t('คุณมี', 'You have')} ${_counterMember!.points} ${locale.t('แต้ม', 'points')} (${locale.t('มูลค่า', 'value')} ${(_counterMember!.points / 100).toStringAsFixed(2)} ${locale.t('บาท', 'baht')})',
                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                        color: kColorPrimary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_memberDiscount > 0) ...[
                                              const SizedBox(height: kSpace8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '${locale.t('ใช้ส่วนลด', 'Discount')}: -฿${_memberDiscount.toStringAsFixed(2)} ($_redeemedPoints ${locale.t('แต้ม', 'pts')})',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: kColorPrimary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _memberDiscount = 0.0;
                                                        _redeemedPoints = 0;
                                                      });
                                                    },
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.red.shade700,
                                                      padding: EdgeInsets.zero,
                                                      minimumSize: const Size(40, 24),
                                                    ),
                                                    child: Text(locale.t('ยกเลิก', 'Remove')),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: kSpace8),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 36,
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _showCounterRedeemDialog(context, _counterMember!),
                                                icon: const Icon(Icons.redeem, size: 16),
                                                label: Text(
                                                  _memberDiscount > 0
                                                      ? locale.t('แก้ไขแต้มส่วนลด', 'Edit Discount')
                                                      : locale.t(
                                                          'ใช้แต้มเป็นส่วนลด', 'Redeem Points for Discount'),
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: kColorPrimary,
                                                  side: const BorderSide(color: kColorPrimary),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: kSpace12),
                              const Divider(),
                              const SizedBox(height: kSpace4),

                              // Subtotal, VAT, Member Discount, Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(locale.t('ราคาก่อนภาษี:', 'Subtotal:'), style: theme.textTheme.bodySmall),
                                  Text('฿${_subtotal.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('VAT 7%:', style: theme.textTheme.bodySmall),
                                  Text('฿${_vat.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
                                ],
                              ),
                              if (_memberDiscount > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      locale.t('ส่วนลดสมาชิก:', 'Member Discount:'),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: kColorPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '-฿${_memberDiscount.toStringAsFixed(2)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: kColorPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    locale.t('ยอดสุทธิ:', 'Grand Total:'),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '฿${_finalTotal.toStringAsFixed(2)}',
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
                                              ? locale.t('กำลังบันทึก...', 'Saving...')
                                              : '${locale.t('ชำระเงินสด', 'Pay with Cash')} (฿${_finalTotal.toStringAsFixed(2)})',
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
                                              ? locale.t('กำลังบันทึก...', 'Saving...')
                                              : '${locale.t('จ่ายด้วย QR', 'Pay with QR')} (฿${_finalTotal.toStringAsFixed(2)})',
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
// Receipt Modal Dialog
// ═════════════════════════════════════════════════════════════════════════════

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();
    final now = order.createdAt ?? DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final paymentMethodStr =
        order.paymentMethod == PaymentMethod.qr ? 'QR PromptPay' : locale.t('เงินสด', 'Cash');

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
                    locale.t('ชำระเงินสำเร็จ ✓', 'Payment Successful ✓'),
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
                          '${locale.t('คิวที่', 'Queue')} ${order.queueNumber}',
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
                        Text(
                          '${locale.t('ราคาก่อนภาษี', 'Subtotal')}:',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kCoffee700),
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
                        Text(
                          '${locale.t('รวมทั้งหมด', 'Grand Total')}:',
                          style: const TextStyle(
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
                      '${locale.t('ชำระด้วย:', 'Payment:')} $paymentMethodStr',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: kCoffee700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Centered: "ขอบคุณที่ใช้บริการ"
                    Center(
                      child: Text(
                        locale.t('ขอบคุณที่ใช้บริการ', 'Thank you for your visit'),
                        style: const TextStyle(
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
                  child: Text(locale.t('🖨️ พิมพ์ใบเสร็จ', '🖨️ Print Receipt')),
                ),
              ),
              const SizedBox(height: kSpace8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(locale.t('ปิด (ไม่พิมพ์)', 'Close (No Print)')),
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
// PART B: Manual Points Dialog (Fallback for forgotten member phone at Kiosk)
// ═════════════════════════════════════════════════════════════════════════════

class _ManualPointsDialog extends StatefulWidget {
  const _ManualPointsDialog();

  @override
  State<_ManualPointsDialog> createState() => _ManualPointsDialogState();
}

class _ManualPointsDialogState extends State<_ManualPointsDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final MemberService _memberService = MemberService();

  Member? _member;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _searchMessage;
  bool _notFound = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchMessage = null;
      _notFound = false;
      _member = null;
    });

    try {
      final member = await _memberService.getMemberByPhone(phone);
      if (!mounted) return;
      if (member != null) {
        setState(() {
          _member = member;
          _isSearching = false;
          _notFound = false;
        });
      } else {
        setState(() {
          _member = null;
          _isSearching = false;
          _notFound = true;
          _searchMessage = 'ไม่พบเบอร์นี้ในระบบสมาชิก';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _notFound = true;
        _searchMessage = 'เกิดข้อผิดพลาดในการค้นหา';
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_member == null) return;
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุยอดเงินที่ถูกต้อง')),
      );
      return;
    }

    final points = (amount / 10).floor();
    if (points <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยอดเงินต้องอย่างน้อย 10 บาทเพื่อรับ 1 แต้ม')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _memberService.addPointsForPurchase(_member!.phone, amount.toInt());

      if (!mounted) return;
      final memberName = (_member!.displayName != null && _member!.displayName!.isNotEmpty)
          ? _member!.displayName!
          : _member!.phone;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เพิ่มแต้มให้ $memberName แล้ว: +$points แต้ม'),
          backgroundColor: kColorPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    final calculatedPoints = (amount / 10).floor();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.stars, color: kGold),
          const SizedBox(width: kSpace8),
          Expanded(
            child: Text(
              locale.t('เพิ่มแต้มสมาชิก (กรณีลืมที่ตู้)', 'Add Member Points'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.t('กรอกเบอร์โทรศัพท์เพื่อค้นหาสมาชิก', 'Enter phone number to search member'),
                style: theme.textTheme.bodySmall?.copyWith(color: kColorTextMuted),
              ),
              const SizedBox(height: kSpace12),

              // Phone Field + Search Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: locale.t('เบอร์โทรศัพท์สมาชิก', 'Member Phone'),
                        hintText: '08XXXXXXXX',
                        prefixIcon: const Icon(Icons.phone, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  const SizedBox(width: kSpace8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _onSearch,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kColorWhite),
                            )
                          : Text(locale.t('ค้นหา', 'Search')),
                    ),
                  ),
                ],
              ),

              if (_notFound && _searchMessage != null) ...[
                const SizedBox(height: kSpace8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: kColorTextMuted),
                    const SizedBox(width: kSpace8),
                    Text(
                      _searchMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(color: kColorTextMuted),
                    ),
                  ],
                ),
              ],

              // Member details confirmation box
              if (_member != null) ...[
                const SizedBox(height: kSpace16),
                Container(
                  padding: const EdgeInsets.all(kSpace16),
                  decoration: BoxDecoration(
                    color: kGreen100.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    border: Border.all(color: kColorPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: kColorPrimary,
                            child: Icon(Icons.person, color: kColorWhite, size: 20),
                          ),
                          const SizedBox(width: kSpace12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_member!.displayName != null && _member!.displayName!.isNotEmpty)
                                      ? _member!.displayName!
                                      : 'สมาชิก (${_member!.phone})',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: kColorTextHeading,
                                  ),
                                ),
                                Text(
                                  _member!.phone,
                                  style: theme.textTheme.bodySmall?.copyWith(color: kColorTextMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kColorSurface,
                              borderRadius: BorderRadius.circular(kRadiusPill),
                              border: Border.all(color: kColorBorder),
                            ),
                            child: Text(
                              '${_member!.points} ${locale.t('แต้ม', 'pts')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: kColorPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: kSpace16),

                // Order amount input
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: locale.t('ยอดเงินที่สั่งซื้อ (บาท)', 'Order Amount (Baht)'),
                    hintText: '100',
                    prefixIcon: const Icon(Icons.receipt_long, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: kSpace12),

                // Calculated points preview
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace8),
                  decoration: BoxDecoration(
                    color: kColorBg,
                    borderRadius: BorderRadius.circular(kRadiusCard),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        locale.t('แต้มที่จะได้รับ (100 บ. = 10 แต้ม):', 'Points to add (100 THB = 10 pts):'),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '+$calculatedPoints ${locale.t('แต้ม', 'pts')}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: kColorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('ยกเลิก', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: (_member != null && calculatedPoints > 0 && !_isSubmitting)
              ? _onSubmit
              : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kColorWhite),
                )
              : Text(locale.t('เพิ่มแต้ม', 'Add Points')),
        ),
      ],
    );
  }
}
