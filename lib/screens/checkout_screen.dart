// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/member.dart';
import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../services/member_service.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../widgets/language_toggle.dart';
import 'cash_waiting_screen.dart';

/// หน้า 3: Checkout (ชำระเงิน)
///
/// Layout (2-column สำหรับ iPad Portrait / Kiosk):
///   Left  — สรุปออร์เดอร์ + Subtotal / VAT 7% / ส่วนลดสมาชิก / Grand Total
///   Right — การ์ดสมาชิก ToTo Cafe (สะสมแต้ม/ใช้แต้ม) + ปุ่มเลือกชำระเงิน "Scan QR" / "Cash"
///   Top   — ปุ่ม "ย้อนกลับหน้าเมนู" + TH/EN Language Toggle
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _hasAutoPromptedMember = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = context.read<CartProvider>();
      if (mounted &&
          cart.member == null &&
          (cart.memberPhone == null || cart.memberPhone!.isEmpty)) {
        if (!_hasAutoPromptedMember) {
          _hasAutoPromptedMember = true;
          _showMemberPromptDialog(context);
        }
      }
    });
  }

  /// แสดง Popup ถามสมาชิกอัตโนมัติ (พร้อม QR ชวนสมัคร และปุ่มข้าม)
  Future<void> _showMemberPromptDialog(BuildContext context) async {
    final cart = context.read<CartProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _MemberPromptDialog(
        initialPhone: cart.memberPhone ?? '',
        onMemberFound: (member, phone) {
          cart.setMember(member, phone: phone);
        },
      ),
    );
  }

  void _onBackToMenu(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/kiosk/menu');
    }
  }

  void _onPayWithQR(BuildContext context) {
    context.go('/kiosk/payment/qr');
  }

  Future<void> _onPayWithCash(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final locale = context.read<LocaleProvider>();
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
        total: cart.totalAfterDiscount,
        discount: cart.discount,
        redeemedPoints: cart.redeemedPoints,
        pointsEarned: (cart.totalAfterDiscount / 20).floor(),
        memberPhone: cart.memberPhone,
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
        SnackBar(
          content: Text(
            '${locale.t('เกิดข้อผิดพลาด', 'Error')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _showRedeemDialog(BuildContext context, Member member) async {
    final cart = context.read<CartProvider>();
    final locale = context.read<LocaleProvider>();
    final maxRedeemablePoints =
        min(member.points, cart.grandTotal.floor());

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

    int currentSelection = cart.redeemedPoints > 0
        ? min(cart.redeemedPoints, maxRedeemablePoints)
        : maxRedeemablePoints;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final discountValue = currentSelection * 1.0;
            final totalAfter =
                (cart.grandTotal - discountValue).clamp(0.0, double.infinity);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.stars, color: kGold),
                  const SizedBox(width: kSpace8),
                  Text(locale.t('ใช้แต้มเป็นส่วนลด', 'Redeem Points for Discount')),
                ],
              ),
              content: SizedBox(
                width: 420,
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: kColorTextMuted),
                    ),
                    const SizedBox(height: kSpace16),

                    // Slider
                    Slider(
                      value: currentSelection.toDouble(),
                      min: 0,
                      max: maxRedeemablePoints.toDouble(),
                      divisions: maxRedeemablePoints > 0
                          ? max(1, min(maxRedeemablePoints, 100))
                          : 1,
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
                      children: [
                        if (maxRedeemablePoints >= 50)
                          ActionChip(
                            label: const Text('50 แต้ม'),
                            onPressed: () =>
                                setDialogState(() => currentSelection = 50),
                          ),
                        if (maxRedeemablePoints >= 100)
                          ActionChip(
                            label: const Text('100 แต้ม'),
                            onPressed: () =>
                                setDialogState(() => currentSelection = 100),
                          ),
                        ActionChip(
                          label: Text(locale.t('ใช้สูงสุด', 'Max points')),
                          onPressed: () => setDialogState(
                              () => currentSelection = maxRedeemablePoints),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace16),

                    // Preview
                    Container(
                      padding: const EdgeInsets.all(kSpace12),
                      decoration: BoxDecoration(
                        color: kColorSurface,
                        borderRadius: BorderRadius.circular(kRadiusCard),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(locale.t('ส่วนลดที่ได้รับ', 'Discount')),
                              Text(
                                '-฿${discountValue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kColorPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: kSpace12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(locale.t('ยอดชำระคงเหลือ', 'Total after discount')),
                              Text(
                                '฿${totalAfter.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kColorTextHeading,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                    cart.applyDiscount(currentSelection);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(locale.t('นำไปใช้', 'Apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: kColorSurface,
                border: Border(bottom: BorderSide(color: kColorBorder)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _onBackToMenu(context),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: Text(
                      locale.t('ย้อนกลับหน้าเมนู', 'Back to Menu'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A2F1E),
                      backgroundColor: const Color(0xFFEDE5D4),
                      side: const BorderSide(color: Color(0xFFCBB89F)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    locale.t('สรุปรายการและชำระเงิน', 'Checkout & Payment'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A2F1E),
                    ),
                  ),
                  const Spacer(),
                  const LanguageToggle(),
                ],
              ),
            ),

            // ── 2-Column Main Content (Optimized for iPad Portrait) ────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Order Summary (~58% width or flex: 6)
                  Expanded(
                    flex: 6,
                    child: _buildOrderSummary(context, theme, locale),
                  ),

                  const VerticalDivider(width: 1, color: kColorBorder),

                  // Right: Member & Payment Selection (~42% width or flex: 4)
                  Expanded(
                    flex: 4,
                    child: _buildPaymentPanel(context, theme, locale),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Left Column: Order Summary
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildOrderSummary(
      BuildContext context, ThemeData theme, LocaleProvider locale) {
    final cart = context.watch<CartProvider>();

    return Container(
      color: kColorSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  locale.t('รายการสินค้า', 'Order Items'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kColorTextHeading,
                  ),
                ),
                Text(
                  '${cart.totalQuantity} ${locale.t('รายการ', 'items')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kColorTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items list
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Text(
                      locale.t('ไม่มีสินค้าในตะกร้า', 'Cart is empty'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: kColorTextMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 16, color: Color(0xFFF1EAD8)),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final sweetnessLabel = item.sweetness.label;
                      final milkLabel = item.milkType.label;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Item quantity badge
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kColorPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kColorPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Item Name & Modifiers
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${locale.t('หวาน', 'Sweet')}: $sweetnessLabel • ${locale.t('นม', 'Milk')}: $milkLabel',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kColorTextMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price
                          Text(
                            '฿${item.lineTotal.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: kColorTextHeading,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // Price Calculation Block
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFFAF7EE),
            child: Column(
              children: [
                _TotalRow(
                  label: locale.t('ยอดรวมก่อนภาษี (Subtotal)', 'Subtotal'),
                  value: '฿${cart.priceBreakdown.subtotal.toStringAsFixed(2)}',
                  theme: theme,
                  isMuted: true,
                ),
                const SizedBox(height: 8),
                _TotalRow(
                  label: locale.t('ภาษีมูลค่าเพิ่ม 7% (VAT)', 'VAT 7%'),
                  value: '฿${cart.priceBreakdown.vat.toStringAsFixed(2)}',
                  theme: theme,
                  isMuted: true,
                ),
                if (cart.discount > 0) ...[
                  const SizedBox(height: 8),
                  _TotalRow(
                    label:
                        '${locale.t('ส่วนลดสมาชิก', 'Member Discount')} (${cart.redeemedPoints} ${locale.t('แต้ม', 'pts')})',
                    value: '-฿${cart.discount.toStringAsFixed(2)}',
                    theme: theme,
                    valueColor: kColorPrimary,
                    isBold: true,
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 1.2),
                ),
                _TotalRow(
                  label: locale.t('ยอดสุทธิ (Grand Total)', 'Grand Total'),
                  value: '฿${cart.totalAfterDiscount.toStringAsFixed(2)}',
                  theme: theme,
                  isBold: true,
                  valueColor: kColorPrimary,
                  fontSize: 22,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Right Column: Member Card & Payment Buttons
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentPanel(
      BuildContext context, ThemeData theme, LocaleProvider locale) {
    final cart = context.watch<CartProvider>();
    final member = cart.member;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Member Section ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(kRadiusCard),
              border: Border.all(
                color: member != null
                    ? kColorPrimary.withValues(alpha: 0.5)
                    : kColorBorder,
                width: member != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      member != null
                          ? Icons.verified_user
                          : Icons.card_membership,
                      color: member != null ? kColorPrimary : kColorSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale.t('สมาชิก ToTo Cafe', 'ToTo Cafe Member'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: kColorTextHeading,
                        ),
                      ),
                    ),
                    if (member != null)
                      TextButton(
                        onPressed: () {
                          cart.clear();
                          _showMemberPromptDialog(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 28),
                          foregroundColor: kColorSecondary,
                        ),
                        child: Text(
                          locale.t('เปลี่ยน', 'Change'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (member != null) ...[
                  // Member details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kColorPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              member.displayName ??
                                  locale.t('สมาชิกทั่วไป', 'Member'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${member.points} ${locale.t('แต้ม', 'points')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kColorPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${locale.t('เบอร์โทร', 'Phone')}: ${member.phone}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kColorTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (cart.discount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: kColorPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${locale.t('ใช้ส่วนลด', 'Discount')}: -฿${cart.discount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: kColorPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () => cart.clearDiscount(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(40, 24),
                            ),
                            child: Text(
                              locale.t('ยกเลิก', 'Remove'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRedeemDialog(context, member),
                      icon: const Icon(Icons.redeem, size: 18),
                      label: Text(
                        cart.discount > 0
                            ? locale.t(
                                'แก้ไขแต้มส่วนลด', 'Edit Points Discount')
                            : locale.t('ใช้แต้มเป็นส่วนลด',
                                'Redeem Points for Discount'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kColorPrimary,
                        side: const BorderSide(color: kColorPrimary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Not logged in member prompt
                  Text(
                    locale.t(
                      'สะสมแต้มทุก 20 บาทรับ 1 แต้ม และใช้ 1 แต้มเป็นส่วนลด 1 บาท',
                      'Earn 1 point every 20 THB and redeem 1 point = 1 THB discount',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kColorTextMuted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showMemberPromptDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: Text(
                        locale.t('ใส่เบอร์สมาชิก / สะสมแต้ม',
                            'Enter Member Phone / Earn Points'),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A2F1E),
                        backgroundColor: const Color(0xFFF5EFE0),
                        side: const BorderSide(color: Color(0xFFD5C4B1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Payment Method Section ──────────────────────────────────
          Text(
            locale.t('เลือกวิธีชำระเงิน', 'Choose Payment Method'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: kColorTextHeading,
            ),
          ),
          const SizedBox(height: 16),

          // Option 1: Scan QR PromptPay
          SizedBox(
            height: 68,
            child: ElevatedButton.icon(
              onPressed: () => _onPayWithQR(context),
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t('สแกน QR จ่ายเงิน', 'Scan QR to Pay'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    locale.t(
                      'PromptPay QR สแกนจ่ายผ่านแอปธนาคาร',
                      'PromptPay QR with mobile banking app',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Option 2: Pay with Cash at Counter
          SizedBox(
            height: 68,
            child: ElevatedButton.icon(
              onPressed: () => _onPayWithCash(context),
              icon: const Icon(Icons.payments_outlined, size: 28),
              label: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t(
                      'จ่ายเงินสดที่เคาน์เตอร์',
                      'Pay with Cash at Counter',
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    locale.t(
                      'รับบัตรคิวและนำไปชำระเงินที่พนักงาน',
                      'Get queue ticket & pay at cashier',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorSecondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Verification notice
          Center(
            child: Text(
              locale.t(
                'พนักงานจะตรวจสอบและยืนยันการชำระเงินที่หน้าจอ POS',
                'Staff will verify payment on Cashier POS',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: kColorTextMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Popup Dialog: Member Prompt (Enter Phone / Register QR / Skip)
// ═════════════════════════════════════════════════════════════════════════════

class _MemberPromptDialog extends StatefulWidget {
  const _MemberPromptDialog({
    required this.initialPhone,
    required this.onMemberFound,
  });

  final String initialPhone;
  final void Function(Member member, String phone) onMemberFound;

  @override
  State<_MemberPromptDialog> createState() => _MemberPromptDialogState();
}

class _MemberPromptDialogState extends State<_MemberPromptDialog> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String val) {
    if (_phoneController.text.length < 10) {
      setState(() {
        _phoneController.text += val;
        _errorMessage = null;
      });
    }
  }

  void _onKeypadDelete() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phoneController.text = _phoneController.text
            .substring(0, _phoneController.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    final locale = context.read<LocaleProvider>();

    if (phone.length < 9) {
      setState(() {
        _errorMessage = locale.t(
          'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง',
          'Please enter a valid phone number',
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final member = await MemberService().getMemberByPhone(phone);
      if (!mounted) return;

      if (member != null) {
        widget.onMemberFound(member, phone);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${locale.t('ยินดีต้อนรับคุณ', 'Welcome')} ${member.displayName ?? phone}! (${member.points} ${locale.t('แต้ม', 'pts')})',
            ),
            backgroundColor: kColorPrimary,
          ),
        );
      } else {
        setState(() {
          _errorMessage = locale.t(
            'ไม่พบเบอร์สมาชิกในระบบ สามารถสแกน QR เพื่อสมัครได้ฟรี',
            'Member not found. Scan the QR code below to register free.',
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${locale.t('เกิดข้อผิดพลาด', 'Error')}: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: kColorSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kColorPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_membership,
                        color: kColorPrimary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.t(
                            'คุณเป็นสมาชิก ToTo Cafe หรือไม่?',
                            'Are you a ToTo Cafe Member?',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A2F1E),
                          ),
                        ),
                        Text(
                          locale.t(
                            'กรอกเบอร์เพื่อสะสมแต้ม หรือสแกนเพื่อสมัครสมาชิกฟรี',
                            'Enter phone to earn points or scan QR to register',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kColorTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Phone Display field
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null
                        ? Colors.red
                        : const Color(0xFFD5C4B1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_iphone,
                        color: Color(0xFF6B4A35), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _phoneController.text.isEmpty
                            ? locale.t(
                                'กดเบอร์โทรศัพท์ที่นี่...',
                                'Enter phone number...',
                              )
                            : _phoneController.text,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: _phoneController.text.isEmpty
                              ? Colors.grey.shade400
                              : const Color(0xFF4A2F1E),
                        ),
                      ),
                    ),
                    if (_phoneController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined,
                            color: Colors.red),
                        onPressed: _onKeypadDelete,
                      ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 16),

              // Middle: Touch Numeric Keypad (Optimized for iPad Kiosk)
              _buildKeypad(),

              const SizedBox(height: 16),

              // Register QR Card (Same LINE LIFF QR as standby screen)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EFE0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4DECC)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD5C4B1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: QrImageView(
                          data: 'https://liff.line.me/2011572383-l29PIrit',
                          version: QrVersions.auto,
                          size: 72,
                          padding: const EdgeInsets.all(4),
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF2E2118),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF2E2118),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                locale.t('ยังไม่ได้เป็นสมาชิก?',
                                    'Not a member yet?'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF4A2F1E),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kColorPrimary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  locale.t('ฟรี!', 'FREE'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locale.t(
                              'สแกน QR เพื่อสมัครสมาชิกฟรี สะสมแต้มได้ทันที',
                              'Scan QR with phone to register & earn points',
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B4A35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Actions: Submit & Skip
              Row(
                children: [
                  // Skip button ("ไม่ได้เป็น / ไม่ใช้สมาชิก")
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B4A35),
                          side: const BorderSide(color: Color(0xFFD5C4B1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          locale.t(
                            'ไม่ใช้ / ไม่ได้เป็นสมาชิก',
                            'Skip / Not a Member',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Confirm / Submit button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitPhone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kColorPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                locale.t('ยืนยันเบอร์สมาชิก', 'Confirm Member'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          children: [
            _keypadBtn('1'),
            const SizedBox(width: 8),
            _keypadBtn('2'),
            const SizedBox(width: 8),
            _keypadBtn('3'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _keypadBtn('4'),
            const SizedBox(width: 8),
            _keypadBtn('5'),
            const SizedBox(width: 8),
            _keypadBtn('6'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _keypadBtn('7'),
            const SizedBox(width: 8),
            _keypadBtn('8'),
            const SizedBox(width: 8),
            _keypadBtn('9'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _phoneController.clear();
                      _errorMessage = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  child: const Text('ล้าง (Clear)'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _keypadBtn('0'),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: _onKeypadDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A2F1E),
                    side: const BorderSide(color: Color(0xFFD5C4B1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.backspace, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keypadBtn(String digit) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: () => _onKeypadTap(digit),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4A2F1E),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE4DECC)),
            ),
          ),
          child: Text(
            digit,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
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
    this.valueColor,
    this.fontSize,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final bool isBold;
  final bool isMuted;
  final Color? valueColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: fontSize ?? 16,
          )
        : isMuted
            ? theme.textTheme.bodySmall?.copyWith(fontSize: fontSize ?? 13)
            : theme.textTheme.bodyMedium?.copyWith(fontSize: fontSize ?? 14);

    final valStyle = valueColor != null
        ? style?.copyWith(color: valueColor, fontWeight: FontWeight.bold)
        : style;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: valStyle),
      ],
    );
  }
}
