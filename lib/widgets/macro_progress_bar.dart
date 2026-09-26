import 'package:flutter/material.dart';
import '../theme/kratos_theme.dart';

/// Macro progress bar used in the Daily Summary card
class MacroProgressBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress; // 0.0 to 1.0
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 1.2,
                color: KratosColors.onSurface,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 1.2,
                color: KratosColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: KratosColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
