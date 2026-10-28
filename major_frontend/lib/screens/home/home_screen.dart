import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_screens.dart';
import 'plan_detail_screen.dart';
import '../../services/workout_generator.dart';
import '../../models/workout_models.dart';
import '../../services/video_preload_service.dart';
import '../../services/chat_service.dart';
import 'notification_screen.dart';
import 'premium_upgrade_screen.dart';
import 'package:major_frontend/services/notification_service.dart' as notif;
import 'package:major_frontend/services/local_exercise_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'workout_execution_screen.dart';
import '../../models/workout_program.dart';
import '../../services/workout_library_service.dart';
import '../../widgets/workout_structure_card.dart';
import '../social/user_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../services/config.dart' as app_config;

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final Function(int)? onTabSwitch;
  const HomeScreen({Key? key, required this.onLogout, this.onTabSwitch}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> suggestedPlans = [];
  bool isLoading = true;
  Map<String, dynamic>? _userData;
  
  // Classic Workout State
  String selectedCategory = 'Full Body';
  List<Exercise> classicWorkouts = [];
  bool isClassicLoading = true;
  final List<String> categories = ['Full Body', 'Arm', 'Shoulder', 'Back', 'Chest', 'Cores', 'Leg'];
  final Map<String, List<Exercise>> _classicWorkoutsCache = {};

  // Workout Structure State
  List<WorkoutProgram> workoutPrograms = [];
  bool isProgramsLoading = true;

  StreamSubscription? _postInteractionSubscription;
  StreamSubscription? _profileSubscription;

  @override
  void initState() {
    super.initState();
    // REMOVED: forced clear of suggested plans cache to allow persistence
    // SharedPreferences.getInstance().then((prefs) => prefs.remove('suggested_plans')); 
    _fetchSuggestedPlans();
    _fetchProfileData();
    _preloadClassicWorkouts(); // Preload everything for instant switching
    notif.NotificationService().getNotifications(); 

    // Listen for real-time post updates
    _postInteractionSubscription = ChatService().postInteractionStream.listen((event) {
      print('Home Screen: Received post interaction event: $event');
      _fetchSuggestedPlans();
    });

    // Listen for global profile updates
    _profileSubscription = AuthService.profileUpdates.listen((_) {
      print('Home Screen: Received profile update broadcast');
      _fetchProfileData();
    });

    _fetchWorkoutPrograms();
  }

  @override
  void dispose() {
    _postInteractionSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchSuggestedPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Try Fetching from Supabase (Source of Truth)
      final authUser = fb.FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        final res = await app_config.Config.supabase
            .from('user_plans')
            .select()
            .eq('userUid', authUser.uid)
            .order('createdAt', ascending: false);
        if (res.isNotEmpty) {
          List<dynamic> backendPlans = [];
          for (var row in res) {
            if (row['planData'] != null) {
              try {
                final parsed = jsonDecode(row['planData']);
                if (parsed is List) backendPlans.addAll(parsed);
                else if (parsed is Map) backendPlans.add(parsed);
              } catch (_) {}
            }
          }
          if (backendPlans.isNotEmpty) {
            if (mounted) {
              setState(() {
                suggestedPlans = backendPlans;
                isLoading = false;
              });
              _preloadAllPlans();
            }
            await prefs.setString('suggested_plans', jsonEncode(backendPlans));
            return;
          }
        }
      }

      // 2. Fallback to Local Cache (for offline or initial load)
      final savedPlansJson = prefs.getString('suggested_plans');
      if (savedPlansJson != null) {
        if (mounted) {
          setState(() {
            suggestedPlans = jsonDecode(savedPlansJson);
            isLoading = false;
          });
          _preloadAllPlans();
        }
        return;
      }

      // 3. Generate New Plans (First time user)
      final profile = _userData ?? await AuthService().getUserProfile();
      if (profile == null) return;
      
      if (mounted && _userData == null) {
        setState(() {
          _userData = profile;
        });
      }
      
      final user = User.fromProfile(profile);
      final generator = WorkoutGenerator();
      final plans = await generator.generatePlans(user);

      if (mounted) {
        final plansJson = plans.map((p) => p.toJson()).toList();
        setState(() {
          suggestedPlans = plansJson;
          isLoading = false;
        });

        // Save for stability
        await prefs.setString('suggested_plans', jsonEncode(plansJson));
        
        // Save to Backend for persistence
        _savePlansToBackend(plansJson);

        // Trigger aggressive preloading for ALL plans
        _preloadAllPlans();
      }
    } catch (e) {
      print('Error fetching plans: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _savePlansToBackend(List<dynamic> plansJson) async {
    try {
      final authUser = fb.FirebaseAuth.instance.currentUser;
      if (authUser == null) return;

      await app_config.Config.supabase.from('user_plans').insert({
        'userUid': authUser.uid,
        'planData': jsonEncode(plansJson),
        'isAI': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('Home Screen: Successfully saved plans to Supabase');
    } catch (e) {
      print('Error saving plans to Supabase: $e');
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final profile = await AuthService().getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _userData = profile;
        });
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

  Future<void> _fetchClassicWorkouts() async {
    // Check cache first for instant update
    if (_classicWorkoutsCache.containsKey(selectedCategory)) {
      setState(() {
        classicWorkouts = _classicWorkoutsCache[selectedCategory]!;
        isClassicLoading = false;
      });
      return;
    }

    setState(() => isClassicLoading = true);
    try {
      final exercises = await LocalExerciseService.getExercisesForClassicWorkout(selectedCategory);
      if (mounted) {
        setState(() {
          _classicWorkoutsCache[selectedCategory] = exercises;
          classicWorkouts = exercises;
          isClassicLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching classic workouts: $e');
      if (mounted) setState(() => isClassicLoading = false);
    }
  }

  /// Preloads classic workouts for all categories to ensure instant switching
  Future<void> _preloadClassicWorkouts() async {
    for (final category in categories) {
      try {
        final exercises = await LocalExerciseService.getExercisesForClassicWorkout(category);
        _classicWorkoutsCache[category] = exercises;
        
        // If this is the currently selected category, update the UI
        if (category == selectedCategory && mounted) {
          setState(() {
            classicWorkouts = exercises;
            isClassicLoading = false;
          });
        }
      } catch (e) {
        print('Error preloading classic workout for $category: $e');
      }
    }
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
  Future<void> _preloadAllPlans() async {
    for (final plan in suggestedPlans) {
      try {
        final days = plan['days'] as List<dynamic>?;
        if (days == null || days.isEmpty) continue;

        // Find first non-rest day
        dynamic firstWorkoutDay;
        for (final day in days) {
          if (day['isRestDay'] != true) {
             final exercises = day['exercises'] as List<dynamic>?;
             if (exercises != null && exercises.isNotEmpty) {
               firstWorkoutDay = day;
               break;
             }
          }
        }

        if (firstWorkoutDay != null) {
          final exercises = firstWorkoutDay['exercises'] as List<dynamic>;
          for (final exercise in exercises) {
            final videoId = exercise['youtubeId'];
            if (videoId != null && (videoId as String).isNotEmpty) {
              // Preload EVERY video
              print('Home Screen: Preloading video $videoId from plan ${plan['title']}');
              VideoPreloadService.instance.preload(videoId);
            }
          }
        }
      } catch (e) {
        print('Error preloading plan ${plan['title']}: $e');
      }
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
          'SPOTTR',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: notif.NotificationService().unreadCount,
            builder: (context, count, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationScreen()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB794F6),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (_userData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SocialUserProfileScreen(
                      userUid: fb.FirebaseAuth.instance.currentUser?.uid ?? '',
                      userName: _userData!['fullName'] ?? 'User',
                      userAvatar: _userData!['profilePictureUrl'],
                      userCover: _userData!['coverPhotoUrl'],
                    ),
                  ),
                );
              }
            },
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB794F6), width: 1.5),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: (_userData?['profilePictureUrl'] != null && _userData!['profilePictureUrl'].toString().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: _userData!['profilePictureUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: const Color(0xFF2E2E2E)),
                            errorWidget: (context, url, error) => const Icon(Icons.person, size: 16, color: Colors.white70),
                          )
                        : const Icon(Icons.person, size: 16, color: Colors.white70),
                  ),
                ),
              ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2)))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Classic Plan',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 253, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: suggestedPlans.length,
                        itemBuilder: (context, index) {
                          final plan = suggestedPlans[index];
                          return _buildPlanCardHorizontal(plan);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Classic Workout Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Classic Workout',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category Filters
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: FilterChip(
                              label: Text(
                                cat,
                                style: GoogleFonts.poppins(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    selectedCategory = cat;
                                  });
                                  _fetchClassicWorkouts();
                                }
                              },
                              backgroundColor: const Color(0xFF2A2A2A),
                              selectedColor: const Color(0xFF8A2BE2),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide.none,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Workout List
                    // Workout List - Classic Workout (This seems to be free based on prompt? 
                    // No, user said "locking workouts soo the classic plan like primary, secondary and balance plan will be lock"
                    // AND "same goes to workout structure section also lock")
                    // Wait, "Classic Plan" is lines 401-421. "Classic Workout" is 428-493. 
                    // User said: "classic plan like primary, secondary and balance plan will be lock"
                    // So lines 412-421 need locking.
                    // Lines 509-529 (Workout Structure) also need locking.
                    isClassicLoading
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Color(0xFF8A2BE2)),
                          ))
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: classicWorkouts.map((ex) => _buildClassicWorkoutCard(ex)).toList(),
                            ),
                          ),
                    const SizedBox(height: 24),

                    // Workout Structure Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Workout Structure',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    isProgramsLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8A2BE2)))
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: workoutPrograms.map((program) {
                                return WorkoutStructureCard(
                                      program: program,
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
                                    );
                              }).toList(),
                            ),
                          ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlanCardHorizontal(dynamic plan, {bool isPremium = true}) {
    String assetPath = 'assets/images/workout guy.png';
    String titleText = plan['title'].toString();
    String titleLower = titleText.toLowerCase();
    
    // Default gradient (Primary)
    List<Color> gradientColors = [
      const Color(0xFF8A2BE2), 
      const Color(0xFF4C187C), 
    ];

    double imgWidth = 188;
    double imgHeight = 194;

    if (titleLower.contains('primary')) {
      assetPath = 'assets/images/workout guy.png';
      gradientColors = [
        const Color(0xFF8A2BE2), 
        const Color(0xFF4C187C), 
      ];
      imgWidth = 188;
      imgHeight = 194;
    } else if (titleLower.contains('secondary')) {
      assetPath = 'assets/images/workout girl.png';
      gradientColors = [
        const Color(0xFF2B3AE2), 
        const Color(0xFF2E187C), 
      ];
      imgWidth = 167;
      imgHeight = 179;
    } else if (titleLower.contains('balance')) {
      assetPath = 'assets/images/another workout guy.png';
      gradientColors = [
        const Color(0xFF235179), 
        const Color(0xFF1B3D5A), 
      ];
      imgWidth = 127;
      imgHeight = 190;
    }

    return Container(
      width: 335,
      height: 238,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlanDetailScreen(plan: plan)),
                );
              }
            });
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors.reversed.toList(),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: 5,
                  bottom: 60,
                  child: SizedBox(
                    width: imgWidth,
                    height: imgHeight,
                    child: Image.asset(assetPath, fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 180,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  titleText.toUpperCase().replaceAll(' ', '\n'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SizedBox(
                                width: 150,
                                child: Text(
                                  plan['description'],
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PlanDetailScreen(plan: plan)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: Text(
                          'Start',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicWorkoutCard(Exercise workout) {
    final thumbUrl = "https://img.youtube.com/vi/${workout.youtubeId}/0.jpg";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF2A2C36),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // Determine sets and reps based on difficulty
            final diff = workout.difficulty.toLowerCase();
            int sets = 3;
            int reps = 12;
            
            if (diff == 'intermediate') {
              sets = 4;
              reps = 10;
            } else if (diff == 'expert' || diff == 'advanced') {
              sets = 5;
              reps = 8;
            }

            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutExecutionScreen(
                      exercises: [
                        {
                          'id': workout.id,
                          'name': workout.name,
                          'youtubeId': workout.youtubeId,
                          'instructions': workout.instructions,
                          'difficulty': workout.difficulty,
                          'targetMuscle': workout.targetMuscle,
                          'type': 'sets',
                          'sets': sets,
                          'reps': reps,
                        }
                      ],
                      dayTitle: selectedCategory,
                      workoutName: workout.name,
                      difficulty: workout.difficulty,
                      coverUrl: "https://img.youtube.com/vi/${workout.youtubeId}/0.jpg",
                    ),
                  ),
                );
              }
            });
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: Colors.black26,
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                      errorWidget: (context, url, error) => const Icon(Icons.fitness_center, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        workout.difficulty.toLowerCase() == 'expert' ? 'Advanced' : workout.difficulty[0].toUpperCase() + workout.difficulty.substring(1),
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
