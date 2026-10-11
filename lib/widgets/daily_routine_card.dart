import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../theme/soma_theme.dart';
import 'routine_selection_sheet.dart';

class DailyRoutineCard extends StatelessWidget {
  const DailyRoutineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final routine = provider.activeRoutine;
    final exercises = routine.exercises;

    // Check which exercises from routine are already logged today
    final loggedExerciseTitles = provider.currentLog.entries
        .where((e) => e.exerciseName != null)
        .map((e) => e.exerciseName!.toLowerCase().trim())
        .toSet();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SomaColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      routine.category.toUpperCase(),
                      style: SomaFonts.mono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY TRAINING PROTOCOL',
                    style: SomaFonts.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SomaColors.onSecondaryContainer,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  RoutineSelectionSheet.show(context);
                },
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 14, color: SomaColors.primaryContainer),
                    const SizedBox(width: 3),
                    Text(
                      'CHANGE',
                      style: SomaFonts.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Routine Title & Target Duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  routine.name,
                  style: SomaFonts.display(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SomaColors.onSurface,
                  ),
                ),
              ),
              Text(
                '~${routine.targetDurationMinutes} min',
                style: SomaFonts.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SomaColors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            routine.description,
            style: SomaFonts.primary(
              fontSize: 12,
              color: SomaColors.onSecondaryContainer,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // Exercise Chips Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: exercises.map((ex) {
                final isCompleted = loggedExerciseTitles.contains(ex.name.toLowerCase().trim());
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<SomaProvider>().setTab(1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? SomaColors.primaryContainer.withValues(alpha: 0.15)
                            : SomaColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompleted
                              ? SomaColors.primaryContainer
                              : SomaColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle : Icons.fitness_center,
                            size: 13,
                            color: isCompleted ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ex.name,
                            style: SomaFonts.primary(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? SomaColors.primaryContainer : SomaColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${ex.defaultSets}×${ex.defaultReps})',
                            style: SomaFonts.mono(
                              fontSize: 10,
                              color: SomaColors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
