import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../theme/soma_theme.dart';

class BmrInfoDialog extends StatelessWidget {
  const BmrInfoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BmrInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final goals = provider.userGoals;

    final bmr = CalorieCalculatorService.calculateBmr(goals);
    final hourlyBmr = CalorieCalculatorService.calculateHourlyBmr(goals);
    final bmrSoFar = CalorieCalculatorService.calculateBmrBurntSoFar(goals, provider.selectedDate);

    String formulaName = 'Mifflin-St Jeor Equation';
    String formulaDesc = 'The modern gold standard formula calculating baseline metabolic rate from age, height, weight, and biological sex.';

    switch (goals.bmrFormula) {
      case 'harris':
        formulaName = 'Harris-Benedict (Revised)';
        formulaDesc = 'Classic revised 1984 formula incorporating body weight, height, age, and biological sex factors.';
        break;
      case 'katch':
        formulaName = 'Katch-McArdle Formula';
        formulaDesc = 'Precision formula based on Lean Body Mass (LBM) calculated using your Body Fat percentage (${goals.bodyFatPercentage ?? 15}%).';
        break;
      case 'cunningham':
        formulaName = 'Cunningham Equation';
        formulaDesc = 'Athletic performance equation calculating BMR from Lean Body Mass (${goals.bodyFatPercentage ?? 15}% body fat).';
        break;
      case 'custom':
        formulaName = 'Custom Manual BMR Target';
        formulaDesc = 'User-specified direct manual BMR target rate entered in settings.';
        break;
    }

    return Dialog(
      backgroundColor: SomaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_fire_department_rounded, color: SomaColors.primaryContainer, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'METABOLIC ENGINE',
                        style: SomaFonts.display(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: SomaColors.onSecondaryContainer),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: SomaColors.cardBorder, height: 24),

              // BMR Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SomaColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$bmr kcal / day',
                      style: SomaFonts.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '~${hourlyBmr.toStringAsFixed(1)} kcal/hr burned continuously at rest',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SomaColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Burnt So Far Today: $bmrSoFar kcal',
                        style: SomaFonts.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: SomaColors.primaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Active Formula Card
              Text(
                'ACTIVE FORMULA MODEL',
                style: SomaFonts.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: SomaColors.onSecondaryContainer,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formulaName,
                style: SomaFonts.primary(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: SomaColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formulaDesc,
                style: SomaFonts.primary(
                  fontSize: 12.5,
                  color: SomaColors.onSecondaryContainer,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 20),
              // User Metrics List
              Text(
                'ATHLETE BIOMETRICS USED',
                style: SomaFonts.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: SomaColors.onSecondaryContainer,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricBadge('Weight', '${goals.weightKg ?? 75} kg'),
                  _buildMetricBadge('Height', '${goals.heightCm ?? 178} cm'),
                  _buildMetricBadge('Age', '${goals.age ?? 25} yrs'),
                  _buildMetricBadge('Sex', (goals.gender ?? 'male').toUpperCase()),
                  if (goals.bmrFormula == 'katch' || goals.bmrFormula == 'cunningham')
                    _buildMetricBadge('Body Fat', '${goals.bodyFatPercentage ?? 15}%'),
                ],
              ),

              const SizedBox(height: 20),
              // Active Burn vs Resting Burn explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SomaColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SomaColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔥 Active Burn vs Resting BMR',
                      style: SomaFonts.primary(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: SomaColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Active Burn: Extra calories burned from steps, cardio, and workouts.\n'
                      '• Resting BMR: Background calories vital organs burn 24/7.\n'
                      '• Total Expenditure (TDEE) = Active Burn + BMR.',
                      style: SomaFonts.primary(
                        fontSize: 12,
                        color: SomaColors.onSecondaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Text(
        '$label: $value',
        style: SomaFonts.mono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SomaColors.onSurface,
        ),
      ),
    );
  }
}
