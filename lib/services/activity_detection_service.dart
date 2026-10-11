import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';

enum DetectedActivityType { running, dancing, workout }

class LiveActivityState {
  final bool isActive;
  final bool isPaused;
  final int elapsedSeconds;
  final DetectedActivityType activityType;
  final bool isAutoDetected;
  final int currentCadenceSpm;
  final int sessionSteps;
  final int caloriesBurned;
  final double distanceKm;

  LiveActivityState({
    required this.isActive,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.activityType,
    required this.isAutoDetected,
    required this.currentCadenceSpm,
    required this.sessionSteps,
    required this.caloriesBurned,
    required this.distanceKm,
  });

  String get typeName {
    switch (activityType) {
      case DetectedActivityType.running:
        return 'Running';
      case DetectedActivityType.dancing:
        return 'Dancing';
      case DetectedActivityType.workout:
        return 'Workout Mode';
    }
  }
}

class ActivityDetectionService {
  static final ActivityDetectionService _instance = ActivityDetectionService._internal();
  factory ActivityDetectionService() => _instance;
  ActivityDetectionService._internal();

  Timer? _tickerTimer;
  StreamSubscription<StepCount>? _stepSubscription;

  bool _isActive = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  DetectedActivityType _activityType = DetectedActivityType.workout;
  bool _isManualOverride = false;
  int _initialSensorSteps = -1;
  int _sessionSteps = 0;
  int _currentCadenceSpm = 0;
  double _userWeightKg = 75.0;

  final List<DateTime> _recentStepTimestamps = [];
  final _stateController = StreamController<LiveActivityState>.broadcast();

  Stream<LiveActivityState> get stateStream => _stateController.stream;

  LiveActivityState get currentState => LiveActivityState(
        isActive: _isActive,
        isPaused: _isPaused,
        elapsedSeconds: _elapsedSeconds,
        activityType: _activityType,
        isAutoDetected: !_isManualOverride,
        currentCadenceSpm: _currentCadenceSpm,
        sessionSteps: _sessionSteps,
        caloriesBurned: _calculateCurrentCalories(),
        distanceKm: _calculateDistanceKm(),
      );

  void startSession({
    DetectedActivityType initialType = DetectedActivityType.workout,
    double userWeightKg = 75.0,
    bool manualLock = false,
  }) {
    _isActive = true;
    _isPaused = false;
    _elapsedSeconds = 0;
    _activityType = initialType;
    _isManualOverride = manualLock;
    _initialSensorSteps = -1;
    _sessionSteps = 0;
    _currentCadenceSpm = 0;
    _userWeightKg = userWeightKg;
    _recentStepTimestamps.clear();

    _initPedometer();

    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _elapsedSeconds++;
        _cleanRecentTimestamps();
        _notifyState();
      }
    });

    _notifyState();
  }

  void pauseSession() {
    _isPaused = true;
    _notifyState();
  }

  void resumeSession() {
    _isPaused = false;
    _notifyState();
  }

  void setManualType(DetectedActivityType type) {
    _activityType = type;
    _isManualOverride = true;
    _notifyState();
  }

  void enableAutoDetection() {
    _isManualOverride = false;
    _notifyState();
  }

  LiveActivityState finishSession() {
    final finalState = currentState;
    _isActive = false;
    _isPaused = false;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _notifyState();
    return finalState;
  }

  void _initPedometer() {
    try {
      _stepSubscription?.cancel();
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepReceived,
        onError: (err) {
          debugPrint('Live activity step error: $err');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Could not bind pedometer for live activity: $e');
    }
  }

  void _onStepReceived(StepCount event) {
    if (!_isActive || _isPaused) return;

    if (_initialSensorSteps < 0) {
      _initialSensorSteps = event.steps;
    }

    final newSessionSteps = (event.steps - _initialSensorSteps).clamp(0, 999999);
    final delta = newSessionSteps - _sessionSteps;
    _sessionSteps = newSessionSteps;

    final now = DateTime.now();
    for (int i = 0; i < delta.clamp(1, 10); i++) {
      _recentStepTimestamps.add(now);
    }

    _calculateCadenceAndAutoDetect();
    _notifyState();
  }

  void _cleanRecentTimestamps() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 15));
    _recentStepTimestamps.removeWhere((t) => t.isBefore(cutoff));
    if (_recentStepTimestamps.isEmpty) {
      _currentCadenceSpm = 0;
    }
  }

  void _calculateCadenceAndAutoDetect() {
    _cleanRecentTimestamps();
    if (_recentStepTimestamps.length >= 3) {
      // Steps in last 15 seconds multiplied by 4 = steps per minute
      _currentCadenceSpm = (_recentStepTimestamps.length * 4);

      if (!_isManualOverride) {
        if (_currentCadenceSpm >= 145) {
          _activityType = DetectedActivityType.running;
        } else if (_currentCadenceSpm >= 105 && _currentCadenceSpm < 145) {
          _activityType = DetectedActivityType.dancing;
        } else if (_currentCadenceSpm > 0 && _currentCadenceSpm < 105) {
          _activityType = DetectedActivityType.workout;
        }
      }
    }
  }

  int _calculateCurrentCalories() {
    // MET values: Running ~ 9.8, Dancing ~ 6.0, Workout ~ 5.0
    double met = 5.0;
    switch (_activityType) {
      case DetectedActivityType.running:
        met = 9.8;
        break;
      case DetectedActivityType.dancing:
        met = 6.0;
        break;
      case DetectedActivityType.workout:
        met = 5.0;
        break;
    }
    final durationHours = _elapsedSeconds / 3600.0;
    return (met * _userWeightKg * durationHours).round();
  }

  double _calculateDistanceKm() {
    // Approximate stride length 0.762m
    return double.parse(((_sessionSteps * 0.762) / 1000.0).toStringAsFixed(2));
  }

  void _notifyState() {
    if (!_stateController.isClosed) {
      _stateController.add(currentState);
    }
  }
}
