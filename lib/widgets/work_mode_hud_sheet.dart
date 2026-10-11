import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/work_mode_service.dart';
import '../theme/soma_theme.dart';

class WorkModeHudSheet extends StatefulWidget {
  const WorkModeHudSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WorkModeHudSheet(),
    );
  }

  @override
  State<WorkModeHudSheet> createState() => _WorkModeHudSheetState();
}

class _WorkModeHudSheetState extends State<WorkModeHudSheet> {
  final WorkModeService _workModeService = WorkModeService();
  int _selectedMinutes = 25;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkModeState>(
      stream: _workModeService.stateStream,
      initialData: _workModeService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _workModeService.currentState;
        final eyeMins = state.nextEyeStretchSeconds ~/ 60;
        final eyeSecs = (state.nextEyeStretchSeconds % 60).toString().padLeft(2, '0');

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

                  // Sheet Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SomaColors.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              color: SomaColors.accentCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WORK & FOCUS PROTOCOL',
                                style: SomaFonts.display(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: SomaColors.onSurface,
                                ),
                              ),
                              Text(
                                'POMODORO & 20-20-20 EYE STRETCH',
                                style: SomaFonts.mono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: SomaColors.accentCyan,
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
                  const SizedBox(height: 18),

                  // Timer Dial Container
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: SomaColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: SomaColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        // Phase Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: state.phase == WorkPhase.focus
                                ? SomaColors.accentCyan.withValues(alpha: 0.2)
                                : SomaColors.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.phaseLabel,
                            style: SomaFonts.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: state.phase == WorkPhase.focus
                                  ? SomaColors.accentCyan
                                  : SomaColors.primaryContainer,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Time Display
                        Text(
                          state.formattedTime,
                          style: SomaFonts.display(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            color: state.isActive && !state.isPaused
                                ? SomaColors.onSurface
                                : SomaColors.onSecondaryContainer,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Progress Indicator Bar
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: SomaColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: state.progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: SomaColors.accentCyan,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Completed Cycles: ${state.completedPomodoros} • Deep Focus State',
                          style: SomaFonts.mono(
                            fontSize: 11,
                            color: SomaColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Preset Selector (25m / 50m) if inactive
                  if (!state.isActive) ...[
                    Row(
                      children: [
                        _buildDurationChip('25m Standard Pomodoro', 25),
                        const SizedBox(width: 10),
                        _buildDurationChip('50m Deep Focus Block', 50),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 20-20-20 Eye Stretch Protocol Tile
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: SomaColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SomaColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, size: 20, color: SomaColors.accentCyan),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '20-20-20 Eye Stretch Alert',
                                  style: SomaFonts.primary(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  state.isActive
                                      ? 'Next interval in $eyeMins:$eyeSecs'
                                      : 'Alert every 20 min (20 ft for 20 sec)',
                                  style: SomaFonts.mono(
                                    fontSize: 10.5,
                                    color: SomaColors.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: state.eyeStretchEnabled,
                          activeThumbColor: SomaColors.accentCyan,
                          activeTrackColor: SomaColors.accentCyan.withValues(alpha: 0.3),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            _workModeService.toggleEyeStretch(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  if (!state.isActive) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _workModeService.startFocus(
                          minutes: _selectedMinutes,
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                      label: Text(
                        'START WORK MODE (${_selectedMinutes}M)',
                        style: SomaFonts.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SomaColors.accentCyan,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        // Pause / Resume
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              if (state.isPaused) {
                                _workModeService.resume();
                              } else {
                                _workModeService.pause();
                              }
                            },
                            icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                            label: Text(
                              state.isPaused ? 'RESUME' : 'PAUSE',
                              style: SomaFonts.mono(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: SomaColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Skip Phase
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _workModeService.skipToNextPhase();
                            },
                            icon: const Icon(Icons.skip_next, size: 18),
                            label: Text(
                              'SKIP PHASE',
                              style: SomaFonts.mono(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: SomaColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Stop / Exit
                        IconButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _workModeService.stop();
                          },
                          icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 26),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDurationChip(String label, int minutes) {
    final isSelected = _selectedMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedMinutes = minutes);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? SomaColors.accentCyan.withValues(alpha: 0.15)
                : SomaColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? SomaColors.accentCyan : SomaColors.cardBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: SomaFonts.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? SomaColors.accentCyan : SomaColors.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
