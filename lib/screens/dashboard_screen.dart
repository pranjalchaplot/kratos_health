import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/kratos_provider.dart';
import '../models/dashboard_data.dart';
import '../theme/kratos_theme.dart';
import '../widgets/week_calendar_strip.dart';
import '../widgets/progress_rings.dart';
import '../widgets/macro_progress_bar.dart';
import '../widgets/metric_card.dart';
import '../widgets/quick_log_modal.dart';

/// Main Dashboard Screen - KRATOS Fitness & Nutrition Ecosystem
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KratosProvider>();
    final currentLog = provider.currentLog;
    final data = DashboardData.fromDailyLog(currentLog, provider.streak, provider.activeDayIndex);

    return Scaffold(
      backgroundColor: KratosColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          _buildAppBar(context, provider),
          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Week Calendar Strip with interactive selection
                WeekCalendarStrip(
                  activeIndex: provider.activeDayIndex,
                  onDaySelected: (index) {
                    provider.selectDayByIndex(index);
                  },
                ),
                const SizedBox(height: 24),
                // Daily Summary Card
                _buildDailySummaryCard(context, data),
                const SizedBox(height: 16),
                // Metrics Grid
                _buildMetricsGrid(context, data),
                // Bottom padding for nav bar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, KratosProvider provider) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: KratosColors.background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile avatar (tapping goes to profile tab)
          GestureDetector(
            onTap: () => provider.setTab(4),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: KratosColors.surfaceContainerHighest,
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Container(
                  color: KratosColors.surfaceContainerHigh,
                  child: const Icon(
                    Icons.person,
                    color: KratosColors.onSecondaryContainer,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          // KRATOS title
          const Text(
            'KRATOS',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.48,
              color: KratosColors.onBackground,
            ),
          ),
          // Streak
          Text(
            '${provider.streak}🔥',
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KratosColors.primaryContainer,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: KratosColors.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(BuildContext context, DashboardData data) {
    final formatCurrency = NumberFormat("#,##0", "en_US");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => QuickLogModal.show(context, initialTabIndex: 1), // Meal tab
        child: Container(
          decoration: BoxDecoration(
            color: KratosColors.cardBackground,
            border: Border.all(color: KratosColors.cardBorder, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 400) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ProgressRings(
                          calorieProgress: data.caloriesProgress,
                          activityProgress: data.caloriesProgress,
                          centerValue: formatCurrency.format(data.caloriesBurned),
                          centerLabel: 'KCAL BURNED',
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _buildMacrosSection(data)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      ProgressRings(
                        calorieProgress: data.caloriesProgress,
                        activityProgress: data.caloriesProgress,
                        centerValue: formatCurrency.format(data.caloriesBurned),
                        centerLabel: 'KCAL BURNED',
                      ),
                      const SizedBox(height: 20),
                      _buildMacrosSection(data),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacrosSection(DashboardData data) {
    final goalPercent = (data.caloriesProgress * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'DAILY SUMMARY',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.36,
                        color: KratosColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.north_east,
                    color: KratosColors.primaryContainer,
                    size: 14,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$goalPercent% OF GOAL',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: 1.2,
                color: KratosColors.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MacroProgressBar(
          label: 'PROTEIN',
          value: '${data.protein}g / ${data.proteinGoal}g',
          progress: data.proteinProgress,
          barColor: KratosColors.primaryContainer,
        ),
        const SizedBox(height: 12),
        MacroProgressBar(
          label: 'CARBS',
          value: '${data.carbs}g / ${data.carbsGoal}g',
          progress: data.carbsProgress,
          barColor: KratosColors.onSurface,
        ),
        const SizedBox(height: 12),
        MacroProgressBar(
          label: 'FATS',
          value: '${data.fats}g / ${data.fatsGoal}g',
          progress: data.fatsProgress,
          barColor: KratosColors.secondary,
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context, DashboardData data) {
    final formatCurrency = NumberFormat("#,##0", "en_US");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Steps Card (taps open Activity tab)
          GestureDetector(
            onTap: () => QuickLogModal.show(context, initialTabIndex: 2),
            child: MetricCard(
              label: 'STEPS TODAY',
              value: formatCurrency.format(data.steps),
              percentage: '${(data.stepsProgress * 100).round()}%',
              progress: data.stepsProgress,
              icon: Icons.directions_walk,
            ),
          ),
          // Water Card (taps open Water tab)
          GestureDetector(
            onTap: () => QuickLogModal.show(context, initialTabIndex: 0),
            child: MetricCard(
              label: 'WATER',
              value: data.water.toStringAsFixed(1),
              unit: 'L',
              percentage: '${(data.waterProgress * 100).round()}%',
              progress: data.waterProgress,
              icon: Icons.water_drop,
            ),
          ),
          // Sleep Card (taps open Sleep tab)
          GestureDetector(
            onTap: () => QuickLogModal.show(context, initialTabIndex: 3),
            child: MetricCard(
              label: 'SLEEP',
              value: data.sleep.toStringAsFixed(1),
              unit: 'h',
              percentage: '${(data.sleepProgress * 100).round()}%',
              progress: data.sleepProgress,
              icon: Icons.bed,
            ),
          ),
          // Digital Wellbeing Card (taps open Digital tab)
          GestureDetector(
            onTap: () => QuickLogModal.show(context, initialTabIndex: 4),
            child: MetricCard(
              label: 'DIGITAL',
              value: '${data.digitalHours}',
              unit: 'h',
              secondaryValue: '${data.digitalMinutes}',
              secondaryUnit: 'm',
              percentage: '${(data.digitalProgress * 100).round()}%',
              progress: data.digitalProgress,
              icon: Icons.phone_iphone,
            ),
          ),
        ],
      ),
    );
  }
}
