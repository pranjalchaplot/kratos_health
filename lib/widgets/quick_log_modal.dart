import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/soma_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../services/screen_time_service.dart';
import '../theme/soma_theme.dart';
import 'bmr_info_dialog.dart';

class QuickLogTab {
  static const int water = 0;
  static const int meal = 1;
  static const int burn = 2;
  static const int sleep = 3;
  static const int digital = 4;
  // Redirect alias for activity -> switches to dedicated Activities tab
  static const int activity = 999;
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
    if (initialTabIndex == QuickLogTab.activity) {
      context.read<SomaProvider>().setTab(1);
      return;
    }
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
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

  Future<void> _syncInitialMetricsFromDevice() async {
    if (!mounted) return;
    final provider = context.read<SomaProvider>();
    final log = provider.currentLog;

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
                  'LOG NUTRITION & VITAL METRICS',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: SomaColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE SYNC',
                    style: SomaFonts.mono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: SomaColors.primaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Live Burn Counter Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SomaColors.primaryContainer.withValues(alpha: 0.12),
                SomaColors.surfaceContainerHigh.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL ENERGY EXPENDITURE (BURN)',
                style: SomaFonts.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: SomaColors.onSecondaryContainer,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    totalBurnPrecise.toStringAsFixed(1),
                    style: SomaFonts.display(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: SomaColors.primaryContainer,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'kcal burned today',
                    style: SomaFonts.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SomaColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '+${bmrPerSec.toStringAsFixed(4)} kcal burnt per second automatically via resting metabolism',
                style: SomaFonts.mono(
                  fontSize: 10,
                  color: SomaColors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        // Breakdown Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: SomaColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SomaColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active vs. Basal Burn',
                    style: SomaFonts.display(
                      fontSize: 14,
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
        // Quick Action Buttons -> Navigate directly to dedicated Activities tab
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
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  context.read<SomaProvider>().setTab(1); // Switch to Activities Tab
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
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  context.read<SomaProvider>().setTab(1); // Switch to Activities Tab
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
                    '$_glassesCount',
                    style: SomaFonts.display(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  Text(
                    '${_glassesCount == 1 ? "Glass" : "Glasses"} ($mlValue ml)',
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(
              _glassesCount.clamp(1, 16),
              (index) => const Icon(Icons.local_drink_rounded, color: Colors.cyanAccent, size: 20),
            ),
          ),
        ] else ...[
          Text(
            '$mlValue ml',
            style: SomaFonts.display(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.cyanAccent,
            ),
          ),
          Text(
            '${_waterAmount.toStringAsFixed(2)} Liters',
            style: SomaFonts.mono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _waterAmount,
            min: 0.1,
            max: 5.0,
            divisions: 49,
            activeColor: Colors.cyanAccent,
            inactiveColor: SomaColors.surfaceContainerHighest,
            onChanged: (val) {
              setState(() {
                _waterAmount = double.parse(val.toStringAsFixed(2));
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ActionChip(
                label: const Text('+250 ml'),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _waterAmount = (_waterAmount + 0.25).clamp(0.1, 8.0);
                  });
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('+500 ml'),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _waterAmount = (_waterAmount + 0.5).clamp(0.1, 8.0);
                  });
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('+1000 ml'),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _waterAmount = (_waterAmount + 1.0).clamp(0.1, 8.0);
                  });
                },
              ),
            ],
          ),
        ],
        const Spacer(),
        _buildSubmitButton('LOG WATER ENTRY', Colors.cyanAccent, () async {
          await context.read<SomaProvider>().logWater(_waterAmount);
          if (mounted) Navigator.pop(context);
        }),
      ],
    );
  }

  // --- Meal Tab ---
  Widget _buildMealTab() {
    return Column(
      children: [
        // Name & Type
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _mealNameController,
                style: SomaFonts.primary(color: SomaColors.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Meal Name',
                  labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
                  filled: true,
                  fillColor: SomaColors.cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _mealCategory,
                dropdownColor: SomaColors.cardBackground,
                style: SomaFonts.primary(color: SomaColors.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Type',
                  labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
                  filled: true,
                  fillColor: SomaColors.cardBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Pre-Workout', 'Post-Workout'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _mealCategory = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Total Calories Slider
        _buildValueControl('Calories', '${_calories.toInt()} kcal', _calories, 50, 2000, (v) {
          setState(() => _calories = v);
        }),
        const SizedBox(height: 4),

        // Macros Breakdown Sliders
        _buildValueControl('Protein', '${_protein.toInt()}g', _protein, 0, 150, (v) {
          setState(() => _protein = v);
        }),
        _buildValueControl('Carbs', '${_carbs.toInt()}g', _carbs, 0, 250, (v) {
          setState(() => _carbs = v);
        }),
        _buildValueControl('Fats', '${_fats.toInt()}g', _fats, 0, 100, (v) {
          setState(() => _fats = v);
        }),

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
