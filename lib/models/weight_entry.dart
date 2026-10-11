import 'dart:convert';

class WeightEntry {
  final String id;
  final DateTime timestamp;
  final double weightKg;
  final String? notes;

  WeightEntry({
    required this.id,
    required this.timestamp,
    required this.weightKg,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'weightKg': weightKg,
      'notes': notes,
    };
  }

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
      notes: json['notes'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory WeightEntry.decode(String str) => WeightEntry.fromJson(jsonDecode(str));
}
