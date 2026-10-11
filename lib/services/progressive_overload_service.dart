import '../models/exercise_set.dart';

enum OverloadType { weightIncrease, repIncrease, maintain, deload }

class OverloadRecommendation {
  final OverloadType type;
  final double deltaWeightKg;
  final int deltaReps;
  final String title;
  final String explanation;
  final List<ExerciseSet> suggestedSets;

  OverloadRecommendation({
    required this.type,
    required this.deltaWeightKg,
    required this.deltaReps,
    required this.title,
    required this.explanation,
    required this.suggestedSets,
  });
}

class ProgressiveOverloadService {
  /// Evaluates previous performance and exertion to calculate next optimal overload
  static OverloadRecommendation computeOverload({
    required String exerciseName,
    required List<ExerciseSet> previousSets,
    required double rpe, // 6.0 to 10.0
    required String velocity, // 'Explosive', 'Controlled', 'Grind'
  }) {
    if (previousSets.isEmpty) {
      return OverloadRecommendation(
        type: OverloadType.maintain,
        deltaWeightKg: 0.0,
        deltaReps: 0,
        title: 'Initial Baseline Session',
        explanation: 'Set initial benchmark weight and establish technical execution.',
        suggestedSets: previousSets,
      );
    }

    final isCompound = _isCompoundLift(exerciseName);
    final standardWeightIncrement = isCompound ? 2.5 : 1.25;

    final normVelocity = velocity.toLowerCase();
    final isExplosive = normVelocity.contains('explosive') || normVelocity.contains('fast') || normVelocity.contains('power');
    final isGrind = normVelocity.contains('grind') || normVelocity.contains('slow') || normVelocity.contains('struggl');

    // Case 1: High speed & low-to-moderate exertion (<= 7.5 or <= 8.0 with fast reps) -> Load jump
    if (rpe <= 7.5 || (rpe <= 8.0 && isExplosive)) {
      final newSets = previousSets.map((s) {
        return ExerciseSet(
          setNumber: s.setNumber,
          reps: s.reps,
          weightKg: double.parse((s.weightKg + standardWeightIncrement).toStringAsFixed(2)),
        );
      }).toList();

      final incStr = standardWeightIncrement % 1 == 0
          ? standardWeightIncrement.toInt().toString()
          : standardWeightIncrement.toString();

      return OverloadRecommendation(
        type: OverloadType.weightIncrease,
        deltaWeightKg: standardWeightIncrement,
        deltaReps: 0,
        title: 'Ready for +$incStr kg weight increase',
        explanation: 'Your reps were fast and you had plenty left in the tank. You can safely increase weight next time!',
        suggestedSets: newSets,
      );
    }

    // Case 2: Solid working set (RPE 8.0 - 8.5) and steady tempo -> Add 1 more rep
    if (rpe <= 8.5 && !isGrind) {
      final newSets = previousSets.map((s) {
        return ExerciseSet(
          setNumber: s.setNumber,
          reps: s.reps + 1,
          weightKg: s.weightKg,
        );
      }).toList();

      return OverloadRecommendation(
        type: OverloadType.repIncrease,
        deltaWeightKg: 0.0,
        deltaReps: 1,
        title: 'Aim for +1 extra rep next time',
        explanation: 'Great steady effort! Try hitting 1 more rep per set before moving up in weight.',
        suggestedSets: newSets,
      );
    }

    // Case 3: Near limit or heavy struggle (RPE 9.0 - 9.5) -> Hold current weight
    if (rpe <= 9.5) {
      return OverloadRecommendation(
        type: OverloadType.maintain,
        deltaWeightKg: 0.0,
        deltaReps: 0,
        title: 'Hold this weight & master form',
        explanation: 'That was heavy and close to your limit. Stick with this weight until your reps feel smoother.',
        suggestedSets: previousSets.map((s) => ExerciseSet(
          setNumber: s.setNumber,
          reps: s.reps,
          weightKg: s.weightKg,
        )).toList(),
      );
    }

    // Case 4: Complete Failure or Extreme Grind (RPE 10.0) -> Micro-deload / recovery
    final deloadIncrement = standardWeightIncrement;
    final newSets = previousSets.map((s) {
      final reducedWeight = (s.weightKg - deloadIncrement).clamp(0.0, 999.0);
      return ExerciseSet(
        setNumber: s.setNumber,
        reps: s.reps,
        weightKg: double.parse(reducedWeight.toStringAsFixed(2)),
      );
    }).toList();

    return OverloadRecommendation(
      type: OverloadType.deload,
      deltaWeightKg: -deloadIncrement,
      deltaReps: 0,
      title: 'Lighten load slightly next session',
      explanation: 'You pushed to absolute limit last time. Drop by $deloadIncrement kg next session to recover and protect your joints.',
      suggestedSets: newSets,
    );
  }

  static bool _isCompoundLift(String name) {
    final lower = name.toLowerCase();
    return lower.contains('bench') ||
        lower.contains('squat') ||
        lower.contains('deadlift') ||
        lower.contains('press') ||
        lower.contains('row') ||
        lower.contains('pull-up') ||
        lower.contains('dips');
  }
}
