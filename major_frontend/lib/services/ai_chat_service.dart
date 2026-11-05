import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_exercise_service.dart';
import '../models/workout_models.dart';

class AIChatService {
  static const String _envApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  /// Allows setting a custom Groq API key dynamically
  static Future<void> setCustomApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', key.trim());
  }

  /// Retrieves any custom or environment Groq API key
  static Future<String> getActiveApiKey() async {
    if (_envApiKey.isNotEmpty) return _envApiKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('groq_api_key')?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

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

  Future<void> clearCoachHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ai_coach_history');
    } catch (e) {
      print('Error clearing coach history: $e');
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

    // 1. Try Groq cloud API first if key is present
    final groqResponse = await _getGroqResponse(systemPrompt, chatHistory, userMessage);
    if (groqResponse != null && groqResponse.trim().isNotEmpty) {
      return groqResponse.trim();
    }

    // 2. Intelligent local exercise coaching engine (works 100% offline & without API key)
    return await _buildLocalExerciseCoachResponse(
      exerciseName: exerciseName,
      userMessage: userMessage,
    );
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

    // 1. Try Groq cloud API first if key is present
    final groqResponse = await _getGroqResponse(systemPrompt, chatHistory, userMessage);
    if (groqResponse != null && groqResponse.trim().isNotEmpty) {
      return groqResponse.trim();
    }

    // 2. Intelligent local coach engine for Gym Bot
    return _buildLocalGeneralCoachResponse(
      userProfile: userProfile,
      workoutHistory: workoutHistory,
      userMessage: userMessage,
    );
  }

  Future<String?> _getGroqResponse(String systemPrompt, List<Map<String, String>> history, String userMessage) async {
    final apiKey = await getActiveApiKey();
    if (apiKey.isEmpty) return null;

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content']?.toString();
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      } else {
        print('Groq API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('AIChatService Groq exception: $e');
    }
    return null;
  }

  // ==========================================
  // EXERCISE-SPECIFIC INTELLIGENT COACH ENGINE
  // ==========================================

  Future<String> _buildLocalExerciseCoachResponse({
    required String exerciseName,
    required String userMessage,
  }) async {
    final q = userMessage.toLowerCase().trim();
    final Exercise? exercise = await LocalExerciseService.getExerciseByName(exerciseName);

    final displayName = exercise?.name ?? exerciseName;
    final targetMuscle = (exercise?.targetMuscle ?? _inferTargetMuscle(exerciseName)).toUpperCase();
    final equipment = exercise?.equipment ?? _inferEquipment(exerciseName);
    final instructions = exercise?.instructions ?? [];

    // 1. Common Mistakes / Injury Prevention
    if (q.contains('mistake') || q.contains('wrong') || q.contains('error') || 
        q.contains('avoid') || q.contains('hurt') || q.contains('pain') || 
        q.contains('injur') || q.contains('danger') || q.contains('bad')) {
      return _getCommonMistakes(displayName, targetMuscle, instructions);
    }

    // 2. Muscles Worked / Anatomy
    if (q.contains('muscle') || q.contains('target') || q.contains('work') || 
        q.contains('hit') || q.contains('part') || q.contains('anatomy') || 
        q.contains('where') || q.contains('feel') || q.contains('group')) {
      return _getMusclesWorked(displayName, targetMuscle);
    }

    // 3. Regressions / Can\'t do yet / Modifications / Substitutes
    if (q.contains("can't") || q.contains('cant') || q.contains('hard') || 
        q.contains('difficult') || q.contains('heavy') || q.contains('fail') || 
        q.contains('easier') || q.contains('substitute') || q.contains('alternative') || 
        q.contains('beginner') || q.contains('regress') || q.contains('modify') || 
        q.contains('stuck') || q.contains('weak') || q.contains('swap')) {
      return _getRegressionsAndSubstitutes(displayName, targetMuscle, equipment);
    }

    // 4. Sets, Reps, Weight & Rest
    if (q.contains('set') || q.contains('rep') || q.contains('weight') || 
        q.contains('rest') || q.contains('how many') || q.contains('how much') || 
        q.contains('tempo') || q.contains('frequency') || q.contains('often')) {
      return _getSetsRepsAndRest(displayName, targetMuscle);
    }

    // 5. Form / Technique / How to do properly / Default
    return _getProperFormGuide(displayName, targetMuscle, equipment, instructions);
  }

  String _getProperFormGuide(String name, String targetMuscle, String equipment, List<String> instructions) {
    final buffer = StringBuffer();
    buffer.writeln('PROPER FORM GUIDE: $name\n');
    buffer.writeln('Target: $targetMuscle | Equipment: $equipment\n');

    if (instructions.isNotEmpty) {
      buffer.writeln('Execution Steps:');
      for (int i = 0; i < instructions.length; i++) {
        buffer.writeln('${i + 1}. ${instructions[i]}');
      }
      buffer.writeln();
    } else {
      buffer.writeln('Key Execution Points:');
      buffer.writeln('1. Setup: Maintain an athletic stance with feet grounded and spine neutral.');
      buffer.writeln('2. Initiation: Brace your core and engage the $targetMuscle before moving the load.');
      buffer.writeln('3. Eccentric Phase: Lower the weight under control (2-3 seconds).');
      buffer.writeln('4. Concentric Phase: Drive through with deliberate power, avoiding momentum.');
      buffer.writeln('5. Lockout: Pause briefly at peak contraction without hyperextending joints.\n');
    }

    buffer.writeln('Breathing & Cueing:');
    buffer.writeln('- Inhale deeply during the lowering (eccentric) phase to maintain intra-abdominal pressure.');
    buffer.writeln('- Exhale forcefully through the sticking point on the exertion (concentric) phase.');
    buffer.writeln('- Mind-Muscle Cue: Focus on contracting your $targetMuscle rather than just displacing the weight.');

    return buffer.toString().trim();
  }

  String _getCommonMistakes(String name, String targetMuscle, List<String> instructions) {
    final lowerName = name.toLowerCase();
    final lowerMuscle = targetMuscle.toLowerCase();
    final buffer = StringBuffer();

    buffer.writeln('COMMON MISTAKES TO AVOID: $name\n');

    if (lowerName.contains('bench') || lowerMuscle.contains('chest') || lowerName.contains('push-up')) {
      buffer.writeln('1. Flaring Elbows Out (90 degrees): Puts intense shear force on the rotator cuff. Keep elbows tucked at 45-60 degrees to your torso.');
      buffer.writeln('2. Bouncing the Weight: Bouncing removes tension from the pectorals and risks sternum/cartilage injury. Pause for 0.5s at the chest.');
      buffer.writeln('3. Lifting Hips Off Bench: Keep your glutes pinned to the bench and drive through your heels for stability.');
      buffer.writeln('4. Wrists Bent Backwards: Keep the bar stacked directly over your wrist joints and forearms.');
    } else if (lowerName.contains('squat') || lowerMuscle.contains('quad') || lowerMuscle.contains('glute') || lowerName.contains('leg press') || lowerName.contains('lunge')) {
      buffer.writeln('1. Knees Caving Inward (Valgus Collapse): Keep your knees actively tracking in the same line as your toes.');
      buffer.writeln('2. Lower Back Rounding ("Butt Wink"): Only descend as deep as your mobility allows while maintaining a neutral lumbar spine.');
      buffer.writeln('3. Heels Lifting Off Ground: Shifting weight to your toes overloads the patellar tendon. Drive through the mid-foot and heels.');
      buffer.writeln('4. Cutting Range of Motion: Aim for hip crease at or slightly below parallel for full quad and glute development.');
    } else if (lowerName.contains('deadlift') || lowerMuscle.contains('lower back') || lowerMuscle.contains('hamstring') || lowerName.contains('rdl')) {
      buffer.writeln('1. Rounding the Lower Back: Keep your chest tall, lats locked down, and spine straight throughout the entire pull.');
      buffer.writeln('2. Bar Drifting Away From Shins: Keep the bar in constant contact with your shins and thighs to protect your lumbar spine.');
      buffer.writeln('3. Hyperextending at Lockout: Stand upright and squeeze your glutes at the top—do not hyperextend your lower back.');
      buffer.writeln('4. Jerking off the Floor: Pull the slack out of the bar first before initiating drive through the floor.');
    } else if (lowerName.contains('pull') || lowerName.contains('chin') || lowerName.contains('row') || lowerMuscle.contains('lat') || lowerMuscle.contains('back')) {
      buffer.writeln('1. Pulling with Arms Only: Retract and depress your scapulae first, then drive your elbows back to engage the lats.');
      buffer.writeln('2. Excessive Body Swinging: Using momentum robs your back of time-under-tension. Keep your torso stable.');
      buffer.writeln('3. Shrugging Shoulders: Keep traps relaxed away from your ears to prevent upper-trap compensation.');
      buffer.writeln('4. Cutting the Stretch: Extend your arms fully at the top/bottom to work the muscle through its complete excursion.');
    } else if (lowerName.contains('press') || lowerName.contains('shoulder') || lowerMuscle.contains('deltoid') || lowerName.contains('raise')) {
      buffer.writeln('1. Over-Arching Lower Back: Squeeze your glutes and brace your abs to prevent lumbar hyperextension during presses.');
      buffer.writeln('2. Raising Dumbbells Straight Out on Laterals: Move dumbbells in the scapular plane (30 degrees forward) with elbows leading.');
      buffer.writeln('3. Shrugging with Upper Traps: Keep your shoulders depressed down away from your neck.');
      buffer.writeln('4. Using Excessive Momentum: Lower the weight under control for 2 seconds to maximize deltoid tension.');
    } else if (lowerName.contains('curl') || lowerMuscle.contains('bicep')) {
      buffer.writeln('1. Torso Rocking / Cheating: Keep your upper body still and let your biceps do 100% of the work.');
      buffer.writeln('2. Elbows Drifting Forward: Keep elbows pinned to your sides to prevent front delts from taking over.');
      buffer.writeln('3. Fast Dropping on the Way Down: The eccentric (lowering) phase stimulates massive hypertrophy—lower with a 2-3s count.');
      buffer.writeln('4. Wrist Hyperextension: Keep wrists neutral or slightly flexed throughout the curl.');
    } else {
      buffer.writeln('1. Rushing the Tempo: Take 2-3 seconds on the eccentric (lowering) phase and 1 second on the concentric phase.');
      buffer.writeln('2. Loose Core: Failing to brace your abdominal wall destabilizes your torso and increases joint strain.');
      buffer.writeln('3. Ego Lifting: Using weight you cannot control with proper form reduces muscle activation and spikes injury risk.');
      buffer.writeln('4. Incomplete Range of Motion: Avoid half-reps; full range stimulates maximum muscle fiber recruitment.');
    }

    buffer.writeln('\nCoaching Rule: Drop the weight by 15-20% if any of these errors occur.');
    return buffer.toString().trim();
  }

  String _getMusclesWorked(String name, String targetMuscle) {
    final lowerName = name.toLowerCase();
    final lowerMuscle = targetMuscle.toLowerCase();
    final buffer = StringBuffer();

    buffer.writeln('MUSCLES WORKED: $name\n');

    if (lowerMuscle.contains('chest') || lowerName.contains('bench') || lowerName.contains('push-up')) {
      buffer.writeln('Primary Target: Pectoralis Major (Sternal & Clavicular heads)');
      buffer.writeln('Secondary (Synergists): Anterior Deltoids, Triceps Brachii');
      buffer.writeln('Stabilizers: Serratus Anterior, Rotator Cuff, Core');
    } else if (lowerMuscle.contains('quad') || lowerName.contains('squat') || lowerName.contains('leg press')) {
      buffer.writeln('Primary Target: Quadriceps (Rectus Femoris, Vastus Lateralis/Medialis/Intermedius)');
      buffer.writeln('Secondary (Synergists): Gluteus Maximus, Adductor Magnus, Hamstrings');
      buffer.writeln('Stabilizers: Erector Spinae, Transverse Abdominis, Calves');
    } else if (lowerMuscle.contains('back') || lowerMuscle.contains('lat') || lowerName.contains('pull') || lowerName.contains('row')) {
      buffer.writeln('Primary Target: Latissimus Dorsi, Rhomboids, Middle & Lower Trapezius');
      buffer.writeln('Secondary (Synergists): Biceps Brachii, Brachialis, Rear Deltoids');
      buffer.writeln('Stabilizers: Core, Erector Spinae, Forearm Flexors');
    } else if (lowerMuscle.contains('shoulder') || lowerName.contains('press') || lowerName.contains('raise')) {
      buffer.writeln('Primary Target: Deltoids (Anterior, Lateral, or Posterior heads)');
      buffer.writeln('Secondary (Synergists): Triceps Brachii, Upper Trapezius, Serratus Anterior');
      buffer.writeln('Stabilizers: Rotator Cuff muscles (Supraspinatus, Infraspinatus), Core');
    } else if (lowerMuscle.contains('bicep') || lowerName.contains('curl')) {
      buffer.writeln('Primary Target: Biceps Brachii (Short Head & Long Head)');
      buffer.writeln('Secondary (Synergists): Brachialis, Brachioradialis');
      buffer.writeln('Stabilizers: Forearm Flexors, Anterior Deltoid');
    } else if (lowerMuscle.contains('tricep') || lowerName.contains('extension') || lowerName.contains('dip')) {
      buffer.writeln('Primary Target: Triceps Brachii (Lateral, Long, and Medial heads)');
      buffer.writeln('Secondary (Synergists): Anterior Deltoids, Pectorals (on dips)');
      buffer.writeln('Stabilizers: Core, Wrist Extensors');
    } else if (lowerMuscle.contains('hamstring') || lowerName.contains('deadlift') || lowerName.contains('rdl')) {
      buffer.writeln('Primary Target: Hamstrings (Biceps Femoris, Semitendinosus), Gluteus Maximus');
      buffer.writeln('Secondary (Synergists): Erector Spinae, Adductor Magnus, Lats');
      buffer.writeln('Stabilizers: Transverse Abdominis, Trapezius, Forearm Grip');
    } else {
      buffer.writeln('Primary Target: $targetMuscle');
      buffer.writeln('Secondary (Synergists): Supporting synergist muscle chains');
      buffer.writeln('Stabilizers: Core and stabilizing postural musculature');
    }

    buffer.writeln('\nBiomechanics Note: Contract the target muscle forcefully at peak contraction to stimulate maximum motor unit recruitment.');
    return buffer.toString().trim();
  }

  String _getRegressionsAndSubstitutes(String name, String targetMuscle, String equipment) {
    final lowerName = name.toLowerCase();
    final lowerMuscle = targetMuscle.toLowerCase();
    final buffer = StringBuffer();

    buffer.writeln('MODIFICATIONS & ALTERNATIVES: $name\n');
    buffer.writeln('If this exercise is too challenging or causing discomfort, try these step-down regressions:\n');

    if (lowerName.contains('pullup') || lowerName.contains('chin-up')) {
      buffer.writeln('1. Resistance Band Assisted Pull-ups: Loop a heavy band under your feet to take off 20-40% of bodyweight.');
      buffer.writeln('2. Inverted Bodyweight Rows (Australian Pull-ups): Hang under a barbell set at waist height with heels on floor.');
      buffer.writeln('3. Lat Pulldowns: Adjust machine pin to a manageable load (e.g. 50-60% bodyweight) and build up volume.');
      buffer.writeln('4. Negative Pull-ups: Jump to the top position, hold for 1 second, then lower yourself down over 5 slow seconds.');
    } else if (lowerName.contains('bench') || (lowerMuscle.contains('chest') && lowerName.contains('barbell'))) {
      buffer.writeln('1. Dumbbell Bench Press: Allows natural wrist and shoulder rotation to reduce joint stress.');
      buffer.writeln('2. Push-ups or Incline Push-ups: Place hands on an elevated bench to reduce load while perfecting pressing mechanics.');
      buffer.writeln('3. Chest Press Machine: Eliminates balance demands so you can focus strictly on pectoral contraction.');
    } else if (lowerName.contains('squat') && (lowerName.contains('barbell') || lowerName.contains('back'))) {
      buffer.writeln('1. Goblet Squats: Hold a single dumbbell vertically against your sternum; naturally enforces an upright torso.');
      buffer.writeln('2. Box Squats: Squat down to a knee-height bench or box to ensure depth and eliminate bottom sticking point fears.');
      buffer.writeln('3. Bodyweight Air Squats: Perfect knee tracking and hip hinge mechanics before adding external load.');
      buffer.writeln('4. Leg Press Machine: Removes spinal loading while safely building quadricep strength.');
    } else if (lowerName.contains('deadlift')) {
      buffer.writeln('1. Trap Bar (Hex Bar) Deadlift: Puts you inside the center of mass with neutral handles, greatly reducing lumbar shear.');
      buffer.writeln('2. Romanian Deadlifts (RDLs) with Dumbbells: Focus strictly on the hip hinge without pulling from floor depth.');
      buffer.writeln('3. Kettlebell Deadlift From Elevated Blocks: Reduces required hip flexion depth.');
    } else if (lowerName.contains('overhead') || lowerName.contains('shoulder press')) {
      buffer.writeln('1. Seated Dumbbell Shoulder Press: Provides back support and independent shoulder stabilization.');
      buffer.writeln('2. Arnold Press: Twisting movement opens up the subacromial space for pain-free pressing.');
      buffer.writeln('3. Resistance Band Overhead Press: Smooth variable resistance that matches your strength curve.');
    } else if (lowerName.contains('dip')) {
      buffer.writeln('1. Bench Dips: Keep feet on the floor with knees bent at 90 degrees.');
      buffer.writeln('2. Assisted Dip Machine: Uses counter-weights to balance your bodyweight.');
      buffer.writeln('3. Close-Grip Push-ups: Trains triceps and chest pressing mechanics with zero shoulder impingement risk.');
    } else {
      buffer.writeln('1. Reduce Load: Drop weight by 30-40% and master a 3-second eccentric tempo.');
      buffer.writeln('2. Dumbbell / Cable Variation: Replace rigid barbell with dumbbells or cables for free range of motion.');
      buffer.writeln('3. Machine Alternative: Utilize a selectorized gym machine to stabilize the movement path.');
    }

    buffer.writeln('\nProgression Plan: Aim for 3 sets of 10-12 clean reps on the regression before graduating back to $name.');
    return buffer.toString().trim();
  }

  String _getSetsRepsAndRest(String name, String targetMuscle) {
    final buffer = StringBuffer();
    buffer.writeln('RECOMMENDED SETS, REPS & INTENSITY: $name\n');

    buffer.writeln('1. Hypertrophy (Muscle Growth):');
    buffer.writeln('   - Sets: 3 to 4');
    buffer.writeln('   - Reps: 8 to 12');
    buffer.writeln('   - Rest: 60 to 90 seconds');
    buffer.writeln('   - Intensity: Leave 1-2 reps in reserve (RPE 8)\n');

    buffer.writeln('2. Pure Strength & Power:');
    buffer.writeln('   - Sets: 4 to 5');
    buffer.writeln('   - Reps: 3 to 6');
    buffer.writeln('   - Rest: 2 to 3 minutes');
    buffer.writeln('   - Intensity: Heavy compound loading (RPE 8.5-9)\n');

    buffer.writeln('3. Muscular Endurance & Conditioning:');
    buffer.writeln('   - Sets: 2 to 3');
    buffer.writeln('   - Reps: 15 to 20');
    buffer.writeln('   - Rest: 45 seconds\n');

    buffer.writeln('Progression Rule: When you can complete all sets at the top rep target with clean form, increase the resistance by 2.5-5% next session.');
    return buffer.toString().trim();
  }

  // ==========================================
  // GENERAL COACH ENGINE (GYM BOT)
  // ==========================================

  String _buildLocalGeneralCoachResponse({
    required Map<String, dynamic> userProfile,
    required List<dynamic> workoutHistory,
    required String userMessage,
  }) {
    final q = userMessage.toLowerCase().trim();
    final name = userProfile['fullName'] ?? 'Athlete';
    final goal = userProfile['fitness_goal'] ?? 'General Fitness';
    final level = userProfile['training_level'] ?? 'Beginner';
    final equipment = userProfile['equipment_list'] ?? 'Standard Gym';

    // 1. Create Workout Plan / Split
    if (q.contains('plan') || q.contains('routine') || q.contains('split') || 
        q.contains('program') || q.contains('workout') || q.contains('schedule') || 
        q.contains('ppl') || q.contains('push pull') || q.contains('upper lower')) {
      return _generateWorkoutPlan(name, goal, level, equipment);
    }

    // 2. Nutrition Tips & Macros
    if (q.contains('nutrition') || q.contains('diet') || q.contains('protein') || 
        q.contains('calorie') || q.contains('deficit') || q.contains('surplus') || 
        q.contains('bulk') || q.contains('cut') || q.contains('meal') || 
        q.contains('food') || q.contains('supplement') || q.contains('creatine')) {
      return _generateNutritionTips(name, goal);
    }

    // 3. Motivation & Recovery
    if (q.contains('motivation') || q.contains('sore') || q.contains('recovery') || 
        q.contains('rest') || q.contains('sleep') || q.contains('doms') || 
        q.contains('tired') || q.contains('fatigue') || q.contains('lazy')) {
      return _generateRecoveryAndMotivation(name, goal);
    }

    // 4. Form Check advice
    if (q.contains('form') || q.contains('check') || q.contains('technique')) {
      return 'Hey $name! For an in-depth form check, tap on any specific exercise during your workout session and open the AI Coach panel.\n\nUniversal Golden Rules of Form:\n1. Core Bracing: Contract your abdominals 360 degrees like preparing for a punch.\n2. Scapular Control: Keep shoulder blades retracted and depressed on pressing and pulling.\n3. Spine Neutrality: Avoid excessive hyperextension or lumbar rounding.\n4. Controlled Eccentric: Take 2-3 seconds to lower the weight under tension.\n\nWhich exercise would you like specific coaching on?';
    }

    // 5. Default Conversational / Greeting
    return 'Hey $name! I\'m your Spottr AI Coach. I see your goal is $goal at the $level level.\n\nHere is what I can do for you right now:\n- 📋 Generate a customized workout split\n- 🥗 Calculate your daily protein & nutrition guidelines\n- 🔍 Step-by-step form cues & common mistake fixes\n- ⚡ Recovery & progressive overload strategies\n\nTap one of the quick chips above or tell me what you want to achieve today!';
  }

  String _generateWorkoutPlan(String name, String goal, String level, String equipment) {
    final buffer = StringBuffer();
    buffer.writeln('### 🏋️ Custom $goal Workout Split for $name ($level)\n');

    if (level.toLowerCase().contains('beginner')) {
      buffer.writeln('**3-Day Full Body Routine (Mon / Wed / Fri)**\n');
      buffer.writeln('**Day 1: Full Body Foundation**');
      buffer.writeln('- Goblet Squats / Barbell Squats: 3 sets x 8-10 reps');
      buffer.writeln('- Push-Ups / Barbell Bench Press: 3 sets x 8-10 reps');
      buffer.writeln('- Dumbbell Rows / Lat Pulldown: 3 sets x 10-12 reps');
      buffer.writeln('- Plank: 3 sets x 45s hold\n');

      buffer.writeln('**Day 2: Full Body Posterior & Core**');
      buffer.writeln('- Romanian Deadlifts (RDLs): 3 sets x 8-10 reps');
      buffer.writeln('- Overhead Dumbbell Shoulder Press: 3 sets x 10 reps');
      buffer.writeln('- Inverted Rows / Seated Cable Rows: 3 sets x 10-12 reps');
      buffer.writeln('- Hanging Knee Raises: 3 sets x 12 reps\n');

      buffer.writeln('**Day 3: Full Body Hypertrophy**');
      buffer.writeln('- Dumbbell Lunges / Leg Press: 3 sets x 10 reps per leg');
      buffer.writeln('- Incline Dumbbell Bench Press: 3 sets x 10-12 reps');
      buffer.writeln('- Lat Pulldowns: 3 sets x 10-12 reps');
      buffer.writeln('- Dumbbell Bicep Curls & Tricep Pushdowns: 3 sets x 12 reps');
    } else {
      buffer.writeln('**Push / Pull / Legs (PPL) Split**\n');
      buffer.writeln('**Day 1: Push (Chest, Shoulders, Triceps)**');
      buffer.writeln('- Barbell Bench Press: 4 sets x 6-8 reps');
      buffer.writeln('- Incline Dumbbell Press: 3 sets x 8-10 reps');
      buffer.writeln('- Standing Overhead Press: 3 sets x 8-10 reps');
      buffer.writeln('- Lateral Raises: 4 sets x 12-15 reps');
      buffer.writeln('- Triceps Rope Pushdown: 3 sets x 12-15 reps\n');

      buffer.writeln('**Day 2: Pull (Back, Rear Delts, Biceps)**');
      buffer.writeln('- Barbell Deadlift or Barbell Row: 4 sets x 6-8 reps');
      buffer.writeln('- Pullups / Lat Pulldown: 4 sets x 8-10 reps');
      buffer.writeln('- Seated Cable Rows: 3 sets x 10-12 reps');
      buffer.writeln('- Face Pulls: 3 sets x 15 reps');
      buffer.writeln('- Incline Dumbbell Curls: 3 sets x 10-12 reps\n');

      buffer.writeln('**Day 3: Legs (Quads, Hamstrings, Calves, Abs)**');
      buffer.writeln('- Barbell Back Squats: 4 sets x 6-8 reps');
      buffer.writeln('- Romanian Deadlifts (RDLs): 3 sets x 8-10 reps');
      buffer.writeln('- Bulgarian Split Squats: 3 sets x 10 reps/leg');
      buffer.writeln('- Standing Calf Raises: 4 sets x 15 reps');
      buffer.writeln('- Hanging Leg Raises: 3 sets x 15 reps');
    }

    buffer.writeln('\n*Warm-up: 5 minutes light cardio + dynamic mobility before every session.*');
    return buffer.toString().trim();
  }

  String _generateNutritionTips(String name, String goal) {
    final buffer = StringBuffer();
    buffer.writeln('### 🥗 Sports Nutrition Blueprint for $name\n');
    buffer.writeln('Goal: **$goal**\n');

    buffer.writeln('**1. Protein Intake (The Building Block):**');
    buffer.writeln('- Aim for **1.6 to 2.2 grams of protein per kilogram** of body weight (0.8 - 1.0g per lb).');
    buffer.writeln('- Distribute across 3-4 meals (25-40g per meal) to maximize Muscle Protein Synthesis (MPS).\n');

    buffer.writeln('**2. Caloric Strategy:**');
    if (goal.toLowerCase().contains('loss') || goal.toLowerCase().contains('cut')) {
      buffer.writeln('- Target a moderate **300-500 calorie deficit** below maintenance for sustainable fat loss without muscle sacrifice.');
      buffer.writeln('- Keep protein high and prioritize fibrous vegetables to maintain satiety.');
    } else {
      buffer.writeln('- Target a clean **200-300 calorie surplus** above maintenance to support new lean tissue growth.');
      buffer.writeln('- Fuel heavy training days with complex carbs (oats, rice, sweet potatoes, whole grains).');
    }

    buffer.writeln('\n**3. Hydration & Performance:**');
    buffer.writeln('- Drink 3.0 to 4.0 liters of water daily. A 2% drop in hydration drops muscle strength by over 10%.');
    buffer.writeln('- Electrolytes (sodium, potassium, magnesium) before and during heavy lifting.\n');

    buffer.writeln('**4. Evidence-Based Supplements:**');
    buffer.writeln('- **Creatine Monohydrate**: 5g daily (enhances ATP power output and cellular volume).');
    buffer.writeln('- **Whey Protein**: Convenient way to hit protein goals post-workout.');
    buffer.writeln('- **Vitamin D3 & Omega-3 Fish Oil**: For joint recovery and hormonal health.');

    return buffer.toString().trim();
  }

  String _generateRecoveryAndMotivation(String name, String goal) {
    final buffer = StringBuffer();
    buffer.writeln('### ⚡ Recovery & Mindset Protocol for $name\n');

    buffer.writeln('"Muscles do not grow in the gym—they get broken down in the gym, and grow while you recover."\n');

    buffer.writeln('**The 4 Pillars of Recovery:**');
    buffer.writeln('1. **Sleep Optimization**: 7 to 9 hours of quality sleep. The majority of growth hormone is released during deep slow-wave sleep.');
    buffer.writeln('2. **DOMS vs. Joint Pain**: Delayed Onset Muscle Soreness peaks 24-48 hours post-workout and feels like dull muscle fullness. Sharp, pinching joint pain means stop and reassess form.');
    buffer.writeln('3. **Active Recovery**: On rest days, do 20-30 minutes of light walking, gentle cycling, or mobility flows to increase blood flow.');
    buffer.writeln('4. **Deload Every 6-8 Weeks**: Reduce workout volume by 50% for one week to allow nervous system and connective tissues to regenerate.');

    return buffer.toString().trim();
  }

  String _inferTargetMuscle(String exerciseName) {
    final lower = exerciseName.toLowerCase();
    if (lower.contains('bench') || lower.contains('chest') || lower.contains('push-up') || lower.contains('fly')) return 'Chest';
    if (lower.contains('squat') || lower.contains('leg press') || lower.contains('lunge') || lower.contains('quad')) return 'Quadriceps';
    if (lower.contains('deadlift') || lower.contains('rdl') || lower.contains('hamstring') || lower.contains('curl')) return 'Hamstrings';
    if (lower.contains('row') || lower.contains('pull') || lower.contains('lat') || lower.contains('chin')) return 'Back / Lats';
    if (lower.contains('shoulder') || lower.contains('overhead') || lower.contains('press') || lower.contains('raise')) return 'Shoulders';
    if (lower.contains('bicep') || lower.contains('curl')) return 'Biceps';
    if (lower.contains('tricep') || lower.contains('dip') || lower.contains('extension') || lower.contains('pushdown')) return 'Triceps';
    if (lower.contains('plank') || lower.contains('crunch') || lower.contains('ab') || lower.contains('sit-up')) return 'Abdominals';
    return 'Full Body';
  }

  String _inferEquipment(String exerciseName) {
    final lower = exerciseName.toLowerCase();
    if (lower.contains('barbell')) return 'Barbell';
    if (lower.contains('dumbbell')) return 'Dumbbell';
    if (lower.contains('cable')) return 'Cable';
    if (lower.contains('machine')) return 'Machine';
    if (lower.contains('band')) return 'Resistance Band';
    if (lower.contains('kettlebell')) return 'Kettlebell';
    return 'Bodyweight';
  }
}
