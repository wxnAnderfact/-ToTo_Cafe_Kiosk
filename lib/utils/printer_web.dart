// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../models/order.dart';
import 'customization_rules.dart';

/// Web implementation of printReceipt using window.print().
void printReceipt() {
  html.window.print();
}

/// Print only the 80mm thermal receipt paper without browser chrome or page background.
void printThermalReceipt(Order order, {String? storeName = "ToTo's Cafe"}) {
  final now = order.createdAt ?? DateTime.now();
  final dateStr =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final queueStr = '${order.queueNumber}'.padLeft(3, '0');
  final isQr = order.paymentMethod == PaymentMethod.qr;

  final itemsHtml = StringBuffer();
  for (final item in order.items) {
    final modSummary =
        CustomizationRules.getModifierSummary(item, includeLabels: false);
    itemsHtml.writeln('''
      <div class="item-row">
        <span class="item-name">${item.name} x${item.quantity}</span>
        <span class="item-price">฿${item.lineTotal.toStringAsFixed(2)}</span>
      </div>
    ''');
    if (modSummary != null && modSummary.isNotEmpty) {
      itemsHtml.writeln('''
        <div class="item-mod">($modSummary)</div>
      ''');
    }
  }

  // Member info & points
  final memberHtml = StringBuffer();
  if (order.memberPhone != null && order.memberPhone!.isNotEmpty) {
    final rawPhone = order.memberPhone!;
    final maskedPhone = rawPhone.length >= 10
        ? '${rawPhone.substring(0, 3)}-xxx-${rawPhone.substring(rawPhone.length - 4)}'
        : rawPhone;
    memberHtml.writeln('''
      <div class="row">
        <span>สมาชิก (Member):</span>
        <span>$maskedPhone</span>
      </div>
    ''');
  }

  if (order.redeemedPoints > 0 || order.discount > 0) {
    memberHtml.writeln('''
      <div class="row discount">
        <span>ส่วนลดแต้ม (-${order.redeemedPoints} แต้ม):</span>
        <span>-฿${order.discount.toStringAsFixed(2)}</span>
      </div>
    ''');
  }

  if (order.pointsEarned > 0) {
    memberHtml.writeln('''
      <div class="row points-earned">
        <span>แต้มสะสมที่ได้รับ:</span>
        <span class="bold">+${order.pointsEarned} แต้ม</span>
      </div>
    ''');
  }

  final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt #$queueStr</title>
  <style>
    @page {
      size: 80mm auto;
      margin: 0;
    }
    @media print {
      html, body {
        width: 72mm;
        margin: 0 auto;
        padding: 4mm 2mm;
        background: #fff !important;
        color: #000 !important;
      }
    }
    body {
      font-family: 'Courier New', Courier, 'Noto Sans Thai', monospace, sans-serif;
      font-size: 12px;
      line-height: 1.35;
      color: #000;
      background: #fff;
      width: 72mm;
      margin: 0 auto;
      padding: 4mm 2mm;
    }
    .center { text-align: center; }
    .right { text-align: right; }
    .bold { font-weight: bold; }
    .store-name { font-size: 18px; font-weight: bold; letter-spacing: 0.5px; }
    .queue-box { font-size: 20px; font-weight: bold; margin: 4px 0; }
    .divider { border-top: 1px dashed #000; margin: 6px 0; }
    .double-divider { border-top: 2px solid #000; margin: 6px 0; }
    .row { display: flex; justify-content: space-between; margin-bottom: 2px; }
    .item-row { display: flex; justify-content: space-between; font-weight: 600; margin-top: 4px; }
    .item-mod { font-size: 10px; color: #444; margin-left: 8px; margin-bottom: 2px; }
    .grand-total { font-size: 15px; font-weight: bold; margin: 6px 0; }
    .discount { color: #000; }
    .points-earned { font-size: 11px; margin-top: 2px; }
    .footer { margin-top: 12px; text-align: center; font-size: 11px; }
  </style>
</head>
<body>
  <div class="center store-name">$storeName</div>
  <div class="center" style="font-size: 10px;">Self-service Kiosk & POS</div>
  <div class="divider"></div>

  <div class="center queue-box">คิวที่ #$queueStr</div>
  <div class="row">
    <span>วันที่:</span>
    <span>$dateStr</span>
  </div>
  <div class="row">
    <span>วิธีชำระ:</span>
    <span>${isQr ? 'QR PromptPay' : 'เงินสด (Cash)'}</span>
  </div>
  ${order.id != null ? '<div class="row"><span>เลขออร์เดอร์:</span><span style="font-size: 10px;">#${order.id!.substring(0, order.id!.length.clamp(0, 8))}</span></div>' : ''}

  <div class="divider"></div>
  <div style="font-weight: bold; margin-bottom: 4px;">รายการสินค้า (Items):</div>
  ${itemsHtml.toString()}

  <div class="divider"></div>
  <div class="row">
    <span>ราคาก่อนภาษี (Subtotal):</span>
    <span>฿${order.subtotal.toStringAsFixed(2)}</span>
  </div>
  <div class="row">
    <span>VAT 7%:</span>
    <span>฿${order.vat.toStringAsFixed(2)}</span>
  </div>

  <div class="double-divider"></div>
  <div class="row grand-total">
    <span>ยอดสุทธิ (Grand Total):</span>
    <span>฿${order.total.toStringAsFixed(2)}</span>
  </div>
  <div class="double-divider"></div>

  ${order.receivedAmount != null ? '''
  <div class="row">
    <span>รับเงินสด (Cash Received):</span>
    <span class="bold">฿${order.receivedAmount!.toStringAsFixed(2)}</span>
  </div>
  <div class="row">
    <span>เงินทอน (Change):</span>
    <span class="bold">฿${(order.changeAmount ?? (order.receivedAmount! - order.total)).toStringAsFixed(2)}</span>
  </div>
  <div class="divider"></div>
  ''' : ''}

  ${memberHtml.toString()}

  <div class="footer">
    <div>ขอบคุณที่ใช้บริการ</div>
    <div style="font-size: 10px;">Thank you for visiting!</div>
  </div>
</body>
</html>
  ''';

  // Remove any previous print iframe
  final oldFrame = html.document.getElementById('receipt-print-frame');
  oldFrame?.remove();

  final iframe = html.IFrameElement()
    ..id = 'receipt-print-frame'
    ..style.position = 'fixed'
    ..style.top = '-9999px'
    ..style.left = '-9999px'
    ..style.width = '72mm'
    ..style.height = '100px'
    ..style.border = 'none'
    ..srcdoc = htmlContent;

  html.document.body?.append(iframe);

  iframe.onLoad.first.then((_) {
    Future.delayed(const Duration(milliseconds: 200), () {
      final win = iframe.contentWindow as dynamic;
      try {
        win?.focus();
        win?.print();
      } catch (e) {
        // Fallback to window.print if iframe access fails
        html.window.print();
      }
    });
  });
}
