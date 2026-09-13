import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toto_cafe_kiosk/widgets/numeric_keypad.dart';

void main() {
  testWidgets('NumericKeypad appends digits up to maxLength', (tester) async {
    String currentVal = '081';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return NumericKeypad(
                value: currentVal,
                maxLength: 5,
                onChanged: (val) {
                  setState(() {
                    currentVal = val;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Tap '2'
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(currentVal, equals('0812'));

    // Tap '3'
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(currentVal, equals('08123'));

    // Tap '4' - should not exceed maxLength 5
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(currentVal, equals('08123'));

    // Tap backspace '⌫'
    await tester.tap(find.text('⌫'));
    await tester.pump();
    expect(currentVal, equals('0812'));

    // Tap clear 'ล้าง'
    await tester.tap(find.text('ล้าง'));
    await tester.pump();
    expect(currentVal, equals(''));
  });
}
