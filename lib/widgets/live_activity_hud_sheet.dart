import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/soma_provider.dart';
import '../services/activity_detection_service.dart';
import '../theme/soma_theme.dart';

class LiveActivityHudSheet extends StatefulWidget {
  final DetectedActivityType initialType;

  const LiveActivityHudSheet({
    super.key,
    this.initialType = DetectedActivityType.workout,
  });

  static void show(BuildContext context, {DetectedActivityType initialType = DetectedActivityType.workout}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LiveActivityHudSheet(initialType: initialType),
    );
  }

  @override
  State<LiveActivityHudSheet> createState() => _LiveActivityHudSheetState();
}

class _LiveActivityHudSheetState extends State<LiveActivityHudSheet> {
  final ActivityDetectionService _detectionService = ActivityDetectionService();

  @override
  void initState() {
    super.initState();
    final goals = context.read<SomaProvider>().userGoals;
    final userWeight = goals.weightKg ?? 75.0;

    // Start session if not already running
    if (!_detectionService.currentState.isActive) {
      _detectionService.startSession(
        initialType: widget.initialType,
        userWeightKg: userWeight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LiveActivityState>(
      stream: _detectionService.stateStream,
      initialData: _detectionService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _detectionService.currentState;
        final elapsedMinutes = (state.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
        final elapsedSecs = (state.elapsedSeconds % 60).toString().padLeft(2, '0');

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

                  // Header with Auto-detection Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SomaColors.primaryContainer.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.sensors_rounded,
                              color: SomaColors.primaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIVE ACTIVITY CLIENT',
                                style: SomaFonts.display(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: SomaColors.onSurface,
                                ),
                              ),
                              Text(
                                state.isAutoDetected ? 'AUTO-CADENCE CLASSIFIER ACTIVE' : 'MANUAL MODE LOCKED',
                                style: SomaFonts.mono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: SomaColors.primaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: SomaColors.onSecondaryContainer),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mode Selector Tabs (Running, Dancing, Workout Mode)
                  Row(
                    children: [
                      _buildModeButton(
                        'RUNNING',
                        DetectedActivityType.running,
                        Icons.directions_run_rounded,
                        state.activityType == DetectedActivityType.running,
                      ),
                      const SizedBox(width: 8),
                      _buildModeButton(
                        'DANCING',
                        DetectedActivityType.dancing,
                        Icons.music_note_rounded,
                        state.activityType == DetectedActivityType.dancing,
                      ),
                      const SizedBox(width: 8),
                      _buildModeButton(
                        'WORKOUT',
                        DetectedActivityType.workout,
                        Icons.fitness_center_rounded,
                        state.activityType == DetectedActivityType.workout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Big Stopwatch Timer Display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: SomaColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SomaColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$elapsedMinutes:$elapsedSecs',
                          style: SomaFonts.display(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: state.isPaused ? SomaColors.onSecondaryContainer : SomaColors.primaryContainer,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          state.isPaused ? 'SESSION PAUSED' : 'TRACKING IN REAL-TIME',
                          style: SomaFonts.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: state.isPaused ? Colors.orangeAccent : SomaColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Metric Telemetry Tiles
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'CADENCE',
                          '${state.currentCadenceSpm}',
                          'SPM',
                          SomaColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          'EST. BURN',
                          '${state.caloriesBurned}',
                          'kcal',
                          SomaColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          'STEPS',
                          '${state.sessionSteps}',
                          'steps',
                          SomaColors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Controls: Pause/Resume and Finish Session
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (state.isPaused) {
                              _detectionService.resumeSession();
                            } else {
                              _detectionService.pauseSession();
                            }
                          },
                          icon: Icon(
                            state.isPaused ? Icons.play_arrow : Icons.pause,
                            size: 18,
                            color: SomaColors.onSurface,
                          ),
                          label: Text(
                            state.isPaused ? 'RESUME' : 'PAUSE',
                            style: SomaFonts.mono(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: SomaColors.onSurface,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: SomaColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            final finalSession = _detectionService.finishSession();
                            final provider = context.read<SomaProvider>();
                            final navigator = Navigator.of(context);
                            await provider.logLiveActivitySession(finalSession);
                            if (mounted) navigator.pop();
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.black),
                          label: Text(
                            'FINISH & LOG SESSION',
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
      },
    );
  }

  Widget _buildModeButton(String label, DetectedActivityType type, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _detectionService.setManualType(type);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? SomaColors.primaryContainer.withValues(alpha: 0.15)
                : SomaColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? SomaColors.primaryContainer : SomaColors.cardBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: SomaFonts.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? SomaColors.primaryContainer : SomaColors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String unit, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: SomaColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SomaColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SomaFonts.mono(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: SomaColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: SomaFonts.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: SomaFonts.mono(
                  fontSize: 10,
                  color: SomaColors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
