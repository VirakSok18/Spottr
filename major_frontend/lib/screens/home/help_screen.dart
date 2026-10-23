import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 12),
            _buildFAQTile(
              'How do I find a workout buddy?',
              'Head to the Community tab to discover other users. You can swipe through profiles, view their training levels, and send a message to start training together.',
            ),
            _buildFAQTile(
              'How do I log a workout?',
              'Select a program from the Workout Library, choose an exercise, and follow the instructions. Your progress is automatically saved to your profile upon completion.',
            ),
            _buildFAQTile(
              'What is Spottr Premium?',
              'Spottr Premium removes all advertisements and provides access to personalized training plans and structured workouts. Regular workouts, such as the classic routines and standard programs in the Workouts tab, remain available to all users. Premium also includes limited access to our AI-powered chatbot.',
            ),
            _buildFAQTile(
              'How is my privacy protected?',
              'We take your privacy seriously. Your body stats are only used to match you with compatible partners, and you control what information is visible on your public profile.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: const Color(0xFFB497FF),
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        iconColor: const Color(0xFFB497FF),
        collapsedIconColor: Colors.white,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              answer,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
