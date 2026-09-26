enum LogType { meal, water, activity, sleep, digital }

class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogType type;
  final String title;
  final String? subtitle;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final double amount; // for water (L) or sleep (h)
  final int count; // for steps

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    this.subtitle,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.amount = 0.0,
    this.count = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'amount': amount,
      'count': count,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      type: LogType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LogType.meal,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toInt() ?? 0,
      carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      fats: (json['fats'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
