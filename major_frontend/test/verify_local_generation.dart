import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_frontend/models/workout_models.dart';
import 'package:major_frontend/services/workout_generator.dart';
import 'package:major_frontend/services/local_exercise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Workout Generator produces valid plans from local data', () async {
    // mock User
    final user = User(
      gender: 'Male',
      trainingLevel: 'Intermediate',
      equipmentAccess: ['Dumbbell', 'Body Weight'],
      focusAreas: ['Chest', 'Arm', 'Leg'],
      workoutFrequency: 4,
      durationWeeks: 4,
    );

    // Run Generator
    final generator = WorkoutGenerator();
    final plans = await generator.generatePlans(user);

    expect(plans.length, 3);
    
    print('Generated ${plans.length} plans.');

    for (var plan in plans) {
      print('\nPlan: ${plan.planName}');
      print('Description: ${plan.focusDistributionDescription}');
      
      expect(plan.dailyWorkouts.isNotEmpty, true);
      
      // Check first workout day
      final firstWorkout = plan.dailyWorkouts.firstWhere((d) => !d.isRestDay);
      print('  First Workout Day: ${firstWorkout.dayTitle}');
      print('  Exercises: ${firstWorkout.exercises.length}');
      
      expect(firstWorkout.exercises.isNotEmpty, true);
      
      for (var ex in firstWorkout.exercises) {
        print('    - ${ex.name} (${ex.equipment}) [Target: ${ex.targetMuscle}]');
        expect(ex.id.isNotEmpty, true);
        expect(ex.imageUrl.isNotEmpty, true);
        // We set videoUrl to match imageUrl in our setup
        expect(ex.videoUrl, ex.imageUrl);
      }
    }
  });
}
