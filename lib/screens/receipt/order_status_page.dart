import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/locale_provider.dart';
import '../../theme.dart';
import '../../utils/customization_rules.dart';
import '../../utils/receipt_sharing.dart';
import '../../widgets/language_toggle.dart';

/// Digital Receipt / Live Order Status Page
///
/// Route: `/receipt/:orderId`
/// Accessible on mobile via QR code scan or direct URL.
/// No login required, read-only, real-time Firestore stream.
class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final GlobalKey _receiptCardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReceipt(Order order) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final bytes = await captureWidgetToImage(_receiptCardKey);
      if (bytes != null && mounted) {
        final queueStr = order.queueNumber.toString().padLeft(3, '0');
        final success = await shareOrDownloadReceipt(
          bytes: bytes,
          filename: 'toto_receipt_queue_$queueStr.png',
          title: 'ใบเสร็จ ToTo Cafe คิว #$queueStr',
          text: 'ใบเสร็จรับเงิน ToTo Cafe คิว #$queueStr ยอดรวม ฿${order.total.toStringAsFixed(2)}',
        );

        if (mounted && success) {
          final loc = context.read<LocaleProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('แชร์ / บันทึกรูปภาพใบเสร็จเรียบร้อย', 'Receipt image shared / saved successfully')),
              backgroundColor: kColorPrimary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[OrderStatusPage] Error sharing receipt: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .snapshots(),
          builder: (context, snapshot) {
            // Top branding & language bar
            Widget buildHeader() {
              return Padding(
                padding: const EdgeInsets.only(bottom: kSpace16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ToTo Cafe',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: 'Noto Serif Thai',
                            fontWeight: FontWeight.bold,
                            color: kColorTextHeading,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'COFFEE & COMFORT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.5,
                            color: kColorTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const LanguageToggle(),
                  ],
                ),
              );
            }

            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(kSpace24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildHeader(),
                        const Spacer(),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(kColorPrimary),
                        ),
                        const SizedBox(height: kSpace16),
                        Text(
                          locale.t(
                            'กำลังโหลดข้อมูลออร์เดอร์...',
                            'Loading order status...',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kColorTextMuted,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Not found state
            if (!snapshot.hasData ||
                !snapshot.data!.exists ||
                snapshot.data!.data() == null) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(kSpace24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildHeader(),
                        const Spacer(),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: kSpace16),
                        Text(
                          locale.t(
                            'ไม่พบข้อมูลคำสั่งซื้อ',
                            'Order Not Found',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: kColorTextHeading,
                          ),
                        ),
                        const SizedBox(height: kSpace8),
                        Text(
                          locale.t(
                            'กรุณาตรวจสอบลิงก์หรือติดต่อพนักงานที่เคาน์เตอร์\n(Order ID: ${widget.orderId})',
                            'Please check the link or contact staff at counter.\n(Order ID: ${widget.orderId})',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kColorTextMuted,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            }

            final order = Order.fromSnapshot(snapshot.data!);
            final queueStr = order.queueNumber.toString().padLeft(3, '0');
            final isUnpaid = order.status == OrderStatus.pendingPayment ||
                order.status == OrderStatus.awaitingApproval;
            final isCancelled = order.status == OrderStatus.cancelled;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildHeader(),

                      // ──────────────────────────────────────────────────────
                      // 1. UNPAID: Pending payment at counter
                      // ──────────────────────────────────────────────────────
                      if (isUnpaid) ...[
                        const SizedBox(height: kSpace12),
                        // Cash register icon
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: kColorSecondary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.point_of_sale,
                              color: kColorSecondary,
                              size: 44,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpace16),

                        // Title
                        Text(
                          locale.t(
                            'กรุณาชำระเงินที่เคาน์เตอร์',
                            'Please pay at the counter',
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: 'Noto Serif Thai',
                            fontWeight: FontWeight.bold,
                            color: kColorTextHeading,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpace4),
                        Text(
                          locale.t(
                            'พนักงานจะเรียกคิวของคุณ',
                            'Staff will call your queue number',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kColorTextMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpace24),

                        // Queue Number Card (DESIGN.md style)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpace24,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: kColorSurface,
                            borderRadius: BorderRadius.circular(kRadiusCard),
                            border: Border.all(color: kColorBorder, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                locale.t(
                                  'หมายเลขคิวของคุณ',
                                  'Your Queue Number',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: kColorTextMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: kSpace8),
                              Text(
                                queueStr,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  color: kColorPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 60,
                                ),
                              ),
                              const SizedBox(height: kSpace12),
                              const Divider(color: kColorBorder),
                              const SizedBox(height: kSpace12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${locale.t('ยอดที่ต้องชำระ', 'Amount to Pay')}:',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '฿${order.total.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: kColorSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Real-time status indicator pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpace16,
                            vertical: kSpace12,
                          ),
                          decoration: BoxDecoration(
                            color: kGreen100.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(kRadiusPill),
                            border: Border.all(color: kColorPrimary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(kColorPrimary),
                                ),
                              ),
                              const SizedBox(width: kSpace8),
                              Flexible(
                                child: Text(
                                  locale.t(
                                    'รอรับชำระเงินสด • หน้านี้จะอัปเดตอัตโนมัติ',
                                    'Pending cash payment • Updates live',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kColorPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kSpace24),

                        // Order Items Preview
                        _buildItemsPreviewCard(context, order, locale, theme),
                      ]

                      // ──────────────────────────────────────────────────────
                      // 2. CANCELLED: Order was cancelled
                      // ──────────────────────────────────────────────────────
                      else if (isCancelled) ...[
                        const SizedBox(height: kSpace16),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cancel_outlined,
                              size: 40,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpace16),
                        Text(
                          locale.t(
                            'ออร์เดอร์นี้ถูกยกเลิกแล้ว',
                            'Order Cancelled',
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: 'Noto Serif Thai',
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpace8),
                        Text(
                          '${locale.t('คิวที่', 'Queue')} #$queueStr',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: kColorTextMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpace16),
                        Text(
                          locale.t(
                            'หากมีข้อสงสัย กรุณาติดต่อพนักงานที่เคาน์เตอร์',
                            'If you have any questions, please contact staff at counter.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: kColorTextMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ]

                      // ──────────────────────────────────────────────────────
                      // 3. PAID / PREPARING / READY / COMPLETED
                      // ──────────────────────────────────────────────────────
                      else ...[
                        const SizedBox(height: kSpace8),
                        // Success icon
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 42,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpace12),

                        // Title: Payment Successful
                        Text(
                          locale.t('ชำระเงินสำเร็จ ✓', 'Payment Successful ✓'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: kSpace8),

                        // Status Badge
                        Center(child: _buildStatusPill(context, order.status, locale)),
                        const SizedBox(height: 20),

                        // Thermal Receipt Style Paper Card
                        _buildReceiptCard(context, order, locale, theme),
                        const SizedBox(height: 16),

                        // Share / Save Receipt Image Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSharing ? null : () => _shareReceipt(order),
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                  )
                                : const Icon(Icons.share, size: 20),
                            label: Text(
                              locale.t(
                                '📲 แชร์ / บันทึกรูปภาพใบเสร็จ',
                                '📲 Share / Save Receipt Image',
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kColorPrimary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: kSpace32),

                      // Footer
                      Center(
                        child: Text(
                          locale.t(
                            'ขอบคุณที่ใช้บริการ ToTo Cafe',
                            'Thank you for visiting ToTo Cafe',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: kColorTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpace12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Status badge pill for paid orders.
  Widget _buildStatusPill(BuildContext context, OrderStatus status, LocaleProvider locale) {
    String text;
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case OrderStatus.ready:
        text = locale.t('🎉 เครื่องดื่มพร้อมรับแล้ว!', '🎉 Ready for Pickup!');
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.notifications_active;
        break;
      case OrderStatus.completed:
        text = locale.t('✓ รับเครื่องดื่มเรียบร้อย', '✓ Order Completed');
        bg = kColorSurface;
        fg = kColorTextMuted;
        icon = Icons.done_all;
        break;
      case OrderStatus.preparing:
      case OrderStatus.paid:
      default:
        text = locale.t('☕ กำลังจัดเตรียมเครื่องดื่ม...', '☕ Preparing your drinks...');
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.coffee_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact item preview card for unpaid orders.
  Widget _buildItemsPreviewCard(
    BuildContext context,
    Order order,
    LocaleProvider locale,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(kSpace16),
      decoration: BoxDecoration(
        color: kColorSurface,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${locale.t('รายการอาหาร', 'Order Items')} (${order.items.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: kColorTextHeading,
            ),
          ),
          const SizedBox(height: kSpace8),
          const Divider(height: 1),
          const SizedBox(height: kSpace8),
          ...order.items.map((item) {
            final modSummary =
                CustomizationRules.getModifierSummary(item, includeLabels: false);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.name} × ${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: kColorTextBody,
                          ),
                        ),
                        if (modSummary != null && modSummary.isNotEmpty)
                          Text(
                            modSummary,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kColorTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '฿${item.lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kColorTextBody,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Full thermal style receipt card for paid orders.
  Widget _buildReceiptCard(
    BuildContext context,
    Order order,
    LocaleProvider locale,
    ThemeData theme,
  ) {
    final now = order.createdAt ?? DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final paymentMethodStr = order.paymentMethod == PaymentMethod.qr
        ? 'QR PromptPay'
        : locale.t('เงินสด', 'Cash');

    return RepaintBoundary(
      key: _receiptCardKey,
      child: Container(
        padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kTan),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cafe Title
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

          // Queue & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${locale.t('คิวที่', 'Queue')} #${order.queueNumber.toString().padLeft(3, '0')}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kCoffee900,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: kCoffee700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: kCoffee500, height: 1),
          const SizedBox(height: 8),

          // Items List
          ...order.items.map((item) {
            final modSummary =
                CustomizationRules.getModifierSummary(item, includeLabels: false);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
                  if (modSummary != null && modSummary.isNotEmpty)
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
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: kCoffee700,
                ),
              ),
              Text(
                '฿${order.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: kCoffee700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),


          // Points discount if any
          if (order.redeemedPoints > 0 || order.discount > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${locale.t('ส่วนลดแต้ม', 'Points Discount')} (-${order.redeemedPoints} ${locale.t('แต้ม', 'pts')}):',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '-฿${order.discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${locale.t('รวมทั้งหมด', 'Grand Total')}:',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kCoffee900,
                ),
              ),
              Text(
                '฿${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kCoffee900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Points Earned if any
          if (order.pointsEarned > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${locale.t('แต้มสะสมที่ได้รับ', 'Points Earned')}:',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: kCoffee700,
                  ),
                ),
                Text(
                  '+${order.pointsEarned} ${locale.t('แต้ม', 'pts')}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],

          // Member Phone if attached
          if (order.memberPhone != null && order.memberPhone!.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${locale.t('สมาชิก', 'Member')}:',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: kCoffee700,
                  ),
                ),
                Text(
                  order.memberPhone!.length >= 10
                      ? '${order.memberPhone!.substring(0, 3)}-xxx-${order.memberPhone!.substring(order.memberPhone!.length - 4)}'
                      : order.memberPhone!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: kCoffee900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Payment Method & Cash details
          Text(
            '${locale.t('ชำระด้วย:', 'Payment:')} $paymentMethodStr',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: kCoffee700,
            ),
          ),
          if (order.receivedAmount != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${locale.t('รับเงินสด', 'Cash Received')}:',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kCoffee700,
                  ),
                ),
                Text(
                  '฿${order.receivedAmount!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kCoffee900,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${locale.t('เงินทอน', 'Change')}:',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '฿${(order.changeAmount ?? (order.receivedAmount! - order.total)).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
}
