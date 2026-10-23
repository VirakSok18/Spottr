import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/local_exercise_service.dart';
import '../../models/workout_models.dart';
import '../../models/workout_program.dart';
import 'package:major_frontend/services/workout_library_service.dart';
import 'premium_upgrade_screen.dart';
import '../../widgets/compact_workout_structure_card.dart';
import 'focus_area_workouts_screen.dart';
import 'plan_detail_screen.dart';
import '../auth/auth_screens.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final List<Map<String, String>> focusAreas = [
    {'name': 'Core', 'image': 'assets/images/core_1.png', 'target': 'abdominals'},
    {'name': 'Arm', 'image': 'assets/images/arm_1.png', 'target': 'biceps,triceps,forearms'},
    {'name': 'Chest', 'image': 'assets/images/chest_1.png', 'target': 'chest'},
    {'name': 'Full Body', 'image': 'assets/images/fullbody_1.png', 'target': 'full body'},
    {'name': 'Shoulder', 'image': 'assets/images/shoulder_1.png', 'target': 'shoulders'},
    {'name': 'Back', 'image': 'assets/images/back_1.png', 'target': 'back,lats'},
    {'name': 'Leg', 'image': 'assets/images/leg_1.png', 'target': 'quadriceps,hamstrings,calves,glutes'},
  ];

  final List<String> difficulties = ['Beginner', 'Intermediate', 'Expert'];
  final List<Map<String, String>> equipments = [
    {'name': 'BW', 'target': 'body only'},
    {'name': 'Dumbbell', 'target': 'dumbbell'},
    {'name': 'Barbell', 'target': 'barbell'},
    {'name': 'Cable', 'target': 'cable'},
    {'name': 'Machine', 'target': 'machine'},
    {'name': 'Kettlebell', 'target': 'kettlebell'},
    {'name': 'Band', 'target': 'band'},
  ];

  final List<Map<String, String>> locations = [
    {'name': 'Home Workout', 'target': 'home', 'image': 'assets/images/home_workout.png'},
    {'name': 'Gym Workout', 'target': 'gym', 'image': 'assets/images/gym_workout.png'},
    {'name': 'Outdoor', 'target': 'outdoor', 'image': 'assets/images/outdoor_workout.png'},
  ];

  Map<String, int> areaCounts = {};
  Map<String, int> difficultyCounts = {};
  Map<String, int> equipmentCounts = {};
  Map<String, int> locationCounts = {};
  
  List<WorkoutProgram> workoutPrograms = [];
  bool isProgramsLoading = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllCounts();
    _fetchWorkoutPrograms();
    // Silently sync profile to update premium notifier
    AuthService().getUserProfile();
  }


  Future<void> _fetchWorkoutPrograms() async {
    setState(() => isProgramsLoading = true);
    try {
      final programs = await WorkoutLibraryService.fetchPrograms();
      if (mounted) {
        setState(() {
          workoutPrograms = programs;
          isProgramsLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching workout programs: $e');
      if (mounted) setState(() => isProgramsLoading = false);
    }
  }

  Future<void> _loadAllCounts() async {
    // Load Focus Area counts
    for (var area in focusAreas) {
      final exercises = await LocalExerciseService.getExercisesByTarget(area['target']!);
      areaCounts[area['name']!] = exercises.length;
    }
    
    // Load Difficulty counts
    for (var diff in difficulties) {
      final exercises = await LocalExerciseService.getExercisesByDifficulty(diff);
      difficultyCounts[diff] = exercises.length;
    }

    // Load Equipment counts
    for (var equip in equipments) {
      final exercises = await LocalExerciseService.getExercisesByEquipment(equip['target']!);
      equipmentCounts[equip['name']!] = exercises.length;
    }

    // Load Location counts
    for (var loc in locations) {
      final exercises = await LocalExerciseService.getExercisesByLocation(loc['target']!);
      locationCounts[loc['target']!] = exercises.length;
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Workouts',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // Focus Areas Row
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: focusAreas.length,
                itemBuilder: (context, index) {
                  final area = focusAreas[index];
                  final count = areaCounts[area['name']] ?? 0;
                  return _buildFocusAreaItem(area, count);
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Difficulty Section
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: difficulties.length,
                itemBuilder: (context, index) {
                  final diff = difficulties[index];
                  return _buildFilterBlock(diff, 'difficulty', diff);
                },
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Equipment Section
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: equipments.length,
                itemBuilder: (context, index) {
                  final equip = equipments[index];
                  return _buildFilterBlock(equip['name']!, 'equipment', equip['target']!);
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Picks For You Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "POPULAR'S CHOICE",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB794F6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Picks For You",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250, // Increased height for larger cinematic cards
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  final count = locationCounts[loc['target']] ?? 0;
                  return _buildLocationCard(loc, count);
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Workout Structure Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Workout Structure",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            isProgramsLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2)))
                : ValueListenableBuilder<bool>(
                    valueListenable: AuthService.isPremiumUser,
                    builder: (context, isPremium, child) {
                      return SizedBox(
                        height: 195, // Adjusted to fit the compact card perfectly
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: workoutPrograms.length,
                          itemBuilder: (context, index) {
                            final program = workoutPrograms[index];
                            return Container(
                              width: 260, // Smaller width for side-by-side feel
                              margin: const EdgeInsets.only(right: 16),
                              child: CompactWorkoutStructureCard(
                                program: program,
                                imageHeight: 140,
                                isPremium: isPremium,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlanDetailScreen(
                                        plan: program.toMap(),
                                        isStructured: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    }
                  ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, String> loc, int count) {
    return Container(
      width: 360, // Much larger width for cinematic look
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FocusAreaWorkoutsScreen(
                  focusArea: loc['name']!,
                  targetMuscle: loc['target']!,
                  filterType: 'location',
                ),
              ),
            );
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(
                image: AssetImage(loc['image']!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.35),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB794F6).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count Workouts',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    loc['name']!.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 32, // Larger font for big cards
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBlock(String label, String type, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FocusAreaWorkoutsScreen(
                  focusArea: label,
                  targetMuscle: value,
                  filterType: type,
                ),
              ),
            );
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusAreaItem(Map<String, String> area, int count) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FocusAreaWorkoutsScreen(
                  focusArea: area['name']!,
                  targetMuscle: area['target']!,
                  filterType: 'muscle',
                ),
              ),
            );
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Column(
            children: [
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      area['image']!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                area['name']!,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '$count Workouts',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                "Structured Programs are only available to Premium members. Upgrade now to unlock them!",
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
}
