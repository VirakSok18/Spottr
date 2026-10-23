import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/workout_models.dart';

class ExerciseDbService {
  static const String _baseUrl = 'https://exercisedb.p.rapidapi.com';
  static const String _host = 'exercisedb.p.rapidapi.com';
  static const String _apiKey = 'e3bfb7c817msh3318ca65a5400c1p1231f3jsna9ae8cb20340';

  static Map<String, String> get _headers => {
    'x-rapidapi-host': _host,
    'x-rapidapi-key': _apiKey,
  };

  /// Fetches exercises for a specific target muscle (e.g., "abs", "biceps")
  static Future<List<Exercise>> getExercisesByTarget(String target) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/exercises/target/${target.toLowerCase()}?limit=10'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Exercise.fromExerciseDb(json)).toList();
    } else {
      throw Exception('Failed to load exercises for $target');
    }
  }

  /// Fetches exercises by body part (e.g., "chest", "back")
  static Future<List<Exercise>> getExercisesByBodyPart(String bodyPart) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/exercises/bodyPart/${bodyPart.toLowerCase()}?limit=10'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Exercise.fromExerciseDb(json)).toList();
    } else {
      throw Exception('Failed to load exercises for $bodyPart');
    }
  }

  /// Fetches full exercise details by ID (required for gifUrl)
  static Future<Exercise?> getExerciseById(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/exercises/exercise/$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Exercise.fromExerciseDb(data);
    }
    return null;
  }
}
