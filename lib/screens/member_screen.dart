import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/liff_service.dart';
import '../services/member_service.dart';

const Color _kBgColor = Color(0xFF1C2B1C);
const Color _kCardColor = Color(0xFF2D3D2D);
const Color _kGoldColor = Color(0xFFC8A96E);

/// MemberScreen for LINE LIFF membership registration and profile view.
class MemberScreen extends StatefulWidget {
  const MemberScreen({super.key});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  final TextEditingController _phoneController = TextEditingController();

  String _screenState = 'loading'; // 'loading' | 'register' | 'profile'
  String _lineUserId = '';
  String _memberDocId = '';
  String _displayName = '';
  String _pictureUrl = '';
  int _points = 0;
  String _phone = '';
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _recentOrders = [];

  StreamSubscription<dynamic>? _memberSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  @override
  void dispose() {
    _memberSubscription?.cancel();
    _ordersSubscription?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _subscribeToMemberUpdates(String phone, {String? docId}) {
    _memberSubscription?.cancel();
    _ordersSubscription?.cancel();
    final cleanPhone = phone.trim();

    debugPrint('=== LIFF: Subscribing to real-time updates for phone: $cleanPhone, docId: $docId ===');

    // 1. Listen to member points and profile in real-time
    if (docId != null && docId.isNotEmpty) {
      _memberSubscription = FirebaseFirestore.instance
          .collection('members')
          .doc(docId)
          .snapshots()
          .listen((docSnap) {
        if (docSnap.exists && docSnap.data() != null && mounted) {
          final data = docSnap.data()!;
          final pts = (data['points'] as num?)?.toInt() ?? 0;
          final name = (data['displayName'] ?? data['display_name'] ?? '').toString();
          final pic = (data['pictureUrl'] ?? data['picture_url'] ?? '').toString();
          final ph = (data['phone'] ?? '').toString();

          setState(() {
            _points = pts;
            if (ph.isNotEmpty) _phone = ph;
            if (name.isNotEmpty) _displayName = name;
            if (pic.isNotEmpty) _pictureUrl = pic;
            _screenState = 'profile';
          });
        }
      });
    } else if (cleanPhone.isNotEmpty) {
      _memberSubscription = FirebaseFirestore.instance
          .collection('members')
          .where('phone', isEqualTo: cleanPhone)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty && mounted) {
          final docSnap = snapshot.docs.first;
          final data = docSnap.data();
          final pts = (data['points'] as num?)?.toInt() ?? 0;
          final name = (data['displayName'] ?? data['display_name'] ?? '').toString();
          final pic = (data['pictureUrl'] ?? data['picture_url'] ?? '').toString();

          setState(() {
            _phone = cleanPhone;
            _points = pts;
            if (name.isNotEmpty) _displayName = name;
            if (pic.isNotEmpty) _pictureUrl = pic;
            _screenState = 'profile';
          });
        }
      });
    }

    // 2. Listen to orders in real-time
    if (cleanPhone.isNotEmpty) {
      _ordersSubscription = FirebaseFirestore.instance
          .collection('orders')
          .where('memberPhone', isEqualTo: cleanPhone)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final list = snapshot.docs.map((d) => d.data()).toList();
          list.sort((a, b) {
            final aTime = _extractDate(a);
            final bTime = _extractDate(b);
            return bTime.compareTo(aTime);
          });
          setState(() {
            _recentOrders = list.take(10).toList();
          });
        }
      });
    }
  }

  Future<void> _loadMember() async {
    setState(() {
      _screenState = 'loading';
    });

    try {
      debugPrint('=== LIFF: starting _loadMember ===');

      await LiffService().initialize();
      debugPrint('=== LIFF: initialized ===');

      if (LiffService().isLoggedIn()) {
        final profile = await LiffService().getProfile();
        debugPrint('=== LIFF: got profile: $profile ===');

        _lineUserId = profile['userId'] ?? '';
        _displayName = profile['displayName'] ?? '';
        _pictureUrl = profile['pictureUrl'] ?? '';

        if (_lineUserId.isNotEmpty) {
          final memberDoc = await MemberService().getMemberByLineId(_lineUserId);
          if (memberDoc != null && memberDoc.exists && memberDoc.data() != null) {
            final data = memberDoc.data() as Map<String, dynamic>;
            final phone = (data['phone'] ?? '').toString();
            final name = (data['displayName'] ?? data['display_name'] ?? '').toString();
            final pic = (data['pictureUrl'] ?? data['picture_url'] ?? '').toString();

            _phone = phone;
            _points = (data['points'] as num?)?.toInt() ?? 0;
            _memberDocId = memberDoc.id;
            if (name.isNotEmpty) _displayName = name;
            if (pic.isNotEmpty) _pictureUrl = pic;

            _subscribeToMemberUpdates(phone, docId: memberDoc.id);

            if (mounted) {
              setState(() {
                _screenState = 'profile';
              });
            }
            return;
          }
        }
      }

      // If not logged in or member not found by LINE ID, show register / login view
      if (mounted) {
        setState(() {
          _screenState = 'register';
        });
      }
    } catch (e, stack) {
      debugPrint('=== LIFF ERROR: $e ===\n$stack');
      if (mounted) {
        setState(() {
          _screenState = 'register';
        });
      }
    }
  }

  DateTime _extractDate(Map<String, dynamic> data) {
    if (data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).toDate();
    }
    if (data['created_at'] is Timestamp) {
      return (data['created_at'] as Timestamp).toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _handleRegister() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกเบอร์โทรศัพท์'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!RegExp(r'^[0-9]{9,10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เบอร์โทรศัพท์ต้องเป็นตัวเลข 9-10 หลัก'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final lineUserId = _lineUserId.isNotEmpty
          ? _lineUserId
          : 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final member = await MemberService().registerMember(
        lineUserId: lineUserId,
        displayName: _displayName,
        pictureUrl: _pictureUrl,
        phone: phone,
      );

      debugPrint('=== LIFF: registration/login succeeded for phone: $phone, points: ${member.points} ===');

      if (!mounted) return;

      setState(() {
        _phone = member.phone;
        _points = member.points;
        _memberDocId = member.id ?? '';
        if (member.displayName != null && member.displayName!.isNotEmpty) {
          _displayName = member.displayName!;
        }
        _isSubmitting = false;
        _screenState = 'profile';
      });

      // Start real-time Firestore listeners for points and orders
      _subscribeToMemberUpdates(member.phone, docId: member.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เข้าสู่ระบบสมาชิกสำเร็จ!'),
          backgroundColor: _kGoldColor,
        ),
      );
    } catch (e) {
      debugPrint('=== LIFF: registration error: $e ===');
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditPhoneDialog() async {
    final editController = TextEditingController(text: _phone);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _kCardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'แก้ไขเบอร์โทรศัพท์',
            style: TextStyle(color: _kGoldColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'คะแนนสะสมและประวัติของคุณจะยังคงอยู่ครบเหมือนเดิม',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: editController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'เบอร์โทรใหม่',
                    labelStyle: const TextStyle(color: _kGoldColor),
                    counterText: '',
                    filled: true,
                    fillColor: _kBgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    final t = val?.trim() ?? '';
                    if (t.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(t)) {
                      return 'กรุณากรอกเบอร์โทร 10 หลัก';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGoldColor,
                foregroundColor: _kBgColor,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final newPhone = editController.text.trim();
                      try {
                        final targetDocId = _memberDocId.isNotEmpty
                            ? _memberDocId
                            : (_lineUserId.isNotEmpty ? _lineUserId : '');
                        if (targetDocId.isNotEmpty) {
                          await MemberService().updateMemberPhone(targetDocId, newPhone);
                        }
                        if (mounted) {
                          setState(() {
                            _phone = newPhone;
                          });
                          _subscribeToMemberUpdates(newPhone, docId: targetDocId);
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('อัปเดตเบอร์โทรศัพท์สำเร็จ!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kBgColor))
                  : const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case 'loading':
        return _buildLoadingView();
      case 'register':
        return _buildRegisterView();
      case 'profile':
        return _buildProfileState();
      default:
        return _buildLoadingView();
    }
  }

  // ── 1. Loading State ────────────────────────────────────────────────────────

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: _kGoldColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'กำลังโหลดข้อมูล...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Registration / Login State ──────────────────────────────────────────

  Widget _buildRegisterView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text(
            'ระบบสมาชิก ToTo Café',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kGoldColor,
            ),
          ),
          const SizedBox(height: 20),

          // LINE profile picture
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kGoldColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: _kBgColor,
              backgroundImage:
                  _pictureUrl.isNotEmpty ? NetworkImage(_pictureUrl) : null,
              child: _pictureUrl.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // Display Name
          Text(
            _displayName.isNotEmpty ? _displayName : 'สวัสดีคุณลูกค้า',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'กรอกเบอร์โทรศัพท์เพื่อเข้าสู่ระบบหรือสะสมแต้ม',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),

          // TextField for phone number
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'เบอร์โทรศัพท์',
              labelStyle: const TextStyle(color: _kGoldColor),
              hintText: '08XXXXXXXX',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.phone_outlined, color: _kGoldColor),
              filled: true,
              fillColor: _kBgColor,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kGoldColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Button "เข้าสู่ระบบ / สมัครสมาชิก"
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGoldColor,
                foregroundColor: _kBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 4,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _kBgColor,
                      ),
                    )
                  : const Text(
                      'เข้าสู่ระบบ / สมัครสมาชิก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Profile State ────────────────────────────────────────────────────────
  // Field names used: data['points'], data['phone']
  /// Builds profile state and verifies points is read using exact field name 'points'.
  Widget _buildProfileState([Map<String, dynamic>? data]) {
    if (data != null) {
      // Reads data['points'] (exact field name, not 'point' or other variants)
      _points = (data['points'] as num?)?.toInt() ?? _points;
      if (data.containsKey('phone')) {
        _phone = (data['phone'] ?? '').toString();
      }
      final name = (data['displayName'] ?? data['display_name'] ?? '').toString();
      if (name.isNotEmpty) {
        _displayName = name;
      }
      final pic = (data['pictureUrl'] ?? data['picture_url'] ?? '').toString();
      if (pic.isNotEmpty) {
        _pictureUrl = pic;
      }
    }
    return _buildProfileView();
  }

  Widget _buildProfileView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Profile & Points Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LINE profile picture with gold border
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kGoldColor, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: _kBgColor,
                  backgroundImage:
                      _pictureUrl.isNotEmpty ? NetworkImage(_pictureUrl) : null,
                  child: _pictureUrl.isEmpty
                      ? const Icon(Icons.person, size: 44, color: Colors.white70)
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Display Name
              Text(
                _displayName.isNotEmpty ? _displayName : 'สมาชิก ToTo Café',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),

              // Phone number
              Text(
                'เบอร์โทรศัพท์: ${_phone.isNotEmpty ? _phone : '-'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),

              // Switch phone button
              InkWell(
                onTap: _showEditPhoneDialog,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: _kGoldColor),
                      SizedBox(width: 4),
                      Text(
                        'แก้ไขเบอร์โทรศัพท์',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kGoldColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Points Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: _kBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGoldColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    // Large Points Text: "XXX แต้ม"
                    Text(
                      '$_points แต้ม',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: _kGoldColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle: "ทุก 20 บาท = 1 แต้ม (1 แต้ม = 1 บาท)"
                    Text(
                      'มูลค่า $_points บาท (1 แต้ม = 1 บาท)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Member QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _lineUserId.isNotEmpty ? _lineUserId : _phone,
                  version: QrVersions.auto,
                  size: 130,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'สแกน QR บัตรสมาชิกที่ตู้ Kiosk หรือหน้าร้าน',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Recent Orders Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: _kGoldColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ประวัติการสั่งซื้อล่าสุด',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_recentOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'ยังไม่มีประวัติการสั่งซื้อ',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentOrders.length,
                  separatorBuilder: (_, index) =>
                      const Divider(color: Colors.white12, height: 16),
                  itemBuilder: (context, index) {
                    final order = _recentOrders[index];
                    final date = _extractDate(order);
                    final formattedDate =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                    final total = (order['total'] as num?)?.toDouble() ??
                        (order['totalAmount'] as num?)?.toDouble() ??
                        0.0;
                    final pointsEarned = (order['pointsEarned'] as num?)?.toInt() ??
                        (total / 10).floor();

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+$pointsEarned แต้ม',
                              style: const TextStyle(
                                color: _kGoldColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '฿${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
