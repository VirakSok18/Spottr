import 'dart:math';
import '../models/workout_models.dart';
import 'local_exercise_service.dart';

class WorkoutGenerator {
  /// Generate 3 Personalized Workout Plans
  Future<List<WorkoutPlan>> generatePlans(User user) async {
    // Ensure local data is loaded
    await LocalExerciseService.init();

    // Step A: Muscle Group Mapping
    // Map focus areas to Target Muscles in our local data
    // Local data uses: "abdominals", "biceps", "chest", "calves", "glutes", "hamstrings", "lats", "lower back", "middle back", "neck", "quadriceps", "shoulders", "traps", "triceps"
    Map<String, List<String>> focusMapping = {
      "Arm": ["biceps", "triceps", "forearms"],
      "Shoulder": ["shoulders"],
      "Back": ["lats", "middle back", "traps", "lower back"],
      "Chest": ["chest"],
      "Cores": ["abdominals"],
      "Leg": ["quadriceps", "hamstrings", "glutes", "calves"],
      "Full Body": ["chest", "lats", "quadriceps", "abdominals", "shoulders", "biceps", "triceps"],
    };

    // Ensure we have at least 3 focus areas for the algorithm logic
    List<String> userFocus = List.from(user.focusAreas);
    if (userFocus.isEmpty) userFocus.add("Full Body");
    while (userFocus.length < 3) {
      userFocus.add(userFocus.first); // Duplicate first if less than 3
    }

    // Step B: Fetch all required exercises from LOCAL Service
    Map<String, List<Exercise>> exercisesByFocus = {};
    for (String area in userFocus) {
      if (exercisesByFocus.containsKey(area)) continue;
      
      List<Exercise> allForArea = [];
      List<String> targets = focusMapping[area] ?? ["abdominals"];
      
      for (String target in targets) {
        try {
          final fetched = await LocalExerciseService.getExercisesByTarget(target);
          allForArea.addAll(fetched);
        } catch (e) {
          print('Error fetching $target: $e');
        }
      }
      
      // Filter by equipment
      // Local data "equipment" examples: "body only", "barbell", "dumbbell", etc.
      allForArea = allForArea.where((ex) {
        final exEquip = ex.equipment.toLowerCase();
        final isBodyweight = exEquip == "body only" || exEquip == "body weight" || exEquip == "bodyweight";
        
        // Simple containment check
        final hasEquipment = user.equipmentAccess.any((e) => exEquip.contains(e.toLowerCase()));
        
        return isBodyweight || hasEquipment;
      }).toList();

      exercisesByFocus[area] = allForArea;
    }

    // Step C: Generate 3 Plans
    // Since we already have full details (including images) from local service, we don't need a second fetch pass.
    final planDrafts = [
      await _createPlan(user, "Primary Plan", [0.6, 0.2, 0.2], userFocus, exercisesByFocus, "assets/images/plan_header.png"),
      await _createPlan(user, "Secondary Plan", [0.2, 0.6, 0.2], userFocus, exercisesByFocus, "assets/images/plan_secondary.png"),
      await _createPlan(user, "Balance Plan", [0.33, 0.33, 0.34], userFocus, exercisesByFocus, "assets/images/plan_balance.png"),
    ];

    return planDrafts;
  }

  Future<WorkoutPlan> _createPlan(
    User user, 
    String planName, 
    List<double> weights, 
    List<String> focusAreas,
    Map<String, List<Exercise>> exercisesByFocus,
    String? imageUrl,
  ) async {
    List<DailyWorkout> days = [];
    int totalDays = user.durationWeeks * 7;
    
    // Determine workout days indices
    List<int> workoutDays = _calculateWorkoutDays(totalDays, user.workoutFrequency);

    final random = Random();

    for (int i = 1; i <= totalDays; i++) {
      bool isWorkoutDay = workoutDays.contains(i);
      
      if (!isWorkoutDay) {
        days.add(DailyWorkout(dayNumber: i, dayTitle: "Recovery Day", isRestDay: true));
        continue;
      }

      // Generate Exercises for the day
      List<Exercise> selectedExercises = [];
      
      // Select 6 exercises based on weights
      // 0: Focus 1, 1: Focus 2, 2: Focus 3
      int count1 = (6 * weights[0]).round();
      int count2 = (6 * weights[1]).round();
      int count3 = 6 - count1 - count2;

      selectedExercises.addAll(_pickExercises(focusAreas[0], count1, exercisesByFocus[focusAreas[0]] ?? [], selectedExercises, random));
      selectedExercises.addAll(_pickExercises(focusAreas[1], count2, exercisesByFocus[focusAreas[1]] ?? [], selectedExercises, random));
      selectedExercises.addAll(_pickExercises(focusAreas[2], count3, exercisesByFocus[focusAreas[2]] ?? [], selectedExercises, random));

      // Sets & Reps
      List<String> dailySetsReps = selectedExercises.map((ex) => _generateSetsReps(ex, user.trainingLevel, random)).toList();

      days.add(DailyWorkout(
        dayNumber: i,
        dayTitle: "Strength & Conditioning",
        isRestDay: false,
        exercises: List.from(selectedExercises),
        setsReps: dailySetsReps,
      ));
    }

    String desc = "Focusing on ${focusAreas[0]} (${(weights[0]*100).toInt()}%), "
                 "${focusAreas[1]} (${(weights[1]*100).toInt()}%), "
                 "and ${focusAreas[2]} (${(weights[2]*100).toInt()}%).";

    return WorkoutPlan(
      planName: planName,
      focusDistributionDescription: desc,
      dailyWorkouts: days,
      imageUrl: imageUrl,
    );
  }

  String _generateSetsReps(Exercise ex, String trainingLevel, Random random) {
    final target = ex.targetMuscle.toLowerCase();
    
    // Categorization
    bool isMajor = ["chest", "lats", "middle back", "quadriceps", "hamstrings", "glutes", "lower back"].any((m) => target.contains(m));
    bool isAbs = target.contains("abdominals");
    
    int sets = 3;
    int reps = 10;
    
    if (trainingLevel == "Advanced") {
      // Focus on Intensity & Strength
      if (isMajor) {
        sets = 5;
        reps = 5 + random.nextInt(4); // 5-8 reps (Heavy/Strength)
      } else if (isAbs) {
        sets = 4;
        reps = 20 + random.nextInt(11); // 20-30 reps
      } else {
        sets = 4;
        reps = 8 + random.nextInt(5); // 8-12 reps
      }
    } else if (trainingLevel == "Intermediate") {
      // Focus on Hypertrophy
      if (isMajor) {
        sets = 4;
        reps = 8 + random.nextInt(5); // 8-12 reps
      } else if (isAbs) {
        sets = 3;
        reps = 15 + random.nextInt(6); // 15-20 reps
      } else {
        sets = 3;
        reps = 10 + random.nextInt(3); // 10-12 reps
      }
    } else {
      // Beginner: Focus on Form & Endurance
      if (isMajor) {
        sets = 3;
        reps = 12 + random.nextInt(4); // 12-15 reps (Higher reps for form practice)
      } else if (isAbs) {
        sets = 2;
        reps = 12 + random.nextInt(4); // 12-15 reps
      } else {
        sets = 3;
        reps = 12 + random.nextInt(4); // 12-15 reps
      }
    }
    
    return "$sets x $reps";
  }

  List<int> _calculateWorkoutDays(int totalDays, int frequency) {
    if (frequency >= 7) return List.generate(totalDays, (i) => i + 1);
    
    List<int> workoutDays = [];
    double interval = 7 / frequency;
    
    for (int week = 0; week < 4; week++) {
      for (int f = 0; f < frequency; f++) {
        int day = (week * 7) + (f * interval).round() + 1;
        if (day <= totalDays) workoutDays.add(day);
      }
    }
    return workoutDays;
  }

  List<Exercise> _pickExercises(
    String focusArea,
    int count,
    List<Exercise> focusPool,
    List<Exercise> alreadySelected,
    Random random,
  ) {
    List<Exercise> pool = focusPool.where((ex) => !alreadySelected.any((s) => s.id == ex.id)).toList();

    if (pool.isEmpty) {
        return [];
    }

    pool.shuffle(random);
    return pool.take(count).toList();
  }
}
