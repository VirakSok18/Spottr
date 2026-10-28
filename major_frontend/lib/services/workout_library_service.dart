import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/workout_program.dart';

class WorkoutLibraryService {
  static Future<List<WorkoutProgram>> fetchPrograms() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/parsed_programs.json');
      final List<dynamic> data = jsonDecode(jsonString);
      return data.map((json) => WorkoutProgram.fromJson(json)).toList();
    } catch (e) {
      print('WorkoutLibraryService Error loading programs: $e');
      return [];
    }
  }
}
