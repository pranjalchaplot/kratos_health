import 'package:flutter/material.dart';
import '../theme/soma_theme.dart';

/// Macro progress bar used in the Daily Summary card
class MacroProgressBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress; // 0.0 to 1.0+
  final Color barColor;

  const MacroProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: barColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: SomaColors.onSurface,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  value,
                  style: SomaFonts.mono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: SomaColors.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$percent%',
                  style: SomaFonts.mono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: SomaColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
