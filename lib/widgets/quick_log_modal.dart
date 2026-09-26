import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratos_provider.dart';
import '../services/screen_time_service.dart';
import '../theme/kratos_theme.dart';

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

  // Activity Form
  final _activityNameController = TextEditingController(text: 'Workout Session');
  double _activitySteps = 3000;
  double _activityCalories = 250;

  // Sleep Form
  double _sleepHours = 8.0;

  // Digital Form
  double _digitalHours = 4.0;
  double _digitalMinutes = 30.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mealNameController.dispose();
    _activityNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 60, bottom: bottomPadding),
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
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOG ACTIVITY',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.36,
                    color: KratosColors.onSurface,
                  ),
                ),
                Icon(Icons.add_circle, color: KratosColors.primaryContainer, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                height: 430,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWaterTab(),
                    _buildMealTab(),
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
        // Mode Selector: Glasses vs ML
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
          // Glasses Display with Stepper
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
          const SizedBox(height: 12),
          // Glasses Preset Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPresetChip('1 Glass (250ml)', () {
                setState(() {
                  _glassesCount = 1;
                  _waterAmount = 0.25;
                });
              }),
              _buildPresetChip('2 Glasses (500ml)', () {
                setState(() {
                  _glassesCount = 2;
                  _waterAmount = 0.50;
                });
              }),
              _buildPresetChip('3 Glasses (750ml)', () {
                setState(() {
                  _glassesCount = 3;
                  _waterAmount = 0.75;
                });
              }),
              _buildPresetChip('4 Glasses (1.0L)', () {
                setState(() {
                  _glassesCount = 4;
                  _waterAmount = 1.00;
                });
              }),
            ],
          ),
        ] else ...[
          // ML Display
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
          const SizedBox(height: 12),
          // ML Preset Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPresetChip('+ 250 ml', () {
                setState(() {
                  _waterAmount = 0.25;
                  _glassesCount = 1;
                });
              }),
              _buildPresetChip('+ 500 ml', () {
                setState(() {
                  _waterAmount = 0.50;
                  _glassesCount = 2;
                });
              }),
              _buildPresetChip('+ 750 ml', () {
                setState(() {
                  _waterAmount = 0.75;
                  _glassesCount = 3;
                });
              }),
              _buildPresetChip('+ 1.0 L', () {
                setState(() {
                  _waterAmount = 1.00;
                  _glassesCount = 4;
                });
              }),
            ],
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
        // Category selection (Horizontal scrollable chip strip)
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
        // Macro Sliders Grid
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

  // --- Activity Tab ---
  Widget _buildActivityTab() {
    return Column(
      children: [
        TextField(
          controller: _activityNameController,
          style: const TextStyle(color: KratosColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Activity / Workout Name',
            labelStyle: const TextStyle(color: KratosColors.onSecondaryContainer),
            filled: true,
            fillColor: KratosColors.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        _buildValueControl('Steps Taken', '${_activitySteps.toInt()} steps', _activitySteps, 500, 20000, (v) {
          setState(() => _activitySteps = v);
        }),
        const SizedBox(height: 12),
        _buildValueControl('Estimated Calories Burned', '${_activityCalories.toInt()} kcal', _activityCalories, 50, 1200, (v) {
          setState(() => _activityCalories = v);
        }),
        const Spacer(),
        _buildSubmitButton('LOG ACTIVITY', KratosColors.secondary, () async {
          await context.read<KratosProvider>().logActivity(
                title: _activityNameController.text.isEmpty ? 'Activity' : _activityNameController.text,
                steps: _activitySteps.toInt(),
                calories: _activityCalories.toInt(),
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
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not fetch usage stats. Ensure Usage Access permission is granted in Android settings.')),
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
  Widget _buildValueControl(String label, String valueDisplay, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: KratosColors.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(valueDisplay, style: const TextStyle(color: KratosColors.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildPresetChip(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: KratosColors.cardBackground,
          border: Border.all(color: KratosColors.cardBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: KratosColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
