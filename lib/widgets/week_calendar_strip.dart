import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/soma_theme.dart';

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
    final currentDayIndex = now.weekday - 1; // 0 = Mon, 6 = Sun
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dates = List.generate(7, (i) => monday.add(Duration(days: i)).day);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SomaColors.cardBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final isSelected = index == activeIndex;
          final isToday = index == currentDayIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onDaySelected?.call(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SomaColors.primaryContainer
                      : isToday
                          ? SomaColors.surfaceContainerHigh
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? SomaColors.primaryContainer
                        : isToday
                            ? SomaColors.primaryContainer.withValues(alpha: 0.4)
                            : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _days[index],
                      style: SomaFonts.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isSelected
                            ? SomaColors.onPrimary
                            : SomaColors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${dates[index]}',
                      style: SomaFonts.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? SomaColors.onPrimary
                            : SomaColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Micro-indicator dot
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? SomaColors.onPrimary
                            : isToday
                                ? SomaColors.primaryContainer
                                : Colors.transparent,
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
