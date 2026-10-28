import 'package:supabase_flutter/supabase_flutter.dart';

class Config {
  static const String supabaseUrl = 'https://movymmlayggqzjtunlfk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1vdnltbWxheWdncXpqdHVubGZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxNjY1MDYsImV4cCI6MjEwODc0MjUwNn0.wnYGxn8vr3EvMMVe__qeTrurkLmCP2-5UsqKA9y9tLw';

  // Live Vercel API Relay for OTP verification emails (spottrnoreply@gmail.com)
  static const String vercelApiUrl = 'https://spottrlanding.vercel.app';

  static String get baseUrl => vercelApiUrl;

  static SupabaseClient get supabase => Supabase.instance.client;

  static Future<void> init() async {
    print('Config: Standalone frontend initialized with Supabase: $supabaseUrl');
  }
}
