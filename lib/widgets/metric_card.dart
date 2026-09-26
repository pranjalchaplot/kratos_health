import 'package:flutter/material.dart';
import '../theme/soma_theme.dart';

/// Metric card used in the 2x2 telemetry grid (Steps, Water, Sleep, Digital)
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? secondaryValue;
  final String? secondaryUnit;
  final String percentage;
  final double progress; // 0.0 to 1.0+
  final IconData icon;
  final Color? accentColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.secondaryValue,
    this.secondaryUnit,
    required this.percentage,
    required this.progress,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? SomaColors.primaryContainer;

    return Container(
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        border: Border.all(color: SomaColors.cardBorder, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: Icon badge, Label, and Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: SomaFonts.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    percentage,
                    style: SomaFonts.mono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Center: Value display with Tabular numerals
            _buildValueText(),

            const Spacer(),

            // Bottom: Progress track
            Container(
              height: 4,
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
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueText() {
    if (secondaryValue != null) {
      // Two-part value like "4h 12m"
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: SomaFonts.display(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: SomaColors.onSurface,
            ),
          ),
          Text(
            unit ?? '',
            style: SomaFonts.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            secondaryValue!,
            style: SomaFonts.display(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: SomaColors.onSurface,
            ),
          ),
          Text(
            secondaryUnit ?? '',
            style: SomaFonts.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: SomaFonts.display(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: SomaColors.onSurface,
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 2),
          Text(
            unit!,
            style: SomaFonts.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
        ],
      ],
    );
  }
}
