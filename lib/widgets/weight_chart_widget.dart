import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weight_entry.dart';
import '../theme/soma_theme.dart';

enum ChartPeriod { days7, days30, days90, all }

class WeightChartWidget extends StatefulWidget {
  final List<WeightEntry> entries;
  final double? targetWeightKg;

  const WeightChartWidget({
    super.key,
    required this.entries,
    this.targetWeightKg,
  });

  @override
  State<WeightChartWidget> createState() => _WeightChartWidgetState();
}

class _WeightChartWidgetState extends State<WeightChartWidget> {
  ChartPeriod _selectedPeriod = ChartPeriod.days30;
  int? _hoveredIndex;

  List<WeightEntry> get _filteredEntries {
    if (widget.entries.isEmpty) return [];
    final sorted = List<WeightEntry>.from(widget.entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedPeriod) {
      case ChartPeriod.days7:
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case ChartPeriod.days30:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case ChartPeriod.days90:
        cutoff = now.subtract(const Duration(days: 90));
        break;
      case ChartPeriod.all:
        return sorted;
    }

    final filtered = sorted.where((e) => e.timestamp.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : sorted;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return Container(
        height: 190,
        alignment: Alignment.center,
        child: Text(
          'No weight logs for this timeframe yet.',
          style: SomaFonts.mono(fontSize: 12, color: SomaColors.onSecondaryContainer),
        ),
      );
    }

    final hoveredEntry = (_hoveredIndex != null && _hoveredIndex! < entries.length)
        ? entries[_hoveredIndex!]
        : entries.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart Period Pills and Tooltip Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${hoveredEntry.weightKg.toStringAsFixed(1)} kg',
                      style: SomaFonts.display(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: SomaColors.primaryContainer,
                      ),
                    ),
                    if (widget.targetWeightKg != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SomaColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Goal: ${widget.targetWeightKg!.toStringAsFixed(1)}kg',
                          style: SomaFonts.mono(
                            fontSize: 10,
                            color: SomaColors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(hoveredEntry.timestamp),
                  style: SomaFonts.mono(
                    fontSize: 10.5,
                    color: SomaColors.onSecondaryContainer,
                  ),
                ),
              ],
            ),

            // Timeframe toggles
            Row(
              children: [
                _buildPeriodChip('7D', ChartPeriod.days7),
                const SizedBox(width: 4),
                _buildPeriodChip('30D', ChartPeriod.days30),
                const SizedBox(width: 4),
                _buildPeriodChip('90D', ChartPeriod.days90),
                const SizedBox(width: 4),
                _buildPeriodChip('ALL', ChartPeriod.all),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Custom Canvas Chart
        SizedBox(
          height: 160,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (details) => _updateHover(details.localPosition, constraints.maxWidth, entries),
                onPanUpdate: (details) => _updateHover(details.localPosition, constraints.maxWidth, entries),
                onPanEnd: (_) => setState(() => _hoveredIndex = null),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 160),
                  painter: _WeightLineChartPainter(
                    entries: entries,
                    targetWeight: widget.targetWeightKg,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateHover(Offset localPos, double width, List<WeightEntry> entries) {
    if (entries.isEmpty) return;
    if (entries.length == 1) {
      setState(() => _hoveredIndex = 0);
      return;
    }
    final ratio = (localPos.dx / width).clamp(0.0, 1.0);
    final index = (ratio * (entries.length - 1)).round();
    setState(() => _hoveredIndex = index);
  }

  Widget _buildPeriodChip(String label, ChartPeriod period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _hoveredIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? SomaColors.primaryContainer : SomaColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: SomaFonts.mono(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black : SomaColors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _WeightLineChartPainter extends CustomPainter {
  final List<WeightEntry> entries;
  final double? targetWeight;
  final int? hoveredIndex;

  _WeightLineChartPainter({
    required this.entries,
    this.targetWeight,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final weights = entries.map((e) => e.weightKg).toList();
    if (targetWeight != null) weights.add(targetWeight!);

    double minWeight = weights.reduce(min);
    double maxWeight = weights.reduce(max);

    // Add padding to bounds
    final range = (maxWeight - minWeight);
    final padding = range == 0 ? 2.0 : range * 0.15;
    minWeight -= padding;
    maxWeight += padding;

    final chartRange = maxWeight - minWeight;

    // Helper coordinates
    Offset getPoint(int index) {
      final x = entries.length == 1
          ? size.width / 2
          : (index / (entries.length - 1)) * size.width;
      final y = size.height - ((entries[index].weightKg - minWeight) / chartRange) * size.height;
      return Offset(x, y.clamp(10.0, size.height - 10));
    }

    // Draw Target Weight Line if present
    if (targetWeight != null) {
      final targetY = size.height - ((targetWeight! - minWeight) / chartRange) * size.height;
      final targetPaint = Paint()
        ..color = SomaColors.primaryContainer.withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Draw dashed line
      const dashWidth = 5.0;
      const dashSpace = 4.0;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, targetY),
          Offset(min(startX + dashWidth, size.width), targetY),
          targetPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    if (entries.length == 1) {
      final pt = getPoint(0);
      final dotPaint = Paint()..color = SomaColors.primaryContainer;
      canvas.drawCircle(pt, 5, dotPaint);
      return;
    }

    final points = List.generate(entries.length, (i) => getPoint(i));

    // Smooth Bezier Path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // Gradient Fill Under Curve
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SomaColors.primaryContainer.withValues(alpha: 0.35),
          SomaColors.primaryContainer.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Glowing Line Paint
    final linePaint = Paint()
      ..color = SomaColors.primaryContainer
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw Data Point Dots & Hover Indicator
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isHovered = hoveredIndex == i;

      if (isHovered) {
        // Vertical indicator line
        final guidePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(pt.dx, 0), Offset(pt.dx, size.height), guidePaint);

        // Hovered pulsing outer ring
        canvas.drawCircle(
          pt,
          8,
          Paint()..color = SomaColors.primaryContainer.withValues(alpha: 0.35),
        );
        canvas.drawCircle(pt, 4.5, Paint()..color = SomaColors.primaryContainer);
        canvas.drawCircle(pt, 2, Paint()..color = Colors.black);
      } else if (i == 0 || i == points.length - 1 || points.length <= 7) {
        canvas.drawCircle(pt, 3.5, Paint()..color = SomaColors.surface);
        canvas.drawCircle(pt, 2, Paint()..color = SomaColors.primaryContainer);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLineChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.targetWeight != targetWeight;
  }
}
