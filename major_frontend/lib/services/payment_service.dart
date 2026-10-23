import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';

class PaymentService {
  static String get baseUrl => '${Config.baseUrl}/api/payments';

  static Future<bool> createCheckoutSession(String planType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'planType': planType}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = Uri.parse(data['url']);
        
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('PaymentService Error: $e');
      return false;
    }
  }
}
