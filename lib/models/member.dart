import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Member — Firestore: members/{member_id}
// ═══════════════════════════════════════════════════════════════════════════

class Member {
  Member({
    this.id,
    required this.phone,
    required this.points,
    required this.joinDate,
    this.displayName,
  });

  /// Firestore document ID (null before first write).
  final String? id;

  /// Phone number used as the primary identifier (e.g. "0812345678").
  final String phone;

  /// Accumulated loyalty points.
  final int points;

  /// Date the member first signed up.
  final DateTime joinDate;

  /// Optional display name from LINE LIFF profile.
  final String? displayName;

  // ── Firestore serialization ─────────────────────────────────────────

  factory Member.fromJson(Map<String, dynamic> json, {String? id}) {
    return Member(
      id: id,
      phone: (json['phone'] ?? '').toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      joinDate: (json['join_date'] as Timestamp?)?.toDate() ??
          (json['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      displayName: (json['displayName'] ?? json['display_name']) as String?,
    );
  }

  /// Construct from a Firestore [DocumentSnapshot].
  factory Member.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Member.fromJson(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'points': points,
      'join_date': Timestamp.fromDate(joinDate),
      if (displayName != null) 'display_name': displayName,
    };
  }

  Member copyWith({
    String? id,
    String? phone,
    int? points,
    DateTime? joinDate,
    String? displayName,
  }) {
    return Member(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      points: points ?? this.points,
      joinDate: joinDate ?? this.joinDate,
      displayName: displayName ?? this.displayName,
    );
  }
}
