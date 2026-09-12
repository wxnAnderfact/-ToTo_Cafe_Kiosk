import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thai_promptpay/thai_promptpay.dart';

import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../utils/customization_rules.dart';
import 'standby_screen.dart';

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

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Delay one frame so Provider / Navigator are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOrder());
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  // ── Order creation ────────────────────────────────────────────────────────

  Future<void> _initOrder() async {
    final cart = context.read<CartProvider>();

    if (cart.isEmpty) {
      setState(() {
        _step = _PaymentStep.error;
        _errorMsg = 'ตะกร้าสินค้าว่าง กรุณาเพิ่มสินค้าก่อนชำระเงิน';
      });
      return;
    }

    if (_kPromptPayId.isEmpty) {
      setState(() {
        _step = _PaymentStep.error;
        _errorMsg =
            'ยังไม่ได้ตั้งค่า PromptPay ID\nรันแอปด้วย --dart-define=PROMPTPAY_ID=<เบอร์>';
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
        total: breakdown.grandTotal,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _PaymentStep.error;
        _errorMsg = 'เกิดข้อผิดพลาด: $e';
      });
    }
  }

  // ── Real-time order listener ──────────────────────────────────────────────

  void _onOrderUpdate(Order? updated) {
    print('[Kiosk] _onOrderUpdate: ${updated?.status}');
    if (updated == null || !mounted) return;

    if (updated.status == OrderStatus.paid ||
        updated.status == OrderStatus.preparing ||
        updated.status == OrderStatus.ready) {
      // Cashier approved — clear cart and show success
      context.read<CartProvider>().clear();
      _orderSub?.cancel();
      setState(() {
        _order = updated;
        _step = _PaymentStep.success;
      });
    }
  }

  // ── Customer confirms transfer ─────────────────────────────────────────────

  Future<void> _onCustomerConfirmed() async {
    if (_order?.id == null) return;
    setState(() => _step = _PaymentStep.awaitingApproval);

    try {
      // Mark order as awaiting_approval (visible to cashier on POS)
      await _orderService.updateStatus(
        _order!.id!,
        OrderStatus.awaitingApproval,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถอัปเดตสถานะได้: $e')),
      );
      setState(() => _step = _PaymentStep.awaitingScan);
    }
  }

  // ── Navigate back to standby after success ────────────────────────────────

  void _onDone() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StandbyScreen()),
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: switch (_step) {
          _PaymentStep.generatingQr => _buildLoading('กำลังสร้าง QR Code...'),
          _PaymentStep.awaitingScan => _buildQrView(),
          _PaymentStep.awaitingApproval =>
            _buildLoading('รอพนักงานยืนยันการชำระเงิน...'),
          _PaymentStep.success => _buildSuccess(),
          _PaymentStep.error => _buildError(),
        },
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

  Widget _buildQrView() {
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
                    'สแกน QR ชำระเงิน',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: kSpace8),
                  Text(
                    'ใช้แอปธนาคารสแกน QR Code ด้านล่าง',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kColorTextMuted,
                    ),
                  ),
                  const SizedBox(height: kSpace32),

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
                      label: const Text('โอนเงินเรียบร้อย'),
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
                Text('สรุปออร์เดอร์', style: theme.textTheme.headlineSmall),
                const SizedBox(height: kSpace4),
                Text(
                  'คิวที่ ${order.queueNumber}',
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
                  label: 'ราคาก่อนภาษี',
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
                  label: 'ยอดสุทธิ',
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

  Widget _buildSuccess() {
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
                    '${order.queueNumber}'.padLeft(3, '0'),
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

  // ── Error view ────────────────────────────────────────────────────────────

  Widget _buildError() {
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
            Text('เกิดข้อผิดพลาด', style: theme.textTheme.headlineSmall),
            const SizedBox(height: kSpace8),
            Text(
              _errorMsg ?? 'ไม่ทราบสาเหตุ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: kColorTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('กลับ'),
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
