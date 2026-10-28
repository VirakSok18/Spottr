import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIChatService {
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // --- Free Standalone Usage Calls ---

  Future<Map<String, dynamic>> getUsageInfo() async {
    return {'isPremium': true, 'limits': []};
  }

  Future<void> incrementUsage(String limitType) async {
    // 100% Free Forever: No limits
  }

  Future<List<Map<String, String>>> getCoachHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('ai_coach_history');
      if (historyStr != null) {
        final List<dynamic> data = jsonDecode(historyStr);
        return data.map((m) => {
          'role': m['role'].toString(),
          'content': m['content'].toString(),
        }).toList();
      }
    } catch (e) {
      print('Error fetching coach history: $e');
    }
    return [];
  }

  Future<void> saveCoachMessage(String role, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getCoachHistory();
      history.add({'role': role, 'content': content});
      if (history.length > 50) history.removeAt(0);
      await prefs.setString('ai_coach_history', jsonEncode(history));
    } catch (e) {
      print('Error saving coach message: $e');
    }
  }

  Future<void> logWorkout({
    required String workoutName,
    required List<dynamic> exercises,
    required int duration,
    required int caloriesBurned,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('user_workout_history') ?? '[]';
      final List<dynamic> list = jsonDecode(listStr);
      list.add({
        'workoutName': workoutName,
        'exercises': exercises,
        'duration': duration,
        'caloriesBurned': caloriesBurned,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setString('user_workout_history', jsonEncode(list));
    } catch (e) {
      print('Error logging workout: $e');
    }
  }

  Future<List<dynamic>> getWorkoutHistory({int limit = 5}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('user_workout_history') ?? '[]';
      final List<dynamic> list = jsonDecode(listStr);
      return list.reversed.take(limit).toList();
    } catch (e) {
      print('Error fetching workout history: $e');
      return [];
    }
  }

  // --- AI Model Calls ---

  Future<String> getAIResponse({
    required String exerciseName,
    required List<Map<String, String>> chatHistory,
    required String userMessage,
  }) async {
    final systemPrompt = '''
You are a fitness assistant explaining the $exerciseName exercise ONLY.

STRICT RULES:
- ONLY answer questions about $exerciseName
- If asked about other exercises or topics, say: "I'm here to help with $exerciseName only. What would you like to know about this exercise?"
- Provide: proper form, technique, variations, common mistakes, muscles worked, tips
- Keep answers under 100 words unless asked for more detail

Do NOT discuss other exercises, workout plans, or unrelated topics.''';

    return _getGroqResponse(systemPrompt, chatHistory, userMessage);
  }

  Future<String> getGeneralCoachResponse({
    required Map<String, dynamic> userProfile,
    required List<dynamic> workoutHistory,
    required List<Map<String, String>> chatHistory,
    required String userMessage,
  }) async {
    final historySummary = workoutHistory.isEmpty 
      ? "No workouts logged yet." 
      : workoutHistory.map((h) => "- ${h['workoutName']} in ${h['duration']}m").join("\n");

    final systemPrompt = '''
You are "Gym Bot", the ultimate AI Fitness Coach for Spottr.

USER PROFILE:
- Name: ${userProfile['fullName'] ?? 'Athlete'}
- Goal: ${userProfile['fitness_goal'] ?? 'General Fitness'}
- Level: ${userProfile['training_level'] ?? 'Beginner'}
- Equipment: ${userProfile['equipment_list'] ?? 'Bodyweight'}

RECENT HISTORY:
$historySummary

CORE RESPONSIBILITIES:
1. Provide expert workout advice and exercise guidance.
2. Generate personalized workout plans visually represented in Markdown.
3. Offer motivation and form tips.
4. Give fitness-focused nutrition advice.
5. Track progress and suggest intensity adjustments.

STRICT RULES:
- Be encouraging, professional, and slightly energetic.
- If asked to create a plan, provide a clear structured list.
- Keep responses concise but impactful.
- ONLY discuss fitness, health, nutrition, and motivation.

Always refer to the user by their name if available.''';

    return _getGroqResponse(systemPrompt, chatHistory, userMessage);
  }

  Future<String> _getGroqResponse(String systemPrompt, List<Map<String, String>> history, String userMessage) async {
    if (_apiKey.isEmpty) {
      return "Hi athlete! I am your Spottr AI Coach. For proper form, remember to keep your core engaged, maintain a steady breathing rhythm, and control the eccentric movement. You've got this! 💪";
    }

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'Sorry, I couldn\'t process that.';
      } else {
        print('Groq API Error: ${response.statusCode} - ${response.body}');
        return 'Error: Unable to connect to AI Coach.';
      }
    } catch (e) {
      print('AIChatService Exception: $e');
      return 'Error: Something went wrong.';
    }
  }
}
