import 'package:flutter/material.dart';

/// Custom on-screen numeric keypad widget for touchscreen Kiosk & POS.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxLength = 10,
  });

  /// Current digits string.
  final String value;

  /// Called with the new value on each button tap.
  final ValueChanged<String> onChanged;

  /// Maximum allowed length of digits.
  final int maxLength;

  static const Color _kDarkGreen = Color(0xFF3D5A3E);
  static const Color _kGrey = Color(0xFF7A7E78);

  void _onDigitTap(String digit) {
    if (value.length < maxLength) {
      onChanged(value + digit);
    }
  }

  void _onClearTap() {
    onChanged('');
  }

  void _onBackspaceTap() {
    if (value.isNotEmpty) {
      onChanged(value.substring(0, value.length - 1));
    }
  }

  Widget _buildKey({
    required String label,
    required VoidCallback onTap,
    required Color backgroundColor,
    double fontSize = 22,
  }) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKey(
              label: '1',
              onTap: () => _onDigitTap('1'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '2',
              onTap: () => _onDigitTap('2'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '3',
              onTap: () => _onDigitTap('3'),
              backgroundColor: _kDarkGreen,
            ),
          ],
        ),
        const SizedBox(height: spacing),

        // Row 2: 4, 5, 6
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKey(
              label: '4',
              onTap: () => _onDigitTap('4'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '5',
              onTap: () => _onDigitTap('5'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '6',
              onTap: () => _onDigitTap('6'),
              backgroundColor: _kDarkGreen,
            ),
          ],
        ),
        const SizedBox(height: spacing),

        // Row 3: 7, 8, 9
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKey(
              label: '7',
              onTap: () => _onDigitTap('7'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '8',
              onTap: () => _onDigitTap('8'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '9',
              onTap: () => _onDigitTap('9'),
              backgroundColor: _kDarkGreen,
            ),
          ],
        ),
        const SizedBox(height: spacing),

        // Row 4: clear (ล้าง), 0, backspace (⌫)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKey(
              label: 'ล้าง',
              onTap: _onClearTap,
              backgroundColor: _kGrey,
              fontSize: 16,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '0',
              onTap: () => _onDigitTap('0'),
              backgroundColor: _kDarkGreen,
            ),
            const SizedBox(width: spacing),
            _buildKey(
              label: '⌫',
              onTap: _onBackspaceTap,
              backgroundColor: _kGrey,
              fontSize: 22,
            ),
          ],
        ),
      ],
    );
  }
}
