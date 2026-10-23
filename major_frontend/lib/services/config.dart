import 'package:http/http.dart' as http;

class Config {
  static const List<String> _candidates = [
    'https://instrumentally-unoffered-bambi.ngrok-free.dev',
    'http://172.20.10.3:5000',
    'http://192.168.100.46:5000',
  ];

  static String _baseUrl = _candidates[0];

  static String get baseUrl => _baseUrl;

  static Future<void> init() async {
    print('Config: Initializing baseUrl...');
    for (String url in _candidates) {
      try {
        final response = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          _baseUrl = url;
          print('Config: Successfully connected to $url');
          return;
        }
      } catch (e) {
        print('Config: Failed to connect to $url: $e');
      }
    }
    print('Config: Using default fallback: $_baseUrl');
  }
}
