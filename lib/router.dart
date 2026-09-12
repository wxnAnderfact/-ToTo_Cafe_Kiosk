import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/standby_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/qr_payment_screen.dart';
import 'screens/cashier_pos_screen.dart';
import 'screens/member_screen.dart';

// ---------------------------------------------------------------------------
// ToTo Cafe — GoRouter configuration
//
// URL structure:
//   /           → redirect to /kiosk  (customer-facing iPad in portrait)
//   /kiosk      → StandbyScreen
//   /kiosk/menu → MainMenuScreen
//   /kiosk/checkout → CheckoutScreen
//   /kiosk/payment/qr → QrPaymentScreen
//   /pos        → CashierPosScreen  (staff iPad in landscape)
//
// Use context.go('/kiosk/menu') anywhere in the widget tree.
// ---------------------------------------------------------------------------

final appRouter = GoRouter(
  initialLocation: '/kiosk',
  redirect: (context, state) {
    final location = state.uri.toString();
    // If LIFF redirects with access_token in path, redirect to /member
    if (location.contains('access_token') || location.contains('liff.state')) {
      return '/member';
    }
    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
  routes: [
    // ── Root redirect ──────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      redirect: (context, state) => '/kiosk',
    ),

    // ── Kiosk (customer) routes ───────────────────────────────────────────
    GoRoute(
      path: '/kiosk',
      builder: (context, state) => const StandbyScreen(),
      routes: [
        GoRoute(
          path: 'menu',
          builder: (context, state) => const MainMenuScreen(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: 'payment/qr',
          builder: (context, state) => const QrPaymentScreen(),
        ),
      ],
    ),

    // ── POS (staff) route ─────────────────────────────────────────────────
    GoRoute(
      path: '/pos',
      builder: (context, state) => const CashierPosScreen(),
    ),

    // ── Member (LINE LIFF) route ──────────────────────────────────────────
    GoRoute(
      path: '/member',
      builder: (context, state) => const MemberScreen(),
    ),
  ],
);
