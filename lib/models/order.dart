import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle for an order.
///
/// ```
/// pending_payment → paid → preparing → ready → completed
/// ```
enum OrderStatus {
  pendingPayment('pending_payment'),
  awaitingApproval('awaiting_approval'),
  paid('paid'),
  preparing('preparing'),
  ready('ready'),
  completed('completed');

  const OrderStatus(this.value);
  final String value;

  static OrderStatus fromString(String s) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => OrderStatus.pendingPayment,
    );
  }
}

/// Payment method chosen at the Kiosk.
enum PaymentMethod {
  qr('qr'),
  cash('cash');

  const PaymentMethod(this.value);
  final String value;

  static PaymentMethod fromString(String s) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == s,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Sweetness level modifier.
enum SweetnessLevel {
  zero(0, '0%'),
  twentyFive(25, '25%'),
  fifty(50, '50%'),
  hundred(100, '100%');

  const SweetnessLevel(this.percent, this.label);
  final int percent;
  final String label;

  static SweetnessLevel fromInt(int p) {
    return SweetnessLevel.values.firstWhere(
      (e) => e.percent == p,
      orElse: () => SweetnessLevel.hundred,
    );
  }
}

/// Milk type modifier.
enum MilkType {
  regular('regular', 'Regular'),
  oat('oat', 'Oat Milk'),
  almond('almond', 'Almond Milk');

  const MilkType(this.value, this.label);
  final String value;
  final String label;

  static MilkType fromString(String s) {
    return MilkType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => MilkType.regular,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OrderItem — a single line item within an order
// ═══════════════════════════════════════════════════════════════════════════

class OrderItem {
  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.sweetness = SweetnessLevel.hundred,
    this.milkType = MilkType.regular,
  });

  final String menuItemId;
  final String name;

  /// Unit price (before quantity multiplication).
  final double price;
  final int quantity;
  final SweetnessLevel sweetness;
  final MilkType milkType;

  /// Line total = price × quantity.
  double get lineTotal => price * quantity;

  // ── Firestore serialization ─────────────────────────────────────────

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menu_item_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      sweetness: SweetnessLevel.fromInt(json['sweetness'] as int? ?? 100),
      milkType: MilkType.fromString(json['milk_type'] as String? ?? 'regular'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_item_id': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'sweetness': sweetness.percent,
      'milk_type': milkType.value,
    };
  }

  OrderItem copyWith({
    String? menuItemId,
    String? name,
    double? price,
    int? quantity,
    SweetnessLevel? sweetness,
    MilkType? milkType,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sweetness: sweetness ?? this.sweetness,
      milkType: milkType ?? this.milkType,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Order — Firestore: orders/{order_id}
// ═══════════════════════════════════════════════════════════════════════════

class Order {
  Order({
    this.id,
    required this.items,
    required this.status,
    required this.paymentMethod,
    required this.queueNumber,
    required this.subtotal,
    required this.vat,
    required this.total,
    this.memberId,
    this.createdAt,
  });

  /// Firestore document ID (null before first write).
  final String? id;

  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final int queueNumber;

  /// Price before tax.
  final double subtotal;

  /// VAT 7% amount.
  final double vat;

  /// Grand total (subtotal + vat).
  final double total;

  /// Optional member ID for loyalty points.
  final String? memberId;

  final DateTime? createdAt;

  // ── Firestore serialization ─────────────────────────────────────────

  factory Order.fromJson(Map<String, dynamic> json, {String? id}) {
    return Order(
      id: id,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: OrderStatus.fromString(json['status'] as String? ?? ''),
      paymentMethod:
          PaymentMethod.fromString(json['payment_method'] as String? ?? ''),
      queueNumber: json['queue_number'] as int? ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      vat: (json['vat'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      memberId: json['member_id'] as String?,
      createdAt: (json['created_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Construct from a Firestore [DocumentSnapshot].
  factory Order.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Order.fromJson(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'status': status.value,
      'payment_method': paymentMethod.value,
      'queue_number': queueNumber,
      'subtotal': subtotal,
      'vat': vat,
      'total': total,
      if (memberId != null) 'member_id': memberId,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  Order copyWith({
    String? id,
    List<OrderItem>? items,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    int? queueNumber,
    double? subtotal,
    double? vat,
    double? total,
    String? memberId,
    DateTime? createdAt,
  }) {
    return Order(
      id: id ?? this.id,
      items: items ?? this.items,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      queueNumber: queueNumber ?? this.queueNumber,
      subtotal: subtotal ?? this.subtotal,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      memberId: memberId ?? this.memberId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
