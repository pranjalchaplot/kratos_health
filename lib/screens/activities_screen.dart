
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/exercise_set.dart';
import '../models/log_entry.dart';
import '../providers/soma_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../services/progressive_overload_service.dart';
import '../theme/soma_theme.dart';

/// Elite Activities Screen designed under Appllama native benchmark standards
/// Hosts 3 swipeable tab pages: WORKOUT, CARDIO, STEPS
class ActivitiesScreen extends StatefulWidget {
  final int initialTab;
  const ActivitiesScreen({super.key, this.initialTab = 0});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final currentLog = provider.currentLog;
    final goals = provider.userGoals;
    final isToday = DateUtils.isSameDay(provider.selectedDate, DateTime.now());
    final dateStr = DateFormat('EEEE, MMM d').format(provider.selectedDate);

    // Compute Activity aggregates
    final activityEntries = currentLog.entries.where((e) => e.type == LogType.activity).toList();
    final totalActiveCalories = activityEntries.fold(0, (sum, e) => sum + e.calories);
    final totalWorkoutMins = activityEntries.fold(0, (sum, e) => sum + (e.durationMinutes ?? 0));
    final stepsCount = currentLog.steps;
    final stepsGoal = goals.stepsGoal;

    return Scaffold(
      backgroundColor: SomaColors.background,
      appBar: AppBar(
        backgroundColor: SomaColors.background,
        elevation: 0,
        title: Text(
          'ACTIVITIES',
          style: SomaFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: SomaColors.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: isToday ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  isToday ? 'TODAY' : dateStr,
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isToday ? SomaColors.primaryContainer : SomaColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: SomaColors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: SomaColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: SomaColors.primaryGlow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              labelColor: Colors.black,
              unselectedLabelColor: SomaColors.onSecondaryContainer,
              labelStyle: SomaFonts.mono(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.fitness_center_rounded, size: 16),
                  text: 'WORKOUT',
                ),
                Tab(
                  icon: Icon(Icons.directions_run_rounded, size: 16),
                  text: 'CARDIO',
                ),
                Tab(
                  icon: Icon(Icons.directions_walk_rounded, size: 16),
                  text: 'STEPS',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Persistent Top Metric Summary Header
          _buildActivitySummaryHeader(
            activeBurn: totalActiveCalories,
            workoutMins: totalWorkoutMins,
            steps: stepsCount,
            stepGoal: stepsGoal,
          ),

          // Swipeable Tab Pages
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _WorkoutTab(activityEntries: activityEntries),
                _CardioTab(activityEntries: activityEntries),
                _StepsTab(activityEntries: activityEntries, currentSteps: stepsCount, stepGoal: stepsGoal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySummaryHeader({
    required int activeBurn,
    required int workoutMins,
    required int steps,
    required int stepGoal,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricPill(
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.orangeAccent,
            value: '$activeBurn',
            unit: 'kcal',
            label: 'ACTIVE BURN',
          ),
          Container(width: 1, height: 32, color: SomaColors.cardBorder),
          _buildMetricPill(
            icon: Icons.timer_outlined,
            iconColor: SomaColors.primaryContainer,
            value: '$workoutMins',
            unit: 'min',
            label: 'DURATION',
          ),
          Container(width: 1, height: 32, color: SomaColors.cardBorder),
          _buildMetricPill(
            icon: Icons.directions_walk_rounded,
            iconColor: SomaColors.secondary,
            value: '$steps',
            unit: '/ $stepGoal',
            label: 'STEPS',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              value,
              style: SomaFonts.display(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SomaColors.onSurface,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: SomaFonts.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: SomaFonts.mono(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: SomaColors.onSecondaryContainer,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 1. WORKOUT / STRENGTH TAB PAGE
// ==========================================
class _WorkoutTab extends StatefulWidget {
  final List<LogEntry> activityEntries;
  const _WorkoutTab({required this.activityEntries});

  @override
  State<_WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<_WorkoutTab> {
  final _exerciseNameController = TextEditingController(text: 'Bench Press');
  int _durationMins = 45;
  final bool _includeRest = true;
  double _rpe = 8.0;
  String _velocity = 'Controlled';

  final List<ExerciseSet> _sets = [
    ExerciseSet(setNumber: 1, reps: 10, weightKg: 60.0),
    ExerciseSet(setNumber: 2, reps: 10, weightKg: 60.0),
    ExerciseSet(setNumber: 3, reps: 10, weightKg: 60.0),
  ];

  static const List<String> _popularExercises = [
    'Bench Press',
    'Squat',
    'Deadlift',
    'Overhead Press',
    'Pull Ups',
    'Barbell Row',
    'Lat Pulldown',
    'Leg Press',
    'Romanian Deadlift',
    'Dumbbell Shoulder Press',
    'Bicep Curl',
    'Dips',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPreviousLog(_exerciseNameController.text);
    });
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    super.dispose();
  }

  void _checkPreviousLog(String name) {
    if (!mounted) return;
    final provider = context.read<SomaProvider>();
    final lastRecord = provider.getLastExerciseLog(name);
    if (lastRecord != null && lastRecord.sets.isNotEmpty) {
      setState(() {
        _sets.clear();
        for (final s in lastRecord.sets) {
          _sets.add(ExerciseSet(
            setNumber: s.setNumber,
            reps: s.reps,
            weightKg: s.weightKg,
          ));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final goals = provider.userGoals;
    final userWeight = goals.weightKg ?? 75.0;
    final userBmr = CalorieCalculatorService.calculateBmr(goals).toDouble();

    final lastRecord = provider.getLastExerciseLog(_exerciseNameController.text);
    OverloadRecommendation? overloadRec;
    if (lastRecord != null && lastRecord.sets.isNotEmpty) {
      overloadRec = ProgressiveOverloadService.computeOverload(
        exerciseName: _exerciseNameController.text,
        previousSets: lastRecord.sets,
        rpe: _rpe,
        velocity: _velocity,
      );
    }

    final estimatedCalories = CalorieCalculatorService.calculateExerciseCalories(
      exerciseName: _exerciseNameController.text,
      sets: _sets,
      durationMinutes: _durationMins,
      weightKg: userWeight,
      userBmr: userBmr,
      includeRest: _includeRest,
    );

    final workoutLogsToday = widget.activityEntries
        .where((e) => e.activityCategory == 'exercise')
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Card: Exercise Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RESISTANCE EXERCISE',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '${_sets.length} SETS PLANNED',
                      style: SomaFonts.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _exerciseNameController.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _popularExercises;
                    }
                    return _popularExercises.where((ex) =>
                        ex.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    HapticFeedback.selectionClick();
                    _exerciseNameController.text = selection;
                    _checkPreviousLog(selection);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: SomaFonts.primary(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SomaColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter exercise name (e.g. Squat)',
                        hintStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.fitness_center_rounded, color: SomaColors.primaryContainer, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            controller.clear();
                            _exerciseNameController.clear();
                          },
                        ),
                        filled: true,
                        fillColor: SomaColors.surfaceContainerHigh.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        _exerciseNameController.text = val;
                      },
                    );
                  },
                ),

                // Quick Exercise Chips
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularExercises.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final ex = _popularExercises[index];
                      final isSelected = _exerciseNameController.text.toLowerCase() == ex.toLowerCase();
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _exerciseNameController.text = ex;
                          });
                          _checkPreviousLog(ex);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SomaColors.primaryContainer.withValues(alpha: 0.2)
                                : SomaColors.surfaceContainerHigh.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                            ),
                          ),
                          child: Text(
                            ex,
                            style: SomaFonts.mono(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Progressive Overload Advisory Banner (if previous history found)
          if (overloadRec != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: SomaColors.primaryContainer.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.trending_up_rounded, color: SomaColors.primaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overloadRec.title,
                          style: SomaFonts.mono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: SomaColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          overloadRec.explanation,
                          style: SomaFonts.primary(
                            fontSize: 11.5,
                            color: SomaColors.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Section Card: Dynamic Set-by-Set Builder
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SETS BREAKDOWN',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: SomaColors.primaryContainer,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          final lastSet = _sets.isNotEmpty
                              ? _sets.last
                              : ExerciseSet(setNumber: 1, reps: 10, weightKg: 60.0);
                          _sets.add(ExerciseSet(
                            setNumber: _sets.length + 1,
                            reps: lastSet.reps,
                            weightKg: lastSet.weightKg,
                          ));
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: Text(
                        'ADD SET',
                        style: SomaFonts.mono(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Table Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          'SET',
                          style: SomaFonts.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SomaColors.onSecondaryContainer),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'WEIGHT (KG)',
                            style: SomaFonts.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SomaColors.onSecondaryContainer),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'REPS',
                            style: SomaFonts.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SomaColors.onSecondaryContainer),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                const Divider(color: SomaColors.cardBorder, height: 12),

                // List of sets
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final set = _sets[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SomaColors.surfaceContainerHigh.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SomaColors.cardBorder.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          // Set number pill
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: SomaFonts.mono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: SomaColors.primaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Weight control
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMiniCounterButton(
                                  icon: Icons.remove,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      if (set.weightKg >= 2.5) {
                                        set.weightKg = (set.weightKg - 2.5).clamp(0.0, 500.0);
                                      }
                                    });
                                  },
                                ),
                                Container(
                                  width: 54,
                                  alignment: Alignment.center,
                                  child: Text(
                                    set.weightKg % 1 == 0
                                        ? '${set.weightKg.toInt()}'
                                        : set.weightKg.toStringAsFixed(1),
                                    style: SomaFonts.mono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: SomaColors.onSurface,
                                    ),
                                  ),
                                ),
                                _buildMiniCounterButton(
                                  icon: Icons.add,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      set.weightKg = (set.weightKg + 2.5).clamp(0.0, 500.0);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Reps control
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMiniCounterButton(
                                  icon: Icons.remove,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      if (set.reps > 1) set.reps--;
                                    });
                                  },
                                ),
                                Container(
                                  width: 44,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${set.reps}',
                                    style: SomaFonts.mono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: SomaColors.onSurface,
                                    ),
                                  ),
                                ),
                                _buildMiniCounterButton(
                                  icon: Icons.add,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      set.reps++;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Delete Set button
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            visualDensity: VisualDensity.compact,
                            onPressed: _sets.length > 1
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _sets.removeAt(index);
                                      for (int i = 0; i < _sets.length; i++) {
                                        _sets[i].setNumber = i + 1;
                                      }
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Intensity, RPE & Exertion Card
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EXERTION (RPE)',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'RPE ${_rpe.toStringAsFixed(1)} / 10',
                      style: SomaFonts.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _rpe,
                  min: 5.0,
                  max: 10.0,
                  divisions: 10,
                  activeColor: SomaColors.primaryContainer,
                  inactiveColor: SomaColors.surfaceContainerHighest,
                  onChanged: (val) {
                    setState(() => _rpe = val);
                  },
                ),
                const SizedBox(height: 10),

                // Rep Velocity selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VELOCITY PROFILE',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Row(
                      children: ['Explosive', 'Controlled', 'Grind'].map((vel) {
                        final isSel = _velocity == vel;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _velocity = vel);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? SomaColors.primaryContainer : SomaColors.cardBorder,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                vel,
                                style: SomaFonts.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.black : SomaColors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Workout Duration Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL SESSION TIME',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '$_durationMins min',
                      style: SomaFonts.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _durationMins.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 22,
                  activeColor: SomaColors.primaryContainer,
                  inactiveColor: SomaColors.surfaceContainerHighest,
                  onChanged: (val) {
                    setState(() => _durationMins = val.round());
                  },
                ),
              ],
            ),
          ),

          // Action Button with Live Burn preview
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final name = _exerciseNameController.text.trim();
              if (name.isEmpty) return;

              await provider.logExercise(
                exerciseName: name,
                sets: _sets,
                durationMinutes: _durationMins,
                calories: estimatedCalories,
                rpe: _rpe,
                velocity: _velocity,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: SomaColors.surfaceContainerHigh,
                    content: Text(
                      '✓ Logged $name ($estimatedCalories kcal burned)',
                      style: SomaFonts.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: SomaColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: SomaColors.primaryGlow,
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'LOG WORKOUT • $estimatedCalories KCAL',
                    style: SomaFonts.mono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contextual History: Completed Strength Workouts Today
          if (workoutLogsToday.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'COMPLETED WORKOUTS TODAY',
              style: SomaFonts.mono(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            ...workoutLogsToday.map((entry) => _buildWorkoutHistoryItem(context, provider, entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCounterButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: SomaColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: SomaColors.onSurface),
      ),
    );
  }

  Widget _buildWorkoutHistoryItem(BuildContext context, SomaProvider provider, LogEntry entry) {
    final setsStr = entry.sets != null ? '${entry.sets!.length} sets' : '';
    final maxWeight = entry.sets?.fold(0.0, (m, s) => s.weightKg > m ? s.weightKg : m) ?? 0.0;
    final maxWeightStr = maxWeight > 0 ? 'Max: ${maxWeight.toStringAsFixed(1)}kg' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SomaColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: SomaColors.primaryContainer, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: SomaFonts.primary(fontSize: 14, fontWeight: FontWeight.w700, color: SomaColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '$setsStr • $maxWeightStr • ${entry.calories} kcal',
                  style: SomaFonts.mono(fontSize: 11, color: SomaColors.onSecondaryContainer),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: SomaColors.onSecondaryContainer),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.deleteLogEntry(entry.id);
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. CARDIO TAB PAGE
// ==========================================
class _CardioTab extends StatefulWidget {
  final List<LogEntry> activityEntries;
  const _CardioTab({required this.activityEntries});

  @override
  State<_CardioTab> createState() => _CardioTabState();
}

class _CardioTabState extends State<_CardioTab> {
  String _cardioType = 'Running';
  String _cardioIntensity = 'Moderate';
  double _durationMins = 30;
  double _distanceKm = 5.0;
  final double _speedMph = 6.0;

  static const List<String> _cardioTypes = [
    'Running',
    'Cycling',
    'Swimming',
    'Rowing',
    'HIIT',
    'Walking',
    'Stair Climber',
    'Jump Rope',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final goals = provider.userGoals;
    final userWeight = goals.weightKg ?? 75.0;
    final userBmr = CalorieCalculatorService.calculateBmr(goals).toDouble();

    final isSpeedBased = _cardioType == 'Running' || _cardioType == 'Walking' || _cardioType == 'Cycling';

    double effectiveSpeed = _speedMph;
    if (isSpeedBased && _distanceKm > 0 && _durationMins > 0) {
      effectiveSpeed = double.parse(((_distanceKm / (_durationMins / 60.0)) / 1.60934).toStringAsFixed(1));
    }

    final calculatedCalories = CalorieCalculatorService.getCardioCalories(
      exercise: _cardioType,
      durationMin: _durationMins,
      speedMph: isSpeedBased ? effectiveSpeed : null,
      effort: !isSpeedBased ? _cardioIntensity : null,
      userWeightKg: userWeight,
      userBmr: userBmr,
    ).round();

    final cardioLogsToday = widget.activityEntries
        .where((e) => e.activityCategory == 'cardio')
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cardio Type Grid/Chip selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARDIO DISCIPLINE',
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: SomaColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cardioTypes.map((type) {
                    final isSel = _cardioType == type;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _cardioType = type;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? SomaColors.primaryContainer.withValues(alpha: 0.2)
                              : SomaColors.surfaceContainerHigh.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? SomaColors.primaryContainer : SomaColors.cardBorder,
                          ),
                        ),
                        child: Text(
                          type,
                          style: SomaFonts.mono(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Duration & Metric Controls
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DURATION',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '${_durationMins.toInt()} min',
                      style: SomaFonts.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _durationMins,
                  min: 5,
                  max: 180,
                  divisions: 35,
                  activeColor: SomaColors.primaryContainer,
                  inactiveColor: SomaColors.surfaceContainerHighest,
                  onChanged: (val) {
                    setState(() => _durationMins = val);
                  },
                ),

                const SizedBox(height: 12),
                if (isSpeedBased) ...[
                  // Distance & Speed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DISTANCE (KM)',
                        style: SomaFonts.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: SomaColors.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        '${_distanceKm.toStringAsFixed(1)} km (${effectiveSpeed.toStringAsFixed(1)} mph)',
                        style: SomaFonts.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _distanceKm,
                    min: 0.5,
                    max: 42.0,
                    divisions: 83,
                    activeColor: SomaColors.secondary,
                    inactiveColor: SomaColors.surfaceContainerHighest,
                    onChanged: (val) {
                      setState(() => _distanceKm = val);
                    },
                  ),
                ] else ...[
                  // Intensity selector
                  Text(
                    'EXERTION / INTENSITY',
                    style: SomaFonts.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Light', 'Moderate', 'Vigorous', 'Max'].map((intensity) {
                      final isSel = _cardioIntensity.toLowerCase() == intensity.toLowerCase();
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _cardioIntensity = intensity);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? SomaColors.primaryContainer : SomaColors.surfaceContainerHigh.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? SomaColors.primaryContainer : SomaColors.cardBorder,
                                ),
                              ),
                              child: Text(
                                intensity,
                                style: SomaFonts.mono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.black : SomaColors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Primary CTA with Live Burn Preview
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await provider.logCardio(
                cardioType: _cardioType,
                intensity: _cardioIntensity,
                durationMinutes: _durationMins.toInt(),
                distanceKm: isSpeedBased ? _distanceKm : null,
                calories: calculatedCalories,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: SomaColors.surfaceContainerHigh,
                    content: Text(
                      '✓ Logged $_cardioType ($calculatedCalories kcal burned)',
                      style: SomaFonts.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: SomaColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: SomaColors.primaryGlow,
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'LOG CARDIO • $calculatedCalories KCAL',
                    style: SomaFonts.mono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contextual History: Completed Cardio Today
          if (cardioLogsToday.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'COMPLETED CARDIO TODAY',
              style: SomaFonts.mono(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            ...cardioLogsToday.map((entry) => _buildCardioHistoryItem(context, provider, entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildCardioHistoryItem(BuildContext context, SomaProvider provider, LogEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SomaColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_run_rounded, color: SomaColors.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: SomaFonts.primary(fontSize: 14, fontWeight: FontWeight.w700, color: SomaColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.subtitle} • ${entry.calories} kcal',
                  style: SomaFonts.mono(fontSize: 11, color: SomaColors.onSecondaryContainer),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: SomaColors.onSecondaryContainer),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.deleteLogEntry(entry.id);
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. STEPS TAB PAGE
// ==========================================
class _StepsTab extends StatefulWidget {
  final List<LogEntry> activityEntries;
  final int currentSteps;
  final int stepGoal;

  const _StepsTab({
    required this.activityEntries,
    required this.currentSteps,
    required this.stepGoal,
  });

  @override
  State<_StepsTab> createState() => _StepsTabState();
}

class _StepsTabState extends State<_StepsTab> {
  double _stepsToAdd = 2500;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final goals = provider.userGoals;
    final userWeight = goals.weightKg ?? 75.0;
    final userBmr = CalorieCalculatorService.calculateBmr(goals).toDouble();

    final stepCalories = CalorieCalculatorService.getStepCalories(
      steps: _stepsToAdd.toInt(),
      userWeightKg: userWeight,
      userBmr: userBmr,
      userHeightCm: goals.heightCm,
    ).round();

    final progress = widget.stepGoal > 0 ? (widget.currentSteps / widget.stepGoal).clamp(0.0, 1.0) : 0.0;
    final estimatedDistanceKm = (widget.currentSteps * 0.00078).toStringAsFixed(2);

    final stepLogsToday = widget.activityEntries
        .where((e) => e.activityCategory == 'steps')
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Progress Dial Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DAILY TARGET PROGRESS',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: SomaFonts.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '${widget.currentSteps}',
                        style: SomaFonts.display(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: SomaColors.secondary,
                        ),
                      ),
                      Text(
                        'of ${widget.stepGoal} steps target',
                        style: SomaFonts.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: SomaColors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: SomaColors.surfaceContainerHighest,
                    color: SomaColors.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatSubItem(
                      label: 'DISTANCE',
                      val: '$estimatedDistanceKm km',
                    ),
                    Container(width: 1, height: 24, color: SomaColors.cardBorder),
                    _buildStatSubItem(
                      label: 'REMAINING',
                      val: '${(widget.stepGoal - widget.currentSteps).clamp(0, 999999)}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Log Steps Control Card
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADD STEP ENTRY',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      '+${_stepsToAdd.toInt()} steps ($stepCalories kcal)',
                      style: SomaFonts.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _stepsToAdd,
                  min: 500,
                  max: 20000,
                  divisions: 39,
                  activeColor: SomaColors.secondary,
                  inactiveColor: SomaColors.surfaceContainerHighest,
                  onChanged: (val) {
                    setState(() => _stepsToAdd = val);
                  },
                ),

                // Quick Increment Buttons
                Row(
                  children: [500, 1000, 2500, 5000].map((inc) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SomaColors.cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _stepsToAdd = inc.toDouble();
                            });
                          },
                          child: Text(
                            '+$inc',
                            style: SomaFonts.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: SomaColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Primary CTA Button
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await provider.logSteps(
                steps: _stepsToAdd.toInt(),
                calories: stepCalories,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: SomaColors.surfaceContainerHigh,
                    content: Text(
                      '✓ Logged ${_stepsToAdd.toInt()} steps ($stepCalories kcal)',
                      style: SomaFonts.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SomaColors.secondary,
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: SomaColors.secondary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: SomaColors.secondary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'LOG STEPS • +${_stepsToAdd.toInt()} STEPS',
                    style: SomaFonts.mono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contextual History: Completed Steps Today
          if (stepLogsToday.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'TODAY\'S STEP ENTRIES',
              style: SomaFonts.mono(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            ...stepLogsToday.map((entry) => _buildStepHistoryItem(context, provider, entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatSubItem({required String label, required String val}) {
    return Column(
      children: [
        Text(
          val,
          style: SomaFonts.mono(fontSize: 14, fontWeight: FontWeight.w800, color: SomaColors.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: SomaFonts.mono(fontSize: 9.5, fontWeight: FontWeight.w700, color: SomaColors.onSecondaryContainer),
        ),
      ],
    );
  }

  Widget _buildStepHistoryItem(BuildContext context, SomaProvider provider, LogEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SomaColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_walk_rounded, color: SomaColors.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: SomaFonts.primary(fontSize: 14, fontWeight: FontWeight.w700, color: SomaColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.subtitle} • ${entry.calories} kcal',
                  style: SomaFonts.mono(fontSize: 11, color: SomaColors.onSecondaryContainer),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: SomaColors.onSecondaryContainer),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.deleteLogEntry(entry.id);
            },
          ),
        ],
      ),
    );
  }
}
