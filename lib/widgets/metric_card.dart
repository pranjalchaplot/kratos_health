import 'package:flutter/material.dart';
import '../theme/kratos_theme.dart';

/// Metric card used in the 2x2 grid (Steps, Water, Sleep, Digital)
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? secondaryValue;
  final String? secondaryUnit;
  final String percentage;
  final double progress; // 0.0 to 1.0
  final IconData icon;

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KratosColors.cardBackground,
        border: Border.all(color: KratosColors.cardBorder, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Label, Percentage, Icon
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: 1.0,
                        color: Color(0x99B6B5B4), // on-secondary-container/70
                      ),
                    ),
                  ),
                  Text(
                    percentage,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      letterSpacing: 1.0,
                      color: KratosColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    icon,
                    color: KratosColors.primaryContainer,
                    size: 20,
                  ),
                ],
              ),
              // Center: Big value
              Expanded(
                child: Center(
                  child: _buildValueText(),
                ),
              ),
              // Bottom: Progress bar
              Container(
                height: 4,
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
                      color: KratosColors.primaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueText() {
    if (secondaryValue != null) {
      // Two-part value like "4h 12m"
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.44,
              fontStyle: FontStyle.italic,
              color: KratosColors.onSurface,
            ),
          ),
          Text(
            unit ?? '',
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: KratosColors.onSurface,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            secondaryValue!,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.44,
              fontStyle: FontStyle.italic,
              color: KratosColors.onSurface,
            ),
          ),
          Text(
            secondaryUnit ?? '',
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: KratosColors.onSurface,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.44,
            fontStyle: FontStyle.italic,
            color: KratosColors.onSurface,
          ),
        ),
        if (unit != null)
          Text(
            unit!,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: KratosColors.onSurface,
            ),
          ),
      ],
    );
  }
}
