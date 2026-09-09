// Basic smoke test for the ToTo Cafe Kiosk app.
//
// NOTE: Full widget tests require Firebase initialization.
// This test is a placeholder — run integration tests on device.

import 'package:flutter_test/flutter_test.dart';
import 'package:toto_cafe_kiosk/services/menu_service.dart';
import 'package:toto_cafe_kiosk/main.dart';

void main() {
  testWidgets('App renders StandbyScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: This requires Firebase to be initialized in the test environment.
    // For CI, use firebase_core_platform_interface mocks.
    await tester.pumpWidget(TotoCafeApp(menuService: MenuService()));
    await tester.pumpAndSettle();

    // Verify the standby screen shows the start ordering button.
    expect(find.text('Tap to start ordering'), findsOneWidget);
  });
}
