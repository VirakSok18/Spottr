import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/workout_program.dart';

class CompactWorkoutStructureCard extends StatelessWidget {
  final WorkoutProgram program;
  final VoidCallback onTap;
  final double imageHeight;

  final bool isPremium;

  const CompactWorkoutStructureCard({
    Key? key,
    required this.program,
    required this.onTap,
    this.imageHeight = 140,
    this.isPremium = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final schedule = program.schedule;
    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () => onTap());
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Section with Overlaid Text
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: program.thumbnail ?? '',
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: imageHeight,
                      color: Colors.white10,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8A2BE2))),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: imageHeight,
                      color: const Color(0xFF222222),
                      child: const Icon(Icons.fitness_center, color: Colors.white24, size: 40),
                    ),
                  ),
                  // Dark Gradient Overlay
                  Container(
                    height: imageHeight,
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
                    bottom: 12,
                    left: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${program.equipment} - ${program.difficulty}',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Schedule Section below image
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF323440),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(7, (index) {
                        final isActive = schedule[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFB794F6) : Colors.white10,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                weekDays[index],
                                style: GoogleFonts.poppins(
                                  color: isActive ? Colors.white : Colors.white24,
                                  fontSize: 8,
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
      ),
    );
  }
}
