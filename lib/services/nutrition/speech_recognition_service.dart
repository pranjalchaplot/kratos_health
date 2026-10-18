import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  static final SpeechRecognitionService instance = SpeechRecognitionService._internal();

  SpeechRecognitionService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isListening = false;
  double _soundLevel = 0.0;

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  double get soundLevel => _soundLevel;

  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    try {
      _isAvailable = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('SpeechRecognition error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (String status) {
          _isListening = (status == 'listening');
        },
      );
      _isInitialized = true;
      return _isAvailable;
    } catch (e) {
      debugPrint('Speech recognition initialization failed: $e');
      _isInitialized = true;
      _isAvailable = false;
      return false;
    }
  }

  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    void Function(String error)? onError,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        onError?.call('Speech recognition is not available or permission was denied.');
        return false;
      }
    }

    if (!_isAvailable) {
      onError?.call('Speech recognition is not available on this device.');
      return false;
    }

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (double level) {
          _soundLevel = level;
          onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_IN', // Default to Indian English for culinary terminology
          cancelOnError: true,
          partialResults: true,
        ),
      );
      _isListening = true;
      return true;
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      onError?.call('Could not start listening: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('Error stopping speech: $e');
      } finally {
        _isListening = false;
      }
    }
  }

  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('Error cancelling speech: $e');
    } finally {
      _isListening = false;
    }
  }
}
