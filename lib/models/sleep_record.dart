enum SleepDataSource {
  androidSleepApi,
  healthConnect,
  manual,
}

class SleepRecord {
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final SleepDataSource source;
  final int? confidence;
  final Map<String, double>? stages; // deep, light, rem, awake (hours)
  final int? status;

  SleepRecord({
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.source,
    this.confidence,
    this.stages,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationHours': durationHours,
      'source': source.name,
      'confidence': confidence,
      'stages': stages,
      'status': status,
    };
  }

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    return SleepRecord(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationHours: (json['durationHours'] as num).toDouble(),
      source: SleepDataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => SleepDataSource.androidSleepApi,
      ),
      confidence: (json['confidence'] as num?)?.toInt(),
      stages: (json['stages'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      status: (json['status'] as num?)?.toInt(),
    );
  }
}
