import 'package:flutter/material.dart';
import '../theme/kratos_theme.dart';

/// Weekly calendar strip showing MON-SUN with active day highlighted & interactive date selection
class WeekCalendarStrip extends StatelessWidget {
  final int activeIndex; // 0 = MON, 6 = SUN
  final ValueChanged<int>? onDaySelected;

  const WeekCalendarStrip({
    super.key,
    required this.activeIndex,
    this.onDaySelected,
  });

  static const List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    // Calculate actual dates for current week (Mon-Sun)
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dates = List.generate(7, (i) => monday.add(Duration(days: i)).day);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: KratosColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final isActive = index == activeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected?.call(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? KratosColors.primaryContainer : null,
                  gradient: isActive
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            KratosColors.primaryContainer.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? KratosColors.primaryContainer
                        : Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _days[index],
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: 1.0,
                        color: isActive
                            ? KratosColors.background
                            : KratosColors.onSecondaryContainer.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dates[index]}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? KratosColors.background
                            : KratosColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
