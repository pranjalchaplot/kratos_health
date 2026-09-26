import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise_set.dart';
import '../providers/kratos_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../services/screen_time_service.dart';
import '../theme/kratos_theme.dart';
import 'bmr_info_dialog.dart';

class QuickLogModal extends StatefulWidget {
  final int initialTabIndex;

  const QuickLogModal({super.key, this.initialTabIndex = 0});

  static void show(BuildContext context, {int initialTabIndex = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickLogModal(initialTabIndex: initialTabIndex),
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
  double _digitalHours = 4.0;
  double _digitalMinutes = 30.0;

  // Activity Master Switch: 'STEPS', 'CARDIO', 'EXERCISE'
  String _activitySubMode = 'EXERCISE';

  // Activity - Steps Form
  double _stepsCount = 5000;

  // Activity - Cardio Form
  String _cardioType = 'Running';
  String _cardioIntensity = 'Moderate';
  double _cardioDurationMins = 30;
  double _cardioDistanceKm = 5.0;

  // Activity - Exercise Strength Form
  final _exerciseNameController = TextEditingController(text: 'Bench Press');
  final double _exerciseDurationMins = 45;
  final List<ExerciseSet> _exerciseSets = [
    ExerciseSet(setNumber: 1, reps: 10, weightKg: 60.0),
    ExerciseSet(setNumber: 2, reps: 10, weightKg: 60.0),
    ExerciseSet(setNumber: 3, reps: 10, weightKg: 60.0),
  ];

  @override
  void initState() {
    super.initState();
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
        color: KratosColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: KratosColors.surfaceContainerHighest, width: 1),
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
              color: KratosColors.onSecondaryContainer.withValues(alpha: 0.4),
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
                const Text(
                  'LOG ACTIVITY & VITAL METRICS',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.36,
                    color: KratosColors.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: KratosColors.primaryContainer),
                  onPressed: () => BmrInfoDialog.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: KratosColors.primaryContainer,
            labelColor: KratosColors.primaryContainer,
            unselectedLabelColor: KratosColors.onSecondaryContainer,
            labelStyle: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.water_drop_outlined, size: 18), text: 'WATER'),
              Tab(icon: Icon(Icons.restaurant_outlined, size: 18), text: 'MEAL'),
              Tab(icon: Icon(Icons.local_fire_department, size: 18), text: 'BURN'),
              Tab(icon: Icon(Icons.fitness_center_outlined, size: 18), text: 'ACTIVITY'),
              Tab(icon: Icon(Icons.bed_outlined, size: 18), text: 'SLEEP'),
              Tab(icon: Icon(Icons.phone_iphone_outlined, size: 18), text: 'DIGITAL'),
            ],
          ),
          const Divider(color: KratosColors.surfaceContainerHighest, height: 1),
          // Tab Views
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
    final provider = context.watch<KratosProvider>();
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
            const Text(
              'LIVE REAL-TIME CALORIE BURN',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KratosColors.onSecondaryContainer,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: KratosColors.primaryContainer, size: 18),
              onPressed: () => BmrInfoDialog.show(context),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live Ticking BMR Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RESTING BMR BURN (BY EXISTING)',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
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
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
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
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'kcal',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
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
            gradient: LinearGradient(
              colors: [
                KratosColors.primaryContainer.withValues(alpha: 0.2),
                KratosColors.cardBackground,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KratosColors.primaryContainer.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Burn: ${totalBurnPrecise.toStringAsFixed(1)} kcal',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: KratosColors.primaryContainer,
                    ),
                  ),
                  Text(
                    'Active ($activeBurn kcal) + Resting BMR (${preciseBmrSoFar.toStringAsFixed(1)} kcal)',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      color: KratosColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.local_fire_department, color: KratosColors.primaryContainer, size: 28),
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
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: KratosColors.onSecondaryContainer,
              ),
            ),
            Text(
              '${((totalBurnPrecise / targetTdee) * 100).round()}%',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: KratosColors.primaryContainer,
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
            backgroundColor: KratosColors.surfaceContainerHighest,
            color: KratosColors.primaryContainer,
          ),
        ),

        const Spacer(),
        // Quick Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: KratosColors.secondary,
                  side: const BorderSide(color: KratosColors.secondary),
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
                  backgroundColor: KratosColors.primaryContainer,
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
        const Text(
          'RECORD HYDRATION',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KratosColors.onSecondaryContainer,
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
                  disabledBackgroundColor: KratosColors.cardBackground,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  Text(
                    '$_glassesCount ${_glassesCount == 1 ? 'Glass' : 'Glasses'}',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  Text(
                    '($mlValue ml)',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KratosColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                onPressed: () {
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
            inactiveColor: KratosColors.surfaceContainerHighest,
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
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.cyanAccent,
            ),
          ),
          Text(
            '(~${(_waterAmount / 0.25).toStringAsFixed(1)} ${_waterAmount / 0.25 == 1.0 ? 'glass' : 'glasses'})',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: KratosColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _waterAmount.clamp(0.1, 2.5),
            min: 0.1,
            max: 2.5,
            divisions: 24,
            activeColor: Colors.cyanAccent,
            inactiveColor: KratosColors.surfaceContainerHighest,
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

          await context.read<KratosProvider>().logWater(
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
          style: const TextStyle(color: KratosColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Meal Name',
            labelStyle: const TextStyle(color: KratosColors.onSecondaryContainer),
            filled: true,
            fillColor: KratosColors.cardBackground,
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
                  selectedColor: KratosColors.primaryContainer,
                  backgroundColor: KratosColors.cardBackground,
                  side: BorderSide(
                    color: isSelected ? KratosColors.primaryContainer : KratosColors.cardBorder,
                  ),
                  labelStyle: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: isSelected ? KratosColors.background : KratosColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _mealCategory = cat),
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
        _buildSubmitButton('SAVE MEAL LOG', KratosColors.primaryContainer, () async {
          await context.read<KratosProvider>().logMeal(
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
                  selectedColor: KratosColors.primaryContainer,
                  backgroundColor: KratosColors.cardBackground,
                  side: BorderSide(
                    color: isSelected ? KratosColors.primaryContainer : KratosColors.cardBorder,
                  ),
                  labelStyle: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : KratosColors.onSurface,
                  ),
                  onSelected: (_) => setState(() => _activitySubMode = mode),
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
    final userWeight = context.read<KratosProvider>().userGoals.weightKg ?? 75.0;
    final calcCalories = CalorieCalculatorService.calculateStepsCalories(_stepsCount.toInt(), userWeight);

    return Column(
      children: [
        Text(
          '${_stepsCount.toInt()} Steps',
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: KratosColors.secondary,
          ),
        ),
        Text(
          'Estimated Active Burn: $calcCalories kcal',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: KratosColors.primaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: _stepsCount,
          min: 500,
          max: 25000,
          divisions: 49,
          activeColor: KratosColors.secondary,
          inactiveColor: KratosColors.surfaceContainerHighest,
          onChanged: (val) => setState(() => _stepsCount = val),
        ),
        const Spacer(),
        _buildSubmitButton('LOG STEPS ENTRY', KratosColors.secondary, () async {
          await context.read<KratosProvider>().logSteps(
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
    final userWeight = context.read<KratosProvider>().userGoals.weightKg ?? 75.0;
    final calcCalories = CalorieCalculatorService.calculateCardioCalories(
      cardioType: _cardioType,
      intensity: _cardioIntensity,
      durationMinutes: _cardioDurationMins.toInt(),
      weightKg: userWeight,
    );

    return Column(
      children: [
        // Cardio Type selector
        DropdownButtonFormField<String>(
          initialValue: _cardioType,
          dropdownColor: KratosColors.cardBackground,
          style: const TextStyle(color: KratosColors.onSurface, fontFamily: 'Geist', fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Cardio Type',
            labelStyle: const TextStyle(color: KratosColors.onSecondaryContainer),
            filled: true,
            fillColor: KratosColors.cardBackground,
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

        // Intensity selector
        Row(
          children: ['Low', 'Moderate', 'High', 'Extreme'].map((intense) {
            final isSelected = _cardioIntensity == intense;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(intense, style: const TextStyle(fontSize: 10)),
                  selected: isSelected,
                  selectedColor: KratosColors.secondary,
                  backgroundColor: KratosColors.cardBackground,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : KratosColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _cardioIntensity = intense),
                ),
              ),
            );
          }).toList(),
        ),
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
            color: KratosColors.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Estimated Calorie Burn: $calcCalories kcal',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: KratosColors.primaryContainer,
            ),
          ),
        ),

        const Spacer(),
        _buildSubmitButton('LOG CARDIO WORKOUT', KratosColors.secondary, () async {
          await context.read<KratosProvider>().logCardio(
                cardioType: _cardioType,
                intensity: _cardioIntensity,
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
    final userWeight = context.read<KratosProvider>().userGoals.weightKg ?? 75.0;
    final calcCalories = CalorieCalculatorService.calculateExerciseCalories(
      exerciseName: _exerciseNameController.text.isEmpty ? 'Exercise' : _exerciseNameController.text,
      sets: _exerciseSets,
      durationMinutes: _exerciseDurationMins.toInt(),
      weightKg: userWeight,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _exerciseNameController,
                style: const TextStyle(color: KratosColors.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Exercise / Workout Name',
                  labelStyle: const TextStyle(color: KratosColors.onSecondaryContainer),
                  filled: true,
                  fillColor: KratosColors.cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: KratosColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KratosColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Text('DUR (m)', style: TextStyle(fontSize: 10, color: KratosColors.onSecondaryContainer, fontWeight: FontWeight.bold)),
                  Text('${_exerciseDurationMins.toInt()}m', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: KratosColors.primaryContainer)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Quick Preset Exercise Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Bench Press', 'Squat', 'Deadlift', 'Overhead Press', 'Pull-ups', 'Bicep Curl'].map((name) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(name, style: const TextStyle(fontSize: 10)),
                  selected: _exerciseNameController.text == name,
                  selectedColor: KratosColors.primaryContainer,
                  backgroundColor: KratosColors.cardBackground,
                  labelStyle: TextStyle(
                    color: _exerciseNameController.text == name ? Colors.black : KratosColors.onSurface,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _exerciseNameController.text = name;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),
        // Sets Manager Table Header
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('WORKOUT SETS', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, fontWeight: FontWeight.bold, color: KratosColors.onSecondaryContainer)),
            Text('REPS × WEIGHT (KG)', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, fontWeight: FontWeight.bold, color: KratosColors.onSecondaryContainer)),
          ],
        ),
        const SizedBox(height: 6),

        // Dynamic Sets List
        Expanded(
          child: ListView.builder(
            itemCount: _exerciseSets.length,
            itemBuilder: (context, index) {
              final setItem = _exerciseSets[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KratosColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KratosColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      'SET ${index + 1}',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: KratosColors.primaryContainer,
                      ),
                    ),
                    const Spacer(),

                    // Reps Stepper
                    Text('${setItem.reps} r', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: KratosColors.onSecondaryContainer),
                      onPressed: setItem.reps > 1
                          ? () {
                              setState(() => setItem.reps--);
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: KratosColors.primaryContainer),
                      onPressed: () {
                        setState(() => setItem.reps++);
                      },
                    ),

                    const SizedBox(width: 8),
                    // Weight Stepper
                    Text('${setItem.weightKg.toInt()} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: KratosColors.onSecondaryContainer),
                      onPressed: setItem.weightKg >= 2.5
                          ? () {
                              setState(() => setItem.weightKg -= 2.5);
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: KratosColors.primaryContainer),
                      onPressed: () {
                        setState(() => setItem.weightKg += 2.5);
                      },
                    ),

                    if (_exerciseSets.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _exerciseSets.removeAt(index);
                          });
                        },
                      ),
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
              icon: const Icon(Icons.add, size: 16, color: KratosColors.primaryContainer),
              label: const Text('ADD SET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: KratosColors.primaryContainer)),
            ),
            Text(
              'Burn: $calcCalories kcal',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: KratosColors.primaryContainer,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        _buildSubmitButton('LOG WORKOUT ENTRY', KratosColors.primaryContainer, () async {
          await context.read<KratosProvider>().logExercise(
                exerciseName: _exerciseNameController.text.isEmpty ? 'Exercise' : _exerciseNameController.text,
                sets: _exerciseSets,
                durationMinutes: _exerciseDurationMins.toInt(),
                calories: calcCalories,
              );
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Sleep Tab ---
  Widget _buildSleepTab() {
    return Column(
      children: [
        const Text(
          'RECORD SLEEP DURATION',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KratosColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${_sleepHours.toStringAsFixed(1)} hrs',
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 44,
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
          inactiveColor: KratosColors.surfaceContainerHighest,
          onChanged: (v) => setState(() => _sleepHours = v),
        ),
        const Spacer(),
        _buildSubmitButton('RECORD SLEEP', Colors.purpleAccent, () async {
          await context.read<KratosProvider>().logSleep(_sleepHours);
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Digital Tab ---
  Widget _buildDigitalTab() {
    return Column(
      children: [
        const Text(
          'UPDATE DIGITAL SCREEN TIME',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KratosColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_digitalHours.toInt()}h ${_digitalMinutes.toInt()}m',
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.amberAccent,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amberAccent,
            side: const BorderSide(color: Colors.amberAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
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
          label: const Text('AUTO-FETCH FROM DEVICE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          await context.read<KratosProvider>().logDigital(_digitalHours.toInt(), _digitalMinutes.toInt());
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
          color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.15) : KratosColors.cardBackground,
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : KratosColors.cardBorder,
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
              color: isSelected ? Colors.cyanAccent : KratosColors.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.cyanAccent : KratosColors.onSecondaryContainer,
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
            Text(label, style: const TextStyle(color: KratosColors.onSecondaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(valueDisplay, style: const TextStyle(color: KratosColors.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: KratosColors.primaryContainer,
          inactiveColor: KratosColors.surfaceContainerHighest,
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
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
