import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import '../models/member.dart';

/// Service for managing Member loyalty data in Firestore.
class MemberService {
  static final MemberService _instance = MemberService._internal();
  factory MemberService() => _instance;
  MemberService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Field names used: 'phone'
  /// Query members where phone == phone, return true if found.
  Future<bool> isMemberExists(String phone) async {
    try {
      final cleanPhone = phone.trim();
      final query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return true;
      if (cleanPhone != phone) {
        final rawQuery = await _firestore
            .collection('members')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        return rawQuery.docs.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('MemberService.isMemberExists error: $e');
      return false;
    }
  }

  // Field names used: 'phone', 'points', 'join_date'/'createdAt', 'displayName'/'display_name'
  /// Query Firestore 'members' collection where phone == phone, return Member or null.
  Future<Member?> getMemberByPhone(String phone) async {
    try {
      final cleanPhone = phone.trim();
      var query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .get();
      if (query.docs.isEmpty && cleanPhone != phone) {
        query = await _firestore
            .collection('members')
            .where('phone', isEqualTo: phone)
            .get();
      }
      if (query.docs.isNotEmpty) {
        // Pick best document if duplicates exist (highest points or has displayName)
        var bestDoc = query.docs.first;
        var maxPoints = (bestDoc.data()['points'] as num?)?.toInt() ?? 0;
        for (final d in query.docs) {
          final pts = (d.data()['points'] as num?)?.toInt() ?? 0;
          final name = (d.data()['displayName'] ?? d.data()['display_name'] ?? '').toString();
          if (pts > maxPoints || (pts == maxPoints && name.isNotEmpty)) {
            bestDoc = d;
            maxPoints = pts;
          }
        }
        return Member.fromJson(bestDoc.data(), id: bestDoc.id);
      }
      return null;
    } catch (e) {
      debugPrint('MemberService.getMemberByPhone error: $e');
      return null;
    }
  }

  // Field names used: 'lineUserId', 'line_user_id', 'points'
  /// Return the member document or null by LINE User ID.
  /// Reads and verifies the 'points' field with exact field name 'points'.
  Future<DocumentSnapshot?> getMemberByLineId(String lineUserId) async {
    debugPrint('MemberService.getMemberByLineId: $lineUserId');
    if (lineUserId.isEmpty) return null;

    try {
      // 1. Check direct doc ID
      final doc = await _firestore.collection('members').doc(lineUserId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final points = (data['points'] as num?)?.toInt() ?? 0;
        debugPrint('MemberService.getMemberByLineId: found doc with points: $points');
        return doc;
      }

      // 2. Query where lineUserId == lineUserId
      final query = await _firestore
          .collection('members')
          .where('lineUserId', isEqualTo: lineUserId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        final points = (data['points'] as num?)?.toInt() ?? 0;
        debugPrint('MemberService.getMemberByLineId: found doc by lineUserId with points: $points');
        return doc;
      }

      // 3. Query fallback where line_user_id == lineUserId
      final fallbackQuery = await _firestore
          .collection('members')
          .where('line_user_id', isEqualTo: lineUserId)
          .limit(1)
          .get();
      if (fallbackQuery.docs.isNotEmpty) {
        final doc = fallbackQuery.docs.first;
        final data = doc.data();
        final points = (data['points'] as num?)?.toInt() ?? 0;
        debugPrint('MemberService.getMemberByLineId: found doc by fallback line_user_id with points: $points');
        return doc;
      }

      return null;
    } catch (e) {
      debugPrint('MemberService.getMemberByLineId error: $e');
      rethrow;
    }
  }

  // Field names used: 'lineUserId', 'line_user_id', 'displayName', 'display_name', 'pictureUrl', 'phone', 'points', 'createdAt', 'join_date'
  /// Register or link member in 'members' collection.
  /// If a member with this phone already exists, preserves existing points and merges LINE details.
  Future<Member> registerMember({
    required String lineUserId,
    required String displayName,
    required String pictureUrl,
    required String phone,
  }) async {
    debugPrint('MemberService.registerMember: lineUserId=$lineUserId, phone=$phone');
    try {
      final now = Timestamp.now();
      final cleanPhone = phone.trim();

      // Check if member already exists by phone
      final existingQuery = await _firestore
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Pick best document with highest points or real name
        var bestDoc = existingQuery.docs.first;
        var maxPoints = (bestDoc.data()['points'] as num?)?.toInt() ?? 0;
        for (final d in existingQuery.docs) {
          final pts = (d.data()['points'] as num?)?.toInt() ?? 0;
          final name = (d.data()['displayName'] ?? d.data()['display_name'] ?? '').toString();
          final lId = (d.data()['lineUserId'] ?? d.data()['line_user_id'] ?? '').toString();
          if (pts > maxPoints || (pts == maxPoints && name.isNotEmpty) || (!lId.startsWith('temp_') && lId.isNotEmpty)) {
            bestDoc = d;
            if (pts > maxPoints) maxPoints = pts;
          }
        }

        // Clean up any duplicate temp docs for this phone so they never pollute queries again
        for (final d in existingQuery.docs) {
          if (d.id != bestDoc.id && d.id.startsWith('temp_')) {
            try {
              await d.reference.delete();
            } catch (_) {}
          }
        }

        final existingData = bestDoc.data();
        final existingPoints = maxPoints;
        final existingName = (existingData['displayName'] ?? existingData['display_name'] ?? '').toString();
        final finalName = displayName.isNotEmpty ? displayName : existingName;
        final existingPic = (existingData['pictureUrl'] ?? existingData['picture_url'] ?? '').toString();
        final finalPic = pictureUrl.isNotEmpty ? pictureUrl : existingPic;

        final updateData = <String, dynamic>{
          if (finalName.isNotEmpty) 'displayName': finalName,
          if (finalName.isNotEmpty) 'display_name': finalName,
          if (finalPic.isNotEmpty) 'pictureUrl': finalPic,
        };

        if (lineUserId.isNotEmpty && !lineUserId.startsWith('temp_')) {
          updateData['lineUserId'] = lineUserId;
          updateData['line_user_id'] = lineUserId;
        }

        if (updateData.isNotEmpty) {
          await bestDoc.reference.update(updateData);
        }

        debugPrint('MemberService.registerMember: Linked to existing member doc ${bestDoc.id} with points: $existingPoints');
        return Member(
          id: bestDoc.id,
          phone: cleanPhone,
          points: existingPoints,
          joinDate: (existingData['join_date'] as Timestamp?)?.toDate() ??
              (existingData['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          displayName: finalName.isNotEmpty ? finalName : null,
        );
      }

      // Brand new member
      final docRef = lineUserId.isNotEmpty && !lineUserId.startsWith('temp_')
          ? _firestore.collection('members').doc(lineUserId)
          : _firestore.collection('members').doc();

      final data = {
        'lineUserId': lineUserId,
        'line_user_id': lineUserId,
        'displayName': displayName,
        'display_name': displayName,
        'pictureUrl': pictureUrl,
        'phone': cleanPhone,
        'points': 0,
        'createdAt': now,
        'join_date': now,
      };

      await docRef.set(data);
      debugPrint('MemberService.registerMember: Successfully registered docId: ${docRef.id}');

      return Member(
        id: docRef.id,
        phone: cleanPhone,
        points: 0,
        joinDate: now.toDate(),
        displayName: displayName.isNotEmpty ? displayName : null,
      );
    } catch (e) {
      debugPrint('MemberService.registerMember error: $e');
      rethrow;
    }
  }

  // Field names used: 'phone', 'points'
  /// Find member by phone, increment points field by points amount.
  Future<void> addPoints(String phone, int points) async {
    try {
      final cleanPhone = phone.trim();
      var query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .get();

      if (query.docs.isEmpty && cleanPhone != phone) {
        query = await _firestore
            .collection('members')
            .where('phone', isEqualTo: phone)
            .get();
      }

      if (query.docs.isNotEmpty) {
        // Increment on the primary document
        var bestDoc = query.docs.first;
        var maxPoints = (bestDoc.data()['points'] as num?)?.toInt() ?? 0;
        for (final d in query.docs) {
          final pts = (d.data()['points'] as num?)?.toInt() ?? 0;
          final lineId = (d.data()['lineUserId'] ?? d.data()['line_user_id'] ?? '').toString();
          if (pts > maxPoints || (!lineId.startsWith('temp_') && lineId.isNotEmpty)) {
            bestDoc = d;
            maxPoints = pts;
          }
        }
        await bestDoc.reference.update({
          'points': FieldValue.increment(points),
        });
        debugPrint('MemberService.addPoints: Incremented $points points on doc ${bestDoc.id}');
      }
    } catch (e) {
      debugPrint('MemberService.addPoints error: $e');
      rethrow;
    }
  }

  // Field names used: 'phone', 'points'
  /// Calculate points = (orderAmount / 20).floor()  // 20 baht = 1 point
  /// Queries 'members' collection where 'phone' == phone (exact field name match)
  /// Uses FieldValue.increment(points) on field named exactly 'points'
  /// Updates the correct document (not creating a new one)
  Future<void> addPointsForPurchase(String phone, int orderAmount) async {
    try {
      final points = (orderAmount / 20).floor();
      if (points <= 0) return;
      await addPoints(phone, points);
    } catch (e) {
      debugPrint('MemberService.addPointsForPurchase error: $e');
      rethrow;
    }
  }

  // Field names used: 'phone', 'points'
  /// Find member by phone, decrement points field by pointsToRedeem.
  /// Throw Exception('แต้มไม่เพียงพอ') if member's current points < pointsToRedeem.
  Future<void> redeemPoints(String phone, int pointsToRedeem) async {
    if (pointsToRedeem <= 0) return;
    try {
      final cleanPhone = phone.trim();
      var query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .get();

      if (query.docs.isEmpty && cleanPhone != phone) {
        query = await _firestore
            .collection('members')
            .where('phone', isEqualTo: phone)
            .get();
      }

      if (query.docs.isEmpty) {
        throw Exception('ไม่พบข้อมูลสมาชิก');
      }

      var bestDoc = query.docs.first;
      var maxPoints = (bestDoc.data()['points'] as num?)?.toInt() ?? 0;
      for (final d in query.docs) {
        final pts = (d.data()['points'] as num?)?.toInt() ?? 0;
        final lineId = (d.data()['lineUserId'] ?? d.data()['line_user_id'] ?? '').toString();
        if (pts > maxPoints || (!lineId.startsWith('temp_') && lineId.isNotEmpty)) {
          bestDoc = d;
          maxPoints = pts;
        }
      }

      // Clean up any other duplicate temp docs for this phone so they don't conflict
      for (final d in query.docs) {
        if (d.id != bestDoc.id && d.id.startsWith('temp_')) {
          try {
            await d.reference.delete();
          } catch (_) {}
        }
      }

      final currentPoints = maxPoints;
      if (currentPoints < pointsToRedeem) {
        throw Exception('แต้มไม่เพียงพอ');
      }

      await bestDoc.reference.update({
        'points': FieldValue.increment(-pointsToRedeem),
      });
      debugPrint('MemberService.redeemPoints: Decremented $pointsToRedeem points on doc ${bestDoc.id}');
    } catch (e) {
      debugPrint('MemberService.redeemPoints error: $e');
      rethrow;
    }
  }

  /// Update phone number for a member by LINE User ID (or docId).
  Future<void> updateMemberPhone(String lineUserId, String newPhone) async {
    try {
      final cleanPhone = newPhone.trim();
      final docRef = _firestore.collection('members').doc(lineUserId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update({'phone': cleanPhone});
        debugPrint('MemberService.updateMemberPhone: Updated phone on doc $lineUserId to $cleanPhone');
        return;
      }

      // Fallback: search where lineUserId == lineUserId
      final query = await _firestore
          .collection('members')
          .where('lineUserId', isEqualTo: lineUserId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'phone': cleanPhone});
        debugPrint('MemberService.updateMemberPhone: Updated phone on doc ${query.docs.first.id} to $cleanPhone');
      }
    } catch (e) {
      debugPrint('MemberService.updateMemberPhone error: $e');
      rethrow;
    }
  }

  /// Delete all member records associated with a phone number (e.g. for reset/testing).
  Future<int> deleteMemberByPhone(String phone) async {
    try {
      final cleanPhone = phone.trim();
      final query = await _firestore
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .get();
      int count = 0;
      for (final doc in query.docs) {
        await doc.reference.delete();
        count++;
      }
      debugPrint('MemberService.deleteMemberByPhone: deleted $count docs for $cleanPhone');
      return count;
    } catch (e) {
      debugPrint('MemberService.deleteMemberByPhone error: $e');
      rethrow;
    }
  }
}
