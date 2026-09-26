import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kratos_provider.dart';
import '../theme/kratos_theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratosProvider>();
    final log = provider.currentLog;

    return Scaffold(
      backgroundColor: KratosColors.background,
      appBar: AppBar(
        backgroundColor: KratosColors.background,
        elevation: 0,
        title: const Text(
          'ANALYTICS & INSIGHTS',
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
            // Streak Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KratosColors.primaryContainer.withValues(alpha: 0.2),
                    KratosColors.cardBackground,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KratosColors.primaryContainer.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.streak} DAY STREAK',
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: KratosColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Consistent performance unlocked!',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          color: KratosColors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'WEEKLY COMPLIANCE',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KratosColors.onSecondaryContainer,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            // Stat Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Calorie Target',
                    '${log.caloriesBurned} / ${log.caloriesGoal}',
                    'kcal',
                    log.caloriesProgress,
                    KratosColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    'Water Intake',
                    '${log.water} / ${log.waterGoal}',
                    'Liters',
                    log.waterProgress,
                    Colors.cyanAccent,
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
                    '${log.sleep} / ${log.sleepGoal}',
                    'Hours',
                    log.sleepProgress,
                    Colors.purpleAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    'Step Goal',
                    '${log.steps} / ${log.stepsGoal}',
                    'Steps',
                    log.stepsProgress,
                    KratosColors.secondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'KRATOS RECOMMENDATIONS',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KratosColors.onSecondaryContainer,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            _buildTipCard(
              '⚡ Optimal Protein Intake',
              'Aim to hit at least 1.6g - 2.2g of protein per kg of body weight to support lean muscular recovery.',
            ),
            const SizedBox(height: 12),
            _buildTipCard(
              '💧 Hydration Peak',
              'Drinking 500ml of water within 30 minutes of waking up accelerates metabolism and cognitive alertness.',
            ),
            const SizedBox(height: 12),
            _buildTipCard(
              '🌙 Sleep Hygiene',
              'Keep digital screen exposure below goal hours 2 hours before bed to maximize REM sleep quality.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String unit, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KratosColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KratosColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: KratosColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: KratosColors.onSurface,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              color: KratosColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: KratosColors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KratosColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KratosColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: KratosColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: KratosColors.onSecondaryContainer,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
