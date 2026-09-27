// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';

import 'package:go_router/go_router.dart';

import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../services/member_service.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../utils/customization_rules.dart';
import '../utils/printer.dart';
import '../widgets/language_toggle.dart';

// ---------------------------------------------------------------------------
// PromptPay ID — store your phone/national-ID in your .env / app config.
// Replace the value below or inject via --dart-define:
//   flutter run --dart-define=PROMPTPAY_ID=0812345678
// ---------------------------------------------------------------------------
const String _kPromptPayId =
    String.fromEnvironment('PROMPTPAY_ID', defaultValue: '');

/// หน้าชำระเงินด้วย QR PromptPay (Semi-automated POS Approval flow)
///
/// Flow:
///   1. สร้าง Order document ใน Firestore (status = pending_payment)
///   2. แสดง PromptPay QR ที่ฝังยอดชำระเงิน (Dynamic QR)
///   3. ลูกค้าสแกน QR จ่าย จากนั้นกดปุ่ม "โอนเงินเรียบร้อย"
///      → อัปเดต Firestore status = pending_confirmation
///   4. stream watchOrder() รับสัญญาณจากพนักงานที่กด Approve ที่หน้า POS
///      → status = paid → เปลี่ยนมาหน้า Payment Success
class QrPaymentScreen extends StatefulWidget {
  const QrPaymentScreen({super.key});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  final _orderService = OrderService();

  // ── State ─────────────────────────────────────────────────────────────────
  _PaymentStep _step = _PaymentStep.generatingQr;
  Order? _order;
  String? _qrPayload;
  String? _errorMsg;
  StreamSubscription<Order?>? _orderSub;
  Timer? _countdownTimer;
  int _countdown = 15;
  bool _countdownStarted = false;
  Timer? _qrExpiryTimer;
  int _qrSecondsRemaining = 180; // 3 minutes

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Delay one frame so Provider / Navigator are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOrder());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _qrExpiryTimer?.cancel();
    _orderSub?.cancel();
    super.dispose();
  }

  // ── Order creation ────────────────────────────────────────────────────────

  Future<void> _initOrder() async {
    final cart = context.read<CartProvider>();
    final locale = context.read<LocaleProvider>();

    if (cart.isEmpty) {
      setState(() {
        _step = _PaymentStep.error;
        _errorMsg = locale.t(
          'ตะกร้าสินค้าว่าง กรุณาเพิ่มสินค้าก่อนชำระเงิน',
          'Cart is empty. Please add items before checkout.',
        );
      });
      return;
    }

    if (_kPromptPayId.isEmpty) {
      setState(() {
        _step = _PaymentStep.error;
        _errorMsg = locale.t(
          'ยังไม่ได้ตั้งค่า PromptPay ID\nรันแอปด้วย --dart-define=PROMPTPAY_ID=<เบอร์>',
          'PromptPay ID not configured\nRun app with --dart-define=PROMPTPAY_ID=<number>',
        );
      });
      return;
    }

    try {
      // 1. Generate queue number
      final queueNumber = await _orderService.nextQueueNumber();

      // 2. Build Order object
      final breakdown = cart.priceBreakdown;
      final order = Order(
        items: List.from(cart.items),
        status: OrderStatus.pendingPayment,
        paymentMethod: PaymentMethod.qr,
        queueNumber: queueNumber,
        subtotal: breakdown.subtotal,
        vat: breakdown.vat,
        total: cart.totalAfterDiscount,
        discount: cart.discount,
        redeemedPoints: cart.redeemedPoints,
        pointsEarned: (cart.totalAfterDiscount / 20).floor(),
        memberPhone: cart.memberPhone,
      );

      // 3. Write to Firestore — get back the doc with its id
      final created = await _orderService.createOrder(order);

      // 4. Build PromptPay payload (Dynamic QR with amount)
      //    Use promptPayMobile for 10-digit phone, promptPayNationalId for 13-digit
      final amountSatang = (created.total * 100).round();
      final String payload;
      if (_kPromptPayId.length == 13) {
        payload = promptPayNationalId(_kPromptPayId, amountSatang: amountSatang);
      } else {
        payload = promptPayMobile(_kPromptPayId, amountSatang: amountSatang);
      }

      // 5. Listen for cashier approval via real-time stream
      _orderSub = _orderService.watchOrder(created.id!).listen(_onOrderUpdate);

      if (!mounted) return;
      setState(() {
        _order = created;
        _qrPayload = payload;
        _step = _PaymentStep.awaitingScan;
      });
      _startQrExpiryTimer();
    } catch (e) {
      if (!mounted) return;
      final locale = context.read<LocaleProvider>();
      setState(() {
        _step = _PaymentStep.error;
        _errorMsg = '${locale.t('เกิดข้อผิดพลาด', 'An error occurred')}: $e';
      });
    }
  }

  // ── Real-time order listener ──────────────────────────────────────────────

  void _onOrderUpdate(Order? updated) {
    debugPrint('[Kiosk] _onOrderUpdate: ${updated?.status}');
    if (updated == null || !mounted) return;

    if (updated.status == OrderStatus.paid ||
        updated.status == OrderStatus.preparing ||
        updated.status == OrderStatus.ready) {
      if (_step == _PaymentStep.success) return;
      _handlePaymentSuccess(updated);
    }
  }

  Future<void> _handlePaymentSuccess(Order updated) async {
    _qrExpiryTimer?.cancel();
    _orderSub?.cancel();

    // If member phone was attached to this order, redeem & add points
    final phone = updated.memberPhone ?? context.read<CartProvider>().memberPhone;
    if (phone != null && phone.isNotEmpty) {
      if (updated.redeemedPoints > 0) {
        try {
          await MemberService().redeemPoints(phone, updated.redeemedPoints);
        } catch (e) {
          debugPrint('[QR] Error redeeming points: $e');
        }
      }
      final earned = updated.pointsEarned > 0 ? updated.pointsEarned : (updated.total / 20).floor();
      if (earned > 0) {
        try {
          await MemberService().addPoints(phone, earned);
        } catch (e) {
          debugPrint('[QR] Error adding points for purchase: $e');
        }
      }
    }

    // Cashier approved — clear cart and show success
    if (mounted) {
      context.read<CartProvider>().clear();
    }
    setState(() {
      _order = updated;
      _step = _PaymentStep.success;
      _countdownStarted = false;
    });

    if (!mounted) return;
    await _showKioskReceiptDialog(context, updated);

    if (!mounted) return;
    setState(() {
      _countdownStarted = true;
    });
    _startSuccessCountdown();
  }

  Future<void> _showKioskReceiptDialog(BuildContext context, Order order) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _KioskReceiptDialog(order: order),
    );
  }

  void _startSuccessCountdown() {
    _countdownTimer?.cancel();
    _countdown = 15;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _onDone();
      }
    });
  }

  // ── Customer confirms transfer ─────────────────────────────────────────────

  Future<void> _onCustomerConfirmed() async {
    if (_order?.id == null) return;
    _qrExpiryTimer?.cancel();
    setState(() => _step = _PaymentStep.awaitingApproval);

    try {
      // Mark order as awaiting_approval (visible to cashier on POS)
      await _orderService.updateStatus(
        _order!.id!,
        OrderStatus.awaitingApproval,
      );
    } catch (e) {
      if (!mounted) return;
      final locale = context.read<LocaleProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${locale.t('ไม่สามารถอัปเดตสถานะได้', 'Could not update status')}: $e'),
        ),
      );
      setState(() => _step = _PaymentStep.awaitingScan);
      _startQrExpiryTimer();
    }
  }

  // ── QR Expiry & Actions ───────────────────────────────────────────────────

  void _startQrExpiryTimer() {
    _qrExpiryTimer?.cancel();
    _qrSecondsRemaining = 180; // 3 minutes
    _qrExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_qrSecondsRemaining > 1) {
        setState(() => _qrSecondsRemaining--);
      } else {
        timer.cancel();
        _onQrExpired();
      }
    });
  }

  void _onQrExpired() {
    _qrExpiryTimer?.cancel();
    _orderSub?.cancel();
    if (_order?.id != null) {
      try {
        _orderService.cancelOrder(_order!.id!);
      } catch (_) {}
    }
    setState(() {
      _step = _PaymentStep.qrExpired;
    });
  }

  Future<void> _onBackToCheckout() async {
    _qrExpiryTimer?.cancel();
    _orderSub?.cancel();
    if (_order?.id != null) {
      try {
        await _orderService.deleteOrder(_order!.id!);
      } catch (_) {}
    }
    if (mounted) {
      context.go('/kiosk/checkout');
    }
  }

  Future<void> _onCancelOrder() async {
    final locale = context.read<LocaleProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locale.t('ยกเลิกการสั่งซื้อ?', 'Cancel Order?')),
        content: Text(
          locale.t(
            'คุณต้องการยกเลิกคำสั่งซื้อนี้และกลับสู่หน้าหลักใช่หรือไม่?',
            'Do you want to cancel this order and return to home?',
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
      _qrExpiryTimer?.cancel();
      _orderSub?.cancel();
      if (_order?.id != null) {
        try {
          await _orderService.deleteOrder(_order!.id!);
        } catch (_) {}
      }
      if (mounted) {
        context.read<CartProvider>().clear();
        _onDone();
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ── Navigate back to standby after success ────────────────────────────────

  void _onDone() {
    _countdownTimer?.cancel();
    _qrExpiryTimer?.cancel();
    _orderSub?.cancel();
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (mounted) {
      context.go('/kiosk');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_step == _PaymentStep.success) {
          _onDone();
        } else {
          await _onBackToCheckout();
        }
      },
      child: Scaffold(
        backgroundColor: kColorBg,
        body: SafeArea(
          child: Stack(
            children: [
              switch (_step) {
                _PaymentStep.generatingQr =>
                  _buildLoading(locale.t('กำลังสร้าง QR Code...', 'Generating QR Code...')),
                _PaymentStep.awaitingScan => _buildQrView(locale),
                _PaymentStep.awaitingApproval =>
                  _buildLoading(locale.t('รอพนักงานยืนยันการชำระเงิน...', 'Waiting for staff approval...')),
                _PaymentStep.success => _buildSuccess(locale),
                _PaymentStep.error => _buildError(locale),
                _PaymentStep.qrExpired => _buildQrExpired(locale),
              },
              const Positioned(
                top: kSpace16,
                right: kSpace16,
                child: LanguageToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading view ──────────────────────────────────────────────────────────

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kColorPrimary),
          const SizedBox(height: kSpace24),
          Text(message, style: _bodyStyle()),
        ],
      ),
    );
  }

  // ── QR code view ──────────────────────────────────────────────────────────

  Widget _buildQrView(LocaleProvider locale) {
    final order = _order!;
    final theme = Theme.of(context);

    return Row(
      children: [
        // ─── Left: QR + instructions ─────────────────────────────────────
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpace32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locale.t('สแกน QR ชำระเงิน', 'Scan QR to Pay'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: kSpace8),
                  Text(
                    locale.t(
                      'ใช้แอปธนาคารสแกน QR Code ด้านล่าง',
                      'Use your banking app to scan the QR Code below',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace16),

                  // Expiration countdown badge
                  Container(
                    margin: const EdgeInsets.only(bottom: kSpace16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _qrSecondsRemaining < 30 ? Colors.red.shade50 : kTan,
                      borderRadius: BorderRadius.circular(kRadiusPill),
                      border: Border.all(
                        color: _qrSecondsRemaining < 30 ? Colors.red.shade300 : kColorBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _qrSecondsRemaining < 30 ? Colors.red.shade700 : kCoffee700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${locale.t('QR Code หมดอายุใน', 'Expires in')} ${_formatTime(_qrSecondsRemaining)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _qrSecondsRemaining < 30 ? Colors.red.shade700 : kCoffee900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // QR Code
                  Container(
                    decoration: BoxDecoration(
                      color: kColorSurface,
                      borderRadius: BorderRadius.circular(kRadiusCard),
                      border: Border.all(color: kColorBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(kSpace24),
                    child: Column(
                      children: [
                        // PromptPay logo row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.qr_code_2,
                              color: kColorPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: kSpace8),
                            Text(
                              'PromptPay',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: kColorPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: kSpace16),

                        QrImageView(
                          data: _qrPayload!,
                          version: QrVersions.auto,
                          size: 260,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: kColorPrimary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: kColorTextHeading,
                          ),
                        ),
                        const SizedBox(height: kSpace16),

                        // Amount
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpace16,
                            vertical: kSpace8,
                          ),
                          decoration: BoxDecoration(
                            color: kColorBg,
                            borderRadius:
                                BorderRadius.circular(kRadiusPill),
                          ),
                          child: Text(
                            '฿${order.total.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: kColorSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpace32),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _onCustomerConfirmed,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(locale.t('โอนเงินเรียบร้อย', 'Transfer Complete')),
                      style: FilledButton.styleFrom(
                        backgroundColor: kColorPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(kRadiusPill),
                        ),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace12),

                  // Cancel & Back buttons
                  Row(
                    children: [
                      // Back / Change payment method
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _onBackToCheckout,
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: Text(locale.t('เปลี่ยนวิธีชำระ', 'Change Payment')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kCoffee900,
                              side: const BorderSide(color: kCoffee500),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadiusPill),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpace12),
                      // Cancel order
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _onCancelOrder,
                            icon: const Icon(Icons.close, size: 16),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const VerticalDivider(width: 1),

        // ─── Right: Order summary ─────────────────────────────────────────
        Expanded(
          flex: 2,
          child: Container(
            color: kColorSurface,
            padding: const EdgeInsets.all(kSpace24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.t('สรุปออร์เดอร์', 'Order Summary'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: kSpace4),
                Text(
                  '${locale.t('คิวที่', 'Queue')} ${order.queueNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kColorPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: kSpace16),
                const Divider(),
                const SizedBox(height: kSpace8),

                // Line items
                Expanded(
                  child: ListView.separated(
                    itemCount: order.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 20),
                    itemBuilder: (context, i) {
                      final item = order.items[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final modSummary = CustomizationRules.getModifierSummary(item, includeLabels: false);
                                    if (modSummary == null) return const SizedBox.shrink();
                                    return Text(
                                      modSummary,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: kColorTextMuted,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'x${item.quantity}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: kSpace12),
                          Text(
                            '฿${item.lineTotal.toStringAsFixed(0)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Totals
                const Divider(),
                const SizedBox(height: kSpace8),
                _TotalRow(
                  label: locale.t('ราคาก่อนภาษี', 'Subtotal'),
                  value: '฿${order.subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: kSpace4),
                _TotalRow(
                  label: 'VAT 7%',
                  value: '฿${order.vat.toStringAsFixed(2)}',
                  muted: true,
                ),
                const SizedBox(height: kSpace8),
                const Divider(),
                const SizedBox(height: kSpace8),
                _TotalRow(
                  label: locale.t('ยอดสุทธิ', 'Grand Total'),
                  value: '฿${order.total.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Success view ──────────────────────────────────────────────────────────

  Widget _buildSuccess(LocaleProvider locale) {
    final theme = Theme.of(context);
    final order = _order!;

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
            Text(
              locale.t('ชำระเงินสำเร็จ! 🎉', 'Payment Successful! 🎉'),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: kSpace8),
            Text(
              locale.t('ขอบคุณที่ใช้บริการ ToTo Cafe', 'Thank you for visiting ToTo Cafe'),
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
                    locale.t('หมายเลขคิวของคุณ', 'Your Queue Number'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace8),
                  Text(
                    '${order.queueNumber}'.padLeft(3, '0'),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: kColorPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: kSpace4),
                  Text(
                    locale.t('กรุณารอเรียกคิว', 'Please wait for your queue'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                ],
              ),
            ),

            if (_countdownStarted) ...[
              const SizedBox(height: kSpace16),
              Text(
                locale.t(
                  'กลับหน้าหลักใน $_countdown วินาที...',
                  'Returning to home in $_countdown seconds...',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kColorTextMuted,
                ),
              ),
            ],
            const SizedBox(height: kSpace32),
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
                child: Text(locale.t('กลับหน้าแรก', 'Return to Home')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error view ────────────────────────────────────────────────────────────

  Widget _buildError(LocaleProvider locale) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: kSpace16),
            Text(
              locale.t('เกิดข้อผิดพลาด', 'An error occurred'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: kSpace8),
            Text(
              _errorMsg ?? locale.t('ไม่ทราบสาเหตุ', 'Unknown error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: kColorTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(locale.t('กลับ', 'Back')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrExpired(LocaleProvider locale) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(kSpace32),
        decoration: BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.circular(kRadiusCard),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.amber.shade800, size: 64),
            const SizedBox(height: kSpace16),
            Text(
              locale.t('QR Code หมดอายุแล้ว', 'QR Code Expired'),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: kSpace8),
            Text(
              locale.t(
                'กรุณาสร้าง QR Code ใหม่อีกครั้ง หรือเลือกเปลี่ยนช่องทางชำระเงิน',
                'Please regenerate the QR Code or change your payment method.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: kColorTextMuted),
            ),
            const SizedBox(height: kSpace24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _initOrder,
                icon: const Icon(Icons.refresh),
                label: Text(locale.t('สร้าง QR Code ใหม่อีกครั้ง', 'Regenerate QR Code')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusPill)),
                ),
              ),
            ),
            const SizedBox(height: kSpace12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _onBackToCheckout,
                icon: const Icon(Icons.payment),
                label: Text(locale.t('เปลี่ยนวิธีชำระเงิน', 'Change Payment Method')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCoffee900,
                  side: const BorderSide(color: kCoffee500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusPill)),
                ),
              ),
            ),
            const SizedBox(height: kSpace12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _onCancelOrder,
                child: Text(
                  locale.t('ยกเลิกการสั่งซื้อนี้', 'Cancel this order'),
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _bodyStyle() => TextStyle(
        color: kColorTextBody,
        fontSize: 16,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Enums & sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

enum _PaymentStep {
  generatingQr,
  awaitingScan,
  awaitingApproval,
  success,
  error,
  qrExpired,
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final style = bold
        ? base?.copyWith(fontWeight: FontWeight.w700)
        : muted
            ? base?.copyWith(color: kColorTextMuted)
            : base;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Kiosk Receipt Modal Dialog
// ═══════════════════════════════════════════════════════════════════════════

class _KioskReceiptDialog extends StatelessWidget {
  const _KioskReceiptDialog({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = order.createdAt ?? DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Consumer<LocaleProvider>(
      builder: (context, locale, child) {
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

                        // Queue number & Date/Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${locale.t('คิวที่', 'Queue #')} ${order.queueNumber}',
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

                        // Grand Total (bold)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${locale.t('ยอดสุทธิ', 'Grand Total')}:',
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

                        if (order.redeemedPoints > 0 || order.discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${locale.t('ส่วนลดแต้ม', 'Points Discount')} (-${order.redeemedPoints} ${locale.t('แต้ม', 'pts')}):',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '-฿${order.discount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (order.pointsEarned > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${locale.t('แต้มสะสมที่ได้รับ', 'Points Earned')}:',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: kCoffee700,
                                ),
                              ),
                              Text(
                                '+${order.pointsEarned} ${locale.t('แต้ม', 'pts')}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: kCoffee900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (order.memberPhone != null && order.memberPhone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${locale.t('สมาชิก', 'Member')}:',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: kCoffee700,
                                ),
                              ),
                              Text(
                                order.memberPhone!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: kCoffee900,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Payment method: "QR PromptPay"
                        const Text(
                          'QR PromptPay',
                          style: TextStyle(
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

                  // Two buttons:
                  // 1. 🖨️ พิมพ์ใบเสร็จ -> thermal receipt print
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        printThermalReceipt(order);
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
                  // 2. ปิด (ไม่พิมพ์) -> outlined
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
      },
    );
  }
}
