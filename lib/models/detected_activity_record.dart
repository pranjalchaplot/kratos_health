class DetectedActivityRecord {
  final String type; // 'running', 'walking', 'cycling', 'dancing', 'workout'
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int durationSeconds;
  final double distanceKm;
  final int calories;
  final int steps;
  final bool isLogged;

  const DetectedActivityRecord({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.durationSeconds,
    required this.distanceKm,
    required this.calories,
    required this.steps,
    this.isLogged = false,
  });

  factory DetectedActivityRecord.fromMap(Map<dynamic, dynamic> map) {
    final startMillis = (map['startTimeMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final endMillis = (map['endTimeMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final durationMins = (map['durationMinutes'] as num?)?.toInt() ?? 0;
    final durationSecs = (map['durationSeconds'] as num?)?.toInt() ?? (durationMins * 60);

    return DetectedActivityRecord(
      type: (map['type']?.toString() ?? 'running').toLowerCase(),
      startTime: DateTime.fromMillisecondsSinceEpoch(startMillis),
      endTime: DateTime.fromMillisecondsSinceEpoch(endMillis),
      durationMinutes: durationMins,
      durationSeconds: durationSecs,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      isLogged: map['isLogged'] == true,
    );
  }

  String get displayName {
    switch (type.toLowerCase()) {
      case 'running':
        return 'Running';
      case 'walking':
        return 'Brisk Walk';
      case 'cycling':
        return 'Cycling';
      case 'dancing':
        return 'Dancing';
      case 'workout':
      default:
        return 'Workout Mode';
    }
  }

  DetectedActivityRecord copyWith({
    String? type,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    int? durationSeconds,
    double? distanceKm,
    int? calories,
    int? steps,
    bool? isLogged,
  }) {
    return DetectedActivityRecord(
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      calories: calories ?? this.calories,
      steps: steps ?? this.steps,
      isLogged: isLogged ?? this.isLogged,
    );
  }
}
