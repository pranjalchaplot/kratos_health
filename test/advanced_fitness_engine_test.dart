import 'package:flutter_test/flutter_test.dart';
import 'package:soma_app/models/exercise_set.dart';
import 'package:soma_app/models/weight_entry.dart';
import 'package:soma_app/models/workout_routine.dart';
import 'package:soma_app/services/progressive_overload_service.dart';
import 'package:soma_app/services/work_mode_service.dart';

void main() {
  group('ProgressiveOverloadService Tests', () {
    test('Compound lift with RPE 7.0 and Explosive tempo recommends +2.5kg overload', () {
      final initialSets = [
        ExerciseSet(setNumber: 1, reps: 10, weightKg: 60.0),
        ExerciseSet(setNumber: 2, reps: 10, weightKg: 60.0),
      ];

      final overload = ProgressiveOverloadService.computeOverload(
        exerciseName: 'Bench Press',
        previousSets: initialSets,
        rpe: 7.0,
        velocity: 'Explosive',
      );

      expect(overload.type, OverloadType.weightIncrease);
      expect(overload.deltaWeightKg, 2.5);
      expect(overload.suggestedSets.first.weightKg, 62.5);
      expect(overload.suggestedSets.first.reps, 10);
    });

    test('Isolation lift with RPE 7.5 recommends +1.25kg overload', () {
      final initialSets = [
        ExerciseSet(setNumber: 1, reps: 12, weightKg: 14.0),
      ];

      final overload = ProgressiveOverloadService.computeOverload(
        exerciseName: 'Lateral Raise',
        previousSets: initialSets,
        rpe: 7.5,
        velocity: 'Controlled',
      );

      expect(overload.type, OverloadType.weightIncrease);
      expect(overload.deltaWeightKg, 1.25);
      expect(overload.suggestedSets.first.weightKg, 15.25);
    });

    test('RPE 8.0 with Controlled tempo recommends rep progression (+1 rep)', () {
      final initialSets = [
        ExerciseSet(setNumber: 1, reps: 8, weightKg: 80.0),
      ];

      final overload = ProgressiveOverloadService.computeOverload(
        exerciseName: 'Squat',
        previousSets: initialSets,
        rpe: 8.0,
        velocity: 'Controlled',
      );

      expect(overload.type, OverloadType.repIncrease);
      expect(overload.deltaReps, 1);
      expect(overload.suggestedSets.first.weightKg, 80.0);
      expect(overload.suggestedSets.first.reps, 9);
    });

    test('RPE 9.5 near-failure recommends load consolidation', () {
      final initialSets = [
        ExerciseSet(setNumber: 1, reps: 6, weightKg: 100.0),
      ];

      final overload = ProgressiveOverloadService.computeOverload(
        exerciseName: 'Deadlift',
        previousSets: initialSets,
        rpe: 9.5,
        velocity: 'Grind',
      );

      expect(overload.type, OverloadType.maintain);
      expect(overload.deltaWeightKg, 0.0);
      expect(overload.suggestedSets.first.weightKg, 100.0);
    });

    test('RPE 10.0 failure recommends deload', () {
      final initialSets = [
        ExerciseSet(setNumber: 1, reps: 5, weightKg: 100.0),
      ];

      final overload = ProgressiveOverloadService.computeOverload(
        exerciseName: 'Deadlift',
        previousSets: initialSets,
        rpe: 10.0,
        velocity: 'Grind',
      );

      expect(overload.type, OverloadType.deload);
      expect(overload.deltaWeightKg, -2.5);
      expect(overload.suggestedSets.first.weightKg, 97.5);
    });
  });

  group('WeightEntry Model Tests', () {
    test('JSON serialization and deserialization works seamlessly', () {
      final now = DateTime.now();
      final entry = WeightEntry(
        id: 'w1',
        timestamp: now,
        weightKg: 74.8,
        notes: 'Morning weigh-in',
      );

      final json = entry.toJson();
      final decoded = WeightEntry.fromJson(json);

      expect(decoded.id, 'w1');
      expect(decoded.weightKg, 74.8);
      expect(decoded.notes, 'Morning weigh-in');
    });
  });

  group('WorkoutRoutine Model Tests', () {
    test('Built-in presets provide Push, Pull, Leg splits and cardio', () {
      final presets = WorkoutRoutine.builtInPresets;
      expect(presets.length, greaterThanOrEqualTo(4));
      expect(presets.any((r) => r.name.contains('Push Split')), isTrue);
      expect(presets.any((r) => r.name.contains('Pull Split')), isTrue);
      expect(presets.any((r) => r.name.contains('Leg Split')), isTrue);
    });
  });

  group('WorkModeService Tests', () {
    test('Initializes with focus phase and formatted time', () {
      final service = WorkModeService();
      service.stop();
      final state = service.currentState;
      expect(state.isActive, isFalse);
      expect(state.phase, WorkPhase.focus);
      expect(state.formattedTime, '25:00');
    });
  });
}
