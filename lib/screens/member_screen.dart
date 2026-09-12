import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
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
  String _displayName = '';
  String _pictureUrl = '';
  int _points = 0;
  String _phone = '';
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadMember() async {
    setState(() {
      _screenState = 'loading';
    });

    try {
      debugPrint('=== LIFF: starting _loadMember ===');

      // 1. Call LiffService().initialize()
      await LiffService().initialize();
      debugPrint('=== LIFF: initialized ===');

      // 2. If not isLoggedIn() -> call LiffService().login() (redirects to LINE login)
      if (!LiffService().isLoggedIn()) {
        debugPrint('=== LIFF: not logged in, calling login() ===');
        LiffService().login();
        return;
      }
      debugPrint('=== LIFF: is logged in ===');

      // 3. If logged in -> call getProfile() to get lineUserId + displayName + pictureUrl
      final profile = await LiffService().getProfile();
      debugPrint('=== LIFF: got profile: $profile ===');

      _lineUserId = profile['userId'] ?? '';
      _displayName = profile['displayName'] ?? '';
      _pictureUrl = profile['pictureUrl'] ?? '';

      // 4. Call MemberService.getMemberByLineId(lineUserId)
      debugPrint('=== LIFF: checking member for lineUserId: $_lineUserId ===');
      final memberDoc = await MemberService().getMemberByLineId(_lineUserId);
      debugPrint('=== LIFF: memberDoc = $memberDoc ===');

      // 5. If member exists -> show profile state
      if (memberDoc != null && memberDoc.exists && memberDoc.data() != null) {
        debugPrint('=== LIFF: member EXISTS, showing profile ===');
        final data = memberDoc.data() as Map<String, dynamic>;
        final points = (data['points'] as num?)?.toInt() ?? 0;
        final phone = (data['phone'] ?? '').toString();

        _phone = phone;
        _points = points;

        _fetchRecentOrders(phone);

        if (mounted) {
          setState(() {
            _screenState = 'profile';
          });
        }
      } else {
        // 6. If not exists -> show register state
        debugPrint('=== LIFF: member NOT FOUND, showing register state ===');
        if (mounted) {
          setState(() {
            _screenState = 'register';
          });
        }
      }
    } catch (e, stack) {
      debugPrint('=== LIFF ERROR: $e ===');
      debugPrint('=== STACK: $stack ===');
      // If error occurs, show register state so user can proceed
      if (mounted) {
        setState(() {
          _screenState = 'register';
        });
      }
    }
  }

  Future<void> _fetchRecentOrders(String phone) async {
    if (phone.isEmpty) return;
    try {
      // Query 'orders' collection where memberPhone == phone, orderBy createdAt desc, limit 5
      final query = await FirebaseFirestore.instance
          .collection('orders')
          .where('memberPhone', isEqualTo: phone)
          .limit(5)
          .get();

      if (query.docs.isNotEmpty) {
        final list = query.docs.map((d) => d.data()).toList();
        list.sort((a, b) {
          final aTime = _extractDate(a);
          final bTime = _extractDate(b);
          return bTime.compareTo(aTime);
        });
        if (mounted) {
          setState(() {
            _recentOrders = list;
          });
        }
        return;
      }

      // Fallback query matching member_id or phone
      final fallbackQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('member_id', isEqualTo: phone)
          .limit(5)
          .get();

      final list = fallbackQuery.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final aTime = _extractDate(a);
        final bTime = _extractDate(b);
        return bTime.compareTo(aTime);
      });
      if (mounted) {
        setState(() {
          _recentOrders = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent orders: $e');
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

      await MemberService().registerMember(
        lineUserId: lineUserId,
        displayName: _displayName,
        pictureUrl: _pictureUrl,
        phone: phone,
      );

      debugPrint('=== LIFF: registration succeeded for phone: $phone ===');

      if (!mounted) return;

      setState(() {
        _phone = phone;
        _points = 0;
        _isSubmitting = false;
        _screenState = 'profile';
      });

      _fetchRecentOrders(phone);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ! ยินดีต้อนรับสู่ ToTo Cafe'),
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
          content: Text('เกิดข้อผิดพลาดในการสมัครสมาชิก: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        return _buildProfileView();
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

  // ── 2. Registration State ───────────────────────────────────────────────────

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
            'สมัครสมาชิก ToTo Café',
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
          const SizedBox(height: 24),

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

          // Button "สมัครสมาชิก"
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
                      'สมัครสมาชิก',
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
              const SizedBox(height: 24),

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
                    // Subtitle: "ทุก 100 แต้ม = 1 บาท"
                    const Text(
                      'ทุก 100 แต้ม = 1 บาท',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
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
