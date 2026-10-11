import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/exercise_set.dart';
import '../providers/soma_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../services/progressive_overload_service.dart';
import '../services/screen_time_service.dart';
import '../theme/soma_theme.dart';
import 'bmr_info_dialog.dart';

class QuickLogTab {
  static const int water = 0;
  static const int meal = 1;
  static const int burn = 2;
  static const int activity = 3;
  static const int sleep = 4;
  static const int digital = 5;
}

class QuickLogModal extends StatefulWidget {
  final int initialTabIndex;
  final String? initialExerciseName;

  const QuickLogModal({
    super.key,
    this.initialTabIndex = QuickLogTab.water,
    this.initialExerciseName,
  });

  static void show(
    BuildContext context, {
    int initialTabIndex = QuickLogTab.water,
    String? initialExerciseName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickLogModal(
        initialTabIndex: initialTabIndex,
        initialExerciseName: initialExerciseName,
      ),
    );
  }

  @override
  State<QuickLogModal> createState() => _QuickLogModalState();
}

class _QuickLogModalState extends State<QuickLogModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _liveTickerTimer;

  // Water Form
  double _waterAmount = 0.5; // Liters
  bool _isGlassesMode = true; // Mode switch: Glasses or ml
  int _glassesCount = 2; // Default 2 glasses (500 ml)

  // Meal Form
  final _mealNameController = TextEditingController(text: 'Healthy Meal');
  String _mealCategory = 'Lunch';
  double _calories = 500;
  double _protein = 35;
  double _carbs = 50;
  double _fats = 15;

  // Sleep Form
  double _sleepHours = 8.0;

  // Digital Form
  double _digitalHours = 0.0;
  double _digitalMinutes = 0.0;
  bool _isAutoSyncingDigital = false;

  // Activity Master Switch: 'STEPS', 'CARDIO', 'EXERCISE'
  String _activitySubMode = 'EXERCISE';

  // Activity - Steps Form
  double _stepsCount = 5000;

  // Activity - Cardio Form
  String _cardioType = 'Running';
  String _cardioIntensity = 'Moderate';
  double _cardioDurationMins = 30;
  double _cardioDistanceKm = 5.0;
  double _cardioSpeedMph = 6.0;

  // Activity - Exercise Strength Form
  final _exerciseNameController = TextEditingController(text: 'Bench Press');
  final double _exerciseDurationMins = 45;
  bool _includeStrengthRest = true;
  double _rpe = 8.0;
  String _velocity = 'Controlled';
  final List<ExerciseSet> _exerciseSets = [
    ExerciseSet(setNumber: 1, reps: 10, weightKg: 60.0),
    ExerciseSet(setNumber: 2, reps: 10, weightKg: 60.0),
    ExerciseSet(setNumber: 3, reps: 10, weightKg: 60.0),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialExerciseName != null && widget.initialExerciseName!.isNotEmpty) {
      _exerciseNameController.text = widget.initialExerciseName!;
      _activitySubMode = 'EXERCISE';
    }

    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    );

    // Start 100ms real-time ticking timer for per-second live BMR burn display
    _liveTickerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    // Auto-fetch digital wellbeing screen time and sleep from device & active log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInitialMetricsFromDevice();
    });
  }

  void _checkAndPrefillExercise(String name) {
    if (!mounted) return;
    final provider = context.read<SomaProvider>();
    final lastRecord = provider.getLastExerciseLog(name);
    if (lastRecord != null && lastRecord.sets.isNotEmpty) {
      setState(() {
        _exerciseSets.clear();
        for (final s in lastRecord.sets) {
          _exerciseSets.add(ExerciseSet(
            setNumber: s.setNumber,
            reps: s.reps,
            weightKg: s.weightKg,
          ));
        }
        if (lastRecord.rpe != null) {
          _rpe = lastRecord.rpe!;
        }
        if (lastRecord.velocity != null) {
          _velocity = lastRecord.velocity!;
        }
      });
    }
  }

  Future<void> _syncInitialMetricsFromDevice() async {
    if (!mounted) return;
    final provider = context.read<SomaProvider>();
    final log = provider.currentLog;

    // Prefill exercise if previous session exists
    _checkAndPrefillExercise(_exerciseNameController.text);

    // 1. Populate initial values from today's active log
    setState(() {
      if (log.sleep > 0) {
        _sleepHours = log.sleep;
      }
      _digitalHours = log.digitalHours.toDouble();
      _digitalMinutes = log.digitalMinutes.toDouble();
      _isAutoSyncingDigital = true;
    });

    // 2. Query device's live ScreenTimeService to get the latest screen time
    try {
      final duration = await ScreenTimeService.getTodayTotalScreenTime();
      if (duration > Duration.zero && mounted) {
        setState(() {
          _digitalHours = duration.inHours.toDouble();
          _digitalMinutes = (duration.inMinutes % 60).toDouble();
        });
        await provider.logDigital(duration.inHours, duration.inMinutes % 60);
      }
    } catch (e) {
      debugPrint('QuickLogModal: Could not auto-sync live screen time: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAutoSyncingDigital = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _liveTickerTimer?.cancel();
    _tabController.dispose();
    _mealNameController.dispose();
    _exerciseNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 40, bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: SomaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: SomaColors.cardBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SomaColors.onSecondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOG ACTIVITY & VITAL METRICS',
                  style: SomaFonts.display(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: SomaColors.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    BmrInfoDialog.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.info_outline_rounded, color: SomaColors.primaryContainer, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: SomaColors.primaryContainer,
            labelColor: SomaColors.primaryContainer,
            unselectedLabelColor: SomaColors.onSecondaryContainer,
            labelStyle: SomaFonts.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.water_drop_rounded, size: 18), text: 'WATER'),
              Tab(icon: Icon(Icons.restaurant_rounded, size: 18), text: 'MEAL'),
              Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'BURN'),
              Tab(icon: Icon(Icons.fitness_center_rounded, size: 18), text: 'ACTIVITY'),
              Tab(icon: Icon(Icons.bedtime_rounded, size: 18), text: 'SLEEP'),
              Tab(icon: Icon(Icons.phone_iphone_rounded, size: 18), text: 'DIGITAL'),
            ],
          ),
          const Divider(color: SomaColors.cardBorder, height: 1),
          // Tab Views
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: 480,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWaterTab(),
                    _buildMealTab(),
                    _buildLiveBurnTab(),
                    _buildActivityTab(),
                    _buildSleepTab(),
                    _buildDigitalTab(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Live Calorie Burn Tab ---
  Widget _buildLiveBurnTab() {
    final provider = context.watch<SomaProvider>();
    final goals = provider.userGoals;
    final log = provider.currentLog;

    final activeBurn = log.activeCaloriesBurned;
    final preciseBmrSoFar = CalorieCalculatorService.calculatePreciseBmrBurntSoFar(goals, provider.selectedDate);
    final bmrPerSec = CalorieCalculatorService.calculateBmrPerSecond(goals);
    final bmrDaily = CalorieCalculatorService.calculateBmr(goals);
    final totalBurnPrecise = activeBurn + preciseBmrSoFar;

    final targetTdee = (bmrDaily * 1.3).round(); // Target TDEE estimate

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIVE REAL-TIME CALORIE BURN',
              style: SomaFonts.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SomaColors.onSecondaryContainer,
                letterSpacing: 0.8,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                BmrInfoDialog.show(context);
              },
              child: const Icon(Icons.info_outline_rounded, color: SomaColors.primaryContainer, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live Ticking BMR Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: SomaColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RESTING BMR BURN (BY EXISTING)',
                    style: SomaFonts.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${bmrPerSec.toStringAsFixed(4)} kcal/sec',
                      style: SomaFonts.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    preciseBmrSoFar.toStringAsFixed(3),
                    style: SomaFonts.mono(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'kcal',
                    style: SomaFonts.mono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Total Burn Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SomaColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Burn: ${totalBurnPrecise.toStringAsFixed(1)} kcal',
                    style: SomaFonts.display(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SomaColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active ($activeBurn kcal) + Resting BMR (${preciseBmrSoFar.toStringAsFixed(1)} kcal)',
                    style: SomaFonts.primary(
                      fontSize: 11.5,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.local_fire_department_rounded, color: SomaColors.primaryContainer, size: 28),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Target TDEE Progress
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TDEE Target ($targetTdee kcal)',
              style: SomaFonts.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
            Text(
              '${((totalBurnPrecise / targetTdee) * 100).round()}%',
              style: SomaFonts.mono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: SomaColors.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (totalBurnPrecise / targetTdee).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: SomaColors.surfaceContainerHighest,
            color: SomaColors.primaryContainer,
          ),
        ),

        const Spacer(),
        // Quick Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SomaColors.secondary,
                  side: const BorderSide(color: SomaColors.secondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _activitySubMode = 'CARDIO';
                  });
                  _tabController.animateTo(3); // Switch to Activity Tab
                },
                icon: const Icon(Icons.directions_run, size: 18),
                label: const Text('LOG CARDIO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SomaColors.primaryContainer,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _activitySubMode = 'EXERCISE';
                  });
                  _tabController.animateTo(3); // Switch to Activity Tab
                },
                icon: const Icon(Icons.fitness_center, size: 18),
                label: const Text('LOG WORKOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Water Tab ---
  Widget _buildWaterTab() {
    final int mlValue = (_waterAmount * 1000).round();

    return Column(
      children: [
        Text(
          'RECORD HYDRATION',
          style: SomaFonts.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SomaColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildUnitToggleChip(
              icon: Icons.local_drink_outlined,
              label: 'Glasses',
              isSelected: _isGlassesMode,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isGlassesMode = true;
                  _glassesCount = (_waterAmount / 0.25).round().clamp(1, 20);
                  _waterAmount = _glassesCount * 0.25;
                });
              },
            ),
            const SizedBox(width: 12),
            _buildUnitToggleChip(
              icon: Icons.water_drop_outlined,
              label: 'Milliliters (ml)',
              isSelected: !_isGlassesMode,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isGlassesMode = false;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isGlassesMode) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _glassesCount > 1
                    ? () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _glassesCount--;
                          _waterAmount = _glassesCount * 0.25;
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                  disabledBackgroundColor: SomaColors.cardBackground,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  Text(
                    '$_glassesCount ${_glassesCount == 1 ? 'Glass' : 'Glasses'}',
                    style: SomaFonts.display(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  Text(
                    '($mlValue ml)',
                    style: SomaFonts.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _glassesCount++;
                    _waterAmount = _glassesCount * 0.25;
                  });
                },
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _glassesCount.toDouble().clamp(1.0, 16.0),
            min: 1.0,
            max: 16.0,
            divisions: 15,
            activeColor: Colors.cyanAccent,
            inactiveColor: SomaColors.surfaceContainerHighest,
            onChanged: (val) {
              setState(() {
                _glassesCount = val.round();
                _waterAmount = _glassesCount * 0.25;
              });
            },
          ),
        ] else ...[
          Text(
            '$mlValue ml',
            style: SomaFonts.display(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.cyanAccent,
            ),
          ),
          Text(
            '(~${(_waterAmount / 0.25).toStringAsFixed(1)} ${_waterAmount / 0.25 == 1.0 ? 'glass' : 'glasses'})',
            style: SomaFonts.mono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _waterAmount.clamp(0.1, 2.5),
            min: 0.1,
            max: 2.5,
            divisions: 24,
            activeColor: Colors.cyanAccent,
            inactiveColor: SomaColors.surfaceContainerHighest,
            onChanged: (val) {
              setState(() {
                _waterAmount = val;
                _glassesCount = (val / 0.25).round().clamp(1, 20);
              });
            },
          ),
        ],
        const Spacer(),
        _buildSubmitButton('LOG WATER INTAKE', Colors.cyanAccent, () async {
          final String customSubtitle = _isGlassesMode
              ? '$_glassesCount ${_glassesCount == 1 ? 'glass' : 'glasses'} ($mlValue ml)'
              : '$mlValue ml (~${(_waterAmount / 0.25).toStringAsFixed(1)} glasses)';

          await context.read<SomaProvider>().logWater(
                _waterAmount,
                customSubtitle: customSubtitle,
              );
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Meal Tab ---
  Widget _buildMealTab() {
    return Column(
      children: [
        TextField(
          controller: _mealNameController,
          style: SomaFonts.primary(color: SomaColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Meal Name',
            labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
            filled: true,
            fillColor: SomaColors.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((cat) {
              final isSelected = _mealCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: SomaColors.primaryContainer,
                  backgroundColor: SomaColors.cardBackground,
                  side: BorderSide(
                    color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                  ),
                  labelStyle: SomaFonts.mono(
                    fontSize: 12,
                    color: isSelected ? SomaColors.background : SomaColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _mealCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildValueControl('Calories', '${_calories.toInt()} kcal', _calories, 50, 1500, (v) {
                setState(() => _calories = v);
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildValueControl('Protein', '${_protein.toInt()} g', _protein, 0, 150, (v) {
                setState(() => _protein = v);
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildValueControl('Carbs', '${_carbs.toInt()} g', _carbs, 0, 200, (v) {
                setState(() => _carbs = v);
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildValueControl('Fats', '${_fats.toInt()} g', _fats, 0, 100, (v) {
                setState(() => _fats = v);
              }),
            ),
          ],
        ),
        const Spacer(),
        _buildSubmitButton('SAVE MEAL LOG', SomaColors.primaryContainer, () async {
          await context.read<SomaProvider>().logMeal(
                name: _mealNameController.text.isEmpty ? 'Meal' : _mealNameController.text,
                mealType: _mealCategory,
                calories: _calories.toInt(),
                protein: _protein.toInt(),
                carbs: _carbs.toInt(),
                fats: _fats.toInt(),
              );
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Activity Master Tab (Steps / Cardio / Exercise Strength) ---
  Widget _buildActivityTab() {
    return Column(
      children: [
        // Mode selector chips: STEPS | CARDIO | EXERCISE
        Row(
          children: ['EXERCISE', 'CARDIO', 'STEPS'].map((mode) {
            final isSelected = _activitySubMode == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(mode),
                  selected: isSelected,
                  selectedColor: SomaColors.primaryContainer,
                  backgroundColor: SomaColors.cardBackground,
                  side: BorderSide(
                    color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                  ),
                  labelStyle: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : SomaColors.onSurface,
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _activitySubMode = mode);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _activitySubMode == 'STEPS'
              ? _buildStepsSubMode()
              : _activitySubMode == 'CARDIO'
                  ? _buildCardioSubMode()
                  : _buildExerciseSubMode(),
        ),
      ],
    );
  }

  // --- Steps Sub-Mode ---
  Widget _buildStepsSubMode() {
    final goals = context.read<SomaProvider>().userGoals;
    final userWeight = goals.weightKg ?? 75.0;
    final userBmr = CalorieCalculatorService.calculateBmr(goals).toDouble();
    final calcCalories = CalorieCalculatorService.getStepCalories(
      steps: _stepsCount.toInt(),
      userWeightKg: userWeight,
      userBmr: userBmr,
      userHeightCm: goals.heightCm,
    ).round();

    return Column(
      children: [
        Text(
          '${_stepsCount.toInt()} Steps',
          style: SomaFonts.display(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: SomaColors.secondary,
          ),
        ),
        Text(
          'Estimated Active Burn: $calcCalories kcal',
          style: SomaFonts.mono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: SomaColors.primaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: _stepsCount,
          min: 500,
          max: 25000,
          divisions: 49,
          activeColor: SomaColors.secondary,
          inactiveColor: SomaColors.surfaceContainerHighest,
          onChanged: (val) => setState(() => _stepsCount = val),
        ),
        const Spacer(),
        _buildSubmitButton('LOG STEPS ENTRY', SomaColors.secondary, () async {
          await context.read<SomaProvider>().logSteps(
                steps: _stepsCount.toInt(),
                calories: calcCalories,
              );
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Cardio Sub-Mode ---
  Widget _buildCardioSubMode() {
    final goals = context.read<SomaProvider>().userGoals;
    final userWeight = goals.weightKg ?? 75.0;
    final userBmr = CalorieCalculatorService.calculateBmr(goals).toDouble();

    final isSpeedBased = _cardioType == 'Running' || _cardioType == 'Walking' || _cardioType == 'Cycling';

    double effectiveSpeed = _cardioSpeedMph;
    if (isSpeedBased && _cardioDistanceKm > 0 && _cardioDurationMins > 0) {
      effectiveSpeed = double.parse(((_cardioDistanceKm / (_cardioDurationMins / 60.0)) / 1.60934).toStringAsFixed(1));
    }

    final calcCalories = CalorieCalculatorService.getCardioCalories(
      exercise: _cardioType,
      durationMin: _cardioDurationMins,
      speedMph: isSpeedBased ? effectiveSpeed : null,
      effort: !isSpeedBased ? _cardioIntensity : null,
      userWeightKg: userWeight,
      userBmr: userBmr,
    ).round();

    return Column(
      children: [
        // Cardio Type selector
        DropdownButtonFormField<String>(
          initialValue: _cardioType,
          dropdownColor: SomaColors.cardBackground,
          style: SomaFonts.primary(color: SomaColors.onSurface, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Cardio Type',
            labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
            filled: true,
            fillColor: SomaColors.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: ['Running', 'Cycling', 'Swimming', 'Rowing', 'HIIT', 'Walking', 'Stair Climber', 'Jump Rope'].map((type) {
            return DropdownMenuItem(value: type, child: Text(type));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _cardioType = val);
          },
        ),
        const SizedBox(height: 10),

        if (isSpeedBased) ...[
          // Speed Control Slider
          _buildValueControl(
            'Target Speed (mph)',
            '${effectiveSpeed.toStringAsFixed(1)} mph',
            _cardioSpeedMph,
            1.0,
            20.0,
            (v) => setState(() => _cardioSpeedMph = v),
          ),
        ] else ...[
          // Effort / Intensity selector
          Row(
            children: ['light', 'moderate', 'vigorous', 'max'].map((intense) {
              final isSelected = _cardioIntensity.toLowerCase() == intense;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(intense.toUpperCase(), style: const TextStyle(fontSize: 10)),
                    selected: isSelected,
                    selectedColor: SomaColors.secondary,
                    backgroundColor: SomaColors.cardBackground,
                    labelStyle: SomaFonts.mono(
                      fontSize: 10,
                      color: isSelected ? Colors.black : SomaColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _cardioIntensity = intense);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildValueControl('Duration', '${_cardioDurationMins.toInt()} mins', _cardioDurationMins, 5, 180, (v) {
                setState(() => _cardioDurationMins = v);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildValueControl('Distance (km)', '${_cardioDistanceKm.toStringAsFixed(1)} km', _cardioDistanceKm, 0.0, 42.0, (v) {
                setState(() => _cardioDistanceKm = v);
              }),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: SomaColors.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Estimated Calorie Burn: $calcCalories kcal',
            style: SomaFonts.mono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: SomaColors.primaryContainer,
            ),
          ),
        ),

        const Spacer(),
        _buildSubmitButton('LOG CARDIO WORKOUT', SomaColors.secondary, () async {
          await context.read<SomaProvider>().logCardio(
                cardioType: _cardioType,
                intensity: isSpeedBased ? '${effectiveSpeed.toStringAsFixed(1)} mph' : _cardioIntensity,
                durationMinutes: _cardioDurationMins.toInt(),
                distanceKm: _cardioDistanceKm > 0 ? _cardioDistanceKm : null,
                calories: calcCalories,
              );
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Exercise Strength Sub-Mode (Workout Sets Manager) ---
  Widget _buildExerciseSubMode() {
    final provider = context.watch<SomaProvider>();
    final goals = provider.userGoals;
    final userWeight = goals.weightKg ?? 75.0;
    final userBmr = CalorieCalculatorService.calculateBmr(goals).toDouble();

    final exerciseName = _exerciseNameController.text.isEmpty ? 'Exercise' : _exerciseNameController.text;
    final calcCalories = CalorieCalculatorService.calculateExerciseCalories(
      exerciseName: exerciseName,
      sets: _exerciseSets,
      durationMinutes: _exerciseDurationMins.toInt(),
      weightKg: userWeight,
      userBmr: userBmr,
      includeRest: _includeStrengthRest,
    );

    final lastRecord = provider.getLastExerciseLog(exerciseName);
    final overload = ProgressiveOverloadService.computeOverload(
      exerciseName: exerciseName,
      previousSets: _exerciseSets,
      rpe: _rpe,
      velocity: _velocity,
    );

    final presetLifts = [
      'Bench Press',
      'Squat',
      'Deadlift',
      'Overhead Press',
      'Pull-ups',
      'Bicep Curl',
      'Barbell Row',
      'Lat Pulldown',
      'Leg Press',
      'Lunges',
      'Hip Thrust',
      'Romanian Deadlift',
      'Dumbbell Shoulder Press',
      'Dips',
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _exerciseNameController,
                style: const TextStyle(color: SomaColors.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Exercise / Workout Name',
                  labelStyle: const TextStyle(color: SomaColors.onSecondaryContainer),
                  filled: true,
                  fillColor: SomaColors.cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) {
                  _checkAndPrefillExercise(val);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(
                _includeStrengthRest ? '+Rest (60s)' : 'No Rest',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              selected: _includeStrengthRest,
              selectedColor: SomaColors.primaryContainer,
              onSelected: (val) => setState(() => _includeStrengthRest = val),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Quick Preset Exercise Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presetLifts.map((name) {
              final isSelected = _exerciseNameController.text.toLowerCase() == name.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(name, style: const TextStyle(fontSize: 10)),
                  selected: isSelected,
                  selectedColor: SomaColors.primaryContainer,
                  backgroundColor: SomaColors.cardBackground,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : SomaColors.onSurface,
                  ),
                  onSelected: (_) {
                    _exerciseNameController.text = name;
                    _checkAndPrefillExercise(name);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Automated Progressive Overload Engine Banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SomaColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        'OVERLOAD ENGINE',
                        style: SomaFonts.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.primaryContainer,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (overload.deltaWeightKg != 0 || overload.deltaReps != 0)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _exerciseSets.clear();
                          _exerciseSets.addAll(overload.suggestedSets);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SomaColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'APPLY OVERLOAD',
                          style: SomaFonts.mono(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                overload.title,
                style: SomaFonts.primary(fontSize: 12, fontWeight: FontWeight.bold, color: SomaColors.onSurface),
              ),
              Text(
                overload.explanation,
                style: SomaFonts.primary(fontSize: 10.5, color: SomaColors.onSecondaryContainer),
              ),
              if (lastRecord != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Previous: ${lastRecord.sets.length} sets • ${lastRecord.sets.first.reps}r @ ${lastRecord.sets.first.weightKg}kg (${DateFormat('MMM d').format(lastRecord.date)})',
                  style: SomaFonts.mono(fontSize: 9.5, color: SomaColors.accentCyan),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Self-Reported Exertion (RPE) & Lifting Velocity Selectors
        Row(
          children: [
            // RPE Pills
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EFFORT (RPE)', style: SomaFonts.mono(fontSize: 9, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [6.0, 7.0, 8.0, 8.5, 9.0, 10.0].map((rpeVal) {
                        final isSel = _rpe == rpeVal;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _rpe = rpeVal),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? SomaColors.primaryContainer : SomaColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                rpeVal == 10.0 ? '10 (Max)' : '$rpeVal',
                                style: SomaFonts.mono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.black : SomaColors.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Velocity Pills
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BAR VELOCITY', style: SomaFonts.mono(fontSize: 9, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Explosive', 'Controlled', 'Grind'].map((vel) {
                        final isSel = _velocity == vel;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _velocity = vel),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? SomaColors.primaryContainer : SomaColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                vel,
                                style: SomaFonts.mono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.black : SomaColors.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Sets Manager Table Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('WORKOUT SETS', style: SomaFonts.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer)),
            Text('REPS × WEIGHT (KG)', style: SomaFonts.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer)),
          ],
        ),
        const SizedBox(height: 4),

        // Dynamic Sets List
        Expanded(
          child: ListView.builder(
            itemCount: _exerciseSets.length,
            itemBuilder: (context, index) {
              final setItem = _exerciseSets[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: SomaColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SomaColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SET ${index + 1}',
                        style: SomaFonts.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.primaryContainer,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Reps Stepper
                    _buildCompactStepper(
                      valueText: '${setItem.reps} r',
                      onMinus: setItem.reps > 1
                          ? () => setState(() => setItem.reps--)
                          : null,
                      onPlus: () => setState(() => setItem.reps++),
                    ),

                    const SizedBox(width: 6),

                    // Weight Stepper
                    _buildCompactStepper(
                      valueText: '${setItem.weightKg.toStringAsFixed(1)} kg',
                      onMinus: setItem.weightKg >= 1.25
                          ? () => setState(() => setItem.weightKg -= 1.25)
                          : null,
                      onPlus: () => setState(() => setItem.weightKg += 1.25),
                    ),

                    if (_exerciseSets.length > 1) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _exerciseSets.removeAt(index);
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  final lastWeight = _exerciseSets.isNotEmpty ? _exerciseSets.last.weightKg : 60.0;
                  final lastReps = _exerciseSets.isNotEmpty ? _exerciseSets.last.reps : 10;
                  _exerciseSets.add(ExerciseSet(
                    setNumber: _exerciseSets.length + 1,
                    reps: lastReps,
                    weightKg: lastWeight,
                  ));
                });
              },
              icon: const Icon(Icons.add, size: 16, color: SomaColors.primaryContainer),
              label: Text('ADD SET', style: SomaFonts.mono(fontSize: 11, fontWeight: FontWeight.bold, color: SomaColors.primaryContainer)),
            ),
            Text(
              'Burn: $calcCalories kcal',
              style: SomaFonts.mono(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SomaColors.primaryContainer,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        _buildSubmitButton('LOG WORKOUT ENTRY', SomaColors.primaryContainer, () async {
          await context.read<SomaProvider>().logExercise(
                exerciseName: _exerciseNameController.text.isEmpty ? 'Exercise' : _exerciseNameController.text,
                sets: _exerciseSets,
                durationMinutes: _exerciseDurationMins.toInt(),
                calories: calcCalories,
                rpe: _rpe,
                velocity: _velocity,
              );
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  Widget _buildCompactStepper({
    required String valueText,
    required VoidCallback? onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: SomaColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onMinus,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.remove,
                size: 13,
                color: onMinus != null
                    ? SomaColors.onSurface
                    : SomaColors.onSecondaryContainer.withValues(alpha: 0.3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              valueText,
              style: SomaFonts.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: SomaColors.onSurface,
              ),
            ),
          ),
          InkWell(
            onTap: onPlus,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.add, size: 13, color: SomaColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sleep Tab ---
  Widget _buildSleepTab() {
    return Column(
      children: [
        Text(
          'RECORD SLEEP DURATION',
          style: SomaFonts.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SomaColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${_sleepHours.toStringAsFixed(1)} hrs',
          style: SomaFonts.display(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Colors.purpleAccent,
          ),
        ),
        Slider(
          value: _sleepHours,
          min: 1.0,
          max: 14.0,
          divisions: 26,
          activeColor: Colors.purpleAccent,
          inactiveColor: SomaColors.surfaceContainerHighest,
          onChanged: (v) => setState(() => _sleepHours = v),
        ),
        const Spacer(),
        _buildSubmitButton('RECORD SLEEP', Colors.purpleAccent, () async {
          await context.read<SomaProvider>().logSleep(_sleepHours);
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Digital Tab ---
  Widget _buildDigitalTab() {
    return Column(
      children: [
        Text(
          'UPDATE DIGITAL SCREEN TIME',
          style: SomaFonts.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SomaColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_digitalHours.toInt()}h ${_digitalMinutes.toInt()}m',
          style: SomaFonts.display(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: Colors.amberAccent,
          ),
        ),
        const SizedBox(height: 6),
        if (_isAutoSyncingDigital)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.amberAccent),
                ),
                const SizedBox(width: 8),
                Text(
                  'SYNCING LIVE DEVICE USAGE...',
                  style: SomaFonts.mono(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 6),
                Text(
                  'SYNCED WITH ANDROID USAGE STATS',
                  style: SomaFonts.mono(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amberAccent,
            side: const BorderSide(color: Colors.amberAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            HapticFeedback.selectionClick();
            final duration = await ScreenTimeService.getTodayTotalScreenTime();
            if (duration > Duration.zero) {
              setState(() {
                _digitalHours = duration.inHours.toDouble();
                _digitalMinutes = (duration.inMinutes % 60).toDouble();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Synced screen time from device: ${duration.inHours}h ${duration.inMinutes % 60}m')),
                );
              }
            }
          },
          icon: const Icon(Icons.sync, size: 16),
          label: Text('AUTO-FETCH FROM DEVICE', style: SomaFonts.mono(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        _buildValueControl('Screen Hours', '${_digitalHours.toInt()} hrs', _digitalHours, 0, 18, (v) {
          setState(() => _digitalHours = v);
        }),
        const SizedBox(height: 8),
        _buildValueControl('Screen Minutes', '${_digitalMinutes.toInt()} mins', _digitalMinutes, 0, 59, (v) {
          setState(() => _digitalMinutes = v);
        }),
        const Spacer(),
        _buildSubmitButton('UPDATE SCREEN TIME', Colors.amberAccent, () async {
          await context.read<SomaProvider>().logDigital(_digitalHours.toInt(), _digitalMinutes.toInt());
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Helpers ---
  Widget _buildUnitToggleChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.15) : SomaColors.cardBackground,
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : SomaColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.cyanAccent : SomaColors.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: SomaFonts.mono(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.cyanAccent : SomaColors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueControl(String label, String valueDisplay, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: SomaFonts.mono(color: SomaColors.onSecondaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(valueDisplay, style: SomaFonts.mono(color: SomaColors.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: SomaColors.primaryContainer,
          inactiveColor: SomaColors.surfaceContainerHighest,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        child: Text(
          label,
          style: SomaFonts.mono(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
