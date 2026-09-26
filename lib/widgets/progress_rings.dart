import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/kratos_theme.dart';

/// Custom painter for the concentric progress rings
class ProgressRingsPainter extends CustomPainter {
  final double calorieProgress; // 0.0 to 1.0
  final double activityProgress; // 0.0 to 1.0

  ProgressRingsPainter({
    required this.calorieProgress,
    required this.activityProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 6;
    final innerRadius = outerRadius - 20;

    // Draw outer track
    final outerTrackPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, outerRadius, outerTrackPaint);

    // Draw outer progress (Electric Lime)
    final outerProgressPaint = Paint()
      ..color = KratosColors.primaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final outerSweepAngle = 2 * pi * calorieProgress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      -pi / 2,
      outerSweepAngle,
      false,
      outerProgressPaint,
    );

    // Draw inner track
    final innerTrackPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // Draw inner progress (White/on-surface)
    final innerProgressPaint = Paint()
      ..color = KratosColors.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final innerSweepAngle = 2 * pi * activityProgress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -pi / 2,
      innerSweepAngle,
      false,
      innerProgressPaint,
    );
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
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
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
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -0.48,
                  color: KratosColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                centerLabel,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 1.0,
                  color: KratosColors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
