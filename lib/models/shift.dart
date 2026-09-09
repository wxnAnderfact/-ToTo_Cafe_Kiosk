import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Shift — Firestore: shifts/{shift_id}
// ═══════════════════════════════════════════════════════════════════════════

class Shift {
  Shift({
    this.id,
    required this.staffId,
    required this.openTime,
    this.closeTime,
    required this.cashSummary,
  });

  /// Firestore document ID (null before first write).
  final String? id;

  /// Staff member who opened this shift.
  final String staffId;

  /// When the shift was opened.
  final DateTime openTime;

  /// When the shift was closed (null if still active).
  final DateTime? closeTime;

  /// Cash reconciliation data for the shift.
  final CashSummary cashSummary;

  /// Whether this shift is still active (not yet closed).
  bool get isActive => closeTime == null;

  // ── Firestore serialization ─────────────────────────────────────────

  factory Shift.fromJson(Map<String, dynamic> json, {String? id}) {
    return Shift(
      id: id,
      staffId: json['staff_id'] as String? ?? '',
      openTime:
          (json['open_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closeTime: (json['close_time'] as Timestamp?)?.toDate(),
      cashSummary: CashSummary.fromJson(
        json['cash_summary'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Construct from a Firestore [DocumentSnapshot].
  factory Shift.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Shift.fromJson(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'open_time': Timestamp.fromDate(openTime),
      if (closeTime != null) 'close_time': Timestamp.fromDate(closeTime!),
      'cash_summary': cashSummary.toJson(),
    };
  }

  Shift copyWith({
    String? id,
    String? staffId,
    DateTime? openTime,
    DateTime? closeTime,
    CashSummary? cashSummary,
  }) {
    return Shift(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      cashSummary: cashSummary ?? this.cashSummary,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CashSummary — embedded object within a Shift document
// ═══════════════════════════════════════════════════════════════════════════

class CashSummary {
  CashSummary({
    this.totalCashReceived = 0,
    this.totalQrReceived = 0,
    this.orderCount = 0,
  });

  /// Total cash collected during the shift (THB).
  final double totalCashReceived;

  /// Total QR / PromptPay payments received during the shift (THB).
  final double totalQrReceived;

  /// Number of orders processed during the shift.
  final int orderCount;

  /// Combined revenue for the shift.
  double get grandTotal => totalCashReceived + totalQrReceived;

  // ── Firestore serialization ─────────────────────────────────────────

  factory CashSummary.fromJson(Map<String, dynamic> json) {
    return CashSummary(
      totalCashReceived:
          (json['total_cash_received'] as num?)?.toDouble() ?? 0,
      totalQrReceived:
          (json['total_qr_received'] as num?)?.toDouble() ?? 0,
      orderCount: json['order_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_cash_received': totalCashReceived,
      'total_qr_received': totalQrReceived,
      'order_count': orderCount,
    };
  }

  CashSummary copyWith({
    double? totalCashReceived,
    double? totalQrReceived,
    int? orderCount,
  }) {
    return CashSummary(
      totalCashReceived: totalCashReceived ?? this.totalCashReceived,
      totalQrReceived: totalQrReceived ?? this.totalQrReceived,
      orderCount: orderCount ?? this.orderCount,
    );
  }
}
