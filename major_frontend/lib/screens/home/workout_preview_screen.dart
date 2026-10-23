import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'workout_execution_screen.dart';
import '../auth/auth_screens.dart';
import 'premium_upgrade_screen.dart';

class WorkoutPreviewScreen extends StatefulWidget {
  final dynamic plan;
  final dynamic day;

  const WorkoutPreviewScreen({
    Key? key,
    required this.plan,
    required this.day,
  }) : super(key: key);

  @override
  State<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends State<WorkoutPreviewScreen> {
  bool _isPremium = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final profile = await AuthService().getUserProfile();
      if (mounted) {
        setState(() {
          _isPremium = (profile?['isPremium'] == true || profile?['isPremium'] == 1);
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB794F6), size: 60),
              const SizedBox(height: 16),
              Text(
                "Premium Feature",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Classic Plans and Structured Programs are only available to Premium members. Upgrade now to unlock them!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PremiumUpgradeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Unlock Everything",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Maybe Later",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.day['exercises'] as List<dynamic>? ?? [];
    final dayTitle = widget.day['title'] ?? 'Workout';
    final dayNumber = widget.day['day'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Header Image with Title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildHeaderImage(exercises),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.purple.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 70,
                  right: 24,
                  child: Text(
                    dayTitle.toString().toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
                // Back Button
                Positioned(
                  top: 50,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          // Content with Curved Top
          Positioned.fill(
            top: 240,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    Text(
                      _getDescription(dayTitle),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Exercises',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...exercises.asMap().entries.map((entry) {
                      int idx = entry.key;
                      dynamic ex = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () async {
                              if (_isLoadingProfile) return;
                              if (!_isPremium) {
                                _showPremiumUpgradeDialog();
                                return;
                              }
                              // Slight delay for premium feel
                              await Future.delayed(const Duration(milliseconds: 100));
                              if (context.mounted) {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WorkoutExecutionScreen(
                                      exercises: exercises,
                                      dayTitle: 'Day $dayNumber',
                                      workoutName: dayTitle,
                                      initialIndex: idx,
                                      difficulty: widget.plan['difficulty']?.toString() ?? 'Medium',
                                      coverUrl: _getPlanCover(widget.plan, exercises),
                                    ),
                                  ),
                                );
                                if (result == true && context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              }
                            },
                            splashColor: Colors.white.withOpacity(0.1),
                            highlightColor: Colors.white.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _buildExerciseItem(ex),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
            ),
          ),
          // Bottom Start Button
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: _isLoadingProfile 
              ? const SizedBox.shrink()
              : ElevatedButton(
                  onPressed: () async {
                    if (!_isPremium) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PremiumUpgradeScreen()),
                      );
                      return;
                    }
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutExecutionScreen(
                          exercises: exercises,
                          dayTitle: 'Day $dayNumber',
                          workoutName: dayTitle,
                          difficulty: widget.plan['difficulty']?.toString() ?? 'Medium',
                          coverUrl: _getPlanCover(widget.plan, exercises),
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isPremium 
                    ? Text(
                        'Start',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Go Premium',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage(List<dynamic> exercises) {
    String? imageUrl;
    if (widget.plan['imageUrl'] != null) {
      imageUrl = widget.plan['imageUrl'];
    } else if (exercises.isNotEmpty) {
      final firstEx = exercises[0];
      if (firstEx['youtubeId'] != null && firstEx['youtubeId'].toString().isNotEmpty) {
        imageUrl = "https://img.youtube.com/vi/${firstEx['youtubeId']}/0.jpg";
      } else {
        imageUrl = firstEx['imageUrl'];
      }
    }

    if (imageUrl != null && imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.cover);
    } else if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.black26),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    }

    return Container(
      color: const Color(0xFF222222),
    );
  }

  String? _getPlanCover(dynamic plan, List<dynamic> exercises) {
    if (plan['imageUrl'] != null) return plan['imageUrl'];
    if (exercises.isNotEmpty) {
      final firstEx = exercises[0];
      if (firstEx['youtubeId'] != null && firstEx['youtubeId'].toString().isNotEmpty) {
        return "https://img.youtube.com/vi/${firstEx['youtubeId']}/0.jpg";
      }
      return firstEx['imageUrl'];
    }
    return null;
  }

  Widget _buildExerciseItem(dynamic exercise) {
    final sets = exercise['sets'] ?? '3';
    final reps = exercise['reps'] ?? '10';
    
    String? imageUrl;
    if (exercise['youtubeId'] != null && exercise['youtubeId'].toString().isNotEmpty) {
      imageUrl = "https://img.youtube.com/vi/${exercise['youtubeId']}/0.jpg";
    } else {
      imageUrl = exercise['imageUrl'];
    }

    return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.white10,
              child: imageUrl != null
                  ? (imageUrl.startsWith('assets/') 
                      ? Image.asset(imageUrl, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (context, url, error) => const Icon(Icons.fitness_center, color: Colors.white54),
                        ))
                  : const Icon(Icons.fitness_center, color: Colors.white54),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'] ?? 'Exercise',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.fitness_center_outlined, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$sets sets x $reps reps',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
  }

  String _getDescription(String title) {
    return "This is a focused workout designed to hit all targeted muscle groups for $title. It includes effective movements for strength and conditioning, ensuring core stability and metabolic burn.";
  }
}
