import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/detected_activity_record.dart';
import '../providers/soma_provider.dart';
import '../services/activity_transition_service.dart';
import '../theme/soma_theme.dart';

/// Modal bottom sheet presented when background sensors detect that the user
/// was running, dancing, walking, or working out while the app was closed.
class DetectedActivityPromptSheet extends StatefulWidget {
  final DetectedActivityRecord record;

  const DetectedActivityPromptSheet({
    super.key,
    required this.record,
  });

  static Future<void> show(BuildContext context, {required DetectedActivityRecord record}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DetectedActivityPromptSheet(record: record),
    );
  }

  @override
  State<DetectedActivityPromptSheet> createState() => _DetectedActivityPromptSheetState();
}

class _DetectedActivityPromptSheetState extends State<DetectedActivityPromptSheet> {
  late String _selectedType;
  late int _calculatedCalories;
  late double _distanceKm;
  late int _steps;

  final List<Map<String, dynamic>> _activityOptions = [
    {'type': 'running', 'label': 'Running', 'icon': Icons.directions_run_rounded, 'met': 9.8},
    {'type': 'dancing', 'label': 'Dancing', 'icon': Icons.music_note_rounded, 'met': 6.0},
    {'type': 'walking', 'label': 'Brisk Walk', 'icon': Icons.directions_walk_rounded, 'met': 3.8},
    {'type': 'cycling', 'label': 'Cycling', 'icon': Icons.directions_bike_rounded, 'met': 7.5},
    {'type': 'workout', 'label': 'Workout Mode', 'icon': Icons.fitness_center_rounded, 'met': 5.0},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.record.type.toLowerCase();
    // Default fallback to workout if unrecognized
    if (!_activityOptions.any((opt) => opt['type'] == _selectedType)) {
      _selectedType = 'running';
    }
    _distanceKm = widget.record.distanceKm;
    _steps = widget.record.steps;
    _calculatedCalories = widget.record.calories;

    if (_calculatedCalories <= 0) {
      _recalculateMetrics();
    }
  }

  void _recalculateMetrics() {
    final goals = context.read<SomaProvider>().userGoals;
    final weightKg = goals.weightKg ?? 75.0;
    final durationHours = widget.record.durationMinutes / 60.0;

    final option = _activityOptions.firstWhere(
      (opt) => opt['type'] == _selectedType,
      orElse: () => _activityOptions.first,
    );
    final met = option['met'] as double;
    _calculatedCalories = (met * weightKg * durationHours).round().clamp(10, 2000);

    if (_selectedType == 'dancing') {
      _distanceKm = double.parse((_distanceKm * 0.7).toStringAsFixed(2));
      if (_steps == 0) _steps = (widget.record.durationMinutes * 125);
    } else if (_selectedType == 'cycling') {
      _distanceKm = double.parse((durationHours * 18.0).toStringAsFixed(2));
      _steps = 0;
    } else if (_selectedType == 'walking') {
      _distanceKm = double.parse((durationHours * 4.8).toStringAsFixed(2));
      if (_steps == 0) _steps = (widget.record.durationMinutes * 110);
    } else if (_selectedType == 'running') {
      _distanceKm = double.parse((durationHours * 8.5).toStringAsFixed(2));
      if (_steps == 0) _steps = (widget.record.durationMinutes * 155);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final timeRangeStr =
        '${timeFormat.format(widget.record.startTime)} – ${timeFormat.format(widget.record.endTime)}';

    return Container(
      decoration: BoxDecoration(
        color: SomaColors.background.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: SomaColors.cardBorder, width: 1),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SomaColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Badge & Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SomaColors.primaryContainer.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: SomaColors.primaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: SomaColors.primaryContainer.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AUTO-DETECTED',
                                style: SomaFonts.mono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: SomaColors.primaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeRangeStr,
                              style: SomaFonts.mono(
                                fontSize: 11,
                                color: SomaColors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Unlogged Activity Detected',
                          style: SomaFonts.primary(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SomaColors.onSurface,
                          ),
                        ),
                        Text(
                          'We detected physical motion while your phone was idle. Add this to your daily log?',
                          style: SomaFonts.primary(
                            fontSize: 12,
                            color: SomaColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Metrics Grid
              Row(
                children: [
                  _buildMetricTile('DURATION', '${widget.record.durationMinutes}', 'MIN', SomaColors.secondary),
                  const SizedBox(width: 10),
                  _buildMetricTile('DISTANCE', _distanceKm.toStringAsFixed(2), 'KM', SomaColors.accentCyan),
                  const SizedBox(width: 10),
                  _buildMetricTile('CALORIES', '$_calculatedCalories', 'KCAL', SomaColors.accentCoral),
                  const SizedBox(width: 10),
                  _buildMetricTile('STEPS', '$_steps', 'STEPS', SomaColors.primaryContainer),
                ],
              ),

              const SizedBox(height: 20),

              // Activity Type Selector Chips
              Text(
                'WHAT WERE YOU DOING?',
                style: SomaFonts.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: SomaColors.onSecondaryContainer,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _activityOptions.map((opt) {
                    final type = opt['type'] as String;
                    final label = opt['label'] as String;
                    final icon = opt['icon'] as IconData;
                    final isSelected = _selectedType == type;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedType = type;
                            _recalculateMetrics();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SomaColors.primaryContainer.withValues(alpha: 0.15)
                                : SomaColors.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: isSelected ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: SomaFonts.mono(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  color: isSelected ? SomaColors.primaryContainer : SomaColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final navigator = Navigator.of(context);
                        await ActivityTransitionService.clearPendingDetectedActivity();
                        if (mounted) navigator.pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: SomaColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'DISMISS',
                        style: SomaFonts.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        final updatedRecord = widget.record.copyWith(
                          type: _selectedType,
                          calories: _calculatedCalories,
                          distanceKm: _distanceKm,
                          steps: _steps,
                          isLogged: true,
                        );

                        final provider = context.read<SomaProvider>();
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        await provider.logDetectedActivity(updatedRecord);
                        await ActivityTransitionService.clearPendingDetectedActivity();

                        if (mounted) {
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: SomaColors.surfaceContainerHigh,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: SomaColors.primaryContainer, width: 1),
                              ),
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: SomaColors.primaryContainer, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Logged ${updatedRecord.displayName} (${updatedRecord.durationMinutes}m • ~$_calculatedCalories kcal) to today\'s stats!',
                                      style: SomaFonts.primary(fontSize: 12.5, color: SomaColors.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle, size: 18, color: Colors.black),
                      label: Text(
                        'ADD TO TODAY\'S LOG',
                        style: SomaFonts.mono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SomaColors.primaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String unit, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: SomaColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SomaColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: SomaFonts.mono(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: SomaFonts.mono(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            Text(
              unit,
              style: SomaFonts.mono(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: SomaColors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
