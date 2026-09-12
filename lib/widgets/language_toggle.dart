import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final isThai = localeProvider.isThai;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.read<LocaleProvider>().toggle(),
          child: Container(
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: kColorSurface,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(color: kColorBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageSegment(
                  label: 'TH',
                  isActive: isThai,
                ),
                _buildLanguageSegment(
                  label: 'EN',
                  isActive: !isThai,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageSegment({
    required String label,
    required bool isActive,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? kColorPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? kColorWhite : kColorTextMuted,
        ),
      ),
    );
  }
}
