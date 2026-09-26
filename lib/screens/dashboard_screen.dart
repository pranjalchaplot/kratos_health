import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/soma_provider.dart';
import '../models/dashboard_data.dart';
import '../theme/soma_theme.dart';
import '../widgets/week_calendar_strip.dart';
import '../widgets/progress_rings.dart';
import '../widgets/macro_progress_bar.dart';
import '../widgets/metric_card.dart';
import '../widgets/quick_log_modal.dart';
import '../widgets/bmr_info_dialog.dart';

/// Main Dashboard Screen - SOMA Performance & Fitness Ecosystem
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    // 1-second real-time ticker timer for live Dashboard BMR updates
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final currentLog = provider.currentLog;
    final data = DashboardData.fromDailyLog(
      currentLog,
      provider.userGoals,
      provider.streak,
      provider.activeDayIndex,
    );

    return Scaffold(
      backgroundColor: SomaColors.background,
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: SomaColors.primaryContainer,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await provider.syncAllFromPhone();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // App Bar
            _buildAppBar(context, provider),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Week Calendar Strip with interactive date selection
                WeekCalendarStrip(
                  activeIndex: provider.activeDayIndex,
                  onDaySelected: (index) {
                    provider.selectDayByIndex(index);
                  },
                ),

                const SizedBox(height: 16),

                // Quick Action Shortcuts Bar
                _buildQuickActionsRow(context),

                const SizedBox(height: 16),

                // Daily Summary Card
                _buildDailySummaryCard(context, data),

                const SizedBox(height: 16),

                // Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BIOMETRIC TELEMETRY',
                        style: SomaFonts.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: SomaColors.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        'LIVE SENSORS',
                        style: SomaFonts.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: SomaColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Metrics Grid (2x2)
                _buildMetricsGrid(context, data, provider),

                // Bottom padding for nav bar
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  SliverAppBar _buildAppBar(BuildContext context, SomaProvider provider) {
    final athleteName = provider.userGoals.userName ?? 'Athlete';

    return SliverAppBar(
      pinned: true,
      backgroundColor: SomaColors.background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile avatar & Greeting
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              provider.setTab(4);
            },
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SomaColors.primaryContainer.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: SomaColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.person,
                        color: SomaColors.primaryContainer,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SomaColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SOMA ACTIVE',
                          style: SomaFonts.mono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: SomaColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      athleteName,
                      style: SomaFonts.primary(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SomaColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Trailing Actions: Sync from Phone + Streak Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Sync Phone Sensors',
                onPressed: provider.isSyncingFromPhone
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await provider.syncAllFromPhone();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Telemetry Synced • Steps: ${provider.currentLog.steps}, Sleep: ${provider.currentLog.sleep}h, Screen: ${provider.currentLog.digitalHours}h ${provider.currentLog.digitalMinutes}m',
                              ),
                              backgroundColor: SomaColors.primaryContainer,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: provider.isSyncingFromPhone
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SomaColors.primaryContainer,
                        ),
                      )
                    : const Icon(
                        Icons.sync_rounded,
                        color: SomaColors.primaryContainer,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 4),
              // Streak Flame Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: SomaColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SomaColors.primaryContainer.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.streak}D',
                      style: SomaFonts.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: SomaColors.cardBorder,
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildActionChip(
              icon: Icons.restaurant_rounded,
              label: '+ MEAL',
              color: SomaColors.primaryContainer,
              onTap: () => QuickLogModal.show(context, initialTabIndex: QuickLogTab.meal),
            ),
            const SizedBox(width: 8),
            _buildActionChip(
              icon: Icons.water_drop_rounded,
              label: '+ WATER',
              color: SomaColors.accentCyan,
              onTap: () => QuickLogModal.show(context, initialTabIndex: QuickLogTab.water),
            ),
            const SizedBox(width: 8),
            _buildActionChip(
              icon: Icons.fitness_center_rounded,
              label: '+ WORKOUT',
              color: SomaColors.accentCoral,
              onTap: () => QuickLogModal.show(context, initialTabIndex: QuickLogTab.activity),
            ),
            const SizedBox(width: 8),
            _buildActionChip(
              icon: Icons.bedtime_rounded,
              label: '+ SLEEP',
              color: SomaColors.accentPurple,
              onTap: () => QuickLogModal.show(context, initialTabIndex: QuickLogTab.sleep),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: SomaColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SomaColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: SomaFonts.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: SomaColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(BuildContext context, DashboardData data) {
    final formatCurrency = NumberFormat("#,##0", "en_US");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          QuickLogModal.show(context, initialTabIndex: QuickLogTab.burn); // Live Calorie Burn tab
        },
        child: Container(
          decoration: BoxDecoration(
            color: SomaColors.cardBackground,
            border: Border.all(color: SomaColors.cardBorder, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
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
                          centerValue: formatCurrency.format(data.totalCaloriesBurned),
                          centerLabel: 'KCAL BURNED',
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _buildMacrosSection(context, data)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      ProgressRings(
                        calorieProgress: data.caloriesProgress,
                        activityProgress: data.caloriesProgress,
                        centerValue: formatCurrency.format(data.totalCaloriesBurned),
                        centerLabel: 'KCAL BURNED',
                      ),
                      const SizedBox(height: 20),
                      _buildMacrosSection(context, data),
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

  Widget _buildMacrosSection(BuildContext context, DashboardData data) {
    final goalPercent = (data.caloriesProgress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'DAILY METABOLIC BURN',
                      style: SomaFonts.display(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: SomaColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      BmrInfoDialog.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: SomaColors.primaryContainer.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: SomaColors.primaryContainer,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$goalPercent% OF GOAL',
                style: SomaFonts.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: SomaColors.primaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Active: ${data.caloriesBurned} kcal • Resting BMR: ${data.bmrBurntSoFar} kcal',
          style: SomaFonts.mono(
            fontSize: 10.5,
            color: SomaColors.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        MacroProgressBar(
          label: 'PROTEIN',
          value: '${data.protein}g / ${data.proteinGoal}g',
          progress: data.proteinProgress,
          barColor: SomaColors.primaryContainer,
        ),
        const SizedBox(height: 12),
        MacroProgressBar(
          label: 'CARBS',
          value: '${data.carbs}g / ${data.carbsGoal}g',
          progress: data.carbsProgress,
          barColor: SomaColors.onSurface,
        ),
        const SizedBox(height: 12),
        MacroProgressBar(
          label: 'FATS',
          value: '${data.fats}g / ${data.fatsGoal}g',
          progress: data.fatsProgress,
          barColor: SomaColors.secondary,
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context, DashboardData data, SomaProvider provider) {
    final formatCurrency = NumberFormat("#,##0", "en_US");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Steps Card
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _handleStepsTap(context, data, provider);
            },
            child: MetricCard(
              label: 'STEPS TODAY',
              value: formatCurrency.format(data.steps),
              percentage: '${(data.stepsProgress * 100).round()}%',
              progress: data.stepsProgress,
              icon: Icons.directions_walk_rounded,
              accentColor: SomaColors.primaryContainer,
            ),
          ),
          // Water Card
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              QuickLogModal.show(context, initialTabIndex: QuickLogTab.water);
            },
            child: MetricCard(
              label: 'HYDRATION',
              value: data.water.toStringAsFixed(1),
              unit: 'L',
              percentage: '${(data.waterProgress * 100).round()}%',
              progress: data.waterProgress,
              icon: Icons.water_drop_rounded,
              accentColor: SomaColors.accentCyan,
            ),
          ),
          // Sleep Card
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              QuickLogModal.show(context, initialTabIndex: QuickLogTab.sleep);
            },
            child: MetricCard(
              label: 'SLEEP REST',
              value: data.sleep.toStringAsFixed(1),
              unit: 'h',
              percentage: '${(data.sleepProgress * 100).round()}%',
              progress: data.sleepProgress,
              icon: Icons.bedtime_rounded,
              accentColor: SomaColors.accentPurple,
            ),
          ),
          // Digital Wellbeing Card
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              QuickLogModal.show(context, initialTabIndex: QuickLogTab.digital);
            },
            child: MetricCard(
              label: 'DIGITAL USE',
              value: '${data.digitalHours}',
              unit: 'h',
              secondaryValue: '${data.digitalMinutes}',
              secondaryUnit: 'm',
              percentage: '${(data.digitalProgress * 100).round()}%',
              progress: data.digitalProgress,
              icon: Icons.phone_iphone_rounded,
              accentColor: SomaColors.accentAmber,
            ),
          ),
        ],
      ),
    );
  }

  void _handleStepsTap(BuildContext context, DashboardData data, SomaProvider provider) {
    if (provider.isStepPermissionGranted) {
      QuickLogModal.show(context, initialTabIndex: QuickLogTab.activity);
    } else {
      _showStepPermissionDialog(context, provider);
    }
  }

  void _showStepPermissionDialog(BuildContext context, SomaProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SomaColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SomaColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: SomaColors.primaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ENABLE REAL-TIME STEP TRACKING',
                style: SomaFonts.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SomaColors.onSurface,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Enable physical activity permission so SOMA can automatically record daily steps in real-time using your device hardware pedometer sensor.',
                style: SomaFonts.primary(
                  fontSize: 14,
                  color: SomaColors.secondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SomaColors.primaryContainer,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final granted = await provider.requestStepPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            granted
                                ? 'Physical Activity permission granted! Step tracking active.'
                                : 'Permission was not granted. Ensure physical activity access is enabled in Settings.',
                          ),
                          backgroundColor: granted
                              ? SomaColors.primaryContainer
                              : SomaColors.surfaceContainerHigh,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    'GRANT SENSOR PERMISSION',
                    style: SomaFonts.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: SomaColors.secondary,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    QuickLogModal.show(context, initialTabIndex: QuickLogTab.activity);
                  },
                  child: Text(
                    'LOG STEPS MANUALLY INSTEAD',
                    style: SomaFonts.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
