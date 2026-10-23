import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart' as app_config;
import 'package:firebase_auth/firebase_auth.dart';

class AIChatService {
  static const String _apiKey = 'YOUR_GROQ_API_KEY';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';
  static String get _localBaseUrl => '${app_config.Config.baseUrl}/api/ai-coach';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getToken() async {
    return _auth.currentUser?.getIdToken();
  }


  // --- Backend Persistence & Usage Calls ---

  Future<Map<String, dynamic>> getUsageInfo() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$_localBaseUrl/usage'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching usage info: $e');
    }
    return {'isPremium': false, 'limits': []};
  }

  Future<void> incrementUsage(String limitType) async {
    final token = await _getToken();
    try {
      await http.post(
        Uri.parse('$_localBaseUrl/increment-usage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'limitType': limitType}),
      );
    } catch (e) {
      print('Error incrementing usage: $e');
    }
  }

  Future<List<Map<String, String>>> getCoachHistory() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$_localBaseUrl/messages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((m) => {
          'role': m['role'].toString(),
          'content': m['content'].toString(),
        }).toList();
      }
    } catch (e) {
      print('Error fetching history: $e');
    }
    return [];
  }

  Future<void> saveCoachMessage(String role, String content) async {
    final token = await _getToken();
    try {
      await http.post(
        Uri.parse('$_localBaseUrl/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'role': role, 'content': content}),
      );
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  Future<void> logWorkout({
    required String workoutName,
    required List<dynamic> exercises,
    required int duration,
    required int caloriesBurned,
  }) async {
    final token = await _getToken();
    try {
      await http.post(
        Uri.parse('$_localBaseUrl/log-workout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'workoutName': workoutName,
          'exercises': exercises,
          'duration': duration,
          'caloriesBurned': caloriesBurned,
        }),
      );
    } catch (e) {
      print('Error logging workout: $e');
    }
  }

  Future<List<dynamic>> getWorkoutHistory({int limit = 5}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$_localBaseUrl/workout-history?limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching workout history: $e');
    }
    return [];
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
You are "Gym Bot", the ultimate premium AI Fitness Coach for the FitFinder app.

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

STRICT REFUSAL POLICY (GUARDRAILS):
- You are a FITNESS COACH. You do NOT talk about politics, history, general news, or personal relationship advice. 
- If asked about these topics, politely decline: "I'm just a gym bot! I can only help you with workouts and nutrition. Let's get back to the gains! 💪"
- DO NOT generate essays on non-fitness topics.
- DO NOT answer questions like "Who is the president?" or "Write me a poem about love."

STRICT RULES:
- Be encouraging, professional, and slightly energetic (bro-science vibes but backed by facts).
- If asked to create a plan, provide a clear structured list.
- Keep responses concise but impactful.
- ONLY discuss fitness, health, nutrition, and motivation.

Always refer to the user by their name if available.''';

    return _getGroqResponse(systemPrompt, chatHistory, userMessage);
  }

  Future<String> _getGroqResponse(String systemPrompt, List<Map<String, String>> history, String userMessage) async {
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
