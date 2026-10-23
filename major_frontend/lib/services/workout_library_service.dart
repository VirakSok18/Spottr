import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout_program.dart';
import 'config.dart' as app_config;

class WorkoutLibraryService {
  static Future<List<WorkoutProgram>> fetchPrograms() async {
    try {
      final response = await http.get(Uri.parse('${app_config.Config.baseUrl}/api/workouts/programs'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WorkoutProgram.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load programs');
      }
    } catch (e) {
      print('WorkoutLibraryService Error: $e');
      return [];
    }
  }
}
