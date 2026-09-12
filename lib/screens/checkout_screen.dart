import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../utils/customization_rules.dart';
import '../widgets/language_toggle.dart';
import 'cash_waiting_screen.dart';
import 'qr_payment_screen.dart';

/// หน้า 3: Checkout
///
/// Layout (2-column):
///   Left  — สรุปออร์เดอร์ + Subtotal / VAT 7% / Grand Total
///   Right — ปุ่มเลือกชำระเงิน "Scan QR to Pay" / "Pay with Cash at Counter"
///   ปุ่ม "Back to Menu" มุมซ้ายบน
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  void _onBackToMenu(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _onPayWithQR(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const QrPaymentScreen(),
      ),
    );
  }

  Future<void> _onPayWithCash(BuildContext context) async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;

    try {
      final orderService = OrderService();
      final queueNumber = await orderService.nextQueueNumber();
      final breakdown = cart.priceBreakdown;
      final order = Order(
        items: List.from(cart.items),
        status: OrderStatus.awaitingApproval,
        paymentMethod: PaymentMethod.cash,
        queueNumber: queueNumber,
        subtotal: breakdown.subtotal,
        vat: breakdown.vat,
        total: breakdown.grandTotal,
      );

      final created = await orderService.createOrder(order);

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CashWaitingScreen(order: created),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      body: Column(
        children: [
          // ── Top bar with Back button ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpace16,
              vertical: kSpace12,
            ),
            decoration: const BoxDecoration(
              color: kColorSurface,
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _onBackToMenu(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(locale.t('กลับไปเมนู', 'Back to Menu')),
                  style: TextButton.styleFrom(
                    foregroundColor: kColorTextBody,
                  ),
                ),
                const Spacer(),
                Text(
                  locale.t('ชำระเงิน', 'Checkout'),
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                Container(
                  width: 140,
                  alignment: Alignment.centerRight,
                  child: const LanguageToggle(),
                ),
              ],
            ),
          ),

          // ── Main content (2-column) ─────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // ═════════════════════════════════════════════════════════
                // LEFT — Order Summary
                // ═════════════════════════════════════════════════════════
                Expanded(
                  flex: 3,
                  child: _buildOrderSummary(context, theme, locale),
                ),

                const VerticalDivider(width: 1),

                // ═════════════════════════════════════════════════════════
                // RIGHT — Payment Options
                // ═════════════════════════════════════════════════════════
                Expanded(
                  flex: 2,
                  child: _buildPaymentOptions(context, theme, locale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left: Order Summary ─────────────────────────────────────────────────

  Widget _buildOrderSummary(BuildContext context, ThemeData theme, LocaleProvider locale) {
    final cart = context.watch<CartProvider>();

    return Container(
      color: kColorBg,
      padding: const EdgeInsets.all(kSpace24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(locale.t('สรุปออร์เดอร์', 'Order Summary'), style: theme.textTheme.headlineMedium),
          const SizedBox(height: kSpace24),

          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Text(
                      locale.t('ยังไม่มีรายการ', 'No items yet'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: kColorTextMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Builder(
                                  builder: (context) {
                                    final modSummary = CustomizationRules.getModifierSummary(item);
                                    if (modSummary == null) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: kSpace4),
                                      child: Text(
                                        modSummary,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Text('x${item.quantity}',
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(width: kSpace16),
                          Text(
                            '฿${item.lineTotal.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // ── Totals ────────────────────────────────────────────────────
          const Divider(),
          const SizedBox(height: kSpace12),
          _TotalRow(
            label: locale.t('ราคาก่อนภาษี', 'Subtotal'),
            value: '฿${cart.subtotal.toStringAsFixed(2)}',
            theme: theme,
          ),
          const SizedBox(height: kSpace8),
          _TotalRow(
            label: locale.t('VAT 7%', 'VAT 7%'),
            value: '฿${cart.vat.toStringAsFixed(2)}',
            theme: theme,
            isMuted: true,
          ),
          const SizedBox(height: kSpace12),
          const Divider(),
          const SizedBox(height: kSpace12),
          _TotalRow(
            label: locale.t('ยอดสุทธิ', 'Grand Total'),
            value: '฿${cart.grandTotal.toStringAsFixed(2)}',
            theme: theme,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ── Right: Payment Options ──────────────────────────────────────────────

  Widget _buildPaymentOptions(BuildContext context, ThemeData theme, LocaleProvider locale) {
    return Container(
      color: kColorSurface,
      padding: const EdgeInsets.all(kSpace32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            locale.t('เลือกวิธีชำระเงิน', 'Choose Payment Method'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpace48),

          // QR Payment button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: () => _onPayWithQR(context),
              icon: const Icon(Icons.qr_code, size: 28),
              label: Text(locale.t('สแกน QR จ่ายเงิน', 'Scan QR to Pay')),
            ),
          ),
          const SizedBox(height: kSpace16),

          // Cash Payment button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton.icon(
              onPressed: () => _onPayWithCash(context),
              icon: const Icon(Icons.payments_outlined, size: 28),
              label: Text(locale.t('จ่ายเงินสดที่เคาน์เตอร์', 'Pay with Cash at Counter')),
            ),
          ),

          const SizedBox(height: kSpace32),

          Text(
            locale.t('QR จะถูกตรวจสอบโดยพนักงาน', 'QR payment will be verified by our staff'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.theme,
    this.isBold = false,
    this.isMuted = false,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final bool isBold;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : isMuted
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
