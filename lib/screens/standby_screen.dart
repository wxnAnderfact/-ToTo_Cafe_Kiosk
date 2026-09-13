import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/locale_provider.dart';
import '../theme.dart';
import '../widgets/language_toggle.dart';

/// หน้า 1: Standby (พักหน้าจอ) / Kiosk Welcome Page
///
/// - Animated cycling background with crossfade and dark overlay
/// - Prominent circular ToTo's Cafe logo at top center
/// - Typography and CTA button
/// - Prominent redesigned Member QR card at bottom-right
/// - TH/EN Language toggle at top-right
class StandbyScreen extends StatefulWidget {
  const StandbyScreen({super.key});

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen> {
  static const List<String> _bgImages = [
    'assets/images/hot_coffee.png',
    'assets/images/americano.png',
    'assets/images/iced_mocha.png',
    'assets/images/cappuccino.png',
    'assets/images/matcha_latte.png',
    'assets/images/thai_tea.png',
  ];

  int _currentImageIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % _bgImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onStartOrdering(BuildContext context) {
    _timer?.cancel();
    try {
      context.go('/kiosk/menu');
    } catch (_) {
      Navigator.of(context).pushReplacementNamed('/kiosk/menu');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider?>(context);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onStartOrdering(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background Base Color ───────────────────────────────────
            Container(
              color: const Color(0xFF1A2B18),
            ),

            // ── Animated Background Crossfading Images ──────────────────
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ...previousChildren,
                      ?currentChild,
                    ],
                  );
                },
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Image.asset(
                  _bgImages[_currentImageIndex],
                  key: ValueKey<int>(_currentImageIndex),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // ── Dark Overlay (0xFF1A2B18 @ 0.72 opacity) ────────────────
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1A2B18).withValues(alpha: 0.72),
              ),
            ),

            // ── Foreground Content (Top Center) ─────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Logo image (circular 260px, white border 3px, drop shadow)
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image(
                            image:
                                const AssetImage('assets/images/logo_toto.jpg'),
                            width: 260,
                            height: 260,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // 2. Gap: 20px
                      const SizedBox(height: 20),

                      // 3. Text "ToTo's Cafe" — Google Fonts Playfair Display, 40px, bold, color #F5F1E4
                      Text(
                        "ToTo's Cafe",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF5F1E4),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 4. Text "COFFEE & COMFORT" — sans-serif, 12px, uppercase, letter-spacing 0.2em, color #C8B99A
                      Text(
                        'COFFEE & COMFORT',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2 * 12,
                          color: const Color(0xFFC8B99A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Center of Screen: "Tap anywhere to start ordering" ──────
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    locale?.t(
                          "แตะที่ใดก็ได้เพื่อเริ่มสั่ง",
                          "Tap anywhere to start ordering",
                        ) ??
                        "แตะที่ใดก็ได้เพื่อเริ่มสั่ง",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF5F1E4),
                      letterSpacing: 1.2,
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Language Toggle (มุมขวาบน) ──────────────────────────────
            const Positioned(
              top: kSpace24,
              right: kSpace24,
              child: SafeArea(
                child: LanguageToggle(),
              ),
            ),

            // ── Member QR Card (มุมขวาล่าง) ─────────────────────────────
            Positioned(
              right: 32,
              bottom: 32,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1E4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Green top-accent bar: height 6px, full width, color #3F5F35
                        Container(
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3F5F35),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // QR Code widget 88x88px
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE4DECC)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: QrImageView(
                                    data:
                                        'https://liff.line.me/2011572383-l29PIrit',
                                    version: QrVersions.auto,
                                    size: 88,
                                    padding: const EdgeInsets.all(4),
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF2E2118),
                                    ),
                                    dataModuleStyle:
                                        const QrDataModuleStyle(
                                      dataModuleShape:
                                          QrDataModuleShape.square,
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
                                    Text(
                                      locale?.t(
                                              'สมัครสมาชิก', 'Register Member') ??
                                          'สมัครสมาชิก',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A2F1E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      locale?.t('แสกนเพื่อสะสมแต้ม',
                                              'Scan to earn points') ??
                                          'แสกนเพื่อสะสมแต้ม',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8A8374),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3F5F35),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        locale?.t('ฟรี! ไม่มีค่าใช้จ่าย',
                                                'Free! No fee') ??
                                            'ฟรี! ไม่มีค่าใช้จ่าย',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias for KioskWelcomePage
typedef KioskWelcomePage = StandbyScreen;


