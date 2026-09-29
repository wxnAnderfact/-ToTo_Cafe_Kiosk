import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme.dart';

/// Renders a QR code linking to the digital receipt / order status page.
///
/// URL format: `https://toto-cafe-kiosk.web.app/receipt/{orderId}`
class OrderQrCode extends StatelessWidget {
  const OrderQrCode({
    super.key,
    required this.orderId,
    this.caption,
    this.size = 180.0,
  });

  final String orderId;
  final String? caption;
  final double size;

  String get receiptUrl => 'https://toto-cafe-kiosk.web.app/receipt/$orderId';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadiusCard),
            border: Border.all(color: kColorBorder),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: QrImageView(
            data: receiptUrl,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: kCoffee900,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: kCoffee900,
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: kSpace8),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: kColorTextMuted,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
