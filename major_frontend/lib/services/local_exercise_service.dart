import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/workout_models.dart';

class LocalExerciseService {
  static List<Exercise> _allExercises = [];
  static bool _initialized = false;

  /// Loads the exercises from the local JSON asset.
  /// Must be called before any other method.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // Use the new v3 JSON which includes YouTube IDs
      final String jsonString = await rootBundle.loadString('assets/data/exercises_v3.json');
      final List<dynamic> data = jsonDecode(jsonString);
      
      _allExercises = data.map((json) => Exercise(
        id: json['id'],
        name: json['name'],
        targetMuscle: json['targetMuscle'],
        equipment: json['equipment'],
        difficulty: json['difficulty'],
        imageUrl: json['imageUrl'],
        videoUrl: json['videoUrl'],
        instructions: List<String>.from(json['instructions']),
        allImageUrls: json['allImageUrls'] != null 
          ? List<String>.from(json['allImageUrls']) 
          : [],
        gifUrl: json['gifUrl'],
        youtubeId: json['youtubeId'],
      )).toList();

      _initialized = true;
      print('LocalExerciseService: Loaded ${_allExercises.length} exercises.');
    } catch (e) {
      print('LocalExerciseService Error: $e');
      // Fallback or empty if load fails
      _allExercises = [];
    }
  }

  /// Fetches exercises for a specific target muscle or multiple comma-separated muscles.
  static Future<List<Exercise>> getExercisesByTarget(String target) async {
    await init();
    final lowerTarget = target.toLowerCase();
    
    // Special handling for Full Body - return a curated list of compound movements
    if (lowerTarget == 'full body') {
      final compoundKeywords = ['squat', 'bench press', 'deadlift', 'overhead press', 'row', 'clean', 'snatch'];
      return _allExercises.where((ex) {
        final name = ex.name.toLowerCase();
        return compoundKeywords.any((k) => name.contains(k)) && ex.youtubeId != null && ex.youtubeId!.isNotEmpty;
      }).toList();
    }

    final targets = lowerTarget.split(',').map((e) => e.trim()).toList();
    
    return _allExercises.where((ex) {
      final muscle = ex.targetMuscle.toLowerCase();
      return targets.any((t) => muscle.contains(t)) && ex.youtubeId != null && ex.youtubeId!.isNotEmpty;
    }).toList();
  }

  /// Fetches exercises by difficulty level (beginner, intermediate, expert)
  static Future<List<Exercise>> getExercisesByDifficulty(String difficulty) async {
    await init();
    final lowerDiff = difficulty.toLowerCase();
    return _allExercises.where((ex) {
      // In our DB, "expert" is often used for "advanced"
      String searchDiff = lowerDiff;
      if (lowerDiff == 'advanced') searchDiff = 'expert';
      if (lowerDiff == 'medium') searchDiff = 'intermediate';
      
      return ex.difficulty.toLowerCase() == searchDiff && ex.youtubeId != null && ex.youtubeId!.isNotEmpty;
    }).toList();
  }

  /// Fetches exercises by equipment keyword
  static Future<List<Exercise>> getExercisesByEquipment(String equipment) async {
    await init();
    final lowerEquip = equipment.toLowerCase();
    
    // Mapping internal keywords
    String searchKey = lowerEquip;
    if (lowerEquip == 'bw') searchKey = 'body only';
    
    return _allExercises.where((ex) {
      return ex.equipment.toLowerCase().contains(searchKey) && ex.youtubeId != null && ex.youtubeId!.isNotEmpty;
    }).toList();
  }

  /// Fetches exercises by location (home, gym, outdoor)
  static Future<List<Exercise>> getExercisesByLocation(String location) async {
    await init();
    final lowerLoc = location.toLowerCase();
    
    return _allExercises.where((ex) {
      if (ex.youtubeId == null || ex.youtubeId!.isEmpty) return false;
      
      final equip = ex.equipment.toLowerCase();
      
      if (lowerLoc == 'home') {
        final homeEquip = ['body only', 'dumbbell', 'band', 'kettlebell', 'exercise ball', 'mat'];
        return homeEquip.any((e) => equip.contains(e));
      } else if (lowerLoc == 'gym') {
        final gymEquip = ['barbell', 'cable', 'machine', 'bench', 'rack', 'smith', 'pull-up bar'];
        return gymEquip.any((e) => equip.contains(e));
      } else if (lowerLoc == 'outdoor') {
        // Outdoor focuses on bodyweight/calisthenics/cardio
        final equip = ex.equipment.toLowerCase();
        final name = ex.name.toLowerCase();
        
        // Explicit exclusions for "actually outdoor" (no heavy equipment or machines)
        final hasProhibitedEquip = equip.contains('machine') || 
                                   equip.contains('cable') || 
                                   equip.contains('barbell') || 
                                   equip.contains('rack') || 
                                   equip.contains('bench') || 
                                   equip.contains('smith') ||
                                   equip.contains('dumbbell') ||
                                   equip.contains('kettlebell') ||
                                   equip.contains('plate');
        
        if (hasProhibitedEquip) return false;

        return equip.contains('body only') || 
               name.contains('run') || 
               name.contains('jump') || 
               name.contains('sprint') || 
               name.contains('walk');
      }
      return false;
    }).toList();
  }

  /// Fetches exercises by body part or keyword
  static Future<List<Exercise>> getExercisesByBodyPart(String bodyPart) async {
    await init();
    // In our simplified local data, targetMuscle covers most needs, 
    // but we can search broadly if needed.
    return _allExercises.where((ex) => 
      ex.targetMuscle.toLowerCase() == bodyPart.toLowerCase()
    ).toList();
  }

  /// Fetches full exercise details by ID
  static Future<Exercise?> getExerciseById(String id) async {
    await init();
    try {
      return _allExercises.firstWhere((ex) => ex.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Fetches 3 static exercises (Beginner, Intermediate, Advanced) for a category
  static Future<List<Exercise>> getExercisesForClassicWorkout(String focusArea) async {
    await init();
    
    // Static mapping for focus areas to specific exercise IDs
    // Each focus area has 3 exercises: [Beginner, Intermediate, Expert/Advanced]
    // Refined Mapping: Each list has exactly [Beginner, Intermediate, Advanced]
    final Map<String, List<String>> staticMapping = {
      'Full Body': [
        'Barbell_Incline_Bench_Press_-_Medium_Grip', // Beginner
        'Barbell_Squat',                             // Intermediate
        'Bent_Over_Barbell_Row'                   // Advanced (Expert)
      ],
      'Arm': [
        'Dumbbell_Alternate_Bicep_Curl',             // Beginner
        'Barbell_Curl',                             // Intermediate
        'Close-Grip_Barbell_Bench_Press'            // Advanced (Expert)
      ],
      'Shoulder': [
        'Barbell_Shoulder_Press',                    // Beginner
        'Dumbbell_Shoulder_Press',                    // Intermediate
        'Circus_Bell'                                // Advanced (Expert)
      ],
      'Back': [
        'Pullups',                                   // Beginner
        'Seated_Cable_Rows',                         // Intermediate
        'One_Arm_Chin-Up'                           // Advanced (Expert)
      ],
      'Chest': [
        'Barbell_Bench_Press_-_Medium_Grip',         // Beginner
        'Dumbbell_Bench_Press',                      // Intermediate
        'Decline_Barbell_Bench_Press'                // Advanced
      ],
      'Cores': [
        'Ab_Crunch_Machine',                         // Beginner
        'Decline_Crunch',                            // Intermediate
        'Hanging_Leg_Raise'                          // Advanced (Expert)
      ],
      'Leg': [
        'Bodyweight_Squat',                          // Beginner
        'Leg_Press',                                 // Intermediate
        'Barbell_Squat_To_A_Bench'                   // Advanced (Expert)
      ],
    };

    final ids = staticMapping[focusArea] ?? staticMapping['Full Body']!;
    
    List<Exercise> results = [];
    final labels = ['Beginner', 'Intermediate', 'Expert'];
    
    for (int i = 0; i < ids.length; i++) {
      final id = ids[i];
      final ex = _allExercises.firstWhere((e) => e.id == id, orElse: () => _allExercises.first);
      
      // Force difficulty label based on position as requested by the user: 
      // 1st is Beginner, 2nd is Intermediate, 3rd is Advanced
      final forcedLabel = i < labels.length ? labels[i] : 'Expert';
      
      results.add(Exercise(
        id: ex.id,
        name: ex.name,
        targetMuscle: ex.targetMuscle,
        equipment: ex.equipment,
        difficulty: forcedLabel,
        imageUrl: ex.imageUrl,
        videoUrl: ex.videoUrl,
        instructions: ex.instructions,
        allImageUrls: ex.allImageUrls,
        gifUrl: ex.gifUrl,
        youtubeId: ex.youtubeId,
      ));
    }

    return results;
  }
  /// Fetches all available exercises.
  static Future<List<Exercise>> getAllExercises() async {
    await init();
    return _allExercises.where((ex) => ex.youtubeId != null && ex.youtubeId!.isNotEmpty).toList();
  }
}
