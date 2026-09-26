import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../services/calorie_calculator_service.dart';
import '../theme/soma_theme.dart';
import '../widgets/bmr_info_dialog.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final log = provider.currentLog;
    final goals = provider.userGoals;
    final calculatedBmr = CalorieCalculatorService.calculateBmr(goals);
    final hourlyBmr = CalorieCalculatorService.calculateHourlyBmr(goals);

    // Compute average compliance percentage
    final complianceCal = log.caloriesProgress.clamp(0.0, 1.0);
    final complianceWater = log.waterProgress.clamp(0.0, 1.0);
    final complianceSleep = log.sleepProgress.clamp(0.0, 1.0);
    final complianceSteps = log.stepsProgress.clamp(0.0, 1.0);
    final overallScore = (((complianceCal + complianceWater + complianceSleep + complianceSteps) / 4) * 100).round();

    return Scaffold(
      backgroundColor: SomaColors.background,
      appBar: AppBar(
        backgroundColor: SomaColors.background,
        elevation: 0,
        title: Text(
          'ANALYTICS & INSIGHTS',
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
            // Streak & Consistency Master Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: SomaColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🔥', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${provider.streak} DAY STREAK',
                              style: SomaFonts.display(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: SomaColors.primaryContainer,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: SomaColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$overallScore% SCORE',
                                style: SomaFonts.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Consistent athletic habits and continuous metabolic logging unlocked.',
                          style: SomaFonts.primary(
                            fontSize: 12.5,
                            color: SomaColors.onSecondaryContainer,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'METABOLIC PERFORMANCE ENGINE',
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
                  child: Text(
                    'FORMULA INFO',
                    style: SomaFonts.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SomaColors.primaryContainer,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live BMR Telemetry Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SomaColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SomaColors.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BASE METABOLIC RATE (BMR)',
                            style: SomaFonts.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: SomaColors.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$calculatedBmr kcal/day',
                            style: SomaFonts.display(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: SomaColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: SomaColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'HOURLY BURN',
                              style: SomaFonts.mono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: SomaColors.onSecondaryContainer,
                              ),
                            ),
                            Text(
                              '~${hourlyBmr.toStringAsFixed(1)} kcal/h',
                              style: SomaFonts.mono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: SomaColors.primaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SomaColors.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Algorithm: ${goals.bmrFormula.toUpperCase()} • Weight: ${goals.weightKg ?? 75}kg • Height: ${goals.heightCm ?? 178}cm',
                      style: SomaFonts.mono(
                        fontSize: 10.5,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'DAILY GOAL COMPLIANCE',
              style: SomaFonts.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SomaColors.onSecondaryContainer,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            // Stat Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Calorie Target',
                    '${log.caloriesBurned} / ${log.caloriesGoal}',
                    'kcal burned',
                    log.caloriesProgress,
                    SomaColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    'Hydration',
                    '${log.water.toStringAsFixed(1)} / ${log.waterGoal}L',
                    'liters consumed',
                    log.waterProgress,
                    SomaColors.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Sleep Rest',
                    '${log.sleep.toStringAsFixed(1)} / ${log.sleepGoal}h',
                    'hours recovered',
                    log.sleepProgress,
                    SomaColors.accentPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    'Step Movement',
                    '${log.steps} / ${log.stepsGoal}',
                    'steps completed',
                    log.stepsProgress,
                    SomaColors.secondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              'SOMA ATHLETIC PROTOCOLS',
              style: SomaFonts.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SomaColors.onSecondaryContainer,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            _buildTipCard(
              '⚡ Optimal Protein Timing & Satiety',
              'Aim for 1.8g - 2.2g of protein per kg of bodyweight spaced across 3-4 meals to maximize muscle protein synthesis and lean recovery.',
              SomaColors.primaryContainer,
              Icons.bolt_rounded,
            ),
            const SizedBox(height: 10),
            _buildTipCard(
              '💧 Morning Hydration Window',
              'Consume 500ml of mineralized water within 30 minutes of waking to counter nocturnal fluid deficit and optimize neurological focus.',
              SomaColors.accentCyan,
              Icons.water_drop_rounded,
            ),
            const SizedBox(height: 10),
            _buildTipCard(
              '🌙 Circadian Light & Sleep Architecture',
              'Limit blue spectrum screen exposure 90 minutes before sleep to facilitate melatonin surge and protect deep slow-wave recovery phases.',
              SomaColors.accentPurple,
              Icons.bedtime_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String unit, double progress, Color color) {
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: SomaFonts.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: SomaColors.onSecondaryContainer,
                ),
              ),
              Text(
                '$percent%',
                style: SomaFonts.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: SomaFonts.display(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SomaColors.onSurface,
            ),
          ),
          Text(
            unit,
            style: SomaFonts.primary(
              fontSize: 11,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: SomaColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String description, Color accentColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SomaFonts.primary(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: SomaColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: SomaFonts.primary(
                    fontSize: 12.5,
                    color: SomaColors.onSecondaryContainer,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
