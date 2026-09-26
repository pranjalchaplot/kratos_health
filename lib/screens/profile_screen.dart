import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratos_provider.dart';
import '../models/user_goals.dart';
import '../services/calorie_calculator_service.dart';
import '../theme/kratos_theme.dart';
import '../widgets/bmr_info_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;
  late TextEditingController _stepsController;
  late TextEditingController _waterController;
  late TextEditingController _sleepController;
  late TextEditingController _digitalController;

  // Body Stats & BMR Controllers
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late TextEditingController _customBmrController;
  late TextEditingController _bodyFatController;

  late String _gender;
  late String _bmrFormula;

  @override
  void initState() {
    super.initState();
    final goals = context.read<KratosProvider>().userGoals;
    _caloriesController = TextEditingController(text: goals.caloriesGoal.toString());
    _proteinController = TextEditingController(text: goals.proteinGoal.toString());
    _carbsController = TextEditingController(text: goals.carbsGoal.toString());
    _fatsController = TextEditingController(text: goals.fatsGoal.toString());
    _stepsController = TextEditingController(text: goals.stepsGoal.toString());
    _waterController = TextEditingController(text: goals.waterGoal.toString());
    _sleepController = TextEditingController(text: goals.sleepGoal.toString());
    _digitalController = TextEditingController(text: goals.digitalGoalHours.toString());

    _weightController = TextEditingController(text: (goals.weightKg ?? 75.0).toString());
    _heightController = TextEditingController(text: (goals.heightCm ?? 178.0).toString());
    _ageController = TextEditingController(text: (goals.age ?? 25).toString());
    _customBmrController = TextEditingController(text: (goals.customBmr ?? 1850).toString());
    _bodyFatController = TextEditingController(text: (goals.bodyFatPercentage ?? 15.0).toString());

    _gender = goals.gender ?? 'male';
    _bmrFormula = goals.bmrFormula;
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _stepsController.dispose();
    _waterController.dispose();
    _sleepController.dispose();
    _digitalController.dispose();

    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _customBmrController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  UserGoals _buildTempGoalsFromInputs() {
    return UserGoals(
      caloriesGoal: int.tryParse(_caloriesController.text) ?? 3200,
      proteinGoal: int.tryParse(_proteinController.text) ?? 180,
      carbsGoal: int.tryParse(_carbsController.text) ?? 250,
      fatsGoal: int.tryParse(_fatsController.text) ?? 70,
      stepsGoal: int.tryParse(_stepsController.text) ?? 10000,
      waterGoal: double.tryParse(_waterController.text) ?? 3.5,
      sleepGoal: double.tryParse(_sleepController.text) ?? 8.5,
      digitalGoalHours: int.tryParse(_digitalController.text) ?? 10,
      weightKg: double.tryParse(_weightController.text) ?? 75.0,
      heightCm: double.tryParse(_heightController.text) ?? 178.0,
      age: int.tryParse(_ageController.text) ?? 25,
      gender: _gender,
      bmrFormula: _bmrFormula,
      customBmr: int.tryParse(_customBmrController.text),
      bodyFatPercentage: double.tryParse(_bodyFatController.text) ?? 15.0,
      primaryFocus: context.read<KratosProvider>().userGoals.primaryFocus,
      userName: context.read<KratosProvider>().userGoals.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratosProvider>();
    final tempGoals = _buildTempGoalsFromInputs();
    final calculatedBmr = CalorieCalculatorService.calculateBmr(tempGoals);
    final hourlyBmr = CalorieCalculatorService.calculateHourlyBmr(tempGoals);

    return Scaffold(
      backgroundColor: KratosColors.background,
      appBar: AppBar(
        backgroundColor: KratosColors.background,
        elevation: 0,
        title: const Text(
          'PROFILE & GOALS',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.36,
            color: KratosColors.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KratosColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KratosColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: KratosColors.primaryContainer.withValues(alpha: 0.2),
                      border: Border.all(color: KratosColors.primaryContainer),
                    ),
                    child: const Icon(Icons.person, color: KratosColors.primaryContainer, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.userGoals.userName ?? 'KRATOS Athlete',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: KratosColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.userGoals.primaryFocus ?? 'Focus: Peak Athletic Performance',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: KratosColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Body Stats & Auto-BMR Burn Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BODY STATS & AUTO-CALORIE BURN (BMR)',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KratosColors.onSecondaryContainer,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: KratosColors.primaryContainer, size: 20),
                  onPressed: () => BmrInfoDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live BMR Rate Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KratosColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KratosColors.primaryContainer.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUTO RESTING BURN (BMR)',
                        style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, fontWeight: FontWeight.bold, color: KratosColors.onSecondaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$calculatedBmr kcal / day',
                        style: const TextStyle(fontFamily: 'Geist', fontSize: 24, fontWeight: FontWeight.w800, color: KratosColors.primaryContainer),
                      ),
                      Text(
                        '~${hourlyBmr.toStringAsFixed(1)} kcal/hr burnt simply by existing',
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: KratosColors.onSurface),
                      ),
                    ],
                  ),
                  const Icon(Icons.local_fire_department, color: KratosColors.primaryContainer, size: 36),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // User Physical Metrics
            Row(
              children: [
                Expanded(child: _buildInputField('Weight (kg)', _weightController, const TextInputType.numberWithOptions(decimal: true), () => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField('Height (cm)', _heightController, const TextInputType.numberWithOptions(decimal: true), () => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField('Age (years)', _ageController, TextInputType.number, () => setState(() {}))),
              ],
            ),
            const SizedBox(height: 12),

            // Gender Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sex / Gender', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, fontWeight: FontWeight.bold, color: KratosColors.onSecondaryContainer)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildGenderChip('male', 'Male'),
                    const SizedBox(width: 8),
                    _buildGenderChip('female', 'Female'),
                    const SizedBox(width: 8),
                    _buildGenderChip('neutral', 'Neutral'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            // BMR Formula Picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BMR Formula Choice', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, fontWeight: FontWeight.bold, color: KratosColors.onSecondaryContainer)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _bmrFormula,
                  dropdownColor: KratosColors.cardBackground,
                  style: const TextStyle(color: KratosColors.onSurface, fontFamily: 'Geist', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: KratosColors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: KratosColors.cardBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mifflin', child: Text('Mifflin-St Jeor (Recommended)')),
                    DropdownMenuItem(value: 'harris', child: Text('Harris-Benedict (Revised)')),
                    DropdownMenuItem(value: 'katch', child: Text('Katch-McArdle (Body Fat %)')),
                    DropdownMenuItem(value: 'cunningham', child: Text('Cunningham (Athletic LBM)')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Manual BMR Target')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _bmrFormula = val);
                  },
                ),
              ],
            ),

            if (_bmrFormula == 'katch' || _bmrFormula == 'cunningham') ...[
              const SizedBox(height: 12),
              _buildInputField('Body Fat Percentage (%)', _bodyFatController, const TextInputType.numberWithOptions(decimal: true), () => setState(() {})),
            ],

            if (_bmrFormula == 'custom') ...[
              const SizedBox(height: 12),
              _buildInputField('Custom Daily BMR Target (kcal)', _customBmrController, TextInputType.number, () => setState(() {})),
            ],

            const SizedBox(height: 24),
            const Text(
              'CUSTOMIZE DAILY TARGETS',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KratosColors.onSecondaryContainer,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            _buildInputField('Calories Target (kcal)', _caloriesController, TextInputType.number, () {}),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInputField('Protein (g)', _proteinController, TextInputType.number, () {})),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField('Carbs (g)', _carbsController, TextInputType.number, () {})),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField('Fats (g)', _fatsController, TextInputType.number, () {})),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField('Daily Steps Target', _stepsController, TextInputType.number, () {}),
            const SizedBox(height: 12),
            _buildInputField('Daily Water Target (Liters)', _waterController, const TextInputType.numberWithOptions(decimal: true), () {}),
            const SizedBox(height: 12),
            _buildInputField('Sleep Target (Hours)', _sleepController, const TextInputType.numberWithOptions(decimal: true), () {}),
            const SizedBox(height: 12),
            _buildInputField('Digital Goal Limit (Hours)', _digitalController, TextInputType.number, () {}),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KratosColors.primaryContainer,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final newGoals = UserGoals(
                    caloriesGoal: int.tryParse(_caloriesController.text) ?? 3200,
                    proteinGoal: int.tryParse(_proteinController.text) ?? 180,
                    carbsGoal: int.tryParse(_carbsController.text) ?? 250,
                    fatsGoal: int.tryParse(_fatsController.text) ?? 70,
                    stepsGoal: int.tryParse(_stepsController.text) ?? 10000,
                    waterGoal: double.tryParse(_waterController.text) ?? 3.5,
                    sleepGoal: double.tryParse(_sleepController.text) ?? 8.5,
                    digitalGoalHours: int.tryParse(_digitalController.text) ?? 10,
                    weightKg: double.tryParse(_weightController.text) ?? 75.0,
                    heightCm: double.tryParse(_heightController.text) ?? 178.0,
                    age: int.tryParse(_ageController.text) ?? 25,
                    gender: _gender,
                    bmrFormula: _bmrFormula,
                    customBmr: int.tryParse(_customBmrController.text),
                    bodyFatPercentage: double.tryParse(_bodyFatController.text) ?? 15.0,
                    primaryFocus: provider.userGoals.primaryFocus,
                    userName: provider.userGoals.userName,
                  );

                  await provider.updateGoals(newGoals);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Target goals & BMR settings updated and saved!'),
                        backgroundColor: KratosColors.primaryContainer,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  'SAVE TARGET GOALS & BMR',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: KratosColors.primaryContainer,
                  side: const BorderSide(color: KratosColors.primaryContainer),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  await provider.resetOnboarding();
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text(
                  'RE-RUN ONBOARDING FLOW',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  await provider.clearAllData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All logged entries cleared!'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text(
                  'CLEAR ALL LOGGED DATA',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'asset/icon_data/playstore.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'KRATOS PERFORMANCE ECOSYSTEM',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: KratosColors.primaryContainer,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 0.1.0 • Build 1',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: KratosColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChip(String key, String label) {
    final isSelected = _gender == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: KratosColors.primaryContainer,
      backgroundColor: KratosColors.cardBackground,
      labelStyle: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.black : KratosColors.onSurface,
      ),
      onSelected: (_) => setState(() => _gender = key),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType keyboardType, VoidCallback onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: KratosColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: KratosColors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: KratosColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KratosColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KratosColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KratosColors.primaryContainer),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
