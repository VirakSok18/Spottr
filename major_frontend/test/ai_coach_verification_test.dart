import 'package:flutter_test/flutter_test.dart';
import 'package:major_frontend/services/ai_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AIChatService Tests', () {
    final aiService = AIChatService();

    test('getAIResponse generates specific form guide for Bench Press', () async {
      final response = await aiService.getAIResponse(
        exerciseName: 'Barbell Bench Press',
        chatHistory: [],
        userMessage: 'How do I do this properly?',
      );

      expect(response, contains('PROPER FORM GUIDE: Barbell Bench Press'));
      expect(response, contains('CHEST'));
      expect(response, isNot(contains('Hi athlete! I am your Spottr AI Coach. For proper form')));
    });

    test('getAIResponse generates common mistakes for Squat', () async {
      final response = await aiService.getAIResponse(
        exerciseName: 'Barbell Full Squat',
        chatHistory: [],
        userMessage: 'What are common mistakes?',
      );

      expect(response, contains('COMMON MISTAKES TO AVOID: Barbell Full Squat'));
      expect(response, contains('Valgus Collapse'));
      expect(response, isNot(contains('Hi athlete! I am your Spottr AI Coach. For proper form')));
    });

    test('getAIResponse generates muscles worked for Pullups', () async {
      final response = await aiService.getAIResponse(
        exerciseName: 'Pullups',
        chatHistory: [],
        userMessage: 'What muscles does this work?',
      );

      expect(response, contains('MUSCLES WORKED: Pullups'));
      expect(response, contains('Latissimus Dorsi'));
      expect(response, isNot(contains('Hi athlete! I am your Spottr AI Coach. For proper form')));
    });

    test('getGeneralCoachResponse generates workout plan', () async {
      final response = await aiService.getGeneralCoachResponse(
        userProfile: {
          'fullName': 'Virak',
          'fitness_goal': 'Muscle Building',
          'training_level': 'Intermediate',
          'equipment_list': 'Gym',
        },
        workoutHistory: [],
        chatHistory: [],
        userMessage: 'Create a plan',
      );

      expect(response, contains('Push / Pull / Legs (PPL) Split'));
      expect(response, contains('Virak'));
      expect(response, isNot(contains('Hi athlete! I am your Spottr AI Coach. For proper form')));
    });

    test('getGeneralCoachResponse generates nutrition tips', () async {
      final response = await aiService.getGeneralCoachResponse(
        userProfile: {
          'fullName': 'Virak',
          'fitness_goal': 'Muscle Building',
          'training_level': 'Intermediate',
        },
        workoutHistory: [],
        chatHistory: [],
        userMessage: 'Nutrition tips',
      );

      expect(response, contains('Sports Nutrition Blueprint'));
      expect(response, contains('Protein Intake'));
      expect(response, contains('Creatine Monohydrate'));
      expect(response, isNot(contains('Hi athlete! I am your Spottr AI Coach. For proper form')));
    });
  });
}
