import '../screens/auth/auth_screens.dart';

class PaymentService {
  static Future<bool> createCheckoutSession(String planType) async {
    // Spottr is 100% free and unlocked forever!
    AuthService.updatePremiumStatus(true);
    return true;
  }
}
