import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final url = Uri.parse('https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json');
  print('Downloading exercises from $url...');
  
  final response = await http.get(url);
  
  if (response.statusCode != 200) {
    print('Failed to download data: ${response.statusCode}');
    return;
  }

  final List<dynamic> rawData = jsonDecode(response.body);
  print('Downloaded ${rawData.length} exercises. Processing...');

  final List<Map<String, dynamic>> processedExercises = [];
  final Set<String> validMuscles = {
    'abdominals', 'abductors', 'adductors', 'biceps', 'calves', 'chest', 
    'forearms', 'glutes', 'hamstrings', 'lats', 'lower back', 'middle back', 
    'neck', 'quadriceps', 'shoulders', 'traps', 'triceps'
  };

  for (final item in rawData) {
    // Basic validation
    if (item['images'] == null || (item['images'] as List).isEmpty) continue;
    
    // Map muscle to our simple mapping if possible, or keep original
    // Our app uses: "biceps", "triceps", "chest", "back", "legs", "shoulders", "abs"
    String target = (item['primaryMuscles'] as List).isNotEmpty 
        ? item['primaryMuscles'][0] 
        : 'unknown';
        
    // Simplify target for our specific generator mapping
    // "Arm": ["biceps", "triceps", "forearms"],
    // "Shoulder": ["delts"], -> "shoulders" in this DB
    // "Back": ["lats", "upper back", "traps", "spine"], -> "lats", "middle back", "traps", "lower back"
    // "Chest": ["pectorals"], -> "chest"
    // "Cores": ["abs"], -> "abdominals"
    // "Leg": ["quads", "hamstrings", "glutes", "calves"], -> "quadriceps", "hamstrings", "glutes", "calves"

    // Construct image URLs
    // Source structure: "3_4_Sit-Up/0.jpg"
    // Base URL: https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/
    final List<String> allImages = [];
    if (item['images'] != null) {
      for (var img in item['images']) {
        allImages.add('https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$img');
      }
    }

    final String fullImageUrl = allImages.isNotEmpty ? allImages[0] : '';

    processedExercises.add({
      'id': item['id'],
      'name': item['name'],
      'targetMuscle': target, 
      'equipment': item['equipment'] ?? 'body weight',
      'difficulty': item['level'] ?? 'beginner',
      'imageUrl': fullImageUrl,
      'videoUrl': fullImageUrl, // Fallback
      'allImageUrls': allImages,
      'instructions': item['instructions'] ?? [],
    });
  }

  // Ensure output directory exists
  final outputDir = Directory('assets/data');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final outputFile = File('assets/data/exercises.json');
  outputFile.writeAsStringSync(jsonEncode(processedExercises));
  
  print('Successfully saved ${processedExercises.length} processed exercises to ${outputFile.path}');
  
  // Verify a few items
  print('Example items:');
  for (var i = 0; i < 3 && i < processedExercises.length; i++) {
    print('${processedExercises[i]['name']} - Images: ${processedExercises[i]['allImageUrls'].length}');
  }
}
