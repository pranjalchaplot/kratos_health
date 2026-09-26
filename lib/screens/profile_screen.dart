import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratos_provider.dart';
import '../models/user_goals.dart';
import '../theme/kratos_theme.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratosProvider>();

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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KRATOS Athlete',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: KratosColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Performance Level: Elite',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: KratosColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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

            _buildInputField('Calories Target (kcal)', _caloriesController, TextInputType.number),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInputField('Protein (g)', _proteinController, TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('Carbs (g)', _carbsController, TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('Fats (g)', _fatsController, TextInputType.number)),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField('Daily Steps Target', _stepsController, TextInputType.number),
            const SizedBox(height: 12),
            _buildInputField('Daily Water Target (Liters)', _waterController, const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _buildInputField('Sleep Target (Hours)', _sleepController, const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _buildInputField('Digital Goal Limit (Hours)', _digitalController, TextInputType.number),

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
                  );

                  await provider.updateGoals(newGoals);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Target goals updated and saved!'),
                        backgroundColor: KratosColors.primaryContainer,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  'SAVE TARGET GOALS',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType keyboardType) {
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
