import 'package:flutter/material.dart';
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
        title: const Text(
          'ACTIVITY & NUTRITION LOGS',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.36,
            color: SomaColors.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: SomaColors.primaryContainer),
            onPressed: () => QuickLogModal.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SomaColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SomaColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: SomaColors.onSurface),
                  onPressed: () {
                    provider.selectDate(provider.selectedDate.subtract(const Duration(days: 1)));
                  },
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SomaColors.primaryContainer,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: SomaColors.onSurface),
                  onPressed: () {
                    provider.selectDate(provider.selectedDate.add(const Duration(days: 1)));
                  },
                ),
              ],
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['ALL', 'MEALS', 'WATER', 'ACTIVITY', 'SLEEP'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: SomaColors.primaryContainer,
                    backgroundColor: SomaColors.cardBackground,
                    side: BorderSide(
                      color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? SomaColors.background : SomaColors.onSurface,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),

          // Entries List
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: SomaColors.onSecondaryContainer.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No logs recorded for this day.',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 16,
                            color: SomaColors.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SomaColors.primaryContainer,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => QuickLogModal.show(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Entry'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
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
        icon = Icons.water_drop;
        iconColor = Colors.cyanAccent;
        break;
      case LogType.meal:
        icon = Icons.restaurant;
        iconColor = SomaColors.primaryContainer;
        break;
      case LogType.activity:
        icon = Icons.fitness_center;
        iconColor = SomaColors.secondary;
        break;
      case LogType.sleep:
        icon = Icons.bed;
        iconColor = Colors.purpleAccent;
        break;
      case LogType.digital:
        icon = Icons.phone_iphone;
        iconColor = Colors.amberAccent;
        break;
    }

    final timeStr = DateFormat('h:mm a').format(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
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
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SomaColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: SomaColors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (entry.subtitle != null)
                  Text(
                    entry.subtitle!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 13,
                      color: SomaColors.onSecondaryContainer,
                    ),
                  ),
                if (entry.type == LogType.meal) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildMacroBadge('CAL', '${entry.calories} kcal'),
                      _buildMacroBadge('PRO', '${entry.protein}g'),
                      _buildMacroBadge('CARB', '${entry.carbs}g'),
                      _buildMacroBadge('FAT', '${entry.fats}g'),
                    ],
                  ),
                ] else if (entry.type == LogType.activity) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildMacroBadge('ACTIVE BURN', '${entry.calories} kcal'),
                      if (entry.activityCategory != null)
                        _buildMacroBadge('TYPE', entry.activityCategory!.toUpperCase()),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
            onPressed: () {
              provider.deleteLogEntry(entry.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, String val) {
    return Text(
      '$label: $val',
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: SomaColors.primaryContainer,
      ),
    );
  }
}
