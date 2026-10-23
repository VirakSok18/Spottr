import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Data. Your Control.',
              style: GoogleFonts.poppins(
                color: const Color(0xFFB497FF),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'At Spottr, we believe your privacy is just as important as your progress. We do not sell your personal data. Here is a transparent look at how we handle your information:',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              icon: Icons.monitor_weight_outlined,
              title: 'Body Stats & Experience',
              content: 'Your height, weight, and training level are strictly used to match you with compatible workout partners and suggest tailored programs. You control what is shown on your public profile.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              icon: Icons.location_on_outlined,
              title: 'Location & Availability',
              content: 'Your location helps connect you with local training buddies and gyms. We ONLY use rough approximations to ensure you stay safe while building your fitness community.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              icon: Icons.shield_outlined,
              title: 'Security First',
              content: 'We use industry-standard encryption to ensure your personal data stays locked down. Your journey stays safe with us.',
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFB497FF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFB497FF), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
