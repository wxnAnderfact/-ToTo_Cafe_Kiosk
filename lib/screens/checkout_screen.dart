import 'package:flutter/material.dart';
import '../theme.dart';

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
    // TODO: Generate PromptPay QR, update order status to pending_payment
  }

  void _onPayWithCash(BuildContext context) {
    // TODO: Print queue number, set payment_method = cash, notify POS
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  label: const Text('Back to Menu'),
                  style: TextButton.styleFrom(
                    foregroundColor: kColorTextBody,
                  ),
                ),
                const Spacer(),
                Text(
                  'Checkout',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                // Balance out the row
                const SizedBox(width: 120),
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
                  child: _buildOrderSummary(context, theme),
                ),

                const VerticalDivider(width: 1),

                // ═════════════════════════════════════════════════════════
                // RIGHT — Payment Options
                // ═════════════════════════════════════════════════════════
                Expanded(
                  flex: 2,
                  child: _buildPaymentOptions(context, theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left: Order Summary ─────────────────────────────────────────────────

  Widget _buildOrderSummary(BuildContext context, ThemeData theme) {
    return Container(
      color: kColorBg,
      padding: const EdgeInsets.all(kSpace24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: theme.textTheme.headlineMedium),
          const SizedBox(height: kSpace24),

          // TODO: List order items from cart state
          Expanded(
            child: Center(
              child: Text(
                'No items yet',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: kColorTextMuted),
              ),
            ),
          ),

          // ── Totals ────────────────────────────────────────────────────
          const Divider(),
          const SizedBox(height: kSpace12),
          _TotalRow(label: 'Subtotal', value: '฿0.00', theme: theme),
          const SizedBox(height: kSpace8),
          _TotalRow(
            label: 'VAT 7%',
            value: '฿0.00',
            theme: theme,
            isMuted: true,
          ),
          const SizedBox(height: kSpace12),
          const Divider(),
          const SizedBox(height: kSpace12),
          _TotalRow(
            label: 'Grand Total',
            value: '฿0.00',
            theme: theme,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ── Right: Payment Options ──────────────────────────────────────────────

  Widget _buildPaymentOptions(BuildContext context, ThemeData theme) {
    return Container(
      color: kColorSurface,
      padding: const EdgeInsets.all(kSpace32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Payment Method',
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
              label: const Text('Scan QR to Pay'),
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
              label: const Text('Pay with Cash at Counter'),
            ),
          ),

          const SizedBox(height: kSpace32),

          Text(
            'QR payment will be verified by our staff',
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
