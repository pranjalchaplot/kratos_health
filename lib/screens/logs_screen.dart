import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/soma_provider.dart';
import '../models/log_entry.dart';
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
    IconData icon;
    Color iconColor;

    switch (entry.type) {
      case LogType.water:
        icon = Icons.water_drop_rounded;
        iconColor = SomaColors.accentCyan;
        break;
      case LogType.meal:
        icon = Icons.restaurant_rounded;
        iconColor = SomaColors.primaryContainer;
        break;
      case LogType.activity:
        icon = Icons.fitness_center_rounded;
        iconColor = SomaColors.accentCoral;
        break;
      case LogType.sleep:
        icon = Icons.bedtime_rounded;
        iconColor = SomaColors.accentPurple;
        break;
      case LogType.digital:
        icon = Icons.phone_iphone_rounded;
        iconColor = SomaColors.accentAmber;
        break;
    }

    final timeStr = DateFormat('h:mm a').format(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                if (entry.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.subtitle!,
                    style: SomaFonts.primary(
                      fontSize: 12.5,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                ],
                if (entry.type == LogType.meal) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildMacroBadge('CAL', '${entry.calories} kcal', SomaColors.primaryContainer),
                      _buildMacroBadge('PRO', '${entry.protein}g', SomaColors.onSurface),
                      _buildMacroBadge('CARB', '${entry.carbs}g', SomaColors.secondary),
                      _buildMacroBadge('FAT', '${entry.fats}g', SomaColors.secondary),
                    ],
                  ),
                ] else if (entry.type == LogType.activity) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildMacroBadge('BURN', '${entry.calories} kcal', SomaColors.accentCoral),
                      if (entry.activityCategory != null)
                        _buildMacroBadge('TYPE', entry.activityCategory!.toUpperCase(), SomaColors.primaryContainer),
                    ],
                  ),
                ],
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

  Widget _buildMacroBadge(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SomaColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
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
