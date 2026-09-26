import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/soma_theme.dart';

/// Custom painter for the concentric progress rings with sleek finish
class ProgressRingsPainter extends CustomPainter {
  final double calorieProgress; // 0.0 to 1.0+
  final double activityProgress; // 0.0 to 1.0+

  ProgressRingsPainter({
    required this.calorieProgress,
    required this.activityProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 8;
    final innerRadius = outerRadius - 18;

    // Draw outer track
    final outerTrackPaint = Paint()
      ..color = SomaColors.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, outerRadius, outerTrackPaint);

    // Draw outer progress (Electric Lime)
    if (calorieProgress > 0) {
      final outerProgressPaint = Paint()
        ..color = SomaColors.primaryContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      final outerSweepAngle = 2 * pi * calorieProgress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        -pi / 2,
        outerSweepAngle,
        false,
        outerProgressPaint,
      );
    }

    // Draw inner track
    final innerTrackPaint = Paint()
      ..color = SomaColors.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // Draw inner progress (Pure white / light neutral)
    if (activityProgress > 0) {
      final innerProgressPaint = Paint()
        ..color = SomaColors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      final innerSweepAngle = 2 * pi * activityProgress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        -pi / 2,
        innerSweepAngle,
        false,
        innerProgressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProgressRingsPainter oldDelegate) {
    return oldDelegate.calorieProgress != calorieProgress ||
        oldDelegate.activityProgress != activityProgress;
  }
}

/// Progress Rings Widget
class ProgressRings extends StatelessWidget {
  final double calorieProgress;
  final double activityProgress;
  final String centerValue;
  final String centerLabel;

  const ProgressRings({
    super.key,
    required this.calorieProgress,
    required this.activityProgress,
    required this.centerValue,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(156, 156),
            painter: ProgressRingsPainter(
              calorieProgress: calorieProgress,
              activityProgress: activityProgress,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: SomaFonts.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.8,
                  color: SomaColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                centerLabel,
                style: SomaFonts.mono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: SomaColors.primaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
