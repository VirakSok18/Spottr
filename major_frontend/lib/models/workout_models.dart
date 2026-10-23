import 'dart:convert';

class User {
  final String gender;
  final String trainingLevel; // Beginner, Intermediate, Advanced
  final List<String> equipmentAccess;
  final List<String> focusAreas;
  final int workoutFrequency;
  final int durationWeeks;

  User({
    required this.gender,
    required this.trainingLevel,
    required this.equipmentAccess,
    required this.focusAreas,
    required this.workoutFrequency,
    required this.durationWeeks,
  });

  /// Factory to map from the existing backend profile map
  factory User.fromProfile(Map<String, dynamic> profile) {
    // Map training level strings to the expected simplified ones
    String level = profile['training_level'] ?? 'Beginner';
    if (level == 'Irregular training') level = 'Beginner';
    if (level == 'Medium') level = 'Intermediate';

    // Handle equipment and focus areas which might be JSON strings or lists
    List<String> equipment = [];
    if (profile['equipment_list'] is String) {
      equipment = List<String>.from(jsonDecode(profile['equipment_list']));
    } else if (profile['equipment_list'] is List) {
      equipment = List<String>.from(profile['equipment_list']);
    }

    List<String> focus = [];
    if (profile['focus_areas'] is String) {
      focus = List<String>.from(jsonDecode(profile['focus_areas']));
    } else if (profile['focus_areas'] is List) {
      focus = List<String>.from(profile['focus_areas']);
    }

    return User(
      gender: profile['gender'] ?? 'Male',
      trainingLevel: level,
      equipmentAccess: equipment,
      focusAreas: focus,
      workoutFrequency: profile['workout_frequency'] ?? 3,
      durationWeeks: 4, // Default to 4 weeks if not specified
    );
  }

  // Add json conversion for easy debugging/local storage if needed
  Map<String, dynamic> toJson() => {
    'gender': gender,
    'trainingLevel': trainingLevel,
    'equipmentAccess': equipmentAccess,
    'focusAreas': focusAreas,
    'workoutFrequency': workoutFrequency,
    'durationWeeks': durationWeeks,
  };
}

class Exercise {
  final String id;
  final String name;
  final String targetMuscle; // Anatomical muscle (e.g., "Biceps", "Quads")
  final String equipment;
  final String difficulty; // Beginner, Intermediate, Advanced
  final String imageUrl;
  final String videoUrl;
  final String? gifUrl;
  final String? youtubeId;
  final List<String> instructions;
  final List<String> allImageUrls;

  Exercise({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.equipment,
    required this.difficulty,
    required this.imageUrl,
    required this.videoUrl,
    required this.instructions,
    this.allImageUrls = const [],
    this.gifUrl,
    this.youtubeId,
  });

  /// Factory constructor for ExerciseDB API response
  factory Exercise.fromExerciseDb(Map<String, dynamic> json) {
    // Note: ExerciseDB traditionally returns 'gifUrl'.
    final String mediaUrl = json['gifUrl'] ?? '';
    
    return Exercise(
      id: json['id']?.toString() ?? '',
      name: capitalize(json['name'] ?? ''),
      targetMuscle: capitalize(json['target'] ?? ''),
      equipment: capitalize(json['equipment'] ?? ''),
      difficulty: 'Intermediate',
      imageUrl: mediaUrl,
      videoUrl: mediaUrl,
      instructions: List<String>.from(json['instructions'] ?? []),
      allImageUrls: [mediaUrl],
      gifUrl: json['gifUrl'],
      youtubeId: null, // API doesn't return this
    );
  }

  Map<String, dynamic> toExecutionMap() {
    return {
      'id': id,
      'name': name,
      'targetMuscle': targetMuscle,
      'equipment': equipment,
      'difficulty': difficulty,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'instructions': instructions,
      'youtubeId': youtubeId,
      'type': 'sets',
      'sets': 3,
      'reps': 12,
    };
  }

  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

class DailyWorkout {
  final int dayNumber;
  final String dayTitle;
  final bool isRestDay;
  final List<Exercise> exercises;
  final List<String> setsReps; // Corresponding sets/reps for each exercise

  DailyWorkout({
    required this.dayNumber,
    required this.dayTitle,
    required this.isRestDay,
    this.exercises = const [],
    this.setsReps = const [],
  });

  Map<String, dynamic> toJson() => {
    'day': dayNumber,
    'title': dayTitle,
    'isRestDay': isRestDay,
    'exercises': exercises.asMap().entries.map((entry) {
      int idx = entry.key;
      Exercise e = entry.value;
      String sr = idx < setsReps.length ? setsReps[idx] : "3 x 10";
      List<String> srParts = sr.split(' x ');
      
      return {
        'id': e.id,
        'name': e.name,
        'targetMuscle': e.targetMuscle,
        'imageUrl': e.imageUrl,
        'videoUrl': e.videoUrl,
        'instructions': e.instructions,
        'allImageUrls': e.allImageUrls,
        'gifUrl': e.gifUrl,
        'youtubeId': e.youtubeId,
        'equipment': e.equipment,
        'sets': srParts.isNotEmpty ? srParts[0] : '3',
        'reps': srParts.length > 1 ? srParts[1] : '10',
      };
    }).toList(),
  };
}

class WorkoutPlan {
  final String planName;
  final String focusDistributionDescription;
  final String? imageUrl;
  final List<DailyWorkout> dailyWorkouts;

  WorkoutPlan({
    required this.planName,
    required this.focusDistributionDescription,
    required this.dailyWorkouts,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'title': planName,
    'description': focusDistributionDescription,
    'imageUrl': imageUrl,
    'days': dailyWorkouts.map((d) => d.toJson()).toList(),
  };
}
