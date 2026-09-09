import 'package:flutter/material.dart';
import '../theme.dart';

/// หน้า 4: Cashier POS
///
/// Landscape layout for staff iPad:
///   Left  — เมนูยอดฮิตสั่งให้ลูกค้าได้เร็ว + สั่งอาหารแทนลูกค้าหน้าเคาน์เตอร์
///   Right — ส่วนจัดการออร์เดอร์จาก Kiosk (cash / QR pending approval)
///
/// Features:
///   - กดยืนยันรับเงินจากออร์เดอร์ Kiosk ที่เลือกจ่ายเงินสด
///   - ยืนยันการโอนจาก QR code (Approve)
///   - เลือกออกใบเสร็จแบบดิจิทัล (SMS/QR) หรือพิมพ์กระดาษ
class CashierPosScreen extends StatefulWidget {
  const CashierPosScreen({super.key});

  @override
  State<CashierPosScreen> createState() => _CashierPosScreenState();
}

class _CashierPosScreenState extends State<CashierPosScreen> {
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
                // Staff / shift info placeholder
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kColorPrimary),
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

          // Quick-order grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: kSpace24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: kSpace12,
                crossAxisSpacing: kSpace12,
                childAspectRatio: 1.2,
              ),
              // TODO: Populate from Firestore (popular / pinned items)
              itemCount: 8,
              itemBuilder: (context, index) {
                return _QuickMenuItem(
                  name: 'Item ${index + 1}',
                  price: (45 + index * 5).toDouble(),
                  onTap: () {
                    // TODO: Add to POS order
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
                onPressed: () {
                  // TODO: Open full menu modal for counter orders
                },
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
    return Container(
      color: kColorSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(kSpace16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kColorBorder)),
            ),
            child: Row(
              children: [
                Text('Incoming Orders', style: theme.textTheme.headlineSmall),
                const Spacer(),
                // Filter chips placeholder
                Chip(
                  label: const Text('All'),
                  backgroundColor: kColorPrimary,
                  labelStyle: theme.textTheme.bodySmall
                      ?.copyWith(color: kColorWhite),
                ),
                const SizedBox(width: kSpace8),
                const Chip(label: Text('Cash')),
                const SizedBox(width: kSpace8),
                const Chip(label: Text('QR')),
              ],
            ),
          ),

          // Order list
          // TODO: StreamBuilder with Firestore onSnapshot for real-time orders
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(kSpace16),
              children: [
                _OrderCard(
                  queueNumber: '--',
                  status: 'No pending orders',
                  paymentMethod: '--',
                  total: 0,
                  onApprove: null,
                  onReceipt: null,
                ),
              ],
            ),
          ),
        ],
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
    required this.onTap,
  });

  final String name;
  final double price;
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
              const Icon(Icons.coffee, color: kCoffee500, size: 28),
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
  final String paymentMethod;
  final double total;
  final VoidCallback? onApprove;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  style: theme.textTheme.titleSmall,
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kColorSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace8),

            // Payment method & total
            Text(
              'Payment: $paymentMethod  •  ฿${total.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium,
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
