import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/soma_provider.dart';
import '../models/log_entry.dart';
import '../models/daily_log.dart';
import '../theme/soma_theme.dart';
import '../widgets/quick_log_modal.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final currentLog = provider.currentLog;
    final yesterdayLog = provider.yesterdayLog;
    final isToday = DateUtils.isSameDay(provider.selectedDate, DateTime.now());
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(provider.selectedDate);

    List<LogEntry> entries = currentLog.entries;
    if (_selectedFilter == 'MEALS') {
      entries = entries.where((e) => e.type == LogType.meal).toList();
    } else if (_selectedFilter == 'WATER') {
      entries = entries.where((e) => e.type == LogType.water).toList();
    } else if (_selectedFilter == 'ACTIVITY') {
      entries = entries.where((e) => e.type == LogType.activity).toList();
    } else if (_selectedFilter == 'SLEEP') {
      entries = entries.where((e) => e.type == LogType.sleep).toList();
    }

    return Scaffold(
      backgroundColor: SomaColors.background,
      appBar: AppBar(
        backgroundColor: SomaColors.background,
        elevation: 0,
        title: Text(
          'ACTIVITY & NUTRITION LOGS',
          style: SomaFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: SomaColors.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: SomaColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: SomaColors.onPrimary, size: 18),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                QuickLogModal.show(context);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: SomaColors.onSurface, size: 22),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    provider.selectDate(provider.selectedDate.subtract(const Duration(days: 1)));
                  },
                ),
                GestureDetector(
                  onTap: () {
                    if (!isToday) {
                      HapticFeedback.selectionClick();
                      provider.selectDate(DateTime.now());
                    }
                  },
                  child: Column(
                    children: [
                      Text(
                        dateStr,
                        style: SomaFonts.primary(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SomaColors.onSurface,
                        ),
                      ),
                      if (isToday)
                        Text(
                          'TODAY',
                          style: SomaFonts.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: SomaColors.primaryContainer,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: SomaColors.onSurface, size: 22),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    provider.selectDate(provider.selectedDate.add(const Duration(days: 1)));
                  },
                ),
              ],
            ),
          ),

          // Daily Telemetry Comparison Strip
          _buildDailyTelemetryStrip(currentLog, yesterdayLog),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['ALL', 'MEALS', 'WATER', 'ACTIVITY', 'SLEEP'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = filter);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: SomaFonts.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isSelected ? SomaColors.onPrimary : SomaColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Entries List
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: SomaColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              size: 32,
                              color: SomaColors.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs recorded for this day',
                            style: SomaFonts.primary(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: SomaColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button below or the + icon in the navbar to log your meals, hydration, workouts, or sleep.',
                            style: SomaFonts.primary(
                              fontSize: 13,
                              color: SomaColors.onSecondaryContainer,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SomaColors.primaryContainer,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              QuickLogModal.show(context);
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'ADD NEW ENTRY',
                              style: SomaFonts.mono(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 120),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _buildLogItem(context, provider, entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, SomaProvider provider, LogEntry entry) {
    final themeColor = _getItemThemeColor(entry);
    final icon = _getItemIcon(entry);
    final timeStr = DateFormat('h:mm a').format(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor.withValues(alpha: 0.16),
            themeColor.withValues(alpha: 0.05),
            SomaColors.cardBackground,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.38),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: themeColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: SomaFonts.primary(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SomaColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: SomaFonts.mono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.subtitle!,
                    style: SomaFonts.primary(
                      fontSize: 12.5,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _buildEntryBadges(entry, themeColor),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 18),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.deleteLogEntry(entry.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTelemetryStrip(DailyLog currentLog, DailyLog? yesterdayLog) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTelemetryChip(
            icon: Icons.local_fire_department_rounded,
            label: 'BURN',
            value: '${currentLog.activeCaloriesBurned}',
            unit: 'kcal',
            diff: yesterdayLog != null ? (currentLog.activeCaloriesBurned - yesterdayLog.activeCaloriesBurned).toDouble() : null,
            color: SomaColors.accentCoral,
          ),
          _buildTelemetryDivider(),
          _buildTelemetryChip(
            icon: Icons.directions_walk_rounded,
            label: 'STEPS',
            value: '${currentLog.steps}',
            diff: yesterdayLog != null ? (currentLog.steps - yesterdayLog.steps).toDouble() : null,
            color: SomaColors.primaryContainer,
          ),
          _buildTelemetryDivider(),
          _buildTelemetryChip(
            icon: Icons.water_drop_rounded,
            label: 'WATER',
            value: '${currentLog.water}',
            unit: 'L',
            diff: yesterdayLog != null ? (currentLog.water - yesterdayLog.water) : null,
            color: SomaColors.accentCyan,
          ),
          _buildTelemetryDivider(),
          _buildTelemetryChip(
            icon: Icons.bedtime_rounded,
            label: 'SLEEP',
            value: '${currentLog.sleep}',
            unit: 'h',
            diff: yesterdayLog != null ? (currentLog.sleep - yesterdayLog.sleep) : null,
            color: SomaColors.accentPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryDivider() {
    return Container(
      width: 1,
      height: 24,
      color: SomaColors.cardBorder,
    );
  }

  Widget _buildTelemetryChip({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    required double? diff,
    required Color color,
  }) {
    final bool hasDiff = diff != null;
    final bool isIncrease = hasDiff && diff > 0.05;
    final bool isDecrease = hasDiff && diff < -0.05;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: SomaFonts.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: SomaColors.onSecondaryContainer,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: SomaFonts.display(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: SomaColors.onSurface,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: SomaFonts.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: SomaColors.onSecondaryContainer,
                ),
              ),
            ],
            if (hasDiff) ...[
              const SizedBox(width: 3),
              if (isIncrease)
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 13,
                  color: SomaColors.primaryContainer,
                )
              else if (isDecrease)
                const Icon(
                  Icons.arrow_downward_rounded,
                  size: 13,
                  color: SomaColors.accentCoral,
                )
              else
                Text(
                  '—',
                  style: SomaFonts.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SomaColors.onSecondaryContainer,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMealHealthBadge(int calories, int protein) {
    final double ratio = protein > 0 ? calories / protein : (calories > 0 ? double.infinity : 0.0);
    final bool isSuperClean = protein > 0 && ratio < 10.0;
    final bool isHealthy = protein > 0 && ratio <= 20.0;

    final Color badgeColor;
    final String badgeLabel;
    final IconData badgeIcon;

    if (isSuperClean) {
      badgeColor = const Color(0xFFFFC700); // Luminous Amber Gold
      badgeLabel = 'SUPER CLEAN';
      badgeIcon = Icons.keyboard_double_arrow_up_rounded; // ⇈
    } else if (isHealthy) {
      badgeColor = const Color(0xFFD4F84D); // Electric Lime
      badgeLabel = 'HEALTHY';
      badgeIcon = Icons.arrow_upward_rounded; // ↑
    } else {
      badgeColor = const Color(0xFFFF4848); // Vivid Punchy Crimson
      badgeLabel = 'HIGH CAL';
      badgeIcon = Icons.arrow_downward_rounded; // ↓
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 3),
          Text(
            badgeLabel,
            style: SomaFonts.mono(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getItemThemeColor(LogEntry entry) {
    switch (entry.type) {
      case LogType.meal:
        final double ratio = entry.protein > 0 ? entry.calories / entry.protein : (entry.calories > 0 ? double.infinity : 0.0);
        if (entry.protein > 0 && ratio < 10.0) {
          return const Color(0xFFFFC700); // Luminous Gold - Super Clean
        } else if (entry.protein > 0 && ratio <= 20.0) {
          return const Color(0xFFD4F84D); // Electric Lime - Healthy
        } else {
          return const Color(0xFFFF4848); // Vivid Crimson - High Cal
        }
      case LogType.activity:
        final cat = entry.activityCategory?.toLowerCase() ?? '';
        final title = entry.title.toLowerCase();
        if (cat == 'exercise' || title.contains('strength') || title.contains('gym') || title.contains('lift') || entry.sets != null) {
          return const Color(0xFF00E676); // Neon Emerald - Strength / Workout
        } else if (cat == 'steps' || title.contains('steps') || title.contains('walk')) {
          return const Color(0xFF00E5FF); // Electric Cyan - Steps
        } else {
          return const Color(0xFFFF5E36); // Electric Coral-Orange - Running / Cardio
        }
      case LogType.water:
        return const Color(0xFF00E5FF); // Hyper-vibrant Cyan
      case LogType.sleep:
        return const Color(0xFFC084FC); // Vivid Electric Purple
      case LogType.digital:
        return const Color(0xFFFFB020); // Vivid Amber
    }
  }

  IconData _getItemIcon(LogEntry entry) {
    switch (entry.type) {
      case LogType.water:
        return Icons.water_drop_rounded;
      case LogType.meal:
        return Icons.restaurant_rounded;
      case LogType.activity:
        final cat = entry.activityCategory?.toLowerCase() ?? '';
        final title = entry.title.toLowerCase();
        if (cat == 'exercise' || title.contains('strength') || title.contains('gym') || title.contains('lift') || entry.sets != null) {
          return Icons.fitness_center_rounded;
        } else if (cat == 'steps' || title.contains('steps') || title.contains('walk')) {
          return Icons.directions_walk_rounded;
        } else {
          return Icons.directions_run_rounded;
        }
      case LogType.sleep:
        return Icons.bedtime_rounded;
      case LogType.digital:
        return Icons.phone_iphone_rounded;
    }
  }

  Widget _buildCategoryBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: SomaFonts.mono(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryBadges(LogEntry entry, Color themeColor) {
    switch (entry.type) {
      case LogType.meal:
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildMealHealthBadge(entry.calories, entry.protein),
            _buildMacroBadge('CAL', '${entry.calories} kcal', themeColor),
            _buildMacroBadge('PRO', '${entry.protein}g', SomaColors.onSurface),
            _buildMacroBadge('CARB', '${entry.carbs}g', SomaColors.secondary),
            _buildMacroBadge('FAT', '${entry.fats}g', SomaColors.secondary),
          ],
        );

      case LogType.activity:
        final cat = entry.activityCategory?.toLowerCase() ?? '';
        final title = entry.title.toLowerCase();
        final String actLabel;
        final IconData actIcon;

        if (cat == 'exercise' || title.contains('strength') || title.contains('gym') || title.contains('lift') || entry.sets != null) {
          actLabel = 'STRENGTH';
          actIcon = Icons.fitness_center_rounded;
        } else if (cat == 'steps' || title.contains('steps') || title.contains('walk')) {
          actLabel = 'STEPS';
          actIcon = Icons.directions_walk_rounded;
        } else {
          actLabel = entry.cardioType?.toUpperCase() ?? (entry.activityCategory?.toUpperCase() ?? 'CARDIO');
          actIcon = Icons.directions_run_rounded;
        }

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCategoryBadge(label: actLabel, icon: actIcon, color: themeColor),
            if (entry.calories > 0)
              _buildMacroBadge('BURN', '${entry.calories} kcal', themeColor),
            if (entry.durationMinutes != null && entry.durationMinutes! > 0)
              _buildMacroBadge('TIME', '${entry.durationMinutes}m', SomaColors.onSurface),
            if (entry.distanceKm != null && entry.distanceKm! > 0)
              _buildMacroBadge('DIST', '${entry.distanceKm!.toStringAsFixed(1)}km', SomaColors.secondary),
            if (entry.sets != null && entry.sets!.isNotEmpty)
              _buildMacroBadge('SETS', '${entry.sets!.length}', SomaColors.secondary),
            if (entry.count > 0)
              _buildMacroBadge('STEPS', '${entry.count}', SomaColors.onSurface),
          ],
        );

      case LogType.water:
        final amountStr = entry.amount > 0
            ? (entry.amount < 1.0 ? '${(entry.amount * 1000).toInt()} ml' : '${entry.amount.toStringAsFixed(1)} L')
            : (entry.count > 0 ? '${entry.count} ml' : 'HYDRATED');

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCategoryBadge(label: 'HYDRATION', icon: Icons.water_drop_rounded, color: themeColor),
            _buildMacroBadge('VOLUME', amountStr, themeColor),
          ],
        );

      case LogType.sleep:
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCategoryBadge(label: 'RECOVERY', icon: Icons.bedtime_rounded, color: themeColor),
            _buildMacroBadge('DURATION', '${entry.amount.toStringAsFixed(1)} hrs', themeColor),
          ],
        );

      case LogType.digital:
        final durationMin = entry.durationMinutes ?? entry.count;
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCategoryBadge(label: 'SCREEN TIME', icon: Icons.phone_iphone_rounded, color: themeColor),
            _buildMacroBadge('USAGE', '$durationMin min', themeColor),
          ],
        );
    }
  }

  Widget _buildMacroBadge(String label, String val, Color color) {
    final bool isHighlighted = color != SomaColors.secondary && color != SomaColors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.15) : SomaColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: isHighlighted
            ? Border.all(color: color.withValues(alpha: 0.40), width: 1.0)
            : Border.all(color: SomaColors.cardBorder, width: 0.8),
      ),
      child: Text(
        '$label: $val',
        style: SomaFonts.mono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
