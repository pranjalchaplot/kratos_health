import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratos_provider.dart';
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
                height: 380,
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
        const SizedBox(height: 16),
        Text(
          '${(_waterAmount * 1000).toInt()} ml',
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.cyanAccent,
          ),
        ),
        Slider(
          value: _waterAmount,
          min: 0.1,
          max: 2.0,
          divisions: 19,
          activeColor: Colors.cyanAccent,
          inactiveColor: KratosColors.surfaceContainerHighest,
          onChanged: (val) => setState(() => _waterAmount = val),
        ),
        const SizedBox(height: 16),
        // Preset Buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildPresetChip('+ 250 ml', () => setState(() => _waterAmount = 0.25)),
            _buildPresetChip('+ 500 ml', () => setState(() => _waterAmount = 0.50)),
            _buildPresetChip('+ 750 ml', () => setState(() => _waterAmount = 0.75)),
            _buildPresetChip('+ 1.0 L', () => setState(() => _waterAmount = 1.0)),
          ],
        ),
        const Spacer(),
        _buildSubmitButton('LOG WATER INTAKE', Colors.cyanAccent, () async {
          await context.read<KratosProvider>().logWater(_waterAmount);
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
        // Category selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((cat) {
            final isSelected = _mealCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: KratosColors.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected ? KratosColors.background : KratosColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) => setState(() => _mealCategory = cat),
            );
          }).toList(),
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
        const SizedBox(height: 20),
        Text(
          '${_digitalHours.toInt()}h ${_digitalMinutes.toInt()}m',
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.amberAccent,
          ),
        ),
        const SizedBox(height: 16),
        _buildValueControl('Screen Hours', '${_digitalHours.toInt()} hrs', _digitalHours, 0, 18, (v) {
          setState(() => _digitalHours = v);
        }),
        const SizedBox(height: 12),
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
