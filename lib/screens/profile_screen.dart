import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../models/user_goals.dart';
import '../services/calorie_calculator_service.dart';
import '../theme/soma_theme.dart';
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
    final goals = context.read<SomaProvider>().userGoals;
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
      primaryFocus: context.read<SomaProvider>().userGoals.primaryFocus,
      userName: context.read<SomaProvider>().userGoals.userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final tempGoals = _buildTempGoalsFromInputs();
    final calculatedBmr = CalorieCalculatorService.calculateBmr(tempGoals);
    final hourlyBmr = CalorieCalculatorService.calculateHourlyBmr(tempGoals);

    return Scaffold(
      backgroundColor: SomaColors.background,
      appBar: AppBar(
        backgroundColor: SomaColors.background,
        elevation: 0,
        title: Text(
          'PROFILE & METRICS',
          style: SomaFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: SomaColors.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: SomaColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SomaColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                      border: Border.all(color: SomaColors.primaryContainer, width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: SomaColors.primaryContainer, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.userGoals.userName ?? 'SOMA Athlete',
                          style: SomaFonts.display(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: SomaColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: SomaColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            provider.userGoals.primaryFocus ?? 'Peak Athletic Performance',
                            style: SomaFonts.mono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: SomaColors.primaryContainer,
                            ),
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
                Text(
                  'BODY STATS & LIVE BMR ENGINE',
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SomaColors.onSecondaryContainer,
                    letterSpacing: 1.0,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    BmrInfoDialog.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.info_outline, color: SomaColors.primaryContainer, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live BMR Rate Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SomaColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUTO RESTING BURN (BMR)',
                        style: SomaFonts.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: SomaColors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$calculatedBmr kcal / day',
                        style: SomaFonts.display(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.primaryContainer,
                        ),
                      ),
                      Text(
                        '~${hourlyBmr.toStringAsFixed(1)} kcal/hr burned continuously',
                        style: SomaFonts.mono(
                          fontSize: 10.5,
                          color: SomaColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.local_fire_department_rounded, color: SomaColors.primaryContainer, size: 36),
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
                Expanded(child: _buildInputField('Age (yrs)', _ageController, TextInputType.number, () => setState(() {}))),
              ],
            ),
            const SizedBox(height: 12),

            // Gender Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sex / Biological Profile',
                  style: SomaFonts.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer),
                ),
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
                Text(
                  'BMR Formula Model',
                  style: SomaFonts.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _bmrFormula,
                  dropdownColor: SomaColors.cardBackground,
                  style: SomaFonts.primary(color: SomaColors.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SomaColors.cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SomaColors.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SomaColors.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SomaColors.primaryContainer)),
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
            Text(
              'DAILY PERFORMANCE TARGETS',
              style: SomaFonts.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SomaColors.onSecondaryContainer,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),

            _buildInputField('Daily Calorie Target (kcal)', _caloriesController, TextInputType.number, () {}),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildInputField('Protein (g)', _proteinController, TextInputType.number, () {})),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField('Carbs (g)', _carbsController, TextInputType.number, () {})),
                const SizedBox(width: 8),
                Expanded(child: _buildInputField('Fats (g)', _fatsController, TextInputType.number, () {})),
              ],
            ),
            const SizedBox(height: 10),
            _buildInputField('Daily Steps Target', _stepsController, TextInputType.number, () {}),
            const SizedBox(height: 10),
            _buildInputField('Daily Water Target (Liters)', _waterController, const TextInputType.numberWithOptions(decimal: true), () {}),
            const SizedBox(height: 10),
            _buildInputField('Sleep Target (Hours)', _sleepController, const TextInputType.numberWithOptions(decimal: true), () {}),
            const SizedBox(height: 10),
            _buildInputField('Digital Goal Limit (Hours)', _digitalController, TextInputType.number, () {}),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SomaColors.primaryContainer,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
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
                        backgroundColor: SomaColors.primaryContainer,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  'SAVE TARGET GOALS & BMR',
                  style: SomaFonts.mono(
                    fontSize: 13,
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
                  foregroundColor: SomaColors.onSurface,
                  side: const BorderSide(color: SomaColors.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await provider.resetOnboarding();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(
                  'RE-RUN ONBOARDING FLOW',
                  style: SomaFonts.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                  foregroundColor: SomaColors.error,
                  side: BorderSide(color: SomaColors.error.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  await provider.clearAllData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All logged entries cleared!'),
                        backgroundColor: SomaColors.error,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text(
                  'CLEAR ALL LOGGED DATA',
                  style: SomaFonts.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                      width: 32,
                      height: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'SOMA PERFORMANCE ECOSYSTEM',
                    style: SomaFonts.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: SomaColors.primaryContainer,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 0.1.0 • Build 1',
                    style: SomaFonts.mono(
                      fontSize: 10,
                      color: SomaColors.onSecondaryContainer,
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _gender = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: SomaFonts.mono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black : SomaColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType keyboardType, VoidCallback onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SomaFonts.mono(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: SomaColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged(),
          style: SomaFonts.primary(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: SomaColors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: SomaColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SomaColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SomaColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SomaColors.primaryContainer),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
