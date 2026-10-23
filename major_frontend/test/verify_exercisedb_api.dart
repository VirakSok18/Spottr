import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- ExerciseDB API Verification ---');
  
  const String baseUrl = 'https://exercisedb.p.rapidapi.com';
  const String host = 'exercisedb.p.rapidapi.com';
  const String apiKey = 'e3bfb7c817msh3318ca65a5400c1p1231f3jsna9ae8cb20340';

  final headers = {
    'x-rapidapi-host': host,
    'x-rapidapi-key': apiKey,
  };

  try {
    print('Fetching exercises for target: abs...');
    final response = await http.get(
      Uri.parse('$baseUrl/exercises/target/abs?limit=2'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('Successfully fetched ${data.length} exercises.');
      
      for (var ex in data) {
        print('\nFull Exercise Object:');
        print(const JsonEncoder.withIndent('  ').convert(ex));
        
        final mediaUrl = ex['gifUrl']?.toString();
        if (mediaUrl != null && mediaUrl.contains('exercisedb.io/image')) {
          print('Note: Media URL is an image endpoint (likely serves GIF or optimized video).');
        }
      }
    } else {
      print('Failed to fetch exercises. Status code: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  print('\n--- Verification Finished ---');
}
