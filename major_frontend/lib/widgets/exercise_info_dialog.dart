import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExerciseInfoDialog extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const ExerciseInfoDialog({
    Key? key,
    required this.exercise,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mapping from targetMuscle to human-readable Focus Area and image
    final String target = (exercise['targetMuscle'] ?? '').toString().toLowerCase();
    
    String focusAreaName = "Full Body";
    String bodyDiagramAsset = "assets/images/fullbody_1.png";
    List<String> secondaryFocusAreas = [];

    if (target.contains('chest')) {
      focusAreaName = "Chest";
      bodyDiagramAsset = "assets/images/chest_1.png";
      secondaryFocusAreas = ["Shoulders", "Triceps"];
    } else if (target.contains('abdominals')) {
      focusAreaName = "Cores";
      bodyDiagramAsset = "assets/images/core_1.png";
    } else if (target.contains('biceps') || target.contains('triceps') || target.contains('forearms')) {
      focusAreaName = "Arm";
      bodyDiagramAsset = "assets/images/arm_1.png";
      if (target.contains('biceps')) secondaryFocusAreas = ["Forearms"];
    } else if (target.contains('shoulders')) {
      focusAreaName = "Shoulder";
      bodyDiagramAsset = "assets/images/shoulder_1.png";
      secondaryFocusAreas = ["Chest"];
    } else if (target.contains('lats') || target.contains('middle back') || target.contains('traps') || target.contains('lower back')) {
      focusAreaName = "Back";
      bodyDiagramAsset = "assets/images/back_1.png";
    } else if (target.contains('quadriceps') || target.contains('hamstrings') || target.contains('glutes') || target.contains('calves')) {
      focusAreaName = "Leg";
      bodyDiagramAsset = "assets/images/leg_1.png";
    }

    // Combine for chips
    List<String> allFocusChips = [focusAreaName, ...secondaryFocusAreas];

    return Dialog(
      backgroundColor: const Color(0xFF1B1B1B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Header
            Text(
              exercise['name'] ?? 'Workout Info',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'INSTRUCTIONS',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFB497FF),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            
            // Instructions Scroll
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInstructions(exercise['instructions']),
                    const SizedBox(height: 24),
                    
                    Text(
                      'FOCUS AREA',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB497FF),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Focus Area Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allFocusChips.map((area) => _buildFocusChip(area)).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Body Diagram
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          bodyDiagramAsset,
                          height: 250,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.accessibility_new, size: 100, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(dynamic instructions) {
    if (instructions == null) return const SizedBox();
    
    List<String> instructionList = [];
    if (instructions is List) {
      instructionList = List<String>.from(instructions);
    } else if (instructions is String) {
      instructionList = [instructions];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: instructionList.map((step) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(
          step,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildFocusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
