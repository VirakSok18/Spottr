class WorkoutProgram {
  final int id;
  final String title;
  final String difficulty;
  final String equipment;
  final List<ProgramDay> days;
  final List<bool> schedule; // S M T W T F S
  final String? thumbnail;

  WorkoutProgram({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.equipment,
    required this.days,
    required this.schedule,
    this.thumbnail,
  });

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) {
    return WorkoutProgram(
      id: json['id'],
      title: json['title'],
      difficulty: json['difficulty'] ?? 'Beginner',
      equipment: json['equipment'] ?? 'None',
      days: (json['days'] as List).map((d) => ProgramDay.fromJson(d)).toList(),
      schedule: List<bool>.from(json['schedule']),
      thumbnail: json['thumbnail'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'difficulty': difficulty,
      'equipment': equipment,
      'days': List.generate(days.length, (i) => days[i].toMap(i + 1)),
      'schedule': schedule,
      'imageUrl': thumbnail, // For compatibility with PlanDetailScreen
    };
  }
}

class ProgramDay {
  final String title;
  final List<ProgramExercise> exercises;

  ProgramDay({required this.title, required this.exercises});

  factory ProgramDay.fromJson(Map<String, dynamic> json) {
    return ProgramDay(
      title: json['title'],
      exercises: (json['exercises'] as List)
          .map((e) => ProgramExercise.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toMap(int dayNum) {
    return {
      'day': dayNum,
      'title': title,
      'isRestDay': false,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}

class ProgramExercise {
  final String name;
  final String youtubeUrl;
  final String? instructions;

  ProgramExercise({
    required this.name,
    required this.youtubeUrl,
    this.instructions,
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> json) {
    return ProgramExercise(
      name: json['name'],
      youtubeUrl: json['youtubeUrl'],
      instructions: json['instructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': name.toLowerCase().replaceAll(' ', '_'),
      'name': name,
      'videoUrl': youtubeUrl,
      'youtubeId': _extractYoutubeId(youtubeUrl),
      'target': 'Full Body', // Placeholder
      'instructions': instructions,
      'sets': 3,
      'reps': 12,
      'restSeconds': 60,
    };
  }

  String? _extractYoutubeId(String url) {
    RegExp regExp = RegExp(
        r"(?:v=|\/)([0-9A-Za-z_-]{11}).*",
        caseSensitive: false,
        multiLine: false);
    Match? match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}
