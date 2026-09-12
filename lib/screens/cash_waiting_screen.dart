import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import '../theme.dart';
import 'standby_screen.dart';

/// Screen displayed when customer selects "Pay with Cash at Counter".
///
/// Shows queue number and instructions to pay at the counter, then listens
/// for cashier confirmation via Firestore real-time snapshot.
class CashWaitingScreen extends StatefulWidget {
  const CashWaitingScreen({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  State<CashWaitingScreen> createState() => _CashWaitingScreenState();
}

class _CashWaitingScreenState extends State<CashWaitingScreen> {
  final _orderService = OrderService();
  late Order _currentOrder;
  bool _isPaid = false;
  StreamSubscription<Order?>? _orderSub;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    if (_currentOrder.id != null) {
      _orderSub = _orderService.watchOrder(_currentOrder.id!).listen(_onOrderUpdate);
    }
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  void _onOrderUpdate(Order? updated) {
    if (updated == null || !mounted) return;

    if (updated.status == OrderStatus.paid ||
        updated.status == OrderStatus.preparing ||
        updated.status == OrderStatus.ready ||
        updated.status == OrderStatus.completed) {
      context.read<CartProvider>().clear();
      _orderSub?.cancel();
      setState(() {
        _currentOrder = updated;
        _isPaid = true;
      });
    }
  }

  void _onDone() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StandbyScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: _isPaid ? _buildSuccess() : _buildWaiting(),
      ),
    );
  }

  // ── Waiting for Cashier Payment ──────────────────────────────────────────

  Widget _buildWaiting() {
    final theme = Theme.of(context);
    final queueStr = '${_currentOrder.queueNumber}'.padLeft(3, '0');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpace32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cash counter icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kColorSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: kColorSecondary,
                size: 56,
              ),
            ),
            const SizedBox(height: kSpace24),

            Text(
              'กรุณาชำระเงินที่เคาน์เตอร์',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace8),
            Text(
              'พนักงานจะเรียกคิวของคุณ',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: kColorTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace32),

            // Queue number badge (large, centered)
            Container(
              width: 320,
              padding: const EdgeInsets.symmetric(
                horizontal: kSpace32,
                vertical: kSpace24,
              ),
              decoration: BoxDecoration(
                color: kColorSurface,
                borderRadius: BorderRadius.circular(kRadiusCard),
                border: Border.all(color: kColorBorder, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'หมายเลขคิวของคุณ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace12),
                  Text(
                    queueStr,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: kColorPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 64,
                    ),
                  ),
                  const SizedBox(height: kSpace12),
                  const Divider(),
                  const SizedBox(height: kSpace12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ยอดที่ต้องชำระ:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '฿${_currentOrder.total.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: kColorSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: kSpace32),

            // Waiting indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(kColorSecondary),
                  ),
                ),
                const SizedBox(width: kSpace12),
                Text(
                  'รอรับเงินสดที่เคาน์เตอร์...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kColorTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Success view (Matches QrPaymentScreen style) ──────────────────────────

  Widget _buildSuccess() {
    final theme = Theme.of(context);
    final queueStr = '${_currentOrder.queueNumber}'.padLeft(3, '0');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpace32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kColorPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: kColorPrimary,
                size: 64,
              ),
            ),
            const SizedBox(height: kSpace24),
            Text('ชำระเงินสำเร็จ! 🎉', style: theme.textTheme.headlineMedium),
            const SizedBox(height: kSpace8),
            Text(
              'ขอบคุณที่ใช้บริการ ToTo Cafe',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: kColorTextMuted,
              ),
            ),
            const SizedBox(height: kSpace32),

            // Queue number badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpace32,
                vertical: kSpace16,
              ),
              decoration: BoxDecoration(
                color: kColorSurface,
                borderRadius: BorderRadius.circular(kRadiusCard),
                border: Border.all(color: kColorBorder),
              ),
              child: Column(
                children: [
                  Text(
                    'หมายเลขคิวของคุณ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace8),
                  Text(
                    queueStr,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: kColorPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  Text(
                    'กรุณารอเรียกคิว',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: kSpace48),

            SizedBox(
              width: 240,
              height: 52,
              child: FilledButton(
                onPressed: _onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: kColorPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                ),
                child: const Text('กลับหน้าแรก'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
