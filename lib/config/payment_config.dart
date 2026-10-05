/// Centralized Payment Configuration for ToTo Cafe Kiosk & POS
///
/// You can override this value via --dart-define during build/run:
///   flutter run --dart-define=PROMPTPAY_ID=0812345678
///   flutter build web --release --dart-define=PROMPTPAY_ID=0812345678
///
/// Or set your store phone number (10 digits) or national ID (13 digits) here.
const String kDefaultPromptPayId = '1103100963315';

const String kPromptPayId = String.fromEnvironment(
  'PROMPTPAY_ID',
  defaultValue: kDefaultPromptPayId,
);
