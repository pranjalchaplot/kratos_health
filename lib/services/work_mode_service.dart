import 'dart:async';
import 'notification_service.dart';

enum WorkPhase { focus, shortBreak, longBreak, eyeStretch }

class WorkModeState {
  final bool isActive;
  final bool isPaused;
  final WorkPhase phase;
  final int remainingSeconds;
  final int totalSeconds;
  final int completedPomodoros;
  final bool eyeStretchEnabled;
  final int nextEyeStretchSeconds;

  WorkModeState({
    required this.isActive,
    required this.isPaused,
    required this.phase,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.completedPomodoros,
    required this.eyeStretchEnabled,
    required this.nextEyeStretchSeconds,
  });

  String get phaseLabel {
    switch (phase) {
      case WorkPhase.focus:
        return 'FOCUS';
      case WorkPhase.shortBreak:
        return 'SHORT BREAK';
      case WorkPhase.longBreak:
        return 'LONG BREAK';
      case WorkPhase.eyeStretch:
        return 'EYE STRETCH';
    }
  }

  String get formattedTime {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get progress => totalSeconds > 0 ? (1.0 - (remainingSeconds / totalSeconds)).clamp(0.0, 1.0) : 0.0;
}

class WorkModeService {
  static final WorkModeService _instance = WorkModeService._internal();
  factory WorkModeService() => _instance;
  WorkModeService._internal();

  Timer? _tickerTimer;
  bool _isActive = false;
  bool _isPaused = false;
  WorkPhase _phase = WorkPhase.focus;
  int _remainingSeconds = 25 * 60;
  int _totalSeconds = 25 * 60;
  int _completedPomodoros = 0;
  bool _eyeStretchEnabled = true;
  int _nextEyeStretchSeconds = 20 * 60; // 20 minutes countdown

  final _stateController = StreamController<WorkModeState>.broadcast();
  Stream<WorkModeState> get stateStream => _stateController.stream;

  WorkModeState get currentState => WorkModeState(
        isActive: _isActive,
        isPaused: _isPaused,
        phase: _phase,
        remainingSeconds: _remainingSeconds,
        totalSeconds: _totalSeconds,
        completedPomodoros: _completedPomodoros,
        eyeStretchEnabled: _eyeStretchEnabled,
        nextEyeStretchSeconds: _nextEyeStretchSeconds,
      );

  void startFocus({int minutes = 25, bool enableEyeStretch = true}) {
    _isActive = true;
    _isPaused = false;
    _phase = WorkPhase.focus;
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _eyeStretchEnabled = enableEyeStretch;
    _nextEyeStretchSeconds = 20 * 60;

    _startTimer();
    _notify();
  }

  void pause() {
    _isPaused = true;
    _notify();
  }

  void resume() {
    _isPaused = false;
    _notify();
  }

  void stop() {
    _isActive = false;
    _isPaused = false;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _phase = WorkPhase.focus;
    _remainingSeconds = 25 * 60;
    _totalSeconds = 25 * 60;
    _notify();
  }

  void toggleEyeStretch(bool enabled) {
    _eyeStretchEnabled = enabled;
    _notify();
  }

  void skipToNextPhase() {
    if (_phase == WorkPhase.focus) {
      _completedPomodoros++;
      final isLong = _completedPomodoros % 4 == 0;
      _phase = isLong ? WorkPhase.longBreak : WorkPhase.shortBreak;
      _totalSeconds = isLong ? 15 * 60 : 5 * 60;
      _remainingSeconds = _totalSeconds;
    } else {
      _phase = WorkPhase.focus;
      _totalSeconds = 25 * 60;
      _remainingSeconds = _totalSeconds;
    }
    _notify();
  }

  void _startTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isActive) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _onPhaseCompleted();
        }

        // Eye stretch check during focus
        if (_phase == WorkPhase.focus && _eyeStretchEnabled) {
          if (_nextEyeStretchSeconds > 0) {
            _nextEyeStretchSeconds--;
          } else {
            _triggerEyeStretchAlert();
            _nextEyeStretchSeconds = 20 * 60;
          }
        }

        _notify();
      }
    });
  }

  void _onPhaseCompleted() {
    if (_phase == WorkPhase.focus) {
      _completedPomodoros++;
      final isLong = _completedPomodoros % 4 == 0;
      _phase = isLong ? WorkPhase.longBreak : WorkPhase.shortBreak;
      _totalSeconds = isLong ? 15 * 60 : 5 * 60;
      _remainingSeconds = _totalSeconds;

      // Trigger Completion Notification
      NotificationService().showNotification(
        id: 7001,
        title: '🎯 SOMA Focus Complete',
        body: 'Pomodoro complete! Time for a ${isLong ? "15-minute long" : "5-minute"} cognitive rest.',
        payload: 'work_mode_break',
      );
    } else {
      _phase = WorkPhase.focus;
      _totalSeconds = 25 * 60;
      _remainingSeconds = _totalSeconds;

      NotificationService().showNotification(
        id: 7002,
        title: '⚡ SOMA Focus Time',
        body: 'Break ended. Ready to initiate deep focus block.',
        payload: 'work_mode_focus',
      );
    }
  }

  void _triggerEyeStretchAlert() {
    NotificationService().showNotification(
      id: 7003,
      title: '👀 20-20-20 Eye Stretch Protocol',
      body: 'Look at an object 20 feet away for 20 seconds to decompress ciliary muscles.',
      payload: 'eye_stretch_alert',
    );
  }

  void _notify() {
    if (!_stateController.isClosed) {
      _stateController.add(currentState);
    }
  }
}
