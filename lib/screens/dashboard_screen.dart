import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/kratos_theme.dart';
import '../widgets/week_calendar_strip.dart';
import '../widgets/progress_rings.dart';
import '../widgets/macro_progress_bar.dart';
import '../widgets/metric_card.dart';
import '../widgets/bottom_nav.dart';
import '../models/dashboard_data.dart';

/// Main Dashboard Screen - KRATOS Fitness & Nutrition Ecosystem
class DashboardScreen extends StatefulWidget {
  final DashboardData data;

  const DashboardScreen({super.key, required this.data});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KratosColors.background,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            slivers: [
              // App Bar
              _buildAppBar(),
              // Content
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Week Calendar Strip
                    WeekCalendarStrip(activeIndex: widget.data.activeDayIndex),
                    const SizedBox(height: 24),
                    // Daily Summary Card
                    _buildDailySummaryCard(),
                    const SizedBox(height: 16),
                    // Metrics Grid
                    _buildMetricsGrid(),
                    // Bottom padding for nav bar
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          // Bottom Navigation
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: KratosBottomNav(currentIndex: 0),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: KratosColors.background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile avatar
          Container(
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
            '${widget.data.streak}🔥',
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

  Widget _buildDailySummaryCard() {
    final formatCurrency = NumberFormat("#,##0", "en_US");
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: KratosColors.cardBackground,
          border: Border.all(color: KratosColors.cardBorder, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Progress Rings + Macros side by side on wider screens
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 400) {
                  // Side by side layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProgressRings(
                        calorieProgress: widget.data.caloriesProgress,
                        activityProgress: widget.data.caloriesProgress,
                        centerValue: formatCurrency.format(widget.data.caloriesBurned),
                        centerLabel: 'KCAL BURNED',
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: _buildMacrosSection()),
                    ],
                  );
                }
                // Stacked layout for mobile
                return Column(
                  children: [
                    ProgressRings(
                      calorieProgress: widget.data.caloriesProgress,
                      activityProgress: widget.data.caloriesProgress,
                      centerValue: formatCurrency.format(widget.data.caloriesBurned),
                      centerLabel: 'KCAL BURNED',
                    ),
                    const SizedBox(height: 20),
                    _buildMacrosSection(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosSection() {
    final goalPercent = (widget.data.caloriesProgress * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
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
                  Icon(
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
        // Macro bars
        MacroProgressBar(
          label: 'PROTEIN',
          value: '${widget.data.protein}g / ${widget.data.proteinGoal}g',
          progress: widget.data.proteinProgress,
          barColor: KratosColors.primaryContainer,
        ),
        const SizedBox(height: 12),
        MacroProgressBar(
          label: 'CARBS',
          value: '${widget.data.carbs}g / ${widget.data.carbsGoal}g',
          progress: widget.data.carbsProgress,
          barColor: KratosColors.onSurface,
        ),
        const SizedBox(height: 12),
        MacroProgressBar(
          label: 'FATS',
          value: '${widget.data.fats}g / ${widget.data.fatsGoal}g',
          progress: widget.data.fatsProgress,
          barColor: KratosColors.secondary,
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
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
          // Steps Card
          MetricCard(
            label: 'STEPS TODAY',
            value: formatCurrency.format(widget.data.steps),
            percentage: '${(widget.data.stepsProgress * 100).round()}%',
            progress: widget.data.stepsProgress,
            icon: Icons.directions_walk,
          ),
          // Water Card
          MetricCard(
            label: 'WATER',
            value: widget.data.water.toStringAsFixed(1),
            unit: 'L',
            percentage: '${(widget.data.waterProgress * 100).round()}%',
            progress: widget.data.waterProgress,
            icon: Icons.water_drop,
          ),
          // Sleep Card
          MetricCard(
            label: 'SLEEP',
            value: widget.data.sleep.toStringAsFixed(1),
            unit: 'h',
            percentage: '${(widget.data.sleepProgress * 100).round()}%',
            progress: widget.data.sleepProgress,
            icon: Icons.bed,
          ),
          // Digital Wellbeing Card
          MetricCard(
            label: 'DIGITAL',
            value: '${widget.data.digitalHours}',
            unit: 'h',
            secondaryValue: '${widget.data.digitalMinutes}',
            secondaryUnit: 'm',
            percentage: '${(widget.data.digitalProgress * 100).round()}%',
            progress: widget.data.digitalProgress,
            icon: Icons.phone_iphone,
          ),
        ],
      ),
    );
  }
}
