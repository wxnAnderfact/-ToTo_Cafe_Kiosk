import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:toto_cafe_kiosk/providers/locale_provider.dart';
import 'package:toto_cafe_kiosk/screens/standby_screen.dart';
import 'package:toto_cafe_kiosk/features/kiosk/presentation/pages/kiosk_welcome_page.dart';

void main() {
  testWidgets('StandbyScreen renders redesigned welcome components accurately',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(
          home: StandbyScreen(),
        ),
      ),
    );
    await tester.pump();

    // 1. Heading "ToTo's Cafe"
    final headingFinder = find.text("ToTo's Cafe");
    expect(headingFinder, findsOneWidget);
    final headingText = tester.widget<Text>(headingFinder);
    expect(headingText.style?.color, const Color(0xFFF5F1E4));
    expect(headingText.style?.fontSize, 40);
    expect(headingText.style?.fontWeight, FontWeight.bold);

    // 2. Eyebrow "COFFEE & COMFORT"
    final eyebrowFinder = find.text('COFFEE & COMFORT');
    expect(eyebrowFinder, findsOneWidget);
    final eyebrowText = tester.widget<Text>(eyebrowFinder);
    expect(eyebrowText.style?.color, const Color(0xFFC8B99A));
    expect(eyebrowText.style?.fontSize, 12);
    expect(eyebrowText.style?.letterSpacing, closeTo(0.2 * 12, 0.01));

    // 3. Tap anywhere prompt text (no button)
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text("แตะที่ใดก็ได้เพื่อเริ่มสั่ง"), findsOneWidget);

    // 4. Logo Image (circular 260px, white border 3px)
    final logoImageFinder = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/logo_toto.jpg');
    expect(logoImageFinder, findsOneWidget);

    final logoContainer = find.ancestor(
      of: logoImageFinder,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxWidth == 260 &&
          w.constraints?.maxHeight == 260 &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle),
    );
    expect(logoContainer, findsOneWidget);
    final logoWidget = tester.widget<Container>(logoContainer);
    final logoDec = logoWidget.decoration as BoxDecoration;
    expect(logoDec.border?.top.width, 3);
    expect(logoDec.border?.top.color, Colors.white);
    expect(logoDec.boxShadow, isNotEmpty);

    // 5. Member QR card (300 width, 88x88 QR, 17px title, 13px subtitle)
    expect(find.byType(QrImageView), findsOneWidget);
    final qrFinder = find.byType(QrImageView);
    final qrWidget = tester.widget<QrImageView>(qrFinder);
    expect(qrWidget.size, 88);

    final titleFinder = find.text('สมัครสมาชิก');
    expect(titleFinder, findsOneWidget);
    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontSize, 17);

    final subtitleFinder = find.text('แสกนเพื่อสะสมแต้ม');
    expect(subtitleFinder, findsOneWidget);
    final subtitleText = tester.widget<Text>(subtitleFinder);
    expect(subtitleText.style?.fontSize, 13);

    expect(find.text('ฟรี! ไม่มีค่าใช้จ่าย'), findsOneWidget);

    // Card width 300
    final cardFinder = find.ancestor(
      of: qrFinder,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxWidth == 300),
    );
    expect(cardFinder, findsOneWidget);

    // 6. Animated background switcher
    expect(find.byType(AnimatedSwitcher), findsOneWidget);

    // 7. KioskWelcomePage alias
    expect(KioskWelcomePage, equals(StandbyScreen));
  });

  testWidgets('Language toggle changes prompt text',
      (WidgetTester tester) async {
    final localeProvider = LocaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
        ],
        child: const MaterialApp(
          home: StandbyScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('แตะที่ใดก็ได้เพื่อเริ่มสั่ง'), findsOneWidget);

    localeProvider.toggle();
    await tester.pump();

    expect(find.text('Tap anywhere to start ordering'), findsOneWidget);
  });
}
