import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import '../models/member.dart';

/// Service for managing Member loyalty data in Firestore.
class MemberService {
  static final MemberService _instance = MemberService._internal();
  factory MemberService() => _instance;
  MemberService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Query members where phone == phone, return true if found.
  Future<bool> isMemberExists(String phone) async {
    try {
      final query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('MemberService.isMemberExists error: $e');
      return false;
    }
  }

  /// Query Firestore 'members' collection where phone == phone, return Member or null.
  Future<Member?> getMemberByPhone(String phone) async {
    try {
      final query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Member.fromJson(doc.data(), id: doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('MemberService.getMemberByPhone error: $e');
      return null;
    }
  }

  /// Return the member document or null by LINE User ID.
  Future<DocumentSnapshot?> getMemberByLineId(String lineUserId) async {
    debugPrint('MemberService.getMemberByLineId: $lineUserId');
    if (lineUserId.isEmpty) return null;

    try {
      // 1. Check direct doc ID
      final doc = await _firestore.collection('members').doc(lineUserId).get();
      if (doc.exists && doc.data() != null) {
        return doc;
      }

      // 2. Query where lineUserId == lineUserId
      final query = await _firestore
          .collection('members')
          .where('lineUserId', isEqualTo: lineUserId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first;
      }

      // 3. Query fallback where line_user_id == lineUserId
      final fallbackQuery = await _firestore
          .collection('members')
          .where('line_user_id', isEqualTo: lineUserId)
          .limit(1)
          .get();
      if (fallbackQuery.docs.isNotEmpty) {
        return fallbackQuery.docs.first;
      }

      return null;
    } catch (e) {
      debugPrint('MemberService.getMemberByLineId error: $e');
      rethrow;
    }
  }

  /// Create document in 'members' collection with fields:
  /// lineUserId, displayName, pictureUrl, phone, points: 0, createdAt: Timestamp.now()
  Future<void> registerMember({
    required String lineUserId,
    required String displayName,
    required String pictureUrl,
    required String phone,
  }) async {
    debugPrint('MemberService.registerMember: lineUserId=$lineUserId, phone=$phone');
    try {
      final now = Timestamp.now();
      final data = {
        'lineUserId': lineUserId,
        'line_user_id': lineUserId,
        'displayName': displayName,
        'display_name': displayName,
        'pictureUrl': pictureUrl,
        'phone': phone,
        'points': 0,
        'createdAt': now,
        'join_date': now,
      };

      // Set document with lineUserId as docId for fast lookup
      await _firestore.collection('members').doc(lineUserId).set(data);
      debugPrint('MemberService.registerMember: Successfully registered docId: $lineUserId');
    } catch (e) {
      debugPrint('MemberService.registerMember error: $e');
      rethrow;
    }
  }

  /// Find member by phone, increment points field by points amount.
  Future<void> addPoints(String phone, int points) async {
    try {
      final query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'points': FieldValue.increment(points),
        });
      }
    } catch (e) {
      debugPrint('MemberService.addPoints error: $e');
      rethrow;
    }
  }

  /// Calculate points = (orderAmount / 10).floor()  // 100 baht = 10 points
  /// Increment the member's points field in Firestore by that amount.
  Future<void> addPointsForPurchase(String phone, int orderAmount) async {
    try {
      final points = (orderAmount / 10).floor();
      if (points <= 0) return;
      await addPoints(phone, points);
    } catch (e) {
      debugPrint('MemberService.addPointsForPurchase error: $e');
      rethrow;
    }
  }

  /// Find member by phone, decrement points field by pointsToRedeem.
  /// Throw Exception('แต้มไม่เพียงพอ') if member's current points < pointsToRedeem.
  Future<void> redeemPoints(String phone, int pointsToRedeem) async {
    try {
      final query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('ไม่พบข้อมูลสมาชิก');
      }

      final doc = query.docs.first;
      final data = doc.data();
      final currentPoints = (data['points'] as num?)?.toInt() ?? 0;

      if (currentPoints < pointsToRedeem) {
        throw Exception('แต้มไม่เพียงพอ');
      }

      await doc.reference.update({
        'points': FieldValue.increment(-pointsToRedeem),
      });
    } catch (e) {
      debugPrint('MemberService.redeemPoints error: $e');
      rethrow;
    }
  }
}
