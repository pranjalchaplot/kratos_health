import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/soma_provider.dart';
import '../theme/soma_theme.dart';

class LogWeightModal extends StatefulWidget {
  final double initialWeight;

  const LogWeightModal({super.key, required this.initialWeight});

  static void show(BuildContext context) {
    final provider = context.read<SomaProvider>();
    final currentWeight = provider.latestWeightKg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogWeightModal(initialWeight: currentWeight),
    );
  }

  @override
  State<LogWeightModal> createState() => _LogWeightModalState();
}

class _LogWeightModalState extends State<LogWeightModal> {
  late double _weight;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _weight = widget.initialWeight > 0 ? widget.initialWeight : 75.0;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SomaProvider>();
    final history = provider.weightHistory;

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

              // Title and toggle history
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
                          Icons.monitor_weight_outlined,
                          color: SomaColors.primaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'LOG BODY WEIGHT',
                        style: SomaFonts.display(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SomaColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showHistory = !_showHistory);
                    },
                    icon: Icon(
                      _showHistory ? Icons.tune : Icons.history,
                      size: 16,
                      color: SomaColors.primaryContainer,
                    ),
                    label: Text(
                      _showHistory ? 'INPUT' : 'HISTORY',
                      style: SomaFonts.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_showHistory) ...[
                // History List View
                Text(
                  'WEIGHT RECORD HISTORY',
                  style: SomaFonts.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SomaColors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: history.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No historical entries logged yet.',
                              style: SomaFonts.mono(
                                fontSize: 12,
                                color: SomaColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const Divider(
                            color: SomaColors.cardBorder,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final entry = history[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              title: Text(
                                '${entry.weightKg.toStringAsFixed(1)} kg',
                                style: SomaFonts.display(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: SomaColors.primaryContainer,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('MMM d, yyyy • h:mm a').format(entry.timestamp) +
                                    (entry.notes != null && entry.notes!.isNotEmpty ? ' (${entry.notes})' : ''),
                                style: SomaFonts.mono(
                                  fontSize: 11,
                                  color: SomaColors.onSecondaryContainer,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await provider.deleteWeightEntry(entry.id);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ] else ...[
                // Weight Stepper & Display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: SomaColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SomaColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _weight.toStringAsFixed(1),
                            style: SomaFonts.display(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: SomaColors.primaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'kg',
                            style: SomaFonts.mono(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: SomaColors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Fine Micro Steppers (-1kg, -0.1kg, +0.1kg, +1kg)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStepButton('-1.0', () => _adjustWeight(-1.0)),
                          const SizedBox(width: 8),
                          _buildStepButton('-0.1', () => _adjustWeight(-0.1)),
                          const SizedBox(width: 16),
                          _buildStepButton('+0.1', () => _adjustWeight(0.1)),
                          const SizedBox(width: 8),
                          _buildStepButton('+1.0', () => _adjustWeight(1.0)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Slider Control
                      Slider(
                        value: _weight.clamp(30.0, 180.0),
                        min: 30.0,
                        max: 180.0,
                        divisions: 1500,
                        activeColor: SomaColors.primaryContainer,
                        inactiveColor: SomaColors.surfaceContainerHigh,
                        onChanged: (val) {
                          setState(() {
                            _weight = double.parse(val.toStringAsFixed(1));
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Date Picker & Optional Note
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: SomaColors.primaryContainer,
                                  onPrimary: Colors.black,
                                  surface: SomaColors.cardBackground,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: SomaColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SomaColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: SomaColors.primaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, yyyy').format(_selectedDate),
                                style: SomaFonts.mono(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _notesController,
                        style: SomaFonts.primary(color: SomaColors.onSurface, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Note (optional)',
                          hintStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer, fontSize: 13),
                          filled: true,
                          fillColor: SomaColors.cardBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: SomaColors.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: SomaColors.cardBorder),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Save Button
                ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final navigator = Navigator.of(context);
                    await provider.logWeight(
                      _weight,
                      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                      timestamp: _selectedDate,
                    );
                    if (mounted) navigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SomaColors.primaryContainer,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'RECORD WEIGHT ENTRY',
                    style: SomaFonts.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _adjustWeight(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _weight = double.parse((_weight + delta).toStringAsFixed(1));
    });
  }

  Widget _buildStepButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SomaColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SomaColors.cardBorder),
        ),
        child: Text(
          text,
          style: SomaFonts.mono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SomaColors.onSurface,
          ),
        ),
      ),
    );
  }
}
