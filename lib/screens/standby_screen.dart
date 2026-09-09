import 'package:flutter/material.dart';
import '../theme.dart';
import 'main_menu_screen.dart';

/// หน้า 1: Standby (พักหน้าจอ)
///
/// - วิดีโอ/ภาพบรรยากาศร้านวนลูปเต็มจอ
/// - QR Code สมัครสมาชิกมุมขวาล่าง (ไม่บังคับ)
/// - ปุ่มใหญ่ "Tap to start ordering" กลาง/ด้านล่างจอ
class StandbyScreen extends StatelessWidget {
  const StandbyScreen({super.key});

  void _onStartOrdering(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainMenuScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => _onStartOrdering(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background (placeholder — replace with video/image loop) ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kGreen800,
                    kCoffee900,
                  ],
                ),
              ),
            ),

            // ── Foreground content ────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo / brand
                  Text(
                    'ToTo Cafe',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: kCream, fontSize: 48),
                  ),
                  const SizedBox(height: kSpace8),
                  Text(
                    'COFFEE & COMFORT',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: kGold,
                          letterSpacing: 0.15 * 11,
                        ),
                  ),

                  const Spacer(flex: 2),

                  // CTA button
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: kSpace48),
                    child: SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: () => _onStartOrdering(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kColorPrimary,
                          foregroundColor: kColorWhite,
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: kColorWhite,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        child: const Text('Tap to start ordering'),
                      ),
                    ),
                  ),

                  const SizedBox(height: kSpace48),

                  const Spacer(),
                ],
              ),
            ),

            // ── QR Code — สมัครสมาชิก (มุมขวาล่าง) ──────────────────────
            Positioned(
              right: kSpace24,
              bottom: kSpace24,
              child: Container(
                padding: const EdgeInsets.all(kSpace12),
                decoration: BoxDecoration(
                  color: kColorSurface,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Placeholder for QR code widget
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: kColorWhite,
                        borderRadius: BorderRadius.circular(kSpace8),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        size: 48,
                        color: kCoffee900,
                      ),
                    ),
                    const SizedBox(width: kSpace12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'สมัครสมาชิก',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: kSpace4),
                        Text(
                          'สแกนเพื่อสะสมแต้ม',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
