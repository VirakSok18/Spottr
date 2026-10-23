import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class WorkoutCompletionScreen extends StatelessWidget {
  final String workoutName;
  final int exercisesCount;
  final String intensity;
  final String? coverUrl;
  final VoidCallback onFinish;

  const WorkoutCompletionScreen({
    Key? key,
    required this.workoutName,
    required this.exercisesCount,
    required this.intensity,
    this.coverUrl,
    required this.onFinish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: Column(
        children: [
          // Header Image with Overlay Text
          Stack(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.45,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                ),
                child: _buildCoverImage(),
              ),
              // Dark gradient overlay
              Positioned.fill(
                child: Container(
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
              ),
              // "WORKOUT COMPLETED!" Text
              Positioned(
                bottom: 20,
                left: 24,
                right: 24,
                child: Text(
                  'WORKOUT\nCOMPLETED!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Workout Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                workoutName.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStat('Intensity:', intensity.toUpperCase()),
                const SizedBox(width: 48),
                _buildStat('Exercises:', exercisesCount.toString()),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Bottom Finish Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'FINISH',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    if (coverUrl == null || coverUrl!.isEmpty) {
      return Image.network(
        'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=2070&auto=format&fit=crop',
        fit: BoxFit.cover,
      );
    }

    if (coverUrl!.startsWith('assets/')) {
      return Image.asset(coverUrl!, fit: BoxFit.cover);
    }

    return CachedNetworkImage(
      imageUrl: coverUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: const Color(0xFF2E2E2E)),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
