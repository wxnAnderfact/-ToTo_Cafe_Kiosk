import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/locale_provider.dart';
import '../services/member_service.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../utils/customization_rules.dart';
import '../widgets/language_toggle.dart';
import 'cash_waiting_screen.dart';
import 'qr_payment_screen.dart';

/// หน้า 3: Checkout
///
/// Layout (2-column):
///   Left  — สรุปออร์เดอร์ + Subtotal / VAT 7% / ส่วนลดสมาชิก / Grand Total
///   Right — สมาชิก ToTo Cafe (ถ้ามี) + ปุ่มเลือกชำระเงิน "Scan QR to Pay" / "Pay with Cash at Counter"
///   ปุ่ม "Back to Menu" มุมซ้ายบน
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final MemberService _memberService = MemberService();
  bool _isSearching = false;
  bool _memberNotFound = false;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    if (cart.memberPhone != null && cart.memberPhone!.isNotEmpty) {
      _phoneController.text = cart.memberPhone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onBackToMenu(BuildContext context) {
    Navigator.of(context).pop();
  }

  Future<void> _onSearchMember() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearching = true;
      _memberNotFound = false;
    });

    try {
      final member = await _memberService.getMemberByPhone(phone);
      if (!mounted) return;
      final cart = context.read<CartProvider>();

      if (member != null) {
        cart.setMember(member);
        setState(() {
          _isSearching = false;
          _memberNotFound = false;
        });
      } else {
        cart.setMember(null);
        setState(() {
          _isSearching = false;
          _memberNotFound = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _memberNotFound = true;
      });
    }
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
        total: cart.totalAfterDiscount,
        discount: cart.discount,
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
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _showRedeemDialog(BuildContext context, Member member) async {
    final cart = context.read<CartProvider>();
    final locale = context.read<LocaleProvider>();
    final maxRedeemablePoints = min(member.points, (cart.grandTotal * 100).toInt());

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
            final discountValue = currentSelection / 100.0;
            final totalAfter = (cart.grandTotal - discountValue).clamp(0.0, double.infinity);

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
                    cart.applyDiscount(currentSelection);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(locale.t('ยืนยันการใช้แต้ม', 'Confirm Redemption')),
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
                // RIGHT — Member & Payment Options
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
          if (cart.discount > 0) ...[
            const SizedBox(height: kSpace8),
            _TotalRow(
              label: locale.t('ส่วนลดสมาชิก', 'Member Discount'),
              value: '-฿${cart.discount.toStringAsFixed(2)}',
              theme: theme,
              valueColor: kColorPrimary,
              isBold: true,
            ),
          ],
          const SizedBox(height: kSpace12),
          const Divider(),
          const SizedBox(height: kSpace12),
          _TotalRow(
            label: locale.t('ยอดสุทธิ', 'Grand Total'),
            value: '฿${cart.totalAfterDiscount.toStringAsFixed(2)}',
            theme: theme,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ── Right: Member & Payment Options ─────────────────────────────────────

  Widget _buildPaymentOptions(BuildContext context, ThemeData theme, LocaleProvider locale) {
    final cart = context.watch<CartProvider>();
    final member = cart.member;

    return Container(
      color: kColorSurface,
      padding: const EdgeInsets.all(kSpace24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════════════════════════════════════════════════
            // SECTION: สมาชิก ToTo Cafe (ถ้ามี)
            // ═══════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(kSpace16),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: kColorTextHeading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace12),

                  if (member != null) ...[
                    // Confirmation Card
                    Container(
                      padding: const EdgeInsets.all(kSpace16),
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
                                radius: 20,
                                backgroundColor: kGreen100,
                                child: const Icon(Icons.person, color: kColorPrimary),
                              ),
                              const SizedBox(width: kSpace12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (member.displayName != null && member.displayName!.isNotEmpty)
                                          ? member.displayName!
                                          : 'สมาชิก (${member.phone})',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: kColorTextHeading,
                                      ),
                                    ),
                                    Text(
                                      member.phone,
                                      style: theme.textTheme.bodySmall?.copyWith(color: kColorTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  cart.setMember(null);
                                  _phoneController.clear();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: kColorTextMuted,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Text(locale.t('เปลี่ยนเบอร์', 'Change')),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpace12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace8),
                            decoration: BoxDecoration(
                              color: kGreen100.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(kRadiusCard),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars, color: kGold, size: 20),
                                const SizedBox(width: kSpace8),
                                Expanded(
                                  child: Text(
                                    '${locale.t('คุณมี', 'You have')} ${member.points} ${locale.t('แต้ม', 'points')} (${locale.t('มูลค่า', 'value')} ${(member.points / 100).toStringAsFixed(member.points % 100 == 0 ? 0 : 2)} ${locale.t('บาท', 'baht')})',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: kColorPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: kSpace12),

                          if (cart.discount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace8),
                              margin: const EdgeInsets.only(bottom: kSpace8),
                              decoration: BoxDecoration(
                                color: kColorPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(kRadiusCard),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${locale.t('ใช้ส่วนลด', 'Discount applied')}: -฿${cart.discount.toStringAsFixed(2)} (${cart.redeemedPoints} ${locale.t('แต้ม', 'pts')})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: kColorPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => cart.clearDiscount(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 28),
                                    ),
                                    child: Text(locale.t('ยกเลิก', 'Remove')),
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
                                    ? locale.t('แก้ไขแต้มส่วนลด', 'Edit Points Discount')
                                    : locale.t('ใช้แต้มเป็นส่วนลด', 'Redeem Points for Discount'),
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
                  ] else ...[
                    // Phone entry + Search
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
                              labelText: locale.t('เบอร์โทรศัพท์สมาชิก', 'Member Phone Number'),
                              hintText: '08XXXXXXXX',
                              prefixIcon: const Icon(Icons.phone, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              counterText: '',
                            ),
                            onSubmitted: (_) => _onSearchMember(),
                          ),
                        ),
                        const SizedBox(width: kSpace8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSearching ? null : _onSearchMember,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: _isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kColorWhite,
                                    ),
                                  )
                                : Text(locale.t('ค้นหา', 'Search')),
                          ),
                        ),
                      ],
                    ),

                    if (_memberNotFound) ...[
                      const SizedBox(height: kSpace8),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: kColorTextMuted),
                          const SizedBox(width: kSpace8),
                          Text(
                            locale.t('ไม่พบเบอร์นี้ในระบบสมาชิก', 'No member found with this phone number'),
                            style: theme.textTheme.bodySmall?.copyWith(color: kColorTextMuted),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: kSpace24),

            // ═══════════════════════════════════════════════════════════
            // SECTION: เลือกวิธีชำระเงิน
            // ═══════════════════════════════════════════════════════════
            Text(
              locale.t('เลือกวิธีชำระเงิน', 'Choose Payment Method'),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace24),

            // QR Payment button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () => _onPayWithQR(context),
                icon: const Icon(Icons.qr_code, size: 26),
                label: Text(locale.t('สแกน QR จ่ายเงิน', 'Scan QR to Pay')),
              ),
            ),
            const SizedBox(height: kSpace16),

            // Cash Payment button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: () => _onPayWithCash(context),
                icon: const Icon(Icons.payments_outlined, size: 26),
                label: Text(locale.t('จ่ายเงินสดที่เคาน์เตอร์', 'Pay with Cash at Counter')),
              ),
            ),

            const SizedBox(height: kSpace24),

            Text(
              locale.t('QR จะถูกตรวจสอบโดยพนักงาน', 'QR payment will be verified by our staff'),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
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
  });

  final String label;
  final String value;
  final ThemeData theme;
  final bool isBold;
  final bool isMuted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : isMuted
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium;

    final valStyle = valueColor != null
        ? style?.copyWith(color: valueColor)
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
