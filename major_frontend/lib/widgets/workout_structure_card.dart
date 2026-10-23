import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/workout_program.dart';

class WorkoutStructureCard extends StatelessWidget {
  final WorkoutProgram program;
  final VoidCallback onTap;
  final bool isPremium;

  const WorkoutStructureCard({
    Key? key,
    required this.program,
    required this.onTap,
    this.isPremium = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final schedule = program.schedule;
    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2C36),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Image Section with Overlaid Text
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: program.thumbnail ?? '',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.white10,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8A2BE2))),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: const Color(0xFF222222),
                      child: const Icon(Icons.fitness_center, color: Colors.white24, size: 40),
                    ),
                  ),
                  // Dark Gradient Overlay
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                  // Title and Subtitle Overlaid
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${program.equipment} - ${program.difficulty}',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Schedule Section below image
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF323440),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Workout Schedule',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: List.generate(7, (index) {
                      final isActive = schedule[index];
                      return Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFB794F6) : Colors.white10,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weekDays[index],
                              style: GoogleFonts.poppins(
                                color: isActive ? Colors.white : Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
