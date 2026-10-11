import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/workout_routine.dart';
import '../providers/soma_provider.dart';
import '../theme/soma_theme.dart';

class RoutineSelectionSheet extends StatefulWidget {
  const RoutineSelectionSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoutineSelectionSheet(),
    );
  }

  @override
  State<RoutineSelectionSheet> createState() => _RoutineSelectionSheetState();
}

class _RoutineSelectionSheetState extends State<RoutineSelectionSheet> {
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customExercisesController = TextEditingController();
  bool _isCreatingCustom = false;

  @override
  void dispose() {
    _customNameController.dispose();
    _customExercisesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final routines = provider.routines;
    final activeId = provider.activeRoutineId;

    return Container(
      decoration: BoxDecoration(
        color: SomaColors.background.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: SomaColors.cardBorder, width: 1),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SomaColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: SomaColors.primaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isCreatingCustom ? 'NEW CUSTOM ROUTINE' : 'SELECT DAILY PROTOCOL',
                        style: SomaFonts.display(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isCreatingCustom = !_isCreatingCustom);
                    },
                    icon: Icon(
                      _isCreatingCustom ? Icons.close : Icons.add,
                      size: 16,
                      color: SomaColors.primaryContainer,
                    ),
                    label: Text(
                      _isCreatingCustom ? 'CANCEL' : 'CREATE',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isCreatingCustom) ...[
                // Custom Routine Creation Form
                TextField(
                  controller: _customNameController,
                  style: SomaFonts.primary(color: SomaColors.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Routine Name (e.g. Chest & Abs)',
                    labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
                    filled: true,
                    fillColor: SomaColors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customExercisesController,
                  maxLines: 3,
                  style: SomaFonts.primary(color: SomaColors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Exercises (comma separated)',
                    hintText: 'Bench Press, Incline DB Press, Cable Flyes',
                    hintStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer.withValues(alpha: 0.6)),
                    labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
                    filled: true,
                    fillColor: SomaColors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final name = _customNameController.text.trim();
                    if (name.isEmpty) return;

                    final exerciseList = _customExercisesController.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .map((exName) => RoutineExercise(name: exName, defaultSets: 3, defaultReps: 10))
                        .toList();

                    final newRoutine = WorkoutRoutine(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      category: 'custom',
                      description: 'Custom athlete training protocol.',
                      exercises: exerciseList.isNotEmpty
                          ? exerciseList
                          : [RoutineExercise(name: 'Workout', defaultSets: 3, defaultReps: 10)],
                      isPreset: false,
                    );

                    HapticFeedback.mediumImpact();
                    final navigator = Navigator.of(context);
                    await provider.addCustomRoutine(newRoutine);
                    if (mounted) navigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SomaColors.primaryContainer,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'SAVE & ACTIVATE PROTOCOL',
                    style: SomaFonts.mono(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ] else ...[
                // List of Built-in & Custom Routines
                Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: routines.length,
                    itemBuilder: (context, index) {
                      final routine = routines[index];
                      final isSelected = routine.id == activeId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SomaColors.primaryContainer.withValues(alpha: 0.12)
                              : SomaColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final navigator = Navigator.of(context);
                            await provider.setActiveRoutine(routine.id);
                            if (mounted) navigator.pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? SomaColors.primaryContainer
                                        : SomaColors.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(routine.category),
                                    color: isSelected ? Colors.black : SomaColors.onSurface,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            routine.name,
                                            style: SomaFonts.primary(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: SomaColors.onSurface,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: SomaColors.primaryContainer,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'ACTIVE',
                                                style: SomaFonts.mono(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${routine.targetDurationMinutes}m • ${routine.exercises.length} exercises • ${routine.description}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SomaFonts.primary(
                                          fontSize: 11.5,
                                          color: SomaColors.onSecondaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!routine.isPreset)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () async {
                                      HapticFeedback.mediumImpact();
                                      await provider.deleteRoutine(routine.id);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'split':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'mobility':
        return Icons.self_improvement;
      default:
        return Icons.bolt;
    }
  }
}
