import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../widgets/language_toggle.dart';
import '../widgets/order_qr_code.dart';

typedef CashWaitingScreen = CashConfirmScreen;

/// หน้าจอแจ้งให้ลูกค้าไปชำระเงินสดที่เคาน์เตอร์
///
/// ไม่ต้องรอพนักงานกดยืนยัน (no onSnapshot listener)
/// มี countdown timer 30 วินาที แล้วจะเคลียร์ตะกร้าและกลับหน้าแรกอัตโนมัติ
class CashConfirmScreen extends StatefulWidget {
  const CashConfirmScreen({
    super.key,
    required this.order,
  });

  final Order order;

  @override
  State<CashConfirmScreen> createState() => _CashConfirmScreenState();
}

class _CashConfirmScreenState extends State<CashConfirmScreen> {
  static const int _kInitialSeconds = 30;
  int _secondsRemaining = _kInitialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _onComplete();
      }
    });
  }

  void _onComplete() {
    _timer?.cancel();
    if (!mounted) return;
    context.read<CartProvider>().clear();
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    context.go('/kiosk');
  }

  Future<void> _onCancelOrder() async {
    final locale = context.read<LocaleProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locale.t('ยกเลิกการสั่งซื้อ?', 'Cancel Order?')),
        content: Text(
          locale.t(
            'คุณต้องการยกเลิกคำสั่งซื้อนี้ใช่หรือไม่?',
            'Do you want to cancel this order?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(locale.t('ไม่ยกเลิก', 'No, keep order')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(locale.t('ยืนยันยกเลิก', 'Yes, cancel')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      if (widget.order.id != null) {
        try {
          await OrderService().cancelOrder(widget.order.id!);
        } catch (_) {}
      }
      if (mounted) {
        context.read<CartProvider>().clear();
        _onComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();
    final queueStr = '${widget.order.queueNumber}'.padLeft(3, '0');
    final progress = _secondsRemaining / _kInitialSeconds;

    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpace32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cash register icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: kColorSecondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.point_of_sale,
                        color: kColorSecondary,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: kSpace24),

                    // Heading
                    Text(
                      locale.t('กรุณาชำระเงินที่เคาน์เตอร์', 'Please pay at the counter'),
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpace8),
                    Text(
                      locale.t('พนักงานจะเรียกคิวของคุณ', 'Staff will call your queue number'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: kColorTextMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpace32),

                    // Queue number badge (large, bold, centered)
                    Container(
                      width: 340,
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
                            locale.t('หมายเลขคิวของคุณ', 'Your Queue Number'),
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
                                '${locale.t('ยอดที่ต้องชำระ', 'Amount to Pay')}:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                '฿${widget.order.total.toStringAsFixed(2)}',
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

                    if (widget.order.id != null && widget.order.id!.isNotEmpty) ...[
                      const SizedBox(height: kSpace24),
                      OrderQrCode(
                        orderId: widget.order.id!,
                        caption: locale.t('สแกนเพื่อดูสถานะคิว', 'Scan to track queue status'),
                      ),
                    ],

                    const SizedBox(height: kSpace32),

                    // 30-second Countdown with CircularProgressIndicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpace24,
                        vertical: kSpace12,
                      ),
                      decoration: BoxDecoration(
                        color: kColorSurface,
                        borderRadius: BorderRadius.circular(kRadiusPill),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              backgroundColor: kColorBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(kColorPrimary),
                            ),
                          ),
                          const SizedBox(width: kSpace12),
                          Text(
                            '${locale.t('หน้าจอจะกลับสู่หน้าหลักใน', 'Returning to home in')} $_secondsRemaining ${locale.t('วินาที', 'seconds')}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: kColorTextBody,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: kSpace32),

                    // Manual action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 50,
                          child: FilledButton(
                            onPressed: _onComplete,
                            style: FilledButton.styleFrom(
                              backgroundColor: kColorPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadiusPill),
                              ),
                            ),
                            child: Text(locale.t('กลับหน้าแรก', 'Return to Home')),
                          ),
                        ),
                        const SizedBox(width: kSpace12),
                        SizedBox(
                          width: 160,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _onCancelOrder,
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(locale.t('ยกเลิกออร์เดอร์', 'Cancel Order')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadiusPill),
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
            const Positioned(
              top: kSpace16,
              right: kSpace16,
              child: LanguageToggle(),
            ),
          ],
        ),
      ),
    );
  }
}
