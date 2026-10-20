import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/soma_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../services/screen_time_service.dart';
import '../theme/soma_theme.dart';
import 'bmr_info_dialog.dart';
import '../models/nutrition_models.dart';
import '../services/nutrition/speech_recognition_service.dart';
import '../services/nutrition/nutrition_database_service.dart';
import 'recipe_customizer_sheet.dart';
import '../services/nutrition/meal_verdict_engine.dart';

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
  final _naturalMealController = TextEditingController();
  final _speechService = SpeechRecognitionService.instance;
  String _mealCategory = 'Lunch';
  double _calories = 500;
  double _protein = 35;
  double _carbs = 50;
  double _fats = 15;
  bool _isListening = false;
  double _soundLevel = 0.0;
  MealParseResult? _parsedResult;
  bool _isParsing = false;
  bool _showManualSliders = false;

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
    _naturalMealController.dispose();
    _speechService.cancelListening();
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
                height: 540,
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

  // --- Smart Meal Logging Methods ---

  Future<void> _toggleSpeechListening() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
      if (_naturalMealController.text.trim().isNotEmpty) {
        await _executeMealParse(_naturalMealController.text.trim());
      }
    } else {
      setState(() {
        _isListening = true;
        _soundLevel = 0.0;
      });

      final available = await _speechService.startListening(
        onResult: (words, isFinal) {
          if (mounted) {
            setState(() {
              _naturalMealController.text = words;
            });
            if (isFinal) {
              _speechService.stopListening();
              setState(() => _isListening = false);
              _executeMealParse(words);
            }
          }
        },
        onSoundLevel: (level) {
          if (mounted) {
            setState(() => _soundLevel = level);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
            );
          }
        },
      );

      if (!available && mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied or speech recognition unavailable on device.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  Future<void> _executeMealParse(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isParsing = true);
    HapticFeedback.selectionClick();

    try {
      final provider = context.read<SomaProvider>();
      final result = await provider.parseMealQuery(trimmed);

      if (mounted) {
        setState(() {
          _parsedResult = result;
          _isParsing = false;
          _calories = result.totalMacros.calories;
          _protein = result.totalMacros.proteinG;
          _carbs = result.totalMacros.carbsG;
          _fats = result.totalMacros.fatG;
          if (_mealNameController.text == 'Healthy Meal' && result.items.isNotEmpty) {
            _mealNameController.text = result.items.map((i) => i.resolvedEntity?.name ?? i.rawInput).join(', ');
          }
        });
      }
    } catch (e) {
      debugPrint('Error parsing meal query: $e');
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  Future<void> _updateItemQuantity(int index, double delta) async {
    if (_parsedResult == null || index >= _parsedResult!.items.length) return;
    HapticFeedback.lightImpact();

    final provider = context.read<SomaProvider>();
    final currentItem = _parsedResult!.items[index];
    final newQty = (currentItem.quantity + delta).clamp(0.25, 50.0);

    final updatedItem = await provider.recalculateParsedItem(currentItem, newQuantity: newQty);

    setState(() {
      _parsedResult!.items[index] = updatedItem;
      // Recalculate total macros
      final newTotal = _parsedResult!.items.fold<MacroNutrients>(
        MacroNutrients.zero,
        (sum, item) => sum + item.macros,
      );
      _parsedResult = MealParseResult(
        query: _parsedResult!.query,
        status: _parsedResult!.status,
        items: _parsedResult!.items,
        totalMacros: newTotal,
        unresolvedTokens: _parsedResult!.unresolvedTokens,
      );
      _calories = newTotal.calories;
      _protein = newTotal.proteinG;
      _carbs = newTotal.carbsG;
      _fats = newTotal.fatG;
    });
  }

  Future<void> _switchItemAlternate(int index, AlternateEntity alt) async {
    if (_parsedResult == null || index >= _parsedResult!.items.length) return;
    HapticFeedback.selectionClick();

    final provider = context.read<SomaProvider>();
    final currentItem = _parsedResult!.items[index];

    final newEntity = await NutritionDatabaseService.instance.getEntity(alt.entityType, alt.entityId);
    if (newEntity == null) return;

    final updatedItem = await provider.recalculateParsedItem(currentItem, newEntity: newEntity);

    setState(() {
      _parsedResult!.items[index] = updatedItem;
      final newTotal = _parsedResult!.items.fold<MacroNutrients>(
        MacroNutrients.zero,
        (sum, item) => sum + item.macros,
      );
      _parsedResult = MealParseResult(
        query: _parsedResult!.query,
        status: _parsedResult!.status,
        items: _parsedResult!.items,
        totalMacros: newTotal,
        unresolvedTokens: _parsedResult!.unresolvedTokens,
      );
      _calories = newTotal.calories;
      _protein = newTotal.proteinG;
      _carbs = newTotal.carbsG;
      _fats = newTotal.fatG;
    });
  }

  void _removeParsedItem(int index) {
    if (_parsedResult == null || index >= _parsedResult!.items.length) return;
    HapticFeedback.lightImpact();

    setState(() {
      _parsedResult!.items.removeAt(index);
      final newTotal = _parsedResult!.items.fold<MacroNutrients>(
        MacroNutrients.zero,
        (sum, item) => sum + item.macros,
      );
      _parsedResult = MealParseResult(
        query: _parsedResult!.query,
        status: _parsedResult!.items.isEmpty ? ParseStatus.unresolved : _parsedResult!.status,
        items: _parsedResult!.items,
        totalMacros: newTotal,
        unresolvedTokens: _parsedResult!.unresolvedTokens,
      );
      _calories = newTotal.calories;
      _protein = newTotal.proteinG;
      _carbs = newTotal.carbsG;
      _fats = newTotal.fatG;
    });
  }

  // --- Meal Tab ---
  Widget _buildMealTab() {
    final hasParsedItems = _parsedResult != null && _parsedResult!.items.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Selector & Manual Sliders Toggle
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _mealCategory,
                  dropdownColor: SomaColors.cardBackground,
                  style: SomaFonts.primary(color: SomaColors.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Meal Type',
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showManualSliders = !_showManualSliders);
                },
                icon: Icon(
                  _showManualSliders ? Icons.tune : Icons.tune_outlined,
                  size: 16,
                  color: _showManualSliders ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                ),
                label: Text(
                  _showManualSliders ? 'Sliders' : 'Manual',
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _showManualSliders ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  side: BorderSide(
                    color: _showManualSliders ? SomaColors.primaryContainer : SomaColors.cardBorder,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- Natural Language & Voice Input Bar ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isListening
                    ? Colors.cyanAccent
                    : (_isParsing ? SomaColors.primaryContainer : SomaColors.cardBorder),
                width: _isListening ? 1.5 : 1,
              ),
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Glowing Microphone Button
                GestureDetector(
                  onTap: _toggleSpeechListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.diagonal3Values(
                      _isListening ? (1.0 + (_soundLevel.clamp(0.0, 10.0) / 50.0)) : 1.0,
                      _isListening ? (1.0 + (_soundLevel.clamp(0.0, 10.0) / 50.0)) : 1.0,
                      1.0,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.cyanAccent.withValues(alpha: 0.2)
                          : SomaColors.surfaceContainerHigh.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening ? Colors.cyanAccent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _isListening ? Colors.cyanAccent : SomaColors.primaryContainer,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text Input Field
                Expanded(
                  child: TextField(
                    controller: _naturalMealController,
                    style: SomaFonts.primary(color: SomaColors.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening to speech...'
                          : 'Talk or type: e.g. "2 bowls poha and 1 glass milk"',
                      hintStyle: SomaFonts.primary(
                        color: _isListening ? Colors.cyanAccent : SomaColors.onSecondaryContainer.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (val) => _executeMealParse(val),
                  ),
                ),

                // Clear or Parse Action Button
                if (_naturalMealController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: SomaColors.onSecondaryContainer),
                    onPressed: () {
                      _naturalMealController.clear();
                      setState(() {
                        _parsedResult = null;
                      });
                    },
                  ),

                IconButton(
                  icon: _isParsing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: SomaColors.primaryContainer),
                        )
                      : const Icon(Icons.auto_awesome, color: SomaColors.primaryContainer, size: 20),
                  onPressed: () => _executeMealParse(_naturalMealController.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Quick Example Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickExampleChip('2 bowls poha and 1 glass milk'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('2 samosas and 1 cup chai'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('1 plate pav bhaji'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('2 rotis with 1 bowl dal tadka'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('1 plate chole bhature'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('1 kachori and 1 jalebi'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('3 boiled eggs + 1 banana'),
                const SizedBox(width: 6),
                _buildQuickExampleChip('1 plate paneer bhurji & 2 rotis'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Listening Status Banner
          if (_isListening)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recording voice... Tap mic to stop and calculate.',
                      style: SomaFonts.mono(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // --- Smart Detected Food Suggestion List ---
          if (hasParsedItems) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DETECTED FOOD ITEMS (${_parsedResult!.items.length})',
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SomaColors.primaryContainer,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Tap +/- to scale',
                  style: SomaFonts.mono(fontSize: 9.5, color: SomaColors.onSecondaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Item Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _parsedResult!.items.length,
              itemBuilder: (context, idx) {
                final item = _parsedResult!.items[idx];
                final isExact = item.confidenceScore >= 0.95;
                final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: SomaColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SomaColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: SomaColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.resolvedEntity?.entityType == EntityType.recipe
                                  ? Icons.soup_kitchen_rounded
                                  : Icons.egg_alt_rounded,
                              size: 16,
                              color: SomaColors.primaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.resolvedEntity?.name ?? item.rawInput,
                                        style: SomaFonts.display(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: SomaColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (item.isCustom)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                                        ),
                                        child: Text(
                                          'CUSTOM',
                                          style: SomaFonts.mono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isExact
                                            ? Colors.greenAccent.withValues(alpha: 0.15)
                                            : Colors.cyanAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isExact ? '100% Match' : '${(item.confidenceScore * 100).toInt()}% Match',
                                        style: SomaFonts.mono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isExact ? Colors.greenAccent : Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Builder(
                                  builder: (context) {
                                    final itemVerdict = MealVerdict.evaluate(
                                      calories: item.macros.calories,
                                      protein: item.macros.proteinG,
                                      carbs: item.macros.carbsG,
                                      fats: item.macros.fatG,
                                    );
                                    return Row(
                                      children: [
                                        Text(
                                          '${item.calculatedGrams.round()}g edible • ${item.unit}',
                                          style: SomaFonts.mono(fontSize: 10, color: SomaColors.onSecondaryContainer),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: itemVerdict.color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: itemVerdict.color.withValues(alpha: 0.4), width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(itemVerdict.icon, size: 9, color: itemVerdict.color),
                                              const SizedBox(width: 3),
                                              Text(
                                                itemVerdict.label,
                                                style: SomaFonts.mono(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: itemVerdict.color,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: SomaColors.onSecondaryContainer),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeParsedItem(idx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Stepper, Recipe Customizer & Alternates Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Quantity Stepper
                          Container(
                            decoration: BoxDecoration(
                              color: SomaColors.surfaceContainerHigh.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _updateItemQuantity(idx, -0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Icon(Icons.remove, size: 14, color: SomaColors.onSurface),
                                  ),
                                ),
                                Text(
                                  '$qtyStr ${item.unit}',
                                  style: SomaFonts.mono(fontSize: 11, fontWeight: FontWeight.bold, color: SomaColors.onSurface),
                                ),
                                InkWell(
                                  onTap: () => _updateItemQuantity(idx, 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Icon(Icons.add, size: 14, color: SomaColors.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Customize Recipe Ingredients Button
                          if (item.resolvedEntity?.entityType == EntityType.recipe)
                            InkWell(
                              onTap: () {
                                RecipeCustomizerSheet.show(
                                  context,
                                  item: item,
                                  onMealItemUpdated: (updatedItem) {
                                    setState(() {
                                      _parsedResult!.items[idx] = updatedItem;
                                      final newTotal = _parsedResult!.items.fold<MacroNutrients>(
                                        MacroNutrients.zero,
                                        (sum, i) => sum + i.macros,
                                      );
                                      _parsedResult = MealParseResult(
                                        query: _parsedResult!.query,
                                        status: _parsedResult!.status,
                                        items: _parsedResult!.items,
                                        totalMacros: newTotal,
                                        unresolvedTokens: _parsedResult!.unresolvedTokens,
                                      );
                                      _calories = newTotal.calories;
                                      _protein = newTotal.proteinG;
                                      _carbs = newTotal.carbsG;
                                      _fats = newTotal.fatG;
                                    });
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item.isCustom
                                      ? Colors.amber.withValues(alpha: 0.15)
                                      : SomaColors.primaryContainer.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: item.isCustom
                                        ? Colors.amber.withValues(alpha: 0.4)
                                        : SomaColors.primaryContainer.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 12,
                                      color: item.isCustom ? Colors.amber : SomaColors.primaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.isCustom ? 'Custom' : 'Recipe',
                                      style: SomaFonts.mono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.isCustom ? Colors.amber : SomaColors.primaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Alternates Picker (if available)
                          if (item.alternates.isNotEmpty)
                            PopupMenuButton<AlternateEntity>(
                              tooltip: 'Switch Dish',
                              color: SomaColors.cardBackground,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              onSelected: (alt) => _switchItemAlternate(idx, alt),
                              itemBuilder: (context) {
                                return item.alternates.map((alt) {
                                  return PopupMenuItem<AlternateEntity>(
                                    value: alt,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            alt.name,
                                            style: SomaFonts.primary(fontSize: 11, color: SomaColors.onSurface),
                                          ),
                                        ),
                                        if (alt.isCustom)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'CUSTOM',
                                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: SomaColors.primaryContainer.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.swap_horiz, size: 12, color: SomaColors.primaryContainer),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Switch',
                                      style: SomaFonts.mono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: SomaColors.primaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Nutrient Pill Tags
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMacroPill('${item.macros.calories.round()} kcal', SomaColors.primaryContainer),
                          _buildMacroPill('${item.macros.proteinG.round()}g P', Colors.cyanAccent),
                          _buildMacroPill('${item.macros.carbsG.round()}g C', Colors.amberAccent),
                          _buildMacroPill('${item.macros.fatG.round()}g F', Colors.orangeAccent),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Live Aggregated Macros Banner with Smart Verdict
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SomaColors.primaryContainer.withValues(alpha: 0.15),
                    SomaColors.cardBackground,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryMacroCol('TOTAL CALORIES', '${_calories.toInt()}', 'kcal', SomaColors.primaryContainer),
                      _buildSummaryMacroCol('PROTEIN', '${_protein.toInt()}', 'g', Colors.cyanAccent),
                      _buildSummaryMacroCol('CARBS', '${_carbs.toInt()}', 'g', Colors.amberAccent),
                      _buildSummaryMacroCol('FATS', '${_fats.toInt()}', 'g', Colors.orangeAccent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final verdict = MealVerdict.evaluate(
                        calories: _calories,
                        protein: _protein,
                        carbs: _carbs,
                        fats: _fats,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: verdict.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: verdict.color.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(verdict.icon, size: 14, color: verdict.color),
                            const SizedBox(width: 6),
                            Text(
                              verdict.label,
                              style: SomaFonts.mono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: verdict.color,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                verdict.description,
                                style: SomaFonts.primary(
                                  fontSize: 10,
                                  color: SomaColors.onSecondaryContainer,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else if (!_isParsing) ...[
            // Friendly Empty Placeholder
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: SomaColors.cardBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SomaColors.cardBorder, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.record_voice_over_rounded, size: 32, color: SomaColors.primaryContainer),
                  const SizedBox(height: 8),
                  Text(
                    'Speak or type your meal above',
                    style: SomaFonts.display(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: SomaColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Auto-detects Indian staples, cooked recipes, quantities & macros offline.',
                    textAlign: TextAlign.center,
                    style: SomaFonts.primary(fontSize: 11, color: SomaColors.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ],

          // Unresolved tokens warning (if any)
          if (_parsedResult != null && _parsedResult!.unresolvedTokens.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Unmatched: ${_parsedResult!.unresolvedTokens.join(", ")}',
                      style: SomaFonts.mono(fontSize: 10, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),

          // Optional Manual Sliders (Toggled via "Manual" button)
          if (_showManualSliders) ...[
            const Divider(color: SomaColors.cardBorder, height: 20),
            Text(
              'MANUAL MACRO ADJUSTMENTS',
              style: SomaFonts.mono(fontSize: 10, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer),
            ),
            const SizedBox(height: 8),
            _buildValueControl('Calories', '${_calories.toInt()} kcal', _calories, 50, 2500, (v) {
              setState(() => _calories = v);
            }),
            _buildValueControl('Protein', '${_protein.toInt()}g', _protein, 0, 200, (v) {
              setState(() => _protein = v);
            }),
            _buildValueControl('Carbs', '${_carbs.toInt()}g', _carbs, 0, 300, (v) {
              setState(() => _carbs = v);
            }),
            _buildValueControl('Fats', '${_fats.toInt()}g', _fats, 0, 150, (v) {
              setState(() => _fats = v);
            }),
          ],

          const SizedBox(height: 16),

          // Submit Button
          _buildSubmitButton('SAVE MEAL LOG', SomaColors.primaryContainer, () async {
            if (hasParsedItems) {
              await context.read<SomaProvider>().logSmartMeal(
                    parseResult: _parsedResult!,
                    mealType: _mealCategory,
                  );
            } else {
              await context.read<SomaProvider>().logMeal(
                    name: _mealNameController.text.isEmpty ? 'Meal' : _mealNameController.text,
                    mealType: _mealCategory,
                    calories: _calories.toInt(),
                    protein: _protein.toInt(),
                    carbs: _carbs.toInt(),
                    fats: _fats.toInt(),
                  );
            }
            if (mounted) Navigator.pop(context);
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildQuickExampleChip(String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: SomaFonts.mono(fontSize: 10, fontWeight: FontWeight.bold, color: SomaColors.onSurface),
      backgroundColor: SomaColors.cardBackground,
      side: const BorderSide(color: SomaColors.cardBorder),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () {
        _naturalMealController.text = text;
        _executeMealParse(text);
      },
    );
  }

  Widget _buildMacroPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: SomaFonts.mono(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSummaryMacroCol(String title, String val, String unit, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: SomaFonts.mono(fontSize: 8.5, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val,
              style: SomaFonts.display(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: SomaFonts.mono(fontSize: 9, color: SomaColors.onSecondaryContainer),
            ),
          ],
        ),
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
